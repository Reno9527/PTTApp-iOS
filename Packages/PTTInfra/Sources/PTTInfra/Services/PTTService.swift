import Foundation
import AVFoundation
import PTTCodec
import os.log
#if canImport(UIKit)
import UIKit
#endif

/// 诊断日志
private let pttLogger = Logger(subsystem: "com.pgarlic.pttapp.native", category: "PTTService")

/// PTT 核心服务
///
/// 整合音频引擎、网络客户端、协议解析等组件
/// 提供完整的 PTT 功能
public final class PTTService: @unchecked Sendable {

    // MARK: - 组件

    private let audioEngine: AudioUnitEngine
    private let udpClient: UDPClient
    private let codec = G711Codec()
    private let keepAlive: BackgroundKeepAlive

    /// Opus 解码器（懒加载，仅接收 Opus 包时创建）
    private var opusCodec: OpusCodec?

    /// 语音增强处理器（仅在需要时创建）
    private var voiceEnhancementProcessor: VoiceEnhancementProcessor?

    /// 语音增强是否已启动
    private var isVoiceEnhancementStarted = false

    /// 获取或创建语音增强处理器
    private func getOrCreateVoiceEnhancementProcessor() -> VoiceEnhancementProcessor {
        if let processor = voiceEnhancementProcessor {
            // 只在回调被清除时才重新设置（避免重复覆盖）
            if processor.onProcessedPCM == nil {
                setupVoiceEnhancementCallbacks(processor)
            }
            return processor
        }
        let processor = VoiceEnhancementProcessor()
        setupVoiceEnhancementCallbacks(processor)
        voiceEnhancementProcessor = processor
        return processor
    }

    // MARK: - 发送相关

    /// 发送队列
    private var sendQueue: [Data] = []
    private let sendQueueLock = NSLock()

    /// 发送定时器 (DispatchSourceTimer)
    private var sendTimer: DispatchSourceTimer?
    private let sendTimerQueue = DispatchQueue(label: "com.pgarlic.ptt.sendtimer", qos: .userInteractive)
    private let sendTimerLock = NSLock()

    /// 预分配的包缓冲区 (548 bytes = 48 header + 500 payload)
    private var preAllocatedPacket: Data?

    /// 音频缓冲区（累积 G711 数据）
    private var audioBuffer: [Data] = []
    private let audioBufferLock = NSLock()

    /// G711 发包间隔 (62ms for 500 bytes G711 @ 8kHz) - 与包大小对齐
    private static let g711SendIntervalMs: Int = 62

    /// Opus 发包间隔 (20ms for Opus frame)
    private static let opusSendIntervalMs: Int = 20

    /// 每包音频大小 - G711 协议固定 500 字节
    private static let audioPacketSize: Int = 500

    /// 当前发包间隔（根据编码格式）
    private var sendIntervalMs: Int {
        txCodec == .opus ? Self.opusSendIntervalMs : Self.g711SendIntervalMs
    }

    // MARK: - 心跳相关

    /// 心跳定时器
    private var heartbeatTimer: DispatchSourceTimer?
    private let heartbeatQueue = DispatchQueue(label: "com.pgarlic.ptt.heartbeat")
    private let heartbeatTimerLock = NSLock()

    /// 心跳间隔 (2秒)
    private static let heartbeatIntervalMs: Int = 2000

    /// 连接超时 (30分钟，允许长时间网络中断后恢复)
    private static let connectionTimeoutMs: Int = 1800000

    /// 离线检测阈值 (5秒无响应触发重连，与服务器一致)
    private static let offlineThresholdMs: Int = 5000

    /// 重连退避间隔 (秒) - 前台模式，首次立即重连，最大延迟 3 秒
    private static let reconnectBackoffSeconds = [0, 1, 2, 2, 3, 3]

    /// 后台重连间隔 (秒)
    private static let backgroundReconnectIntervalSec = 60

    /// 连续发送失败次数（线程安全）
    private var consecutiveSendFail: Int {
        get { sendFailLock.withLock { _consecutiveSendFail } }
        set { sendFailLock.withLock { _consecutiveSendFail = newValue } }
    }
    private var _consecutiveSendFail: Int = 0
    private let sendFailLock = NSLock()

    /// 重连重试次数
    private var reconnectRetryCount: Int = 0

    /// 是否正在重连
    private var isReconnecting: Bool = false

    /// 是否在后台（由外部设置，影响重连策略）
    public var isInBackground: Bool = false

    // MARK: - 后台保活相关

    /// 最后语音活动时间（发射或接收）
    private var lastVoiceActivityTime: Date?

    /// 空闲超时时长（5分钟）
    private static let idleTimeoutSeconds: TimeInterval = 300

    /// 空闲检测定时器
    private var idleCheckTimer: DispatchSourceTimer?
    private let idleCheckQueue = DispatchQueue(label: "com.pgarlic.ptt.idlecheck")

    // MARK: - 位置相关

    /// 当前位置 (经度, 纬度) - 外部设置，用于心跳包和语音包头部
    public var currentLocation: (latitude: Double, longitude: Double)? {
        get { locationLock.withLock { _currentLocation } }
        set { locationLock.withLock { _currentLocation = newValue } }
    }
    private var _currentLocation: (latitude: Double, longitude: Double)?
    private let locationLock = NSLock()

    /// 心跳包接收回调 (呼号, SSID, 纬度, 经度)
    /// 位置数据通过心跳包传输 (offset 32-39)
    public var onHeartbeatReceived: ((String, Int, Double?, Double?) -> Void)?

    /// 最后收到服务器响应的时间
    private var lastServerResponse: Date?

    /// 音频会话是否被中断（电话、Siri 等）
    private var isAudioInterrupted: Bool = false

    /// 后台任务标识符（用于电话期间保活）
    #if canImport(UIKit)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif

    /// 是否启用了后台保活增强（定位模式）
    /// 如果启用，电话期间使用定位保活；否则使用 beginBackgroundTask（30秒限制）
    /// 直接从 UserDefaults 读取，与 LocationService 同步
    private var isBackgroundKeepAliveEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "background_keepalive_enabled")
    }

    /// 音频中断开始时间（用于恢复后重置超时）
    private var interruptionStartTime: Date?

    /// 中断前的连接配置（用于自动重连）
    private var savedConnectionConfig: UserConfig?

    // MARK: - 状态

    /// 连接状态（线程安全）
    public var isConnected: Bool {
        get { stateLock.withLock { _isConnected } }
        set { stateLock.withLock { _isConnected = newValue } }
    }
    private var _isConnected: Bool = false

    /// 是否正在发射（线程安全）
    public var isTalking: Bool {
        get { stateLock.withLock { _isTalking } }
        set { stateLock.withLock { _isTalking = newValue } }
    }
    private var _isTalking: Bool = false

    /// 当前讲话者（线程安全）
    public var currentSpeaker: String? {
        get { stateLock.withLock { _currentSpeaker } }
        set { stateLock.withLock { _currentSpeaker = newValue } }
    }
    private var _currentSpeaker: String?

    /// 当前讲话者的 DMR ID（线程安全）
    public var currentSpeakerDmrID: String? {
        get { stateLock.withLock { _currentSpeakerDmrID } }
        set { stateLock.withLock { _currentSpeakerDmrID = newValue } }
    }
    private var _currentSpeakerDmrID: String?

    /// 状态锁（保护 isConnected, isTalking, currentSpeaker, currentSpeakerDmrID）
    private let stateLock = NSLock()

    /// 全双工模式（始终启用，保留属性以兼容设置页面）
    public var isFullDuplex: Bool = true

    /// 播放音量 (0.0 ~ 1.0)
    public var playbackVolume: Float = 1.0 {
        didSet {
            audioEngine.playbackVolume = playbackVolume
        }
    }

    /// 录音音量 (0.0 ~ 1.0)
    public var recordingVolume: Float = 1.0 {
        didSet {
            audioEngine.recordingVolume = recordingVolume
            // 仅当已创建时才更新
            voiceEnhancementProcessor?.inputGain = recordingVolume
        }
    }

    /// 语音降噪开关
    public var noiseReductionEnabled: Bool = false

    /// TX 人声 EQ 开关（让人声更洪亮）
    public var voiceEQEnabled: Bool = false

    /// 会议模式标志（用于控制 speaker 切换行为）
    private var isConferenceMode: Bool = false

    /// RX 语音识别开关（实时字幕）
    public var speechRecognitionEnabled: Bool = false {
        didSet {
            if speechRecognitionEnabled {
                // 首次启用时请求权限
                SpeechRecognitionService.shared.requestAuthorization { authorized in
                    if !authorized {
                        print("[PTTService] Speech recognition not authorized")
                    }
                }
            }
        }
    }

    /// 语音识别结果回调 (speaker, sessionId, text, isFinal)
    public var onTranscriptionUpdate: ((String, UUID, String, Bool) -> Void)? {
        didSet {
            // 同步到识别服务（同时内部存储最终结果用于 CallRecord）
            SpeechRecognitionService.shared.onTranscriptionUpdate = { [weak self] speaker, sessionId, text, isFinal in
                // 内部存储（用于保存到 CallRecord）
                self?.currentRxTranscription = text
                // 转发给外部回调
                self?.onTranscriptionUpdate?(speaker, sessionId, text, isFinal)
            }
        }
    }

    /// 当前接收语音的识别文字（用于保存到 CallRecord）
    private var currentRxTranscription: String?

    /// TX 编码格式 (默认 G711)
    public var txCodec: AudioCodec = .g711

    /// Opus TX 编码器（独立于 RX 解码器）
    private var txOpusCodec: OpusCodec?

    /// 用户配置
    private var userConfig: UserConfig?

    /// 发射序列号
    /// 发送序列号（固定为 0，与硬件设备保持一致）
    private let txSeq: UInt16 = 0

    /// 最后接收的序列号
    private var lastRxSeq: UInt16 = 0

    /// 接收超时定时器
    private var receiveTimeoutTask: Task<Void, Never>?

    /// 自动重连任务（音频中断恢复后）
    private var reconnectTask: Task<Void, Never>?

    /// 音频中断观察者（需要在 deinit 时移除）
    private var audioInterruptionObserver: NSObjectProtocol?

    /// 媒体服务重置观察者
    private var mediaServicesResetObserver: NSObjectProtocol?

    /// 音频路由变化观察者
    private var routeChangeObserver: NSObjectProtocol?

    /// 语音开始时间（用于通话记录）
    private var voiceStartTime: Date?

    /// 发送音频归档（用于保存通话记录）
    private var sendAudioArchive: [Data] = []

    /// 接收音频归档（用于保存通话记录）
    private var receiveAudioArchive: [Data] = []

    /// 接收语音开始时间
    private var receiveStartTime: Date?

    /// 接收语音的讲话者信息
    private var receiveSpeakerCallSign: String?
    private var receiveSpeakerSsid: Int = 0

    /// 接收语音的编码格式（公开，用于 UI 显示不同颜色）
    public private(set) var receiveCodec: AudioCodec = .g711

    // MARK: - 回调

    /// 状态变化回调
    public var onStateChanged: ((PTTServiceState) -> Void)?

    /// 讲话者变化回调
    public var onSpeakerChanged: ((String?) -> Void)?

    /// 统计更新回调
    public var onStatsUpdated: ((PTTStats) -> Void)?

    /// 错误回调
    public var onError: ((PTTServiceError) -> Void)?

    /// 音量电平回调
    public var onVolumeLevel: ((Float) -> Void)?

    /// 通话结束回调（用于保存记录）
    public var onCallEnded: ((CallRecord) -> Void)?

    /// 文本消息回调
    public var onTextReceived: ((TextMessage) -> Void)?

    // MARK: - 统计（线程安全）

    private var _packetsReceived: UInt64 = 0
    private var _packetsSent: UInt64 = 0
    private var _packetsLost: UInt64 = 0
    private let statsLock = NSLock()

    private var packetsReceived: UInt64 {
        get { statsLock.withLock { _packetsReceived } }
        set { statsLock.withLock { _packetsReceived = newValue } }
    }
    private var packetsSent: UInt64 {
        get { statsLock.withLock { _packetsSent } }
        set { statsLock.withLock { _packetsSent = newValue } }
    }
    private var packetsLost: UInt64 {
        get { statsLock.withLock { _packetsLost } }
        set { statsLock.withLock { _packetsLost = newValue } }
    }

    // MARK: - 初始化

    public init() {
        self.audioEngine = AudioUnitEngine()
        self.udpClient = UDPClient()
        self.keepAlive = BackgroundKeepAlive()

        setupCallbacks()
        setupAudioInterruptionObserver()
    }

    /// 设置音频会话相关监听
    private func setupAudioInterruptionObserver() {
        let session = AVAudioSession.sharedInstance()

        // 1. 音频中断监听（电话、Siri 等）
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }

        // 2. 媒体服务重置监听（iOS 重置音频守护进程时触发）
        mediaServicesResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }

        // 3. 音频路由变化监听（蓝牙耳机、扬声器切换等）
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    deinit {
        // 移除 NotificationCenter 观察者
        if let observer = audioInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = mediaServicesResetObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // 取消进行中的任务
        reconnectTask?.cancel()
        receiveTimeoutTask?.cancel()

        // 清空所有回调，避免循环引用
        onStateChanged = nil
        onSpeakerChanged = nil
        onStatsUpdated = nil
        onError = nil
        onVolumeLevel = nil
        onCallEnded = nil
        onTextReceived = nil
        onHeartbeatReceived = nil
    }

    /// 处理音频会话中断
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // 中断开始（电话、Siri 等）
            pttLogger.notice("🔔 Audio interrupted - pausing timeout check")
            isAudioInterrupted = true
            interruptionStartTime = Date()
            // 保存当前连接配置
            if isConnected {
                savedConnectionConfig = userConfig
            }

            // 通知 BackgroundKeepAlive 音频已中断，需要安全机制保护
            keepAlive.notifyAudioInterrupted()

            // 💡 后台保活处理
            #if canImport(UIKit)
            if !isBackgroundKeepAliveEnabled {
                // 方案 A：使用 beginBackgroundTask（约 30 秒限制）
                backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "PTTHeartbeat") { [weak self] in
                    // 后台时间即将耗尽
                    pttLogger.warning("⚠️ Background task expiring")
                    if let self = self, self.backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                        self.backgroundTaskId = .invalid
                    }
                }
                pttLogger.notice("🔔 Started background task (30s limit), id=\(self.backgroundTaskId.rawValue)")
            } else {
                // 方案 B：使用定位服务保活，无需额外处理
                pttLogger.notice("🔔 Using location keep-alive mode (unlimited)")
            }
            #endif

        case .ended:
            // 中断结束
            pttLogger.notice("🔔 Audio interruption ended - resuming")
            isAudioInterrupted = false

            // 💡 结束旧的后台任务，并重新申请新的（用于音频恢复期间的保护）
            #if canImport(UIKit)
            if self.backgroundTaskId != .invalid {
                pttLogger.notice("🔔 Ending old background task, id=\(self.backgroundTaskId.rawValue)")
                UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                self.backgroundTaskId = .invalid
            }

            // 💡 场景2修复：电话结束后重新申请后台任务（仅非定位保活模式）
            // 给音频恢复过程提供额外的后台时间保护
            if !isBackgroundKeepAliveEnabled && isConnected {
                backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "PTTAudioRecovery") { [weak self] in
                    pttLogger.warning("⚠️ Audio recovery background task expiring")
                    if let self = self, self.backgroundTaskId != .invalid {
                        UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                        self.backgroundTaskId = .invalid
                    }
                }
                pttLogger.notice("🔔 Started audio recovery background task, id=\(self.backgroundTaskId.rawValue)")
            }
            #endif

            // 计算中断时长
            let interruptionDuration: TimeInterval
            if let startTime = interruptionStartTime {
                interruptionDuration = Date().timeIntervalSince(startTime)
                pttLogger.notice("🔔 Interruption lasted \(Int(interruptionDuration))s")
            } else {
                interruptionDuration = 0
            }
            interruptionStartTime = nil

            // 💡 始终尝试恢复音频，不依赖 shouldResume 标志
            // iOS 在电话结束后可能不会设置 .shouldResume，但我们仍需重启音频
            // Apple 文档建议：中断结束后总是尝试重新激活音频会话
            let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            let shouldResume = options.map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? true
            pttLogger.notice("🔔 Interruption ended, shouldResume=\(shouldResume), will restart audio anyway")

            // 1. 重新激活音频会话
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: [])
                pttLogger.notice("🔔 Audio session reactivated")
            } catch {
                pttLogger.error("❌ Failed to reactivate audio session: \(error)")
            }

            // 2. 重启 AudioUnit（核心修复！）
            // 电话/Siri 等中断后，iOS 可能已停止 AudioUnit，必须重启
            // 无论 shouldResume 是什么值都要重启
            restartAudioEngineAfterInterruption()

            // 3. 验证连接状态
            // 由于电话期间我们继续发心跳，服务器应该不会踢我们
            // 但仍需验证连接是否正常
            if isConnected {
                // 发送心跳验证，3秒后检查是否收到响应
                sendHeartbeat()
                let verifyTime = Date()
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
                    guard let self = self else { return }
                    if let lastRx = self.lastServerResponse {
                        // 如果3秒内没收到新响应，说明连接可能有问题
                        if lastRx < verifyTime {
                            pttLogger.warning("⚠️ No heartbeat response after interruption, triggering reconnect")
                            self.triggerReconnect(reason: "中断后心跳无响应")
                        } else {
                            pttLogger.notice("✅ Connection verified after interruption")
                        }
                    }
                }
            }

            // 4. 如果断线了，尝试自动重连
            if !isConnected, let config = savedConnectionConfig {
                pttLogger.notice("🔄 Auto-reconnecting after interruption")
                reconnectTask?.cancel()
                reconnectTask = Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.connect(config: config)
                        pttLogger.notice("✅ Reconnected after interruption")
                    } catch {
                        pttLogger.error("❌ Failed to reconnect after interruption: \(error)")
                        // 触发重连机制
                        self.triggerReconnect(reason: "中断后重连失败")
                    }
                }
            }

        @unknown default:
            break
        }
    }

    /// 处理媒体服务重置
    /// iOS 在某些情况下会重置音频守护进程，导致所有 AudioUnit 失效
    private func handleMediaServicesReset() {
        pttLogger.warning("⚠️ Media services were reset - restarting audio engine")

        // 媒体服务重置后，所有 AudioUnit 都已失效，必须重新创建
        if isVoiceEnhancementStarted {
            voiceEnhancementProcessor?.stop()
            isVoiceEnhancementStarted = false
        }

        if isConnected {
            do {
                try audioEngine.forceRestart()
                setupCallbacks()
                pttLogger.notice("✅ Audio engine restarted after media services reset")
            } catch {
                pttLogger.error("❌ Failed to restart audio engine after media services reset: \(error)")
            }
        }
    }

    /// 处理音频路由变化
    /// 蓝牙耳机连接/断开、扬声器/听筒切换等
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .unknown:
            pttLogger.notice("🎧 Unknown route change")

        case .newDeviceAvailable:
            // 新设备可用（如蓝牙耳机连接）
            pttLogger.notice("🎧 New audio device available")

        case .oldDeviceUnavailable:
            // 旧设备不可用（如蓝牙耳机断开）
            pttLogger.notice("🎧 Audio device disconnected")
            // 某些情况下需要重新配置音频
            if isConnected && !isAudioInterrupted {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: [])
                } catch {
                    pttLogger.error("❌ Failed to reactivate audio session: \(error)")
                }
            }

        case .categoryChange:
            pttLogger.notice("🎧 Audio category changed")

        case .override:
            pttLogger.notice("🎧 Audio route override")

        case .wakeFromSleep:
            pttLogger.notice("🎧 Device woke from sleep")

        case .noSuitableRouteForCategory:
            pttLogger.warning("⚠️ No suitable audio route for category")

        case .routeConfigurationChange:
            pttLogger.notice("🎧 Route configuration changed")

        @unknown default:
            pttLogger.notice("🎧 Unknown route change reason: \(reasonValue)")
        }
    }

    private func setupCallbacks() {
        // 录音回调 - 将 PCM 编码为 G711 并放入缓冲区
        audioEngine.onPCMRecorded = { [weak self] samples in
            guard let self = self, self.isTalking else { return }
            // 降噪模式下不使用 audioEngine 的录音
            guard !self.noiseReductionEnabled else { return }
            self.handleRecordedPCM(samples)
        }

        // 网络接收回调
        udpClient.onReceive = { [weak self] data in
            self?.handleReceivedData(data)
        }
    }

    /// 设置语音增强处理器回调
    private func setupVoiceEnhancementCallbacks(_ processor: VoiceEnhancementProcessor) {
        // 处理后的 PCM 数据回调
        processor.onProcessedPCM = { [weak self] samples in
            guard let self = self, self.isTalking else { return }
            self.handleRecordedPCM(samples)
        }

        // VAD 概率回调（可用于显示语音活动指示器）
        processor.onVadProbability = { [weak self] probability in
            _ = self
            _ = probability
        }

        // 音量电平回调（用于 UI 水波纹动画）
        processor.onVolumeLevel = { [weak self] level in
            self?.onVolumeLevel?(level)
        }
    }

    // MARK: - 公开 API

    /// 连接到服务器
    public func connect(config: UserConfig) async throws {
        // 如果已连接，先断开（防止状态不一致）
        if isConnected {
            pttLogger.notice("⚠️ Already connected, disconnecting first...")
            await disconnect()
        }

        pttLogger.notice("🔌 Connecting to \(config.host):\(config.port)...")
        self.userConfig = config

        // 1. 配置音频引擎
        try audioEngine.start()

        do {
            // 2. 重新设置音频录音回调（可能在 disconnect 时被清除）
            audioEngine.onPCMRecorded = { [weak self] samples in
                guard let self = self, self.isTalking else { return }
                // 降噪模式下不使用 audioEngine 的录音（由 VoiceEnhancementProcessor 处理）
                guard !self.noiseReductionEnabled else { return }
                self.handleRecordedPCM(samples)
            }

            // 3. 重新设置 UDP 接收回调（可能在 disconnect 时被清除）
            udpClient.onReceive = { [weak self] data in
                self?.handleReceivedData(data)
            }

            // 4. 连接 UDP
            try await udpClient.connect(host: config.host, port: config.port)

            // 6. 后台保活由 onEnterBackground() 按条件启动，不在这里自动启动

            // 7. 预分配发送包
            preAllocatedPacket = createPreAllocatedPacket(config: config)

            // 8. 发送初始心跳
            sendHeartbeat()

            // 9. 启动心跳定时器
            startHeartbeatTimer()

            // 10. 更新状态
            isConnected = true
            lastServerResponse = Date()
            consecutiveSendFail = 0
            reconnectRetryCount = 0
            isReconnecting = false
            savedConnectionConfig = config  // 保存配置供重连使用
            onStateChanged?(.connected)

            print("[PTTService] Connected to \(config.host):\(config.port)")
        } catch {
            // 连接失败，清理已启动的音频引擎
            audioEngine.stop()
            pttLogger.error("❌ Connection failed, audio engine stopped: \(error.localizedDescription)")
            throw error
        }
    }

    /// 录音播放定时器
    private var recordPlaybackTimer: DispatchSourceTimer?
    private let recordPlaybackQueue = DispatchQueue(label: "com.pgarlic.ptt.recordplayback")
    private let recordPlaybackTimerLock = NSLock()

    /// 分段播放状态
    private var playbackPcmData: [Int16] = []
    private var playbackOffset: Int = 0
    private var playbackSampleRate: Int = 8000
    private let playbackChunkDurationSec: Double = 0.5  // 每次写入 500ms（匹配缓冲区大小）

    /// 播放录音数据（支持 G711 和 Opus 编码）
    /// - Parameters:
    ///   - audioData: 编码后的音频数据
    ///   - audioCodec: 编码格式（默认 G711）
    public func playRecordAudio(_ audioData: Data, codec audioCodec: AudioCodec = .g711) {
        guard !audioData.isEmpty else {
            print("[PTTService] playRecordAudio: audioData is empty")
            return
        }

        // 停止之前的播放
        stopRecordPlayback()

        // 暂停静音保活，避免干扰录音播放
        keepAlive.isVoiceActive = true

        switch audioCodec {
        case .g711:
            playG711RecordAudio(audioData)
        case .opus:
            playOpusRecordAudio(audioData)
        }
    }

    /// 播放 G711 编码录音（分段播放）
    private func playG711RecordAudio(_ audioData: Data) {
        // G711 解码为 PCM
        let decoded = codec.decode(audioData)
        guard !decoded.isEmpty else {
            print("[PTTService] playRecordAudio: G711 decoded PCM is empty")
            return
        }

        let durationMs = decoded.count * 1000 / 8000
        print("[PTTService] playRecordAudio: playing G711 \(decoded.count) samples (\(durationMs)ms)")

        // 分段播放
        startChunkedPlayback(pcmData: decoded, sampleRate: 8000)
    }

    /// 播放 Opus 编码录音（分段播放）
    private func playOpusRecordAudio(_ audioData: Data) {
        // Opus 数据是多个帧拼接，需要按帧解码
        // 每帧有 2 字节长度前缀（小端序）
        guard let opusDecoder = getOrCreateOpusCodec() else {
            print("[PTTService] playRecordAudio: failed to create Opus decoder")
            return
        }

        // 解析并解码所有 Opus 帧
        var decoded: [Int16] = []
        var dataOffset = 0

        while dataOffset < audioData.count {
            // 读取帧长度（2 字节小端序）
            guard dataOffset + 2 <= audioData.count else { break }
            let frameLength = Int(audioData[dataOffset]) | (Int(audioData[dataOffset + 1]) << 8)
            dataOffset += 2

            // Opus 帧通常不超过 1275 字节，设置 2000 作为安全上限防止异常数据
            guard frameLength > 0, frameLength <= 2000, dataOffset + frameLength <= audioData.count else { break }

            // 提取 Opus 帧数据
            let frameData = audioData.subdata(in: dataOffset..<(dataOffset + frameLength))
            dataOffset += frameLength

            // 解码 Opus 帧
            do {
                let pcmData = try opusDecoder.decode(frameData)
                // 转换 Data 为 [Int16]（安全的逐字节读取，避免内存对齐问题）
                // 确保只处理偶数长度，防止越界
                let safeByteCount = (pcmData.count / 2) * 2
                let sampleCount = safeByteCount / 2
                var samples = [Int16](repeating: 0, count: sampleCount)
                for i in 0..<sampleCount {
                    let low = UInt16(pcmData[i * 2])
                    let high = UInt16(pcmData[i * 2 + 1])
                    samples[i] = Int16(bitPattern: low | (high << 8))
                }
                decoded.append(contentsOf: samples)
            } catch {
                print("[PTTService] playRecordAudio: Opus decode error: \(error)")
            }
        }

        guard !decoded.isEmpty else {
            print("[PTTService] playRecordAudio: Opus decoded PCM is empty")
            return
        }

        let durationMs = decoded.count * 1000 / 16000
        print("[PTTService] playRecordAudio: playing Opus \(decoded.count) samples (\(durationMs)ms)")

        // 分段播放
        startChunkedPlayback(pcmData: decoded, sampleRate: 16000)
    }

    /// 开始分段播放
    private func startChunkedPlayback(pcmData: [Int16], sampleRate: Int) {
        playbackPcmData = pcmData
        playbackOffset = 0
        playbackSampleRate = sampleRate

        // 计算每段的样本数（2秒）
        let chunkSize = Int(playbackChunkDurationSec * Double(sampleRate))

        // 先写入第一段（立即开始播放）
        writeNextPlaybackChunk(chunkSize: chunkSize)

        // 如果还有更多数据，启动定时器继续写入
        if playbackOffset < playbackPcmData.count {
            startPlaybackTimer(chunkSize: chunkSize)
        }
    }

    /// 写入下一段播放数据
    private func writeNextPlaybackChunk(chunkSize: Int) {
        guard playbackOffset < playbackPcmData.count else { return }

        let remaining = playbackPcmData.count - playbackOffset
        let writeCount = min(chunkSize, remaining)

        let chunk = Array(playbackPcmData[playbackOffset..<(playbackOffset + writeCount)])
        audioEngine.playInt16(chunk, sampleRate: playbackSampleRate)

        playbackOffset += writeCount
    }

    /// 启动播放定时器（每秒检查并写入下一段）
    private func startPlaybackTimer(chunkSize: Int) {
        recordPlaybackTimerLock.withLock {
            recordPlaybackTimer?.cancel()

            let timer = DispatchSource.makeTimerSource(queue: recordPlaybackQueue)
            // 每 400ms 写入下一段数据（比 500ms 分段稍快，保持缓冲余量）
            timer.schedule(deadline: .now() + 0.4, repeating: 0.4)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }

                if self.playbackOffset < self.playbackPcmData.count {
                    self.writeNextPlaybackChunk(chunkSize: chunkSize)
                } else {
                    // 播放完成，停止定时器
                    self.recordPlaybackTimerLock.withLock {
                        self.recordPlaybackTimer?.cancel()
                        self.recordPlaybackTimer = nil
                    }
                    self.playbackPcmData = []

                    // 恢复静音保活（仅在没有其他语音活动时）
                    if !self.isTalking && self.currentSpeaker == nil {
                        self.keepAlive.isVoiceActive = false
                    }
                }
            }
            timer.resume()
            recordPlaybackTimer = timer
        }
    }

    /// 获取或创建 Opus 解码器
    private func getOrCreateOpusCodec() -> OpusCodec? {
        if let codec = opusCodec {
            return codec
        }
        do {
            let codec = try OpusCodec()
            opusCodec = codec
            return codec
        } catch {
            print("[PTTService] Failed to create Opus codec: \(error)")
            return nil
        }
    }

    /// 停止录音播放
    public func stopRecordPlayback() {
        recordPlaybackTimerLock.withLock {
            recordPlaybackTimer?.cancel()
            recordPlaybackTimer = nil
        }

        // 清空分段播放状态
        playbackPcmData = []
        playbackOffset = 0

        audioEngine.clearPlayBuffer()

        // 恢复静音保活（仅在没有其他语音活动时）
        if !isTalking && currentSpeaker == nil {
            keepAlive.isVoiceActive = false
        }
    }

    /// 断开连接
    public func disconnect() async {
        // 不检查 isConnected，确保完全清理（防止状态不一致）
        pttLogger.notice("🔌 Disconnecting... (wasConnected=\(self.isConnected))")

        // 1. 首先立即标记为未连接，阻止所有回调继续执行
        isConnected = false
        isTalking = false
        currentSpeaker = nil
        print("[PTTService] Disconnecting...")

        // 2. 停止所有定时器和任务（防止回调）
        stopHeartbeatTimer()
        stopSendTimer()
        receiveTimeoutTask?.cancel()
        receiveTimeoutTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        recordPlaybackTimerLock.withLock {
            recordPlaybackTimer?.cancel()
            recordPlaybackTimer = nil
        }

        // 3. 清除所有回调（防止断开过程中触发回调）
        udpClient.onReceive = nil

        // 4. 停止音频引擎（先停音频，避免回调访问已释放资源）
        audioEngine.stopRecording()
        audioEngine.stop()

        // 4.1 停止语音增强处理器
        if isVoiceEnhancementStarted {
            voiceEnhancementProcessor?.stop()
            isVoiceEnhancementStarted = false
        }

        // 5. 停止后台保活和空闲检测定时器
        idleCheckTimer?.cancel()
        idleCheckTimer = nil
        keepAlive.stop()

        // 6. 断开 UDP（同步操作）
        udpClient.disconnect()

        // 7. 清理其他状态
        userConfig = nil
        lastRxSeq = 0
        preAllocatedPacket = nil
        opusCodec = nil  // 释放 Opus 解码器
        txOpusCodec = nil  // 释放 Opus 编码器
        lastServerResponse = nil
        voiceStartTime = nil
        sendAudioArchive.removeAll()
        receiveAudioArchive.removeAll()
        receiveStartTime = nil
        receiveSpeakerCallSign = nil
        receiveSpeakerSsid = 0
        consecutiveSendFail = 0
        // 注意：不重置 reconnectRetryCount 和 savedConnectionConfig，重连时需要

        // 8. 清空缓冲区
        audioBufferLock.withLock {
            audioBuffer.removeAll()
        }

        sendQueueLock.withLock {
            sendQueue.removeAll()
        }

        // 9. 等待一小段时间确保所有回调完成
        try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // 10. 最后触发状态回调
        onStateChanged?(.disconnected)
        print("[PTTService] Disconnected")
    }

    /// 开始发射
    public func startTalking() async throws {
        guard isConnected, !isTalking else { return }
        // 全双工模式：始终允许发射（可抢麦）

        isTalking = true
        keepAlive.isVoiceActive = true  // 暂停静音保活，避免干扰发射
        lastVoiceActivityTime = Date()  // 记录语音活动时间
        voiceStartTime = Date()
        sendAudioArchive.removeAll()

        // 清空缓冲区
        audioBufferLock.withLock {
            audioBuffer.removeAll()
        }

        sendQueueLock.withLock {
            sendQueue.removeAll()
        }

        // 清空 Opus TX 缓冲
        opusTxBufferLock.withLock {
            opusTxBuffer.removeAll()
        }

        // 开始录音
        if noiseReductionEnabled || voiceEQEnabled {
            // 使用语音增强处理器（48kHz 采集 + RNNoise 降噪 + EQ）
            let processor = getOrCreateVoiceEnhancementProcessor()

            // 根据 TX 编码设置输出采样率
            let targetMode: VoiceEnhancementProcessor.OutputSampleRateMode = (txCodec == .opus) ? .rate16k : .rate8k

            // 如果 outputMode 需要改变，需要重启 processor
            // 修复：不仅检查 isVoiceEnhancementStarted，还要检查 processor.isRunning
            if processor.outputMode != targetMode && (isVoiceEnhancementStarted || processor.isRunning) {
                print("[PTTService] Output mode changed, restarting processor: \(processor.outputMode.rawValue)Hz → \(targetMode.rawValue)Hz")
                processor.stop()
                isVoiceEnhancementStarted = false
                // 重新设置回调（stop() 会清除回调）
                setupVoiceEnhancementCallbacks(processor)
            }

            processor.setOutputMode(targetMode)

            // 启用 RNNoise 降噪
            processor.enableNoiseReduction = noiseReductionEnabled
            // 启用 TX 人声 EQ
            processor.enableVoiceEQ = voiceEQEnabled
            if !isVoiceEnhancementStarted {
                do {
                    try processor.start()
                    isVoiceEnhancementStarted = true
                    print("[PTTService] Voice enhancement started (RNNoise enabled, output: \(targetMode.rawValue)Hz)")
                } catch {
                    print("[PTTService] Voice enhancement start failed: \(error), falling back to normal recording")
                    audioEngine.startRecording()
                }
            }
            if isVoiceEnhancementStarted {
                processor.startProcessing()
            }
        } else {
            // 使用普通录音（8kHz）- 仅支持 G711
            // Opus TX 需要开启降噪才能使用（因为需要 16kHz 输入）
            if txCodec == .opus {
                print("[PTTService] Warning: Opus TX requires noise reduction enabled, falling back to G711")
            }
            audioEngine.startRecording()
        }

        // Opus 使用定时器发送（20ms 帧），G711 使用数据驱动发送（500字节立即发）
        if txCodec == .opus {
            startSendTimer()
        }

        onStateChanged?(.talking)
        print("[PTTService] Start talking (codec: \(txCodec.rawValue), noise reduction: \(noiseReductionEnabled), voiceEQ: \(voiceEQEnabled))")
    }

    /// 停止发射
    public func stopTalking() async {
        guard isTalking else { return }

        // 停止录音
        if (noiseReductionEnabled || voiceEQEnabled) && isVoiceEnhancementStarted {
            voiceEnhancementProcessor?.stopProcessing()
        } else {
            audioEngine.stopRecording()
        }

        // Opus 使用定时器，需要停止定时器并刷新队列
        // G711 数据驱动，不需要刷新队列
        if txCodec == .opus {
            stopSendTimer()
            await flushSendQueue()
        }

        // 发送结束包
        sendEndPacket()

        // 生成通话记录（记录当前编码格式）
        if let startTime = voiceStartTime {
            let record = CallRecord(
                callSign: userConfig?.callSign ?? "",
                ssid: userConfig?.ssid ?? 0,
                startTime: startTime,
                endTime: Date(),
                isSelf: true,
                audioData: mergeAudioArchive(),
                groupId: userConfig?.groupId ?? 0,
                codec: txCodec
            )
            onCallEnded?(record)
        }

        isTalking = false
        voiceStartTime = nil
        lastVoiceActivityTime = Date()  // 记录语音活动时间
        // 停止发射后，如果还有人在讲话，恢复到接收状态
        if let speaker = currentSpeaker {
            onStateChanged?(.receiving(speaker: speaker))
        } else {
            onStateChanged?(.connected)
            // 没有人讲话时，恢复静音保活
            keepAlive.isVoiceActive = false
        }
        print("[PTTService] Stop talking")
    }

    /// 清空播放缓冲
    public func clearPlayBuffer() {
        audioEngine.clearPlayBuffer()
    }

    // MARK: - 音频控制

    /// 静音状态
    private var isMuted: Bool = false

    /// 设置静音
    public func setMuted(_ muted: Bool) {
        isMuted = muted
        audioEngine.playbackVolume = muted ? 0 : playbackVolume
    }

    /// 设置扬声器音量
    public func setSpeakerVolume(_ volume: Float) {
        playbackVolume = volume
        if !isMuted {
            audioEngine.playbackVolume = volume
        }
    }

    /// 设置麦克风音量
    public func setMicVolume(_ volume: Float) {
        recordingVolume = volume
    }

    /// 设置扬声器/听筒模式
    public func setSpeakerMode(_ speakerOn: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if speakerOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            pttLogger.error("❌ Failed to set speaker mode: \(error.localizedDescription)")
        }
    }

    /// 设置会议模式（切换音频处理模式）
    /// - Parameter enabled: true = 会议模式（启用 AEC 回声消除），false = 普通 PTT 模式
    public func setConferenceMode(_ enabled: Bool) {
        guard isConferenceMode != enabled else { return }  // 模式相同，不做任何操作

        isConferenceMode = enabled
        audioEngine.setConferenceMode(enabled)
        pttLogger.info("🎤 Conference mode: \(enabled ? "ON" : "OFF")")
        // 不再清空缓冲区，让音频流自然过渡
    }

    // MARK: - 音频中断恢复

    /// 音频重启重试次数
    private var audioRestartRetryCount = 0
    private static let maxAudioRestartRetries = 3
    private static let audioRestartDelayMs = 500  // 延迟 500ms 后重启

    // MARK: - 语音接收时音频检测（用于检测音频是否真正在工作）

    /// 上次音频检测重启时间（避免频繁重启）
    private var lastAudioCheckRestartTime: Date?
    /// 音频检测重启冷却时间（秒）- 避免频繁重启
    private static let audioCheckRestartCooldownSec: TimeInterval = 5.0
    /// 播放回调活跃检测时间窗口（毫秒）
    private static let playbackCallbackActiveWindowMs = 1000

    /// 中断后重启音频引擎
    /// 电话、Siri 等中断结束后，iOS 可能已停止 AudioUnit，必须重新启动
    private func restartAudioEngineAfterInterruption() {
        // 1. 如果有语音增强处理器在运行，先停止
        if isVoiceEnhancementStarted {
            voiceEnhancementProcessor?.stop()
            isVoiceEnhancementStarted = false
            pttLogger.notice("🔔 Voice enhancement processor stopped")
        }

        // 2. 检查连接状态
        guard isConnected else {
            pttLogger.notice("🔔 Not connected, skip audio engine restart")
            return
        }

        // 3. 重置重试计数
        audioRestartRetryCount = 0

        // 4. 延迟执行重启（给 iOS 时间准备）
        pttLogger.notice("🔔 Scheduling audio restart in \(Self.audioRestartDelayMs)ms...")
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.audioRestartDelayMs)) { [weak self] in
            self?.performAudioRestart()
        }
    }

    /// 执行音频重启（带重试机制）
    private func performAudioRestart() {
        guard isConnected else {
            pttLogger.notice("🔔 Connection lost, abort audio restart")
            return
        }

        self.audioRestartRetryCount += 1
        pttLogger.notice("🔔 Audio restart attempt #\(self.audioRestartRetryCount)")

        // 1. 确保音频路由正确（强制切换到扬声器）
        do {
            let session = AVAudioSession.sharedInstance()

            // 检查当前音频路由
            let currentRoute = session.currentRoute
            let outputPorts = currentRoute.outputs.map { $0.portType.rawValue }
            pttLogger.notice("🔊 Current audio route: \(outputPorts.joined(separator: ", "))")

            // 重新激活音频会话并切换到扬声器
            try session.setActive(false, options: [])
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            )
            try session.setActive(true, options: [])

            // 验证路由已切换
            let newRoute = session.currentRoute
            let newOutputPorts = newRoute.outputs.map { $0.portType.rawValue }
            pttLogger.notice("🔊 New audio route: \(newOutputPorts.joined(separator: ", "))")

        } catch {
            pttLogger.error("❌ Failed to configure audio session: \(error)")
        }

        // 2. 强制重启音频引擎
        do {
            try audioEngine.forceRestart()
            pttLogger.notice("✅ Audio engine force restarted after interruption (attempt #\(self.audioRestartRetryCount))")

            // 3. 重新设置录音回调
            setupCallbacks()

            // 4. 通知 BackgroundKeepAlive 音频已恢复
            keepAlive.notifyAudioRestarted()

            // 5. 如果降噪开启，重启 VoiceEnhancementProcessor（仅预热，不影响前台正常使用）
            if (noiseReductionEnabled || voiceEQEnabled), let processor = voiceEnhancementProcessor {
                pttLogger.notice("🔔 Restarting VoiceEnhancementProcessor after interruption...")
                processor.stop()
                isVoiceEnhancementStarted = false
                do {
                    try processor.start()
                    isVoiceEnhancementStarted = true
                    setupVoiceEnhancementCallbacks(processor)
                    pttLogger.notice("✅ VoiceEnhancementProcessor restarted after interruption")
                } catch {
                    pttLogger.error("❌ Failed to restart VoiceEnhancementProcessor: \(error)")
                    // 失败不影响基本功能，用户按 PTT 时会再次尝试启动
                }
            }

            pttLogger.notice("✅ Audio restart completed successfully")

            // 6. 延迟验证音频是否真正恢复
            scheduleAudioVerificationAfterRestart()

        } catch {
            pttLogger.error("❌ Failed to force restart audio engine (attempt #\(self.audioRestartRetryCount)): \(error)")

            // 重试机制
            if self.audioRestartRetryCount < Self.maxAudioRestartRetries {
                let retryDelayMs = Self.audioRestartDelayMs * (self.audioRestartRetryCount + 1)
                pttLogger.notice("🔄 Retrying audio restart in \(retryDelayMs)ms...")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(retryDelayMs)) { [weak self] in
                    self?.performAudioRestart()
                }
            } else {
                pttLogger.error("❌ Audio restart failed after \(Self.maxAudioRestartRetries) attempts")
                // 最后尝试普通重启
                do {
                    audioEngine.stop()
                    try audioEngine.start()
                    setupCallbacks()
                    keepAlive.notifyAudioRestarted()
                    pttLogger.notice("✅ Audio engine restarted (final fallback)")
                } catch {
                    pttLogger.error("❌ Final fallback restart also failed: \(error)")
                }
            }
        }
    }

    /// 电话中断后调度音频验证
    /// 验证 AudioUnit 是否真正开始工作（检测假启动）
    private func scheduleAudioVerificationAfterRestart() {
        // 1 秒后验证 playbackCallback 是否被调用
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isConnected else { return }

            let isActive = self.audioEngine.isPlaybackCallbackActive(withinMs: 1500)

            if !isActive {
                pttLogger.warning("⚠️ Audio verification failed after restart: playback callback not active")

                // 再次尝试重启（最多重试 2 次）
                if self.audioRestartRetryCount < Self.maxAudioRestartRetries + 2 {
                    pttLogger.notice("🔄 Scheduling another restart attempt...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.performAudioRestart()
                    }
                }
            } else {
                pttLogger.notice("✅ Audio verification passed after restart")
            }
        }
    }

    // MARK: - 发送定时器

    private func startSendTimer() {
        sendTimerLock.lock()
        defer { sendTimerLock.unlock() }

        // 先停止旧定时器
        sendTimer?.cancel()
        sendTimer = nil

        let interval = sendIntervalMs
        let timer = DispatchSource.makeTimerSource(queue: sendTimerQueue)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(interval),
            leeway: .milliseconds(2)
        )

        timer.setEventHandler { [weak self] in
            self?.sendNextPacket()
        }

        timer.resume()
        sendTimer = timer

        print("[PTTService] Send timer started (interval: \(interval)ms, codec: \(txCodec.rawValue))")
    }

    private func stopSendTimer() {
        sendTimerLock.lock()
        defer { sendTimerLock.unlock() }

        sendTimer?.cancel()
        sendTimer = nil
    }

    /// 发送下一个包
    private func sendNextPacket() {
        sendQueueLock.lock()
        guard !sendQueue.isEmpty else {
            sendQueueLock.unlock()
            return
        }
        let chunk = sendQueue.removeFirst()
        sendQueueLock.unlock()

        guard let config = userConfig else { return }

        let packet: Data

        // 获取当前位置
        let location = currentLocation

        switch txCodec {
        case .g711:
            // G711: 使用预分配包模板
            guard var g711Packet = preAllocatedPacket else { return }

            // 序列号固定为 0 (offset 22-23)
            g711Packet[22] = 0
            g711Packet[23] = 0

            // 写入位置信息 (offset 32-39)
            if let loc = location {
                let latFloat = Float(loc.latitude)
                let lonFloat = Float(loc.longitude)
                let latBits = latFloat.bitPattern
                let lonBits = lonFloat.bitPattern

                g711Packet[32] = UInt8((latBits >> 24) & 0xFF)
                g711Packet[33] = UInt8((latBits >> 16) & 0xFF)
                g711Packet[34] = UInt8((latBits >> 8) & 0xFF)
                g711Packet[35] = UInt8(latBits & 0xFF)

                g711Packet[36] = UInt8((lonBits >> 24) & 0xFF)
                g711Packet[37] = UInt8((lonBits >> 16) & 0xFF)
                g711Packet[38] = UInt8((lonBits >> 8) & 0xFF)
                g711Packet[39] = UInt8(lonBits & 0xFF)
            }

            // 复制音频数据到 payload (offset 48)
            g711Packet.replaceSubrange(48..<(48 + Self.audioPacketSize), with: chunk)

            packet = g711Packet

        case .opus:
            // Opus: 构建可变长度包
            let buildInfo = NRL21Protocol.BuildInfo(
                callSign: config.callSign,
                ssid: config.ssid,
                dmrID: config.dmrID
            )
            packet = NRL21Protocol.buildOpusPacket(
                payload: chunk,
                seq: 0,  // 序列号固定为 0
                info: buildInfo,
                latitude: location?.latitude,
                longitude: location?.longitude
            )
        }

        // 发送
        Task { [weak self] in
            do {
                try await self?.udpClient.send(packet)
                self?.consecutiveSendFail = 0
            } catch {
                self?.handleSendFailure()
            }
        }

        packetsSent += 1

        // 归档 (G711 归档原始数据，Opus 归档带长度前缀)
        if txCodec == .opus {
            // Opus: 添加 2 字节长度前缀（小端序），用于后续解码
            var framedData = Data()
            let length = UInt16(chunk.count)
            framedData.append(UInt8(length & 0xFF))
            framedData.append(UInt8(length >> 8))
            framedData.append(chunk)
            sendAudioArchive.append(framedData)
        } else {
            // G711: 直接归档
            sendAudioArchive.append(chunk)
        }
    }

    /// 刷新发送队列中剩余的包
    private func flushSendQueue() async {
        let interval = sendIntervalMs
        while true {
            let isEmpty = sendQueueLock.withLock { sendQueue.isEmpty }

            if isEmpty { break }

            sendNextPacket()
            try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000)
        }
    }

    // MARK: - 录音处理

    /// Opus TX 帧缓冲 (累积 16kHz Int16 samples)
    private var opusTxBuffer: [Int16] = []
    private let opusTxBufferLock = NSLock()

    private func handleRecordedPCM(_ samples: [Int16]) {
        switch txCodec {
        case .g711:
            handleG711TX(samples)
        case .opus:
            handleOpusTX(samples)
        }

        // 更新音量电平
        let stats = audioEngine.recordingStats
        onVolumeLevel?(stats.rmsLevel)
    }

    /// G711 TX 处理 (8kHz PCM → G711)
    /// 数据驱动发送：累积到 500 字节立即发送，不使用定时器
    private func handleG711TX(_ samples: [Int16]) {
        // 调试：检查收到的样本数量
        print("[G711-TX] received \(samples.count) samples, expected 500 @ 8kHz")

        // PCM -> G711
        let g711Data = codec.encode(samples)

        // 放入音频缓冲区
        audioBufferLock.lock()
        audioBuffer.append(g711Data)

        // 累积到 500 字节时，立即发送
        var totalSize = audioBuffer.reduce(0) { $0 + $1.count }

        while totalSize >= Self.audioPacketSize {
            // 合并缓冲区
            var combined = Data(capacity: totalSize)
            for data in audioBuffer {
                combined.append(data)
            }
            audioBuffer.removeAll()

            // 取出一个完整包
            let chunk = Data(combined.prefix(Self.audioPacketSize))

            // 剩余数据放回缓冲区
            if combined.count > Self.audioPacketSize {
                audioBuffer.append(combined.suffix(from: Self.audioPacketSize))
            }

            totalSize = audioBuffer.reduce(0) { $0 + $1.count }

            audioBufferLock.unlock()

            // 立即发送（数据驱动，不经过队列）
            sendG711PacketDirectly(chunk)

            audioBufferLock.lock()
        }

        audioBufferLock.unlock()
    }

    /// G711 直接发送（数据驱动，不经过发送队列）
    private func sendG711PacketDirectly(_ chunk: Data) {
        // 使用预分配包模板（在 connect 时创建）
        guard var g711Packet = preAllocatedPacket else { return }

        // 获取当前位置
        let location = currentLocation

        // 序列号固定为 0 (offset 22-23)
        g711Packet[22] = 0
        g711Packet[23] = 0

        // 写入位置信息 (offset 32-39)
        if let loc = location {
            let latFloat = Float(loc.latitude)
            let lonFloat = Float(loc.longitude)
            let latBits = latFloat.bitPattern
            let lonBits = lonFloat.bitPattern

            g711Packet[32] = UInt8((latBits >> 24) & 0xFF)
            g711Packet[33] = UInt8((latBits >> 16) & 0xFF)
            g711Packet[34] = UInt8((latBits >> 8) & 0xFF)
            g711Packet[35] = UInt8(latBits & 0xFF)

            g711Packet[36] = UInt8((lonBits >> 24) & 0xFF)
            g711Packet[37] = UInt8((lonBits >> 16) & 0xFF)
            g711Packet[38] = UInt8((lonBits >> 8) & 0xFF)
            g711Packet[39] = UInt8(lonBits & 0xFF)
        }

        // 复制音频数据到 payload (offset 48)
        g711Packet.replaceSubrange(48..<(48 + Self.audioPacketSize), with: chunk)

        // 发送
        Task { [weak self] in
            do {
                try await self?.udpClient.send(g711Packet)
                self?.consecutiveSendFail = 0
            } catch {
                self?.handleSendFailure()
            }
        }

        packetsSent += 1

        // 归档（G711 直接归档）
        sendAudioArchive.append(chunk)
    }

    /// Opus TX 处理 (16kHz PCM → Opus)
    private func handleOpusTX(_ samples: [Int16]) {
        // 懒加载 Opus 编码器
        if txOpusCodec == nil {
            do {
                txOpusCodec = try OpusCodec()
                print("[PTTService] OpusCodec created for TX")
            } catch {
                print("[PTTService] Failed to create OpusCodec for TX: \(error)")
                return
            }
        }

        guard let encoder = txOpusCodec else { return }

        // 累积 16kHz PCM samples
        opusTxBufferLock.lock()
        opusTxBuffer.append(contentsOf: samples)

        // Opus 帧大小: 320 samples @ 16kHz = 20ms
        let opusFrameSize = Int(OpusCodec.frameSize)

        while opusTxBuffer.count >= opusFrameSize {
            // 取出一帧
            let frame = Array(opusTxBuffer.prefix(opusFrameSize))
            opusTxBuffer.removeFirst(opusFrameSize)

            opusTxBufferLock.unlock()

            // 编码为 Opus
            do {
                // 转换为 Data (Int16 -> bytes)
                let pcmData = frame.withUnsafeBytes { Data($0) }
                let opusData = try encoder.encode(pcmData)

                // 放入发送队列 (Opus 包直接发送，不需要累积)
                sendQueueLock.lock()
                sendQueue.append(opusData)
                sendQueueLock.unlock()
            } catch {
                print("[PTTService] Opus encode error: \(error)")
            }

            opusTxBufferLock.lock()
        }

        opusTxBufferLock.unlock()
    }

    // MARK: - 预分配包

    private func createPreAllocatedPacket(config: UserConfig) -> Data {
        let buildInfo = NRL21Protocol.BuildInfo(
            callSign: config.callSign,
            ssid: config.ssid,
            dmrID: config.dmrID
        )

        // 创建一个空的语音包
        let emptyPayload = Data(count: Self.audioPacketSize)
        return NRL21Protocol.buildVoicePacket(
            payload: emptyPayload,
            seq: 0,
            info: buildInfo
        )
    }

    private func sendEndPacket() {
        guard let config = userConfig else { return }

        let buildInfo = NRL21Protocol.BuildInfo(
            callSign: config.callSign,
            ssid: config.ssid,
            dmrID: config.dmrID
        )

        // 发送 3 个结束包确保送达
        for _ in 0..<3 {
            let packet = NRL21Protocol.buildEndPacket(seq: 0, info: buildInfo)  // 序列号固定为 0

            Task {
                do {
                    try await udpClient.send(packet)
                } catch {
                    print("[PTTService] Failed to send end packet: \(error)")
                }
            }
        }
    }

    // MARK: - 接收

    private func handleReceivedData(_ data: Data) {
        // 更新最后响应时间（收到任何包都算）
        updateLastServerResponse()

        // 解析 NRL21 包
        guard let packet = NRL21Protocol.parse(data) else {
            print("[PTTService] Failed to parse packet, size=\(data.count)")
            return
        }

        switch packet.type {
        case .voice, .opus:
            print("[PTTService] Voice packet from \(packet.callSign)-\(packet.ssid), seq=\(packet.seq), payload=\(packet.payload.count)")
            handleVoicePacket(packet)
        case .serverVoice:
            // Type 9 服务器互联语音 (DMR/YSF 等)
            print("[PTTService] ServerVoice(Type9) from \(packet.displayString), DMRID=\(packet.dmrID ?? ""), Orig=\(packet.origCallSign ?? ""), seq=\(packet.seq)")
            handleVoicePacket(packet)
        case .text:
            handleTextPacket(packet)
        case .heartbeat:
            // 心跳响应 - 位置数据通过心跳包传输 (offset 32-39)
            let lat = packet.latitude != nil ? Double(packet.latitude!) : nil
            let lon = packet.longitude != nil ? Double(packet.longitude!) : nil
            if lat != nil && lon != nil {
                print("[PTTService] Heartbeat from \(packet.callSign)-\(packet.ssid), lat=\(lat!), lon=\(lon!)")
            }
            onHeartbeatReceived?(packet.callSign, packet.ssid, lat, lon)
        case .unknown:
            let typeValue = data.count > 20 ? "\(data[20])" : "N/A (data too short: \(data.count))"
            print("[PTTService] Unknown packet type: \(typeValue)")
            break
        }
    }

    private func handleVoicePacket(_ packet: NRL21Protocol.Packet) {
        // 如果未连接，忽略接收（全双工模式：发射时也可接收）
        guard isConnected else { return }

        // 调试日志：打印包内容
        let payloadHex = packet.payload.prefix(20).map { String(format: "%02X", $0) }.joined(separator: " ")
        print("[RX] \(packet.callSign)-\(packet.ssid) seq=\(packet.seq) type=\(packet.type) len=\(packet.payload.count) payload=\(payloadHex)...")

        packetsReceived += 1

        // 检测丢包（使用有符号差值，正确处理序列号回绕）
        if lastRxSeq > 0 || packetsReceived > 1 {
            let diff = Int16(bitPattern: packet.seq &- lastRxSeq)
            if diff > 1 {
                // 正向跳跃，有丢包
                packetsLost += UInt64(diff - 1)
            }
            // diff <= 0: 乱序或重复包，忽略
            // diff == 1: 正常连续，无丢包
        }
        lastRxSeq = packet.seq

        // 提取位置信息（如果有）
        if let lat = packet.latitude, let lon = packet.longitude {
            onHeartbeatReceived?(packet.callSign, packet.ssid, Double(lat), Double(lon))
        }

        // 更新讲话者 (Type 9 服务器互联时使用 displayString 显示真实来源)
        let packetSpeaker = packet.displayString

        // 会议模式下过滤混音呼号（MEETLY），只显示真实说话者
        let isMixerPacket = packetSpeaker.hasPrefix("MEETLY")
        let speaker = (isConferenceMode && isMixerPacket) ? (currentSpeaker ?? packetSpeaker) : packetSpeaker

        // 确定编码类型
        let audioCodec: AudioCodec = (packet.type == .opus) ? .opus : .g711

        if currentSpeaker != speaker {
            // 如果之前有讲话者，先结束之前的通话记录
            if currentSpeaker != nil {
                finalizeReceiveRecord()
            }

            // 讲话者变化，只更新编码配置，不清空缓冲区
            // 让音频自然过渡，避免卡顿
            audioEngine.configureForRxCodec(audioCodec)
            lastRxSeq = 0
            print("[PTTService] Speaker changed to \(speaker), codec: \(audioCodec.rawValue)")

            currentSpeaker = speaker
            currentSpeakerDmrID = packet.dmrID
            keepAlive.isVoiceActive = true  // 暂停静音保活，避免干扰接收
            lastVoiceActivityTime = Date()  // 记录语音活动时间
            receiveSpeakerCallSign = packet.callSign
            receiveSpeakerSsid = packet.ssid
            receiveStartTime = Date()
            receiveAudioArchive.removeAll()

            onSpeakerChanged?(speaker)
            onStateChanged?(.receiving(speaker: speaker))

            // 启动语音识别（如果已启用）
            if speechRecognitionEnabled {
                let sampleRate = (packet.type == .opus) ? 16000 : 8000
                SpeechRecognitionService.shared.startRecognition(speaker: speaker, sampleRate: sampleRate)
            }
        }

        // 不再检测静音包内容，完全依靠超时机制（500ms 无包）判断结束
        // 这样更可靠，避免误判对方"按住 PTT 但没说话"的情况

        // 归档接收的音频数据（记录编码格式）
        if audioCodec == .opus {
            // Opus: 添加 2 字节长度前缀（小端序），用于后续解码
            var framedData = Data()
            let length = UInt16(packet.payload.count)
            framedData.append(UInt8(length & 0xFF))
            framedData.append(UInt8(length >> 8))
            framedData.append(packet.payload)
            receiveAudioArchive.append(framedData)
        } else {
            // G711: 直接归档
            receiveAudioArchive.append(packet.payload)
        }
        receiveCodec = audioCodec

        // 直接解码并写入播放缓冲区（数据驱动，playbackBuffer 内部有初始缓冲逻辑）
        playAudioPacket(payload: packet.payload, codec: audioCodec)

        // 重置接收超时
        resetReceiveTimeout()
    }

    /// 解码并播放音频包（数据驱动，直接写入 playbackBuffer）
    private func playAudioPacket(payload: Data, codec audioCodec: AudioCodec) {
        guard isConnected, !payload.isEmpty else { return }

        switch audioCodec {
        case .g711:
            // G711 解码 → 8kHz PCM Int16 → 写入 playbackBuffer（内部 8k→16k 上采样）
            let pcm8k = codec.decode(payload)
            guard !pcm8k.isEmpty else { return }
            audioEngine.playInt16(pcm8k, sampleRate: 8000)

            // 追加到语音识别（如果已启用）
            if speechRecognitionEnabled {
                SpeechRecognitionService.shared.appendAudio(pcm8k, sampleRate: 8000)
            }

        case .opus:
            // Opus 解码 → 16kHz PCM Int16 → 直接写入 playbackBuffer
            guard let pcm16k = decodeOpusPacket(payload), !pcm16k.isEmpty else { return }
            audioEngine.playInt16(pcm16k, sampleRate: 16000)

            // 追加到语音识别（如果已启用）
            if speechRecognitionEnabled {
                SpeechRecognitionService.shared.appendAudio(pcm16k, sampleRate: 16000)
            }
        }

        // 更新音量电平
        let stats = audioEngine.playbackStats
        onVolumeLevel?(stats.rmsLevel)

        // 直接检测音频回调是否活跃（不依赖语音状态，每次写入都检测）
        checkPlaybackAndRestartIfNeeded()
    }

    /// 检查播放回调是否活跃，如果不活跃则重启音频
    /// 直接检测，不依赖 currentSpeaker 状态
    private func checkPlaybackAndRestartIfNeeded() {
        // 检查是否在冷却期内
        if let lastRestart = lastAudioCheckRestartTime {
            let elapsed = Date().timeIntervalSince(lastRestart)
            if elapsed < Self.audioCheckRestartCooldownSec {
                // 冷却期内，跳过检测（每 10 秒打印一次日志避免刷屏）
                return
            }
        }

        // 检查播放回调是否活跃（1秒内是否有回调）
        let isCallbackActive = audioEngine.isPlaybackCallbackActive(withinMs: Self.playbackCallbackActiveWindowMs)

        if !isCallbackActive {
            // 回调不活跃，音频没有工作，需要重启
            pttLogger.warning("⚠️ Audio check: playback callback NOT active (no callback in \(Self.playbackCallbackActiveWindowMs)ms), restarting...")

            // 记录重启时间
            lastAudioCheckRestartTime = Date()

            // 执行完整的音频重启
            performFullAudioRestart()
        }
    }

    /// 执行完整的音频重启（用于语音接收时检测到音频不工作的情况）
    private func performFullAudioRestart() {
        pttLogger.notice("🔄 Performing full audio restart due to inactive playback callback")

        // 1. 如果有语音增强处理器在运行，先停止
        if isVoiceEnhancementStarted {
            voiceEnhancementProcessor?.stop()
            isVoiceEnhancementStarted = false
        }

        // 2. 重新配置音频会话
        do {
            let session = AVAudioSession.sharedInstance()

            // 先停用再激活，完全重置
            try session.setActive(false, options: [])
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            )
            try session.setActive(true, options: [])
            pttLogger.notice("🔊 Audio session reconfigured")
        } catch {
            pttLogger.error("❌ Failed to reconfigure audio session: \(error)")
        }

        // 3. 强制重启 AudioUnit
        do {
            try audioEngine.forceRestart()
            setupCallbacks()
            keepAlive.notifyAudioRestarted()
            pttLogger.notice("✅ Full audio restart completed")
        } catch {
            pttLogger.error("❌ Full audio restart failed: \(error)")
        }
    }

    /// 解码 Opus 包为 16kHz PCM
    private func decodeOpusPacket(_ opusData: Data) -> [Int16]? {
        // 懒加载 Opus 解码器
        if opusCodec == nil {
            do {
                opusCodec = try OpusCodec()
                print("[PTTService] OpusCodec created for RX")
            } catch {
                print("[PTTService] Failed to create OpusCodec: \(error)")
                return nil
            }
        }

        guard let decoder = opusCodec else { return nil }

        do {
            // Opus 解码 -> 16kHz PCM (Data)
            let pcm16kData = try decoder.decode(opusData)

            // Data -> [Int16]（安全的逐字节读取，避免内存对齐问题）
            // 确保只处理偶数长度，防止越界
            let safeByteCount = (pcm16kData.count / 2) * 2
            let sampleCount = safeByteCount / 2
            var samples16k = [Int16](repeating: 0, count: sampleCount)
            for i in 0..<sampleCount {
                let low = UInt16(pcm16kData[i * 2])
                let high = UInt16(pcm16kData[i * 2 + 1])
                samples16k[i] = Int16(bitPattern: low | (high << 8))
            }

            return samples16k
        } catch {
            print("[PTTService] Opus decode error: \(error)")
            return nil
        }
    }

    private func handleVoiceEnd() {
        // 如果已断开连接，不处理
        guard isConnected else { return }

        // 停止语音识别（如果正在进行）
        if speechRecognitionEnabled {
            SpeechRecognitionService.shared.stopRecognition()
        }

        // 生成接收通话记录
        finalizeReceiveRecord()

        // 记录语音活动时间
        lastVoiceActivityTime = Date()
        currentSpeaker = nil
        currentSpeakerDmrID = nil
        receiveTimeoutTask?.cancel()
        onSpeakerChanged?(nil)
        onStateChanged?(.connected)

        // 没有发射时，恢复静音保活
        if !isTalking {
            keepAlive.isVoiceActive = false
        }
    }

    /// 生成接收通话记录
    private func finalizeReceiveRecord() {
        guard let startTime = receiveStartTime,
              let callSign = receiveSpeakerCallSign,
              !receiveAudioArchive.isEmpty else {
            return
        }

        // 合并接收的音频数据
        var mergedData = Data()
        for chunk in receiveAudioArchive {
            mergedData.append(chunk)
        }

        let record = CallRecord(
            callSign: callSign,
            ssid: receiveSpeakerSsid,
            startTime: startTime,
            endTime: Date(),
            isSelf: false,
            audioData: mergedData,
            groupId: userConfig?.groupId ?? 0,
            codec: receiveCodec,
            transcription: currentRxTranscription
        )

        onCallEnded?(record)

        // 清空接收归档
        receiveAudioArchive.removeAll()
        receiveStartTime = nil
        receiveSpeakerCallSign = nil
        receiveSpeakerSsid = 0
        receiveCodec = .g711
        currentRxTranscription = nil
    }

    private func resetReceiveTimeout() {
        receiveTimeoutTask?.cancel()
        receiveTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms 超时（快速释放）
            guard let self = self, !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.handleVoiceEnd()
            }
        }
    }

    private func handleTextPacket(_ packet: NRL21Protocol.Packet) {
        // 未连接时不处理
        guard isConnected else { return }

        // 解析文本内容
        guard let text = String(data: packet.payload, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) else {
            return
        }

        // 忽略空消息
        guard !text.isEmpty else { return }

        print("[PTTService] Text from \(packet.callSign)-\(packet.ssid): \(text)")

        // 创建消息对象
        let message = TextMessage(
            sender: packet.callSign,
            ssid: packet.ssid,
            content: text,
            timestamp: Date(),
            isSelf: packet.callSign == userConfig?.callSign && packet.ssid == userConfig?.ssid
        )

        // 回调
        Task { @MainActor in
            self.onTextReceived?(message)
        }
    }

    // MARK: - 文本消息

    /// 发送文本消息 (紧凑格式，不补0)
    public func sendText(_ text: String) {
        guard isConnected, let config = userConfig else {
            print("[PTTService] Cannot send text: not connected")
            return
        }

        guard !text.isEmpty else { return }

        let buildInfo = NRL21Protocol.BuildInfo(
            callSign: config.callSign,
            ssid: config.ssid,
            dmrID: config.dmrID
        )

        let packet = NRL21Protocol.buildCompactTextPacket(text: text, info: buildInfo)

        Task {
            try? await udpClient.send(packet)
            print("[PTTService] Sent text: \(text)")
        }
    }

    /// 发送紧凑文本消息 (可变长度，用于 LOC 等)
    public func sendCompactText(_ text: String) {
        guard isConnected, let config = userConfig else { return }
        guard !text.isEmpty else { return }

        let buildInfo = NRL21Protocol.BuildInfo(
            callSign: config.callSign,
            ssid: config.ssid,
            dmrID: config.dmrID
        )

        let packet = NRL21Protocol.buildCompactTextPacket(text: text, info: buildInfo)

        Task {
            try? await udpClient.send(packet)
        }
    }

    // MARK: - 归档

    private func mergeAudioArchive() -> Data {
        var merged = Data()
        for chunk in sendAudioArchive {
            merged.append(chunk)
        }
        return merged
    }

    // MARK: - 心跳

    /// 启动心跳定时器
    private func startHeartbeatTimer() {
        heartbeatTimerLock.lock()
        defer { heartbeatTimerLock.unlock() }

        // 先停止旧定时器
        heartbeatTimer?.cancel()
        heartbeatTimer = nil

        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(
            deadline: .now() + .milliseconds(Self.heartbeatIntervalMs),
            repeating: .milliseconds(Self.heartbeatIntervalMs),
            leeway: .milliseconds(100)
        )

        timer.setEventHandler { [weak self] in
            self?.checkConnectionAndSendHeartbeat()
        }

        timer.resume()
        heartbeatTimer = timer

        print("[PTTService] Heartbeat timer started (interval: \(Self.heartbeatIntervalMs)ms)")
    }

    /// 停止心跳定时器
    private func stopHeartbeatTimer() {
        heartbeatTimerLock.lock()
        defer { heartbeatTimerLock.unlock() }

        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    /// 检查连接状态并发送心跳
    private func checkConnectionAndSendHeartbeat() {
        let now = Date()
        let nowStr = Self.diagDateFormatter.string(from: now)

        // 音频中断期间：跳过超时检查，但继续发心跳保持服务器连接
        // 这样电话结束后服务器不会踢掉客户端
        if isAudioInterrupted {
            pttLogger.notice("⏱ HB check \(nowStr) | interrupted, send HB only")
            sendHeartbeat()  // 继续发心跳！
            return
        }

        // 正在重连时：跳过超时检查，但继续发送心跳保持服务器端在线
        if isReconnecting {
            pttLogger.notice("⏱ HB check \(nowStr) | reconnecting, send HB only")
            sendHeartbeat()
            return
        }

        // 检查超时
        if let lastResponse = lastServerResponse {
            let elapsed = now.timeIntervalSince(lastResponse) * 1000

            // 诊断日志：每次心跳检查都记录状态
            pttLogger.notice("⏱ HB check \(nowStr) | lastRx=\(Int(elapsed))ms | offline=\(Self.offlineThresholdMs)ms")

            // 8秒无响应触发重连
            if elapsed > Double(Self.offlineThresholdMs) {
                pttLogger.warning("⚠️ Offline detected: elapsed=\(Int(elapsed))ms > \(Self.offlineThresholdMs)ms")
                triggerReconnect(reason: "无响应超过 \(Int(elapsed / 1000))s")
                return
            }

            // 60秒超时：前台无限重连，后台彻底断开
            if elapsed > Double(Self.connectionTimeoutMs) {
                if isInBackground {
                    // 后台模式：60秒超时彻底断开，节省电量
                    pttLogger.error("❌ TIMEOUT (bg): elapsed=\(Int(elapsed))ms > \(Self.connectionTimeoutMs)ms")
                    pttLogger.error("❌ Last response: \(Self.diagDateFormatter.string(from: lastResponse))")
                    Task { @MainActor in
                        self.isConnected = false
                        self.onStateChanged?(.disconnected)
                        self.onError?(.networkError("连接超时"))
                    }
                    return
                } else {
                    // 前台模式：继续重连，不断开
                    pttLogger.warning("⚠️ TIMEOUT (fg): elapsed=\(Int(elapsed))ms, keep reconnecting...")
                    triggerReconnect(reason: "超时但前台继续重连")
                    return
                }
            }
        } else {
            pttLogger.notice("⏱ HB check \(nowStr) | No lastServerResponse yet")
        }

        // 发送心跳
        sendHeartbeat()
    }

    /// 诊断用日期格式化器
    private static let diagDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt
    }()

    /// 发送心跳包
    private func sendHeartbeat() {
        guard let config = userConfig else { return }

        let location = currentLocation
        let packet = NRL21Protocol.createHeartbeatPacket(
            callSign: config.callSign,
            ssid: config.ssid,
            dmrID: config.dmrID,
            latitude: location?.latitude,
            longitude: location?.longitude
        )

        let sendTime = Self.diagDateFormatter.string(from: Date())
        pttLogger.notice("📤 HB SENT \(sendTime)")

        Task { [weak self] in
            do {
                try await self?.udpClient.send(packet)
            } catch {
                self?.handleSendFailure()
            }
        }
    }

    /// 更新最后服务器响应时间（收到任何包时调用）
    private func updateLastServerResponse() {
        lastServerResponse = Date()
        consecutiveSendFail = 0  // 收到包说明连接正常
        reconnectRetryCount = 0  // 重置重连计数

        // 如果正在重连，收到响应说明网络已恢复，取消重连
        if isReconnecting {
            pttLogger.notice("📥 RX while reconnecting - network recovered, cancel reconnect")
            reconnectTask?.cancel()
            reconnectTask = nil
            isReconnecting = false
        }

        pttLogger.notice("📥 RX \(Self.diagDateFormatter.string(from: self.lastServerResponse!))")
    }

    // MARK: - 自愈重连

    /// 处理发送失败
    private func handleSendFailure() {
        consecutiveSendFail += 1
        pttLogger.warning("⚠️ Send failed, count=\(self.consecutiveSendFail)")

        if consecutiveSendFail >= 3 {
            triggerReconnect(reason: "连续发送失败 \(consecutiveSendFail) 次")
        }
    }

    /// 触发重连
    private func triggerReconnect(reason: String) {
        guard !isReconnecting, isConnected else { return }

        pttLogger.notice("🔄 Reconnect triggered: \(reason)")
        startReconnect()
    }

    /// 开始重连（指数退避，前台持续/后台降频）
    private func startReconnect() {
        guard !isReconnecting else { return }
        guard let config = userConfig ?? savedConnectionConfig else {
            pttLogger.error("❌ Cannot reconnect: no saved config")
            return
        }

        isReconnecting = true
        savedConnectionConfig = config

        // 计算退避延迟
        let delaySec: Int
        if isInBackground {
            // 后台模式：固定 60s 间隔
            delaySec = Self.backgroundReconnectIntervalSec
        } else {
            // 前台模式：指数退避 1→2→4→8→15s，之后保持 15s
            let delayIndex = min(reconnectRetryCount, Self.reconnectBackoffSeconds.count - 1)
            delaySec = Self.reconnectBackoffSeconds[delayIndex]
        }
        reconnectRetryCount += 1

        let mode = isInBackground ? "bg" : "fg"
        pttLogger.notice("🔄 Reconnect[\(mode)] in \(delaySec)s (attempt #\(self.reconnectRetryCount))")

        // 取消之前的重连任务
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySec) * 1_000_000_000)
            guard let self = self, !Task.isCancelled else { return }

            // 执行重连
            await self.performReconnect(config: config)
        }
    }

    /// 执行重连
    private func performReconnect(config: UserConfig) async {
        pttLogger.notice("🔄 Performing reconnect...")

        // 先断开
        await disconnect()

        // 重连
        do {
            try await connect(config: config)
            pttLogger.notice("✅ Reconnect successful after \(self.reconnectRetryCount) attempts")
            isReconnecting = false
            reconnectRetryCount = 0
            consecutiveSendFail = 0
        } catch {
            pttLogger.error("❌ Reconnect failed: \(error.localizedDescription)")
            isReconnecting = false
            // 前台：持续重连；后台：继续尝试
            startReconnect()
        }
    }

    /// 取消重连（tokenExpired 或登出时调用）
    public func cancelReconnect() {
        pttLogger.notice("🛑 Reconnect cancelled")
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
        reconnectRetryCount = 0
    }

    /// 手动触发重连（供 UI 调用）
    public func manualReconnect() {
        pttLogger.notice("🔄 Manual reconnect triggered")

        // 如果正在重连，不重复触发
        guard !isReconnecting else {
            pttLogger.notice("🔄 Already reconnecting, skip")
            return
        }

        // 检查是否有保存的配置
        guard savedConnectionConfig != nil || userConfig != nil else {
            pttLogger.error("❌ Cannot reconnect: no saved config")
            return
        }

        reconnectRetryCount = 0  // 重置计数，立即重连
        startReconnect()  // 直接调用 startReconnect，绕过 isConnected 检查
    }

    /// App 进入前台时检查连接状态（供外部调用）
    public func checkConnectionOnForeground() {
        isInBackground = false

        guard isConnected || savedConnectionConfig != nil else { return }

        // 如果正在重连，取消后台的60秒等待，立即用前台短延迟重连
        if isReconnecting {
            pttLogger.notice("🔄 Foreground: canceling bg reconnect, retry immediately")
            reconnectTask?.cancel()
            isReconnecting = false
            reconnectRetryCount = 0
            // 立即触发前台重连（使用短延迟）
            triggerReconnect(reason: "前台立即重连")
            return
        }

        if let lastRx = lastServerResponse {
            let elapsed = Date().timeIntervalSince(lastRx) * 1000
            if elapsed > Double(Self.offlineThresholdMs) {
                pttLogger.notice("🔄 Foreground check: offline detected (elapsed=\(Int(elapsed))ms)")
                triggerReconnect(reason: "前台检测到离线")
            }
        }
    }

    /// App 进入后台时调用
    public func onEnterBackground() {
        isInBackground = true
        pttLogger.notice("📴 Entered background mode")

        // 检查后台保活激活条件
        // 1. 已连接服务器
        guard isConnected else {
            pttLogger.notice("📴 Background keep-alive: OFF (not connected)")
            return
        }

        // 3. 最近 5 分钟有语音活动
        let hasRecentActivity: Bool
        if let lastActivity = lastVoiceActivityTime {
            let elapsed = Date().timeIntervalSince(lastActivity)
            hasRecentActivity = elapsed < Self.idleTimeoutSeconds
            pttLogger.notice("📴 Last voice activity: \(Int(elapsed))s ago")
        } else {
            hasRecentActivity = false
            pttLogger.notice("📴 No voice activity recorded")
        }

        guard hasRecentActivity else {
            pttLogger.notice("📴 Background keep-alive: OFF (no recent voice activity)")
            return
        }

        // 所有条件满足，启动后台保活
        pttLogger.notice("🟢 Background keep-alive: STARTING")
        keepAlive.start(audioEngine: audioEngine)

        // 启动空闲检测定时器
        startIdleCheckTimer()
    }

    /// App 进入前台时调用
    public func onEnterForeground() {
        isInBackground = false
        pttLogger.notice("📱 Entered foreground mode")

        // 结束后台任务（前台不需要）
        #if canImport(UIKit)
        if self.backgroundTaskId != .invalid {
            pttLogger.notice("📱 Ending background task on foreground, id=\(self.backgroundTaskId.rawValue)")
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
        #endif

        // 停止后台保活（前台不需要）
        stopBackgroundKeepAlive()

        // 只在音频被中断过时才重启引擎，否则不做任何操作
        // 减少不必要的干预，保持音频流稳定
        if isConnected && !audioEngine.isEngineRunning {
            do {
                try audioEngine.start()
                setupCallbacks()
                pttLogger.notice("📱 Audio engine started for foreground")
            } catch {
                pttLogger.error("❌ Failed to start audio engine: \(error)")
            }
        }

        // 检查连接状态
        checkConnectionOnForeground()
    }

    /// 停止后台保活（登出/Token 过期/空闲超时时调用）
    public func stopBackgroundKeepAlive() {
        idleCheckTimer?.cancel()
        idleCheckTimer = nil
        keepAlive.stop()
        pttLogger.notice("🔴 Background keep-alive: STOPPED")
    }

    /// 启动空闲检测定时器
    private func startIdleCheckTimer() {
        idleCheckTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: idleCheckQueue)
        // 每 30 秒检查一次空闲状态
        timer.schedule(deadline: .now() + 30, repeating: 30, leeway: .seconds(5))
        timer.setEventHandler { [weak self] in
            self?.checkIdleTimeout()
        }
        timer.resume()
        idleCheckTimer = timer
        pttLogger.notice("⏱ Idle check timer started")
    }

    /// 检查空闲超时
    private func checkIdleTimeout() {
        guard let lastActivity = lastVoiceActivityTime else {
            // 无语音活动记录，停止保活
            pttLogger.notice("⏱ Idle check: no activity recorded, stopping keep-alive")
            stopBackgroundKeepAlive()
            return
        }

        let elapsed = Date().timeIntervalSince(lastActivity)
        pttLogger.notice("⏱ Idle check: last activity \(Int(elapsed))s ago")

        if elapsed >= Self.idleTimeoutSeconds {
            pttLogger.notice("⏱ Idle timeout (\(Int(Self.idleTimeoutSeconds))s), stopping keep-alive")
            stopBackgroundKeepAlive()
        }
    }

    // MARK: - 统计

    public var stats: PTTStats {
        PTTStats(
            packetsReceived: packetsReceived,
            packetsSent: packetsSent,
            packetsLost: packetsLost,
            bufferLevelMs: audioEngine.playbackStats.bufferLevelMs,
            underrunCount: audioEngine.playbackStats.underrunCount
        )
    }
}

// MARK: - 辅助类型

/// 用户配置
public struct UserConfig: Sendable {
    public let host: String
    public let port: UInt16
    public let callSign: String
    public let ssid: Int
    public let groupId: Int
    public let dmrID: String?

    public init(host: String, port: UInt16, callSign: String, ssid: Int, groupId: Int = 0, dmrID: String? = nil) {
        self.host = host
        self.port = port
        self.callSign = callSign
        self.ssid = ssid
        self.groupId = groupId
        self.dmrID = dmrID
    }
}

/// 服务状态
public enum PTTServiceState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case talking
    case receiving(speaker: String)
}

/// 服务错误
public enum PTTServiceError: Error, LocalizedError {
    case notConnected
    case channelBusy
    case audioSetupFailed
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到服务器"
        case .channelBusy:
            return "频道繁忙，请稍后再试"
        case .audioSetupFailed:
            return "音频设置失败"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        }
    }
}

/// PTT 统计
public struct PTTStats: Sendable {
    public let packetsReceived: UInt64
    public let packetsSent: UInt64
    public let packetsLost: UInt64
    public let bufferLevelMs: Int
    public let underrunCount: UInt64

    public var lossRate: Double {
        let total = packetsReceived + packetsLost
        guard total > 0 else { return 0 }
        return Double(packetsLost) / Double(total)
    }
}

/// 通话记录
public struct CallRecord: Sendable, Identifiable, Codable {
    public let id: String
    public let callSign: String
    public let ssid: Int
    public let startTime: Date
    public let endTime: Date
    public let isSelf: Bool
    public let groupId: Int
    public let audioData: Data
    /// 音频编码格式（默认 G711，向后兼容）
    public let codec: AudioCodec
    /// 语音识别文字（实时字幕）
    public var transcription: String?

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public init(callSign: String, ssid: Int, startTime: Date, endTime: Date, isSelf: Bool, audioData: Data, groupId: Int = 0, codec: AudioCodec = .g711, transcription: String? = nil) {
        self.id = UUID().uuidString
        self.callSign = callSign
        self.ssid = ssid
        self.startTime = startTime
        self.endTime = endTime
        self.isSelf = isSelf
        self.audioData = audioData
        self.groupId = groupId
        self.codec = codec
        self.transcription = transcription
    }

    // MARK: - Codable (向后兼容旧数据)

    private enum CodingKeys: String, CodingKey {
        case id, callSign, ssid, startTime, endTime, isSelf, groupId, audioData, codec, transcription
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        callSign = try container.decode(String.self, forKey: .callSign)
        ssid = try container.decode(Int.self, forKey: .ssid)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        isSelf = try container.decode(Bool.self, forKey: .isSelf)
        groupId = try container.decode(Int.self, forKey: .groupId)
        audioData = try container.decode(Data.self, forKey: .audioData)
        // 向后兼容：旧数据没有 codec 字段，默认使用 G711
        codec = try container.decodeIfPresent(AudioCodec.self, forKey: .codec) ?? .g711
        // 向后兼容：旧数据没有 transcription 字段
        transcription = try container.decodeIfPresent(String.self, forKey: .transcription)
    }
}

/// 文本消息
public struct TextMessage: Sendable, Identifiable, Codable {
    public let id: String
    public let sender: String
    public let ssid: Int
    public let content: String
    public let timestamp: Date
    public let isSelf: Bool
    public let groupId: Int

    /// 显示名称 (带SSID)
    public var displayName: String {
        "\(sender)-\(ssid)"
    }

    public init(sender: String, ssid: Int, content: String, timestamp: Date, isSelf: Bool, groupId: Int = 0) {
        self.id = UUID().uuidString
        self.sender = sender
        self.ssid = ssid
        self.content = content
        self.timestamp = timestamp
        self.isSelf = isSelf
        self.groupId = groupId
    }
}
