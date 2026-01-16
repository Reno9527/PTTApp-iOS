import Foundation

/// NRL21 协议常量
public enum NRL21Constants {
    /// 版本标识 "NRL2"
    public static let version: [UInt8] = [0x4E, 0x52, 0x4C, 0x32]

    /// 包头大小
    public static let headerSize = 48

    /// 负载大小
    public static let payloadSize = 500

    /// 完整包大小
    public static let packetSize = headerSize + payloadSize

    /// 心跳包大小（仅头部）
    public static let heartbeatSize = headerSize
}

/// 包类型 (与小程序一致)
public enum NRL21PacketType: UInt8, Sendable {
    case voice = 1          // G.711 语音
    case heartbeat = 2      // 心跳 (包含位置信息 offset 32-39)
    case text = 5           // 文本消息
    case opus = 8           // Opus 语音
    case serverVoice = 9    // 服务器互联语音 (DMR/YSF 等数字网络)
    case unknown = 255
}

/// NRL21 协议解析器
public struct NRL21Protocol: Sendable {

    // MARK: - 解析统计

    /// 解析错误统计（用于监控异常包）
    public struct ParseStats: Sendable {
        public var shortPackets: UInt64 = 0        // 包长度不足 header
        public var invalidVersion: UInt64 = 0      // 版本标识错误
        public var invalidLength: UInt64 = 0       // Length 字段异常
        public var totalParsed: UInt64 = 0         // 总解析次数
    }

    /// 全局解析统计（线程安全）
    private static let statsLock = NSLock()
    private static var _stats = ParseStats()

    /// 获取解析统计
    public static var stats: ParseStats {
        statsLock.lock()
        defer { statsLock.unlock() }
        return _stats
    }

    /// 重置解析统计
    public static func resetStats() {
        statsLock.lock()
        _stats = ParseStats()
        statsLock.unlock()
    }

    // MARK: - 解析结果

    /// 解析后的包
    public struct Packet: Sendable {
        /// 包类型
        public let type: NRL21PacketType

        /// 序列号
        public let seq: UInt16

        /// 呼号
        public let callSign: String

        /// SSID
        public let ssid: Int

        /// 纬度 (心跳包使用, offset 32-35)
        public let latitude: Float?

        /// 经度 (心跳包使用, offset 36-39)
        public let longitude: Float?

        /// 负载数据
        public let payload: Data

        // MARK: - Type 9 服务器互联扩展字段

        /// DMR ID (Type 9, offset 6-14, 9字节字符串)
        public let dmrID: String?

        /// 原始呼号 (Type 9, offset 32-37, 6字节)
        public let origCallSign: String?

        /// 原始 SSID (Type 9, offset 38)
        public let origSSID: Int?

        /// 原始 IP (Type 9, offset 39-42)
        public let origIP: UInt32?

        /// 是否为服务器互联包 (SSID=200 且 Type=9)
        public var isServerInterconnect: Bool {
            return ssid == 200 && type == .serverVoice
        }

        /// 获取显示用呼号 (服务器互联时优先使用原始呼号)
        public var displayCallSign: String {
            if ssid == 200, let orig = origCallSign, !orig.isEmpty {
                return orig
            }
            return callSign
        }

        /// 获取显示用 SSID (服务器互联时使用原始 SSID)
        public var displaySSID: Int {
            if ssid == 200, let orig = origSSID {
                return orig
            }
            return ssid
        }

        /// 获取完整显示字符串 (呼号-SSID 或 DMR:ID)
        public var displayString: String {
            if ssid == 200 {
                // 服务器互联
                if let orig = origCallSign, !orig.isEmpty {
                    if let origSsid = origSSID, origSsid > 0 {
                        return "\(orig)-\(origSsid)"
                    }
                    return orig
                } else if let dmr = dmrID, !dmr.isEmpty {
                    return "DMR:\(dmr)"
                }
            }
            // 普通用户或 fallback
            return "\(callSign)-\(ssid)"
        }
    }

    // MARK: - 解析

    /// 解析 NRL21 数据包
    /// - Parameter data: 原始数据（48 或 548 字节）
    /// - Returns: 解析后的包，如果无效返回 nil
    public static func parse(_ data: Data) -> Packet? {
        statsLock.lock()
        _stats.totalParsed += 1
        statsLock.unlock()

        // 1. 长度检查（至少需要头部）
        guard data.count >= NRL21Constants.headerSize else {
            statsLock.lock()
            _stats.shortPackets += 1
            statsLock.unlock()
            return nil
        }

        // 2. 版本检查 "NRL2" (offset 0-3)
        guard data[0] == 0x4E && data[1] == 0x52 &&
              data[2] == 0x4C && data[3] == 0x32 else {
            statsLock.lock()
            _stats.invalidVersion += 1
            statsLock.unlock()
            return nil
        }

        // 3. Length 字段检查 (offset 4-5, Big-Endian)
        //    协议规范：固定为 48，表示 header 大小
        //    兼容策略：不等于 48 时记录统计但继续解析（向后兼容）
        let lengthField = UInt16(data[4]) << 8 | UInt16(data[5])
        if lengthField != UInt16(NRL21Constants.headerSize) {
            statsLock.lock()
            _stats.invalidLength += 1
            statsLock.unlock()
            // 不返回 nil，保持向后兼容，但已记录异常
        }

        // 4. 提取类型 (offset 20)
        let type = NRL21PacketType(rawValue: data[20]) ?? .unknown

        // 5. 提取计数/序列号 (offset 22-23, big-endian)
        let seq = UInt16(data[22]) << 8 | UInt16(data[23])

        // 6. 提取呼号 (offset 24-29, 6 bytes)
        let callSignData = data[24..<30]
        let callSign = String(data: callSignData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) ?? ""

        // 7. 提取 SSID (offset 30, 1 byte)
        let ssid = Int(data[30])

        // 8. DMR ID (offset 6-14, 9字节字符串) - 所有语音包类型都解析
        var dmrID: String? = nil
        if (type == .voice || type == .opus || type == .serverVoice) && data.count >= 15 {
            let dmrIDData = data[6..<15]
            let rawDmrID = String(data: dmrIDData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            // 只有非空且非全零时才设置
            if let raw = rawDmrID, !raw.isEmpty, raw != "000000000" {
                dmrID = raw
            }
        }

        // 9. Type 9 扩展字段 (服务器互联)
        var origCallSign: String? = nil
        var origSSID: Int? = nil
        var origIP: UInt32? = nil

        // 10. 提取经纬度或 Type 9 扩展字段 (offset 32-42)
        var latitude: Float? = nil
        var longitude: Float? = nil

        if type == .serverVoice && data.count >= 43 {
            // Type 9: 解析服务器互联扩展字段
            // OrigCallSign (offset 32-37, 6字节)
            let origCallSignData = data[32..<38]
            origCallSign = String(data: origCallSignData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))

            // OrigSSID (offset 38)
            origSSID = Int(data[38])

            // OrigIP (offset 39-42, Big-Endian)
            origIP = UInt32(data[39]) << 24 | UInt32(data[40]) << 16 | UInt32(data[41]) << 8 | UInt32(data[42])

        } else if (type == .heartbeat || type == .voice || type == .opus) && data.count >= 40 {
            // 其他类型: 解析经纬度
            // 提取纬度 (offset 32-35)
            let latBits = UInt32(data[32]) << 24 | UInt32(data[33]) << 16 | UInt32(data[34]) << 8 | UInt32(data[35])
            let latValue = Float(bitPattern: latBits)
            // 提取经度 (offset 36-39)
            let lonBits = UInt32(data[36]) << 24 | UInt32(data[37]) << 16 | UInt32(data[38]) << 8 | UInt32(data[39])
            let lonValue = Float(bitPattern: lonBits)
            // 只有有效坐标才设置 (非 NaN、在合理范围内、且不是 (0,0))
            // 注意: 协议规定 (0, 0) 表示"无位置信息"
            if !latValue.isNaN && !lonValue.isNaN &&
               latValue >= -90 && latValue <= 90 &&
               lonValue >= -180 && lonValue <= 180 &&
               !(latValue == 0 && lonValue == 0) {
                latitude = latValue
                longitude = lonValue
            }
        }

        // 10. 提取负载 (使用 data.count 做边界检查，防止越界)
        var payload = Data()
        if data.count > NRL21Constants.headerSize {
            let availablePayload = data.count - NRL21Constants.headerSize
            if type == .opus || type == .text {
                // Opus/文本包: 可变长度负载，取实际可用长度
                payload = Data(data[NRL21Constants.headerSize..<data.count])
            } else {
                // G711/ServerVoice 包: 期望 500 字节，但只取实际可用的
                let payloadLen = min(availablePayload, NRL21Constants.payloadSize)
                payload = Data(data[NRL21Constants.headerSize..<(NRL21Constants.headerSize + payloadLen)])
            }
        }

        return Packet(
            type: type,
            seq: seq,
            callSign: callSign,
            ssid: ssid,
            latitude: latitude,
            longitude: longitude,
            payload: payload,
            dmrID: dmrID,
            origCallSign: origCallSign,
            origSSID: origSSID,
            origIP: origIP
        )
    }

    // MARK: - 构建

    /// 构建信息
    public struct BuildInfo: Sendable {
        public let callSign: String
        public let ssid: Int
        public let dmrID: String?

        public init(callSign: String, ssid: Int, dmrID: String? = nil) {
            self.callSign = callSign
            self.ssid = ssid
            self.dmrID = dmrID
        }
    }

    /// 构建通用头部 (48字节)
    /// - Parameters:
    ///   - type: 包类型
    ///   - count: 计数/序列号
    ///   - info: 构建信息
    /// - Returns: 48字节头部
    private static func buildHeader(
        type: NRL21PacketType,
        count: UInt16,
        info: BuildInfo
    ) -> Data {
        var header = Data(count: NRL21Constants.headerSize)

        // Version "NRL2" (offset 0-3)
        header[0] = 0x4E
        header[1] = 0x52
        header[2] = 0x4C
        header[3] = 0x32

        // Length (offset 4-5, Big-Endian, 固定48)
        header[4] = 0x00
        header[5] = 0x30  // 48

        // DMRID (offset 6-14, 9字节 ASCII)
        if let dmrID = info.dmrID, !dmrID.isEmpty {
            let dmrIDBytes = dmrID.prefix(9).data(using: .ascii) ?? Data()
            for (i, byte) in dmrIDBytes.enumerated() {
                header[6 + i] = byte
            }
        }

        // (保留 offset 15-19)

        // Type (offset 20)
        header[20] = type.rawValue

        // Status (offset 21, 默认1)
        header[21] = 1

        // Count (offset 22-23, Big-Endian)
        header[22] = UInt8((count >> 8) & 0xFF)
        header[23] = UInt8(count & 0xFF)

        // CallSign (offset 24-29, 6 bytes, ASCII)
        let callSignBytes = info.callSign.prefix(6).data(using: .ascii) ?? Data()
        for (i, byte) in callSignBytes.enumerated() {
            header[24 + i] = byte
        }

        // SSID (offset 30)
        header[30] = UInt8(info.ssid)

        // DevMode (offset 31, iOS 固定 106)
        header[31] = 106

        // (保留 offset 32-47)

        return header
    }

    /// 写入位置信息到头部 (offset 32-39)
    private static func writeLocation(to header: inout Data, latitude: Double?, longitude: Double?) {
        guard let lat = latitude, let lon = longitude else { return }

        let latFloat = Float(lat)
        let lonFloat = Float(lon)
        let latBits = latFloat.bitPattern
        let lonBits = lonFloat.bitPattern

        // 纬度 (offset 32-35, Big-Endian)
        header[32] = UInt8((latBits >> 24) & 0xFF)
        header[33] = UInt8((latBits >> 16) & 0xFF)
        header[34] = UInt8((latBits >> 8) & 0xFF)
        header[35] = UInt8(latBits & 0xFF)

        // 经度 (offset 36-39, Big-Endian)
        header[36] = UInt8((lonBits >> 24) & 0xFF)
        header[37] = UInt8((lonBits >> 16) & 0xFF)
        header[38] = UInt8((lonBits >> 8) & 0xFF)
        header[39] = UInt8(lonBits & 0xFF)
    }

    /// 构建语音包
    /// - Parameters:
    ///   - payload: G.711 负载（500 字节）
    ///   - seq: 序列号
    ///   - info: 构建信息 (包含 dmrID)
    ///   - latitude: 纬度 (可选，嵌入 header offset 32-35)
    ///   - longitude: 经度 (可选，嵌入 header offset 36-39)
    /// - Returns: 完整的 548 字节数据包
    public static func buildVoicePacket(
        payload: Data,
        seq: UInt16,
        info: BuildInfo,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Data {
        // 构建头部 (Length 固定48，DMRID 已在 buildHeader 中写入)
        var packet = buildHeader(
            type: .voice,
            count: seq,
            info: info
        )

        // 写入位置信息
        writeLocation(to: &packet, latitude: latitude, longitude: longitude)

        // 扩展到 548 字节
        packet.append(Data(count: NRL21Constants.payloadSize))

        // 填充负载 (offset 48-547)
        let payloadData = payload.prefix(NRL21Constants.payloadSize)
        for (i, byte) in payloadData.enumerated() {
            packet[NRL21Constants.headerSize + i] = byte
        }

        // 如果负载不足 500 字节，填充 A-law 静音 (0x55)
        if payloadData.count < NRL21Constants.payloadSize {
            for i in payloadData.count..<NRL21Constants.payloadSize {
                packet[NRL21Constants.headerSize + i] = 0x55
            }
        }

        return packet
    }

    /// 构建结束包
    /// - Parameters:
    ///   - seq: 序列号
    ///   - info: 构建信息
    /// - Returns: 完整的 548 字节数据包
    public static func buildEndPacket(seq: UInt16, info: BuildInfo) -> Data {
        // 结束包是全静音的语音包
        let silentPayload = Data(repeating: 0x55, count: NRL21Constants.payloadSize)
        return buildVoicePacket(payload: silentPayload, seq: seq, info: info)
    }

    /// 构建 Opus 语音包 (可变长度)
    /// - Parameters:
    ///   - payload: Opus 编码负载 (可变长度，通常 20-100 字节)
    ///   - seq: 序列号
    ///   - info: 构建信息 (包含 dmrID)
    ///   - latitude: 纬度 (可选，嵌入 header offset 32-35)
    ///   - longitude: 经度 (可选，嵌入 header offset 36-39)
    /// - Returns: 完整的数据包 (48 字节头部 + Opus 负载)
    public static func buildOpusPacket(
        payload: Data,
        seq: UInt16,
        info: BuildInfo,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Data {
        // 构建头部 (DMRID 已在 buildHeader 中写入)
        var packet = buildHeader(
            type: .opus,
            count: seq,
            info: info
        )

        // 写入位置信息
        writeLocation(to: &packet, latitude: latitude, longitude: longitude)

        // 直接追加 Opus 负载（可变长度）
        packet.append(payload)

        return packet
    }

    /// 构建心跳包 (仅头部 48 字节，包含位置信息)
    /// - Parameters:
    ///   - callSign: 呼号
    ///   - ssid: SSID
    ///   - dmrID: DMR ID (可选)
    ///   - latitude: 纬度 (可选)
    ///   - longitude: 经度 (可选)
    /// - Returns: 48 字节心跳包
    public static func createHeartbeatPacket(
        callSign: String,
        ssid: Int,
        dmrID: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> Data {
        let info = BuildInfo(callSign: callSign, ssid: ssid, dmrID: dmrID)
        var header = buildHeader(
            type: .heartbeat,
            count: 0,
            info: info
        )

        // 写入位置信息
        writeLocation(to: &header, latitude: latitude, longitude: longitude)

        return header
    }

    /// 构建文本消息包
    /// - Parameters:
    ///   - text: 文本内容 (UTF-8)
    ///   - info: 构建信息
    /// - Returns: 完整的 548 字节数据包
    public static func buildTextPacket(
        text: String,
        info: BuildInfo
    ) -> Data {
        // 构建头部
        var packet = buildHeader(
            type: .text,
            count: 0,
            info: info
        )

        // 扩展到 548 字节
        packet.append(Data(count: NRL21Constants.payloadSize))

        // 填充文本数据 (UTF-8 编码)
        if let textData = text.data(using: .utf8) {
            let textBytes = textData.prefix(NRL21Constants.payloadSize)
            for (i, byte) in textBytes.enumerated() {
                packet[NRL21Constants.headerSize + i] = byte
            }
        }

        return packet
    }

    /// 构建紧凑文本消息包 (可变长度，用于 LOC 等短消息)
    /// - Parameters:
    ///   - text: 文本内容 (UTF-8)
    ///   - info: 构建信息
    /// - Returns: 48字节头部 + 实际文本长度
    public static func buildCompactTextPacket(
        text: String,
        info: BuildInfo
    ) -> Data {
        // 构建头部
        var packet = buildHeader(
            type: .text,
            count: 0,
            info: info
        )

        // 直接追加文本数据 (不填充)
        if let textData = text.data(using: .utf8) {
            packet.append(textData)
        }

        return packet
    }
}
