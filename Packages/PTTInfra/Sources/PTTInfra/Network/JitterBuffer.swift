import Foundation

/// 自适应网络抖动缓冲（FIFO 队列 + 动态深度调整）
///
/// 简化设计原因：某些设备的协议 count 字段固定为 0，不递增
/// 因此不能使用序列号检测乱序，采用 FIFO 队列按接收顺序播放
/// 与 Flutter 版本和小程序保持一致
///
/// 自适应策略：
/// - 默认 62ms（1包深度），低延迟
/// - 10秒内欠载 > 3次，自动升到 120ms
/// - 连续稳定 30秒，降回 62ms
public final class JitterBuffer: @unchecked Sendable {

    // MARK: - 配置

    /// 缓冲配置
    public struct Config: Sendable {
        /// 最小目标缓存深度（毫秒）- 低延迟模式
        public let minTargetBufferMs: Int

        /// 最大目标缓存深度（毫秒）- 高稳定模式
        public let maxTargetBufferMs: Int

        /// 最大缓存深度（毫秒）- 超过则丢弃旧包
        public let maxBufferMs: Int

        /// 单包时长（毫秒）
        /// G711 500B @ 8kHz ≈ 62.5ms
        public let packetDurationMs: Int

        /// 自适应：检测窗口（秒）
        public let adaptiveWindowSec: Int

        /// 自适应：窗口内欠载阈值，超过则升级
        public let underrunThreshold: Int

        /// 自适应：稳定时间（秒），无欠载则降级
        public let stableTimeSec: Int

        /// 默认配置（自适应）
        public static let `default` = Config(
            minTargetBufferMs: 62,      // 1 包深度，低延迟
            maxTargetBufferMs: 120,     // 2 包深度，高稳定
            maxBufferMs: 300,           // 约 5 包
            packetDurationMs: 62,
            adaptiveWindowSec: 10,      // 10秒窗口
            underrunThreshold: 3,       // 3次欠载触发升级
            stableTimeSec: 30           // 30秒稳定后降级
        )

        public init(
            minTargetBufferMs: Int,
            maxTargetBufferMs: Int,
            maxBufferMs: Int,
            packetDurationMs: Int,
            adaptiveWindowSec: Int = 10,
            underrunThreshold: Int = 3,
            stableTimeSec: Int = 30
        ) {
            self.minTargetBufferMs = minTargetBufferMs
            self.maxTargetBufferMs = maxTargetBufferMs
            self.maxBufferMs = maxBufferMs
            self.packetDurationMs = packetDurationMs
            self.adaptiveWindowSec = adaptiveWindowSec
            self.underrunThreshold = underrunThreshold
            self.stableTimeSec = stableTimeSec
        }
    }

    // MARK: - 统计

    /// 统计信息
    public struct Stats: Sendable {
        public var packetsReceived: UInt64 = 0
        public var currentBufferMs: Int = 0
        public var underrunCount: UInt64 = 0
        public var currentTargetMs: Int = 0
        public var isHighStabilityMode: Bool = false
    }

    // MARK: - 属性

    private let config: Config
    private var fifoBuffer: [Packet] = []
    private var isBuffering = true
    private let lock = NSLock()

    /// 当前动态目标深度
    private var currentTargetBufferMs: Int

    /// 自适应状态
    private var underrunTimestamps: [Date] = []  // 欠载时间记录
    private var lastUnderrunTime: Date?          // 最后一次欠载时间
    private var stableSince: Date?               // 开始稳定的时间

    /// 统计信息
    public private(set) var stats = Stats()

    // MARK: - 数据包结构

    /// 数据包
    public struct Packet: Sendable {
        public let seq: UInt16
        public let timestamp: UInt32
        public let payload: Data
        public let codec: AudioCodec

        public init(seq: UInt16, timestamp: UInt32, payload: Data, codec: AudioCodec = .g711) {
            self.seq = seq
            self.timestamp = timestamp
            self.payload = payload
            self.codec = codec
        }
    }

    // MARK: - 回调

    /// 数据包就绪回调
    public var onPacketReady: ((Packet) -> Void)?

    // MARK: - 初始化

    public init(config: Config = .default) {
        self.config = config
        self.currentTargetBufferMs = config.minTargetBufferMs
        self.stableSince = Date()
    }

    // MARK: - 公开方法

    /// 推送数据包
    /// - Parameter packet: 数据包
    public func push(_ packet: Packet) {
        push(seq: packet.seq, payload: packet.payload, codec: packet.codec)
    }

    /// 推送数据包
    /// - Parameters:
    ///   - seq: 序列号（仅用于统计）
    ///   - payload: 负载数据
    ///   - codec: 编码格式
    public func push(seq: UInt16, payload: Data, codec: AudioCodec = .g711) {
        var packetsToOutput: [Packet] = []

        lock.lock()

        stats.packetsReceived += 1

        // 直接添加到 FIFO 队列尾部
        let nowMs = UInt64(Date().timeIntervalSince1970 * 1000)
        let packet = Packet(
            seq: seq,
            timestamp: UInt32(truncatingIfNeeded: nowMs),
            payload: Data(payload),
            codec: codec
        )
        fifoBuffer.append(packet)

        // 更新统计
        stats.currentBufferMs = fifoBuffer.count * config.packetDurationMs

        // 限制缓冲区大小，溢出时丢弃最旧的包
        let maxPackets = config.maxBufferMs / config.packetDurationMs
        while fifoBuffer.count > maxPackets {
            fifoBuffer.removeFirst()
        }

        // 检查是否可以输出（使用动态目标深度）
        if isBuffering && stats.currentBufferMs >= currentTargetBufferMs {
            isBuffering = false
        }

        // 直接输出所有包（低延迟方案，靠 AudioUnit 缓冲区平滑）
        if !isBuffering {
            while !fifoBuffer.isEmpty {
                packetsToOutput.append(fifoBuffer.removeFirst())
            }
            stats.currentBufferMs = 0
        }

        // 更新统计
        stats.currentTargetMs = currentTargetBufferMs
        stats.isHighStabilityMode = currentTargetBufferMs > config.minTargetBufferMs

        lock.unlock()

        // 在锁外执行回调
        for pkt in packetsToOutput {
            onPacketReady?(pkt)
        }
    }

    /// 报告欠载事件（由播放端调用）
    public func reportUnderrun() {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        stats.underrunCount += 1
        underrunTimestamps.append(now)
        lastUnderrunTime = now
        stableSince = nil  // 重置稳定计时

        // 清理过期的欠载记录（超过窗口期）
        let windowStart = now.addingTimeInterval(-Double(config.adaptiveWindowSec))
        underrunTimestamps.removeAll { $0 < windowStart }

        // 检查是否需要升级到高稳定模式
        if underrunTimestamps.count >= config.underrunThreshold {
            if currentTargetBufferMs < config.maxTargetBufferMs {
                currentTargetBufferMs = config.maxTargetBufferMs
                print("[JitterBuffer] 🔺 升级到高稳定模式: targetBufferMs=\(currentTargetBufferMs)ms (欠载\(underrunTimestamps.count)次/\(config.adaptiveWindowSec)秒)")
            }
        }
    }

    /// 检查并尝试降级（定期调用，如每秒）
    public func checkDowngrade() {
        lock.lock()
        defer { lock.unlock() }

        // 只有在高稳定模式下才考虑降级
        guard currentTargetBufferMs > config.minTargetBufferMs else { return }

        let now = Date()

        // 如果还没开始稳定计时，开始计时
        if stableSince == nil {
            stableSince = now
            return
        }

        // 检查是否稳定足够长时间
        if let stableStart = stableSince {
            let stableDuration = now.timeIntervalSince(stableStart)
            if stableDuration >= Double(config.stableTimeSec) {
                currentTargetBufferMs = config.minTargetBufferMs
                stableSince = now  // 重置
                underrunTimestamps.removeAll()
                print("[JitterBuffer] 🔻 降级到低延迟模式: targetBufferMs=\(currentTargetBufferMs)ms (稳定\(Int(stableDuration))秒)")
            }
        }
    }

    /// 清空缓冲区
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        fifoBuffer.removeAll()
        isBuffering = true
        stats = Stats()
        stats.currentTargetMs = currentTargetBufferMs
        stats.isHighStabilityMode = currentTargetBufferMs > config.minTargetBufferMs
        // 注意：不重置自适应状态，保持当前模式
    }

    /// 重置自适应状态（完全重置）
    public func resetAdaptive() {
        lock.lock()
        defer { lock.unlock() }

        currentTargetBufferMs = config.minTargetBufferMs
        underrunTimestamps.removeAll()
        lastUnderrunTime = nil
        stableSince = Date()
        stats.isHighStabilityMode = false
        stats.currentTargetMs = currentTargetBufferMs
        print("[JitterBuffer] 🔄 自适应状态重置: targetBufferMs=\(currentTargetBufferMs)ms")
    }
}
