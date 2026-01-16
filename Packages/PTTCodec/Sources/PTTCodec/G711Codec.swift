import Foundation

/// G.711 A-law 编解码器
///
/// 实现 ITU-T G.711 标准 A-law 编解码
/// - 采样率: 8000 Hz
/// - 位深: 8-bit A-law (编码后) / 16-bit PCM (解码后)
/// - 通道: 单声道
public struct G711Codec: Sendable {

    public init() {}

    // MARK: - 解码 (A-law → PCM)

    /// 解码单个 A-law 样本为 16-bit PCM
    /// - Parameter alaw: A-law 编码字节
    /// - Returns: 16-bit 有符号 PCM 样本
    @inlinable
    public func decode(_ alaw: UInt8) -> Int16 {
        // XOR with 0x55 (A-law even-bit inversion)
        let code = Int(alaw) ^ 0x55

        // Extract sign, segment, quantization
        let sign = code & 0x80
        let seg = (code & 0x70) >> 4
        let quant = code & 0x0F

        // Compute magnitude
        var sample: Int
        if seg == 0 {
            sample = (quant << 1) | 0x01
        } else {
            sample = ((quant << 1) | 0x21) << (seg - 1)
        }

        // Scale to 16-bit and apply sign
        let scaled = sample << 3
        return sign != 0 ? Int16(scaled) : Int16(-scaled)
    }

    /// 解码 A-law 数据为 PCM 样本数组
    /// - Parameter data: A-law 编码数据
    /// - Returns: 16-bit PCM 样本数组
    public func decode(_ data: Data) -> [Int16] {
        var result = [Int16]()
        result.reserveCapacity(data.count)
        for byte in data {
            result.append(decode(byte))
        }
        return result
    }

    /// 解码 A-law 数据为 PCM 字节数据 (Little-Endian)
    /// - Parameter data: A-law 编码数据
    /// - Returns: PCM 字节数据
    public func decodeToData(_ data: Data) -> Data {
        let samples = decode(data)
        var result = Data(capacity: samples.count * 2)
        for sample in samples {
            var s = sample.littleEndian
            withUnsafeBytes(of: &s) { result.append(contentsOf: $0) }
        }
        return result
    }

    // MARK: - 编码 (PCM → A-law)

    /// 编码单个 16-bit PCM 样本为 A-law
    /// - Parameter pcm: 16-bit 有符号 PCM 样本
    /// - Returns: A-law 编码字节
    @inlinable
    public func encode(_ pcm: Int16) -> UInt8 {
        // Determine sign and magnitude
        let sign: UInt8
        var magnitude: Int

        if pcm >= 0 {
            sign = 0x80
            magnitude = Int(pcm)
        } else {
            sign = 0x00
            // 先转换为 Int 再取负，避免 Int16.min (-32768) 溢出
            magnitude = -Int(pcm)
        }

        // Scale down from 16-bit
        magnitude = magnitude >> 3

        // Clamp to A-law range
        if magnitude > 0xFFF {
            magnitude = 0xFFF
        }

        // Determine segment and quantization
        var seg = 0
        var temp = magnitude
        while temp > 0x1F && seg < 7 {
            temp >>= 1
            seg += 1
        }

        let quant: UInt8
        if seg == 0 {
            quant = UInt8((magnitude >> 1) & 0x0F)
        } else {
            quant = UInt8((magnitude >> seg) & 0x0F)
        }

        // Combine and XOR
        let code = sign | UInt8(seg << 4) | quant
        return code ^ 0x55
    }

    /// 编码 PCM 样本数组为 A-law 数据
    /// - Parameter samples: 16-bit PCM 样本数组
    /// - Returns: A-law 编码数据
    public func encode(_ samples: [Int16]) -> Data {
        var result = Data(capacity: samples.count)
        for sample in samples {
            result.append(encode(sample))
        }
        return result
    }

    /// 编码 PCM 字节数据为 A-law 数据
    /// - Parameter data: PCM 字节数据 (Little-Endian)
    /// - Returns: A-law 编码数据
    public func encodeFromData(_ data: Data) -> Data {
        guard data.count >= 2 else { return Data() }

        let sampleCount = data.count / 2
        var result = Data(capacity: sampleCount)

        data.withUnsafeBytes { buffer in
            let samples = buffer.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let sample = Int16(littleEndian: samples[i])
                result.append(encode(sample))
            }
        }

        return result
    }
}
