import Foundation

/// 音频编码格式
///
/// Feature Flag: Opus TX 为实验性功能，默认使用 G711
public enum AudioCodec: String, CaseIterable, Sendable, Codable {
    /// G.711 A-law (默认)
    /// - 采样率: 8kHz
    /// - 码率: 64kbps
    /// - 延迟: ~62.5ms/包
    case g711

    /// Opus (实验性)
    /// - 采样率: 16kHz
    /// - 码率: 16-24kbps
    /// - 延迟: ~20ms/包
    case opus

    /// 显示名称
    public var displayName: String {
        switch self {
        case .g711: return "G.711"
        case .opus: return "Opus (实验)"
        }
    }

    /// 采样率 (Hz)
    public var sampleRate: Int {
        switch self {
        case .g711: return 8000
        case .opus: return 16000
        }
    }

    /// 帧大小 (samples)
    public var frameSize: Int {
        switch self {
        case .g711: return 500   // 62.5ms @ 8kHz
        case .opus: return 320   // 20ms @ 16kHz
        }
    }

    /// 帧时长 (ms)
    public var frameDurationMs: Int {
        switch self {
        case .g711: return 62
        case .opus: return 20
        }
    }

    /// NRL21 包类型
    public var packetType: UInt8 {
        switch self {
        case .g711: return 1  // NRL21PacketType.voice
        case .opus: return 8  // NRL21PacketType.opus
        }
    }

    /// 是否为实验性功能
    public var isExperimental: Bool {
        switch self {
        case .g711: return false
        case .opus: return true
        }
    }
}

// MARK: - 默认编码

extension AudioCodec {
    /// 默认编码格式
    public static let `default`: AudioCodec = .g711
}
