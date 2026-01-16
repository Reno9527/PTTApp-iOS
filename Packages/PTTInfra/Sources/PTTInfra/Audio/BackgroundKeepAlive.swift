import Foundation
import AVFoundation
import os.log

private let keepAliveLogger = Logger(subsystem: "com.pgarlic.pttapp.native", category: "KeepAlive")

/// 后台保活服务
///
/// 通过持续播放静音 PCM 帧保持 iOS 音频会话和网络连接活跃
/// 使用 audio background mode，不使用 VoIP Push
public final class BackgroundKeepAlive {

    // MARK: - 配置

    /// 静音播放间隔（秒）- 每秒播放一次确保音频流连续
    private let silenceInterval: TimeInterval = 1.0

    /// 静音时长（毫秒）- 每次播放 1 秒静音，确保音频持续
    private let silenceDurationMs = 1000

    /// 安全超时时间（秒）- 如果 isVoiceActive 为 true 但超过此时间没有实际音频，恢复播放静音
    /// 这是一个保底机制，防止音频引擎故障导致 App 被挂起
    private static let voiceActiveTimeoutSec: TimeInterval = 3.0

    // MARK: - 属性

    /// 使用 DispatchSourceTimer 替代 Timer，后台更可靠
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.pttapp.keepalive", qos: .userInitiated)
    private weak var audioEngine: AudioUnitEngine?
    private var isRunning = false
    private var silenceCount = 0

    /// 是否有活跃的语音通信（接收或发射）- 外部设置
    /// 当有语音通信时，跳过静音播放以避免干扰
    public var isVoiceActive: Bool = false {
        didSet {
            if isVoiceActive && !oldValue {
                // 进入语音活动状态，记录时间
                voiceActiveStartTime = Date()
                keepAliveLogger.notice("🎙 Voice active started")
            } else if !isVoiceActive && oldValue {
                // 退出语音活动状态
                voiceActiveStartTime = nil
                keepAliveLogger.notice("🎙 Voice active ended")
            }
        }
    }

    /// 语音活动开始时间（用于安全超时检测）
    private var voiceActiveStartTime: Date?

    /// 音频引擎是否已确认工作（电话中断后重启成功时设置）
    private var audioEngineConfirmedWorking = true

    // MARK: - 初始化

    public init() {}

    deinit {
        stop()
    }

    // MARK: - 公开方法

    /// 启动后台保活
    /// - Parameter audioEngine: 音频引擎（用于播放静音）
    public func start(audioEngine: AudioUnitEngine) {
        guard !isRunning else { return }

        self.audioEngine = audioEngine
        isRunning = true
        silenceCount = 0
        audioEngineConfirmedWorking = true

        // 注意：不重新配置音频会话，避免切换时卡顿
        // 音频会话在 AudioUnitEngine.start() 时已配置好

        // 使用 DispatchSourceTimer 替代 Timer，后台更可靠
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: silenceInterval, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            self?.playSilence()
        }
        timer.resume()
        self.timer = timer

        keepAliveLogger.notice("🟢 KeepAlive started (interval=\(self.silenceInterval)s, duration=\(self.silenceDurationMs)ms)")
    }

    /// 停止后台保活
    public func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        audioEngine = nil
        voiceActiveStartTime = nil
        keepAliveLogger.notice("🔴 KeepAlive stopped")
    }

    /// 通知音频引擎已重启（电话中断后调用）
    /// 重置状态，确保保活机制正常工作
    public func notifyAudioRestarted() {
        audioEngineConfirmedWorking = true
        voiceActiveStartTime = nil
        keepAliveLogger.notice("🔔 Audio engine restarted notification received")
    }

    /// 通知音频被中断（电话开始时调用）
    /// 标记音频引擎状态为未确认，启用安全机制
    public func notifyAudioInterrupted() {
        audioEngineConfirmedWorking = false
        keepAliveLogger.notice("🔔 Audio interrupted notification received, safety mechanism enabled")
    }

    // MARK: - 内部方法

    /// 播放静音 PCM - 持续播放以保持后台网络活跃
    private func playSilence() {
        // 检查是否需要强制播放静音（安全机制）
        let shouldForcePlaySilence = checkVoiceActiveTimeout()

        // 有语音通信时跳过，除非触发了安全机制
        if isVoiceActive && !shouldForcePlaySilence {
            return
        }

        guard let engine = audioEngine else {
            keepAliveLogger.warning("⚠️ No audio engine at \(Self.diagDateFormatter.string(from: Date()))")
            return
        }

        // 生成静音 PCM 数据
        // 1000ms @ 8kHz = 8000 samples，确保音频流持续
        let sampleCount = silenceDurationMs * 8
        let silence = [Int16](repeating: 0, count: sampleCount)

        // 直接喂给音频引擎，保持音频会话活跃
        engine.playInt16(silence, sampleRate: 8000)

        // 每 10 次记录一次日志，避免刷屏
        silenceCount += 1
        if silenceCount % 10 == 0 {
            let status = shouldForcePlaySilence ? " (SAFETY MODE)" : ""
            keepAliveLogger.notice("🔇 KeepAlive running (\(self.silenceCount) cycles)\(status)")
        }
    }

    /// 检查语音活动是否超时（安全机制）
    /// - Returns: true 表示应该强制播放静音
    private func checkVoiceActiveTimeout() -> Bool {
        guard isVoiceActive, let startTime = voiceActiveStartTime else {
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // 如果音频引擎未确认工作，且语音活动超时，强制播放静音
        if !audioEngineConfirmedWorking && elapsed > Self.voiceActiveTimeoutSec {
            keepAliveLogger.warning("⚠️ Voice active timeout (\(Int(elapsed))s), forcing silence playback for safety")
            return true
        }

        return false
    }

    /// 诊断用日期格式化器
    private static let diagDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()
}
