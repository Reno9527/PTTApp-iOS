import Foundation
import COpus

/// Opus 编解码器
///
/// 参数配置:
/// - Sample rate: 16kHz
/// - Channels: 1 (mono)
/// - Frame size: 20ms (320 samples)
/// - Bitrate: 32-40 kbps (VBR)
/// - Application: VOIP
/// - Complexity: 8
public final class OpusCodec {

    // MARK: - 常量

    /// 采样率 16kHz
    public static let sampleRate: Int32 = 16000

    /// 单声道
    public static let channels: Int32 = 1

    /// 帧大小 20ms = 320 samples @ 16kHz
    public static let frameSize: Int32 = 320

    /// 帧时长 (毫秒)
    public static let frameDurationMs: Int = 20

    /// 默认码率 (bps) - VBR 模式下作为目标码率
    public static let defaultBitrate: Int32 = 32000

    /// 最大包大小 (字节)
    private static let maxPacketSize: Int32 = 4000

    // MARK: - 编码器

    private var encoder: OpaquePointer?
    private let encoderLock = NSLock()

    // MARK: - 解码器

    private var decoder: OpaquePointer?
    private let decoderLock = NSLock()

    // MARK: - 初始化

    public init() throws {
        try createEncoder()
        try createDecoder()
    }

    deinit {
        if let encoder = encoder {
            opus_encoder_destroy(encoder)
        }
        if let decoder = decoder {
            opus_decoder_destroy(decoder)
        }
    }

    // MARK: - 创建编码器

    private func createEncoder() throws {
        var error: Int32 = 0
        encoder = opus_encoder_create(
            Self.sampleRate,
            Self.channels,
            OPUS_APPLICATION_VOIP,
            &error
        )

        guard error == OPUS_OK, encoder != nil else {
            throw OpusError.encoderCreateFailed(code: error)
        }

        // 设置码率
        opus_encoder_set_bitrate(encoder!, Self.defaultBitrate)

        // 设置复杂度 (0-10，8 是较高质量)
        opus_encoder_set_complexity(encoder!, 8)

        // 设置信号类型为语音
        opus_encoder_set_signal(encoder!, OPUS_SIGNAL_VOICE)

        // 启用 DTX (非连续传输，静音时降低码率)
        opus_encoder_set_dtx(encoder!, 1)

        // 启用带内 FEC (前向纠错)
        opus_encoder_set_inband_fec(encoder!, 1)

        #if DEBUG
        print("[OpusCodec] Encoder created: \(Self.sampleRate)Hz, \(Self.channels)ch, \(Self.defaultBitrate)bps")
        #endif
    }

    // MARK: - 创建解码器

    private func createDecoder() throws {
        var error: Int32 = 0
        decoder = opus_decoder_create(
            Self.sampleRate,
            Self.channels,
            &error
        )

        guard error == OPUS_OK, decoder != nil else {
            throw OpusError.decoderCreateFailed(code: error)
        }

        #if DEBUG
        print("[OpusCodec] Decoder created: \(Self.sampleRate)Hz, \(Self.channels)ch")
        #endif
    }

    // MARK: - 编码

    /// 编码 PCM 数据为 Opus
    /// - Parameter pcm: 16-bit PCM 数据 (320 samples = 640 bytes)
    /// - Returns: Opus 编码后的数据
    public func encode(_ pcm: Data) throws -> Data {
        encoderLock.lock()
        defer { encoderLock.unlock() }

        guard let encoder = encoder else {
            throw OpusError.encoderNotInitialized
        }

        // 检查输入大小
        let expectedBytes = Int(Self.frameSize * Self.channels * 2)  // 16-bit = 2 bytes
        guard pcm.count >= expectedBytes else {
            throw OpusError.invalidInputSize(expected: expectedBytes, actual: pcm.count)
        }

        // 输出缓冲区
        var outputBuffer = [UInt8](repeating: 0, count: Int(Self.maxPacketSize))

        let encodedBytes = pcm.withUnsafeBytes { pcmPtr -> Int32 in
            let pcmSamples = pcmPtr.bindMemory(to: Int16.self)
            guard let baseAddress = pcmSamples.baseAddress else { return -1 }
            return opus_encode(
                encoder,
                baseAddress,
                Self.frameSize,
                &outputBuffer,
                Self.maxPacketSize
            )
        }

        guard encodedBytes > 0 else {
            throw OpusError.encodeFailed(code: encodedBytes)
        }

        return Data(outputBuffer.prefix(Int(encodedBytes)))
    }

    // MARK: - 解码

    /// 解码 Opus 数据为 PCM
    /// - Parameter opus: Opus 编码数据
    /// - Returns: 16-bit PCM 数据 (320 samples = 640 bytes)
    public func decode(_ opus: Data) throws -> Data {
        decoderLock.lock()
        defer { decoderLock.unlock() }

        guard let decoder = decoder else {
            throw OpusError.decoderNotInitialized
        }

        // 输出缓冲区 (320 samples * 2 bytes)
        let outputSamples = Int(Self.frameSize * Self.channels)
        var pcmBuffer = [Int16](repeating: 0, count: outputSamples)

        let decodedSamples = opus.withUnsafeBytes { opusPtr -> Int32 in
            guard let baseAddress = opusPtr.bindMemory(to: UInt8.self).baseAddress else { return -1 }
            return opus_decode(
                decoder,
                baseAddress,
                Int32(opus.count),
                &pcmBuffer,
                Self.frameSize,
                0  // decode_fec = 0
            )
        }

        guard decodedSamples > 0 else {
            throw OpusError.decodeFailed(code: decodedSamples)
        }

        // 转换为 Data
        return pcmBuffer.withUnsafeBufferPointer { ptr in
            Data(bytes: ptr.baseAddress!, count: Int(decodedSamples * Self.channels) * 2)
        }
    }

    /// 解码丢包补偿 (PLC)
    /// - Returns: 补偿后的 PCM 数据
    public func decodePLC() throws -> Data {
        decoderLock.lock()
        defer { decoderLock.unlock() }

        guard let decoder = decoder else {
            throw OpusError.decoderNotInitialized
        }

        let outputSamples = Int(Self.frameSize * Self.channels)
        var pcmBuffer = [Int16](repeating: 0, count: outputSamples)

        let decodedSamples = opus_decode(
            decoder,
            nil,  // NULL 表示丢包
            0,
            &pcmBuffer,
            Self.frameSize,
            0
        )

        guard decodedSamples > 0 else {
            throw OpusError.decodeFailed(code: decodedSamples)
        }

        return pcmBuffer.withUnsafeBufferPointer { ptr in
            Data(bytes: ptr.baseAddress!, count: Int(decodedSamples * Self.channels) * 2)
        }
    }

    // MARK: - 配置

    /// 设置码率
    public func setBitrate(_ bitrate: Int32) {
        encoderLock.lock()
        defer { encoderLock.unlock() }
        guard let encoder = encoder else { return }
        opus_encoder_set_bitrate(encoder, bitrate)
    }

    /// 设置复杂度 (0-10)
    public func setComplexity(_ complexity: Int32) {
        encoderLock.lock()
        defer { encoderLock.unlock() }
        guard let encoder = encoder else { return }
        let clamped = max(0, min(10, complexity))
        opus_encoder_set_complexity(encoder, clamped)
    }

    /// 重置编码器状态
    public func resetEncoder() {
        encoderLock.lock()
        defer { encoderLock.unlock() }
        guard let encoder = encoder else { return }
        opus_encoder_reset_state(encoder)
    }

    /// 重置解码器状态
    public func resetDecoder() {
        decoderLock.lock()
        defer { decoderLock.unlock() }
        guard let decoder = decoder else { return }
        opus_decoder_reset_state(decoder)
    }
}

// MARK: - 错误类型

public enum OpusError: Error, LocalizedError {
    case encoderCreateFailed(code: Int32)
    case decoderCreateFailed(code: Int32)
    case encoderNotInitialized
    case decoderNotInitialized
    case encodeFailed(code: Int32)
    case decodeFailed(code: Int32)
    case invalidInputSize(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .encoderCreateFailed(let code):
            return "Opus encoder creation failed: \(code)"
        case .decoderCreateFailed(let code):
            return "Opus decoder creation failed: \(code)"
        case .encoderNotInitialized:
            return "Opus encoder not initialized"
        case .decoderNotInitialized:
            return "Opus decoder not initialized"
        case .encodeFailed(let code):
            return "Opus encode failed: \(code)"
        case .decodeFailed(let code):
            return "Opus decode failed: \(code)"
        case .invalidInputSize(let expected, let actual):
            return "Invalid input size: expected \(expected), got \(actual)"
        }
    }
}
