import Foundation
import Combine
import AVFoundation
import PTTInfra
import PTTCodec

/// Re-export AudioCodec for UI use (fully qualified to avoid AudioToolbox conflict)
public typealias TxAudioCodec = PTTInfra.AudioCodec

/// APP 设备默认 SSID
private let kAppDefaultSsid = 106

/// PTT 主界面 ViewModel
///
/// 桥接 PTTService 到 SwiftUI
@MainActor
public final class PTTViewModel: ObservableObject {

    // MARK: - Published 状态

    /// 是否已登录（PTT 服务器）
    @Published public var isLoggedIn: Bool = false

    /// 是否正在登录
    @Published public var isLoggingIn: Bool = false

    /// 是否已连接
    @Published public var isConnected: Bool = false

    /// 是否正在连接
    @Published public var isConnecting: Bool = false

    /// 是否正在发射
    @Published public var isTalking: Bool = false

    /// 当前讲话者
    @Published public var currentSpeaker: String?

    /// 当前讲话者的 DMR ID
    public var currentSpeakerDmrID: String? {
        pttService.currentSpeakerDmrID
    }

    /// 当前接收的编码格式（用于 UI 显示不同颜色）
    public var receiveCodec: PTTInfra.AudioCodec {
        pttService.receiveCodec
    }

    /// 错误信息
    @Published public var errorMessage: String?

    /// 登录错误
    @Published public var loginError: String?

    /// 是否显示 Token 过期弹窗
    @Published public var showTokenExpiredAlert: Bool = false

    /// 当前音量电平 (0.0 ~ 1.0)
    @Published public var volumeLevel: Float = 0

    /// 网络延迟（毫秒），nil 表示未知
    @Published public var latency: Int? = nil

    /// 发射计时（秒）
    @Published public var talkingDuration: Int = 0

    // MARK: - 网络统计

    @Published public var packetsReceived: UInt64 = 0
    @Published public var packetsLost: UInt64 = 0
    @Published public var lossRate: Double = 0
    @Published public var bufferLevelMs: Int = 0

    // MARK: - 用户配置

    /// API 服务器地址 (HTTP/HTTPS)
    @Published public var serverUrl: String = "https://ptt.pgarlic.com"

    /// UDP 服务器地址（从 API 服务器提取）
    @Published public var serverHost: String = "ptt.pgarlic.com"
    @Published public var serverPort: UInt16 = 60050

    /// 平台服务器列表
    @Published public var platformServers: [PlatformServer] = []

    /// 自定义服务器列表
    @Published public var customServers: [PlatformServer] = []

    /// 当前选中的平台服务器
    @Published public var selectedPlatformServer: PlatformServer?

    /// 是否正在加载平台服务器列表
    @Published public var isLoadingPlatformServers: Bool = false

    /// 平台服务器加载错误信息
    @Published public var platformServerError: String?

    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var callSign: String = ""
    @Published public var ssid: Int = kAppDefaultSsid

    /// 当前用户 ID（用于修改密码等 API）
    public var userId: Int = 0

    /// 当前用户对象（用于更新用户信息）
    private var currentUser: UserInfo?

    /// DMR ID（协议传输 + 后端存储）
    @Published public var dmrid: String = ""

    /// MDC ID（仅后端存储）
    @Published public var mdcid: String = ""

    /// 记住密码
    @Published public var rememberMe: Bool = false

    /// 是否管理员
    @Published public var isAdmin: Bool = false

    /// 对讲组列表
    @Published public var groups: [PttGroup] = []

    /// 当前选中的群组
    @Published public var currentGroup: PttGroup? {
        didSet {
            // 只在会议模式真正变化时才切换音频模式
            // 减少不必要的干预，保持音频流稳定
            let isConference = currentGroup?.isConferenceMode ?? false
            let wasConference = oldValue?.isConferenceMode ?? false

            if isConference != wasConference {
                pttService.setConferenceMode(isConference)
            }

            // 会议模式不支持 Opus，自动切换到 G711
            if isConference && txCodec == .opus {
                txCodec = .g711
            }

            // 切换群组时更新 Live Activity（如果已连接）
            if isConnected && currentGroup != nil {
                restartLiveActivity()
            }
        }
    }

    /// 当前是否处于会议模式
    public var isConferenceMode: Bool {
        currentGroup?.isConferenceMode ?? false
    }

    /// 群组详情缓存
    @Published public var currentGroupDetail: GroupDetail?

    /// 是否正在加载群组详情
    @Published public var isLoadingGroupDetail: Bool = false

    /// PTT 模式
    @Published public var pttMode: PTTMode = .holdToTalk

    /// 全双工模式（始终启用，保留属性以兼容设置页面）
    @Published public var isFullDuplex: Bool = true {
        didSet {
            // 全双工模式始终启用，此属性仅用于 UI 显示
            UserDefaults.standard.set(isFullDuplex, forKey: "ptt_full_duplex")
        }
    }

    /// 扬声器音量
    @Published public var speakerVolume: Float = 1.0 {
        didSet {
            pttService.playbackVolume = speakerVolume
            UserDefaults.standard.set(speakerVolume, forKey: "ptt_speaker_volume")
        }
    }

    /// 麦克风音量
    @Published public var micVolume: Float = 1.0 {
        didSet {
            pttService.recordingVolume = micVolume
            UserDefaults.standard.set(micVolume, forKey: "ptt_mic_volume")
        }
    }

    /// 人声增强开关 (RNNoise 降噪 + EQ)
    @Published public var noiseReductionEnabled: Bool = false {
        didSet {
            // 开启人声增强时，同时启用降噪和 EQ
            pttService.noiseReductionEnabled = noiseReductionEnabled
            pttService.voiceEQEnabled = noiseReductionEnabled
            UserDefaults.standard.set(noiseReductionEnabled, forKey: "ptt_noise_reduction")
        }
    }

    /// TX 编码格式 (G.711 默认, Opus 实验性)
    @Published public var txCodec: TxAudioCodec = .g711 {
        didSet {
            pttService.txCodec = txCodec
            UserDefaults.standard.set(txCodec.rawValue, forKey: "ptt_tx_codec")
        }
    }

    /// 语音识别开关（实时字幕）
    @Published public var speechRecognitionEnabled: Bool = false {
        didSet {
            pttService.speechRecognitionEnabled = speechRecognitionEnabled
            UserDefaults.standard.set(speechRecognitionEnabled, forKey: "ptt_speech_recognition")
        }
    }

    /// 当前正在进行的语音识别文字
    @Published public var currentTranscription: String = ""

    /// 当前识别会话的说话者
    @Published public var transcriptionSpeaker: String?

    /// 通话历史记录（所有群组）
    @Published public var callHistory: [CallRecord] = []

    /// 当前正在播放的录音ID
    @Published public var playingRecordId: String?

    /// 是否处于多选模式
    @Published public var isMultiSelectMode: Bool = false

    /// 多选选中的录音ID
    @Published public var selectedRecordIds: Set<String> = []

    /// 文本消息列表
    @Published public var textMessages: [TextMessage] = []

    /// 服务器节点列表
    @Published public var serverNodes: [ServerNode] = []

    /// 当前选中的服务器节点
    @Published public var currentServerNode: ServerNode?

    /// 最大文本消息条数
    private let maxTextMessageCount = 200

    /// 最大通话历史条数
    private let maxCallHistoryCount = 500

    /// 持久化存储路径
    private var callHistoryFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("call_history.json")
    }

    /// 文本消息存储路径
    private var textMessagesFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("text_messages.json")
    }

    /// 服务器节点存储路径
    private var serverNodesFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("server_nodes.json")
    }

    // MARK: - 依赖

    /// PTTService 懒加载（登录时才创建，避免启动卡顿）
    private lazy var pttService: PTTService = {
        let service = PTTService()
        setupServiceCallbacks(service)
        return service
    }()

    public let apiService = PttApiService()
    private var talkingTimer: Timer?
    private var statsTimer: Timer?
    private var playbackTask: Task<Void, Never>?

    // MARK: - 初始化

    public init() {
        // 注意：不在 init 中访问 pttService，延迟到登录时
        loadSavedSettings()

        // 异步加载本地数据，不阻塞 UI
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.loadLocalDataAsync()
        }

        // 激活 WatchConnectivity
        setupWatchConnectivity()
    }

    /// 设置 WatchConnectivity
    private func setupWatchConnectivity() {
        let watchSession = WatchSessionManager.shared
        watchSession.activate()

        // Watch PTT 开始回调
        watchSession.onPTTStart = { [weak self] in
            try await self?.pttDown()
        }

        // Watch PTT 停止回调
        watchSession.onPTTStop = { [weak self] in
            await self?.pttUp()
        }

        // TODO: Watch 音频数据回调（用于发送 Watch 录音到服务器）
        // watchSession.onWatchAudioData = { [weak self] data in
        //     self?.pttService.sendWatchAudioData(data)
        // }
    }

    /// 发送状态更新到 Watch
    private func sendStatusToWatch() {
        WatchSessionManager.shared.sendStatusToWatch(
            isConnected: isConnected,
            isTalking: isTalking,
            speaker: currentSpeaker,
            roomName: currentGroup?.name
        )
    }

    /// 异步加载本地数据
    @MainActor
    private func loadLocalDataAsync() {
        loadCallHistory()
        loadTextMessages()
        loadServerNodes()
        loadCustomServers()
    }

    deinit {
        // 确保定时器和任务被正确释放
        talkingTimer?.invalidate()
        statsTimer?.invalidate()
        playbackTask?.cancel()
    }

    private func setupServiceCallbacks(_ service: PTTService) {
        service.onStateChanged = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleStateChange(state)
            }
        }

        service.onSpeakerChanged = { [weak self] speaker in
            Task { @MainActor [weak self] in
                // 如果有信号进来（有人在说话），停止录音播放
                if speaker != nil {
                    self?.stopPlayback()
                }
                self?.currentSpeaker = speaker

                // 更新 Live Activity 显示说话者
                self?.updateLiveActivitySpeaker(speaker)

                // 同步状态到 Watch
                self?.sendStatusToWatch()
            }
        }

        service.onVolumeLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.volumeLevel = level
            }
        }

        service.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.errorMessage = error.localizedDescription
            }
        }

        service.onCallEnded = { [weak self] record in
            Task { @MainActor [weak self] in
                self?.addCallRecord(record)
            }
        }

        service.onTextReceived = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleTextMessage(message)
            }
        }

        // 心跳包位置回调 - 位置数据通过心跳包传输 (offset 32-39)
        service.onHeartbeatReceived = { [weak self] callSign, ssid, latitude, longitude in
            Task { @MainActor [weak self] in
                self?.onPeerLocationReceived?(callSign, ssid, latitude, longitude)
            }
        }

        print("[PTTViewModel] PTTService initialized (lazy)")
    }

    // MARK: - 位置相关

    /// 外部设置当前位置（用于心跳包发送）
    public func setCurrentLocation(latitude: Double, longitude: Double) {
        pttService.currentLocation = (latitude: latitude, longitude: longitude)
    }

    /// 心跳包收到其他用户位置的回调 - 位置数据通过心跳包传输
    public var onPeerLocationReceived: ((String, Int, Double?, Double?) -> Void)?

    /// 处理文本消息（区分普通消息和位置消息）
    private func handleTextMessage(_ message: TextMessage) {
        // 检查是否是位置消息 (格式: [loc]lat,lon)
        if message.content.hasPrefix("[loc]") {
            parseLocationMessage(message)
            return  // 不添加到聊天列表
        }

        // 兼容旧设备: 屏蔽旧格式 LOC: 位置消息，不显示在聊天列表
        if message.content.hasPrefix("LOC:") {
            return
        }

        // 普通消息
        addTextMessage(message)
    }

    /// 解析位置消息并更新 peers
    private func parseLocationMessage(_ message: TextMessage) {
        let content = message.content
        guard content.hasPrefix("[loc]") else { return }

        let coordString = String(content.dropFirst(5))  // 移除 "[loc]"
        let parts = coordString.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            print("[PTTViewModel] Invalid [loc] message: \(content)")
            return
        }

        // 更新 peers 位置
        let callsign = "\(message.sender)-\(message.ssid)"
        print("[PTTViewModel] [loc] from \(callsign): lat=\(lat), lon=\(lon)")
        onPeerLocationReceived?(message.sender, message.ssid, lat, lon)
    }

    /// 添加文本消息
    private func addTextMessage(_ message: TextMessage) {
        // 使用当前群组ID，确保消息绑定到正确的房间
        let actualGroupId = currentGroup?.id ?? 0
        let updatedMessage = TextMessage(
            sender: message.sender,
            ssid: message.ssid,
            content: message.content,
            timestamp: message.timestamp,
            isSelf: message.isSelf,
            groupId: actualGroupId
        )

        textMessages.insert(updatedMessage, at: 0)
        // 限制消息数量
        while textMessages.count > maxTextMessageCount {
            textMessages.removeLast()
        }
        // 保存到磁盘
        saveTextMessages()
        print("[PTTViewModel] Added text message for group \(actualGroupId) from \(message.displayName): \(message.content)")
    }

    /// 发送文本消息
    public func sendText(_ text: String) {
        guard isConnected else {
            errorMessage = "未连接到服务器"
            return
        }

        guard !text.isEmpty else { return }

        // [loc] 位置消息使用紧凑格式发送，不添加到聊天列表
        if text.hasPrefix("[loc]") {
            pttService.sendCompactText(text)
            return
        }

        pttService.sendText(text)

        // 添加自己发送的消息到列表
        let message = TextMessage(
            sender: callSign,
            ssid: ssid,
            content: text,
            timestamp: Date(),
            isSelf: true,
            groupId: currentGroup?.id ?? 0
        )
        addTextMessage(message)
    }

    /// 删除单条文本消息
    public func deleteTextMessage(_ message: TextMessage) {
        textMessages.removeAll { $0.id == message.id }
        saveTextMessages()
    }

    /// 清空文本消息
    public func clearTextMessages() {
        textMessages.removeAll()
        saveTextMessages()
    }

    /// 获取当前群组的文本消息
    public var currentGroupTextMessages: [TextMessage] {
        guard let groupId = currentGroup?.id else {
            return textMessages
        }
        return textMessages.filter { $0.groupId == groupId }
    }

    /// 添加通话记录
    private func addCallRecord(_ record: CallRecord) {
        // 过滤小于0.5秒的语音包（太短无意义）
        guard record.duration >= 0.5 else {
            print("[PTTViewModel] Filtered short record: \(String(format: "%.2f", record.duration))s < 0.5s")
            return
        }

        // 使用当前群组ID，确保录音绑定到正确的房间
        let actualGroupId = currentGroup?.id ?? 0
        let updatedRecord = CallRecord(
            callSign: record.callSign,
            ssid: record.ssid,
            startTime: record.startTime,
            endTime: record.endTime,
            isSelf: record.isSelf,
            audioData: record.audioData,
            groupId: actualGroupId,
            codec: record.codec,
            transcription: record.transcription
        )

        callHistory.insert(updatedRecord, at: 0)
        // 限制历史记录数量，删除最早的
        while callHistory.count > maxCallHistoryCount {
            callHistory.removeLast()
        }
        // 清除当前讲话者
        currentSpeaker = nil
        // 保存到磁盘
        saveCallHistory()
        print("[PTTViewModel] Added call record for group \(actualGroupId)")
    }

    private func handleStateChange(_ state: PTTServiceState) {
        switch state {
        case .disconnected:
            isConnected = false
            isConnecting = false
            isTalking = false
            currentSpeaker = nil
            stopTalkingTimer()
            stopStatsTimer()
            // 清除缓存的群组详情，避免显示旧的在线人数
            currentGroupDetail = nil

        case .connecting:
            isConnecting = true

        case .connected:
            isConnected = true
            isConnecting = false
            // 全双工模式：如果正在发射，不要中断
            if !pttService.isTalking {
                isTalking = false
                stopTalkingTimer()
            }
            currentSpeaker = nil
            startStatsTimer()

        case .talking:
            isTalking = true
            startTalkingTimer()
            // 更新 Live Activity 为发射状态
            updateLiveActivityTransmitting()

        case .receiving(let speaker):
            // 全双工模式：收到语音不中断发射
            // 但如果用户已停止发射，需要同步 UI 状态
            if !pttService.isTalking && isTalking {
                isTalking = false
                stopTalkingTimer()
            }
            currentSpeaker = speaker
        }

        // 同步状态到 Watch
        sendStatusToWatch()
    }

    /// 处理语音识别结果更新
    private func handleTranscriptionUpdate(speaker: String, sessionId: UUID, text: String, isFinal: Bool) {
        // 更新当前识别文字
        transcriptionSpeaker = speaker
        currentTranscription = text

        // 如果是最终结果，尝试更新对应的通话记录
        if isFinal {
            // 解析 speaker 格式: "CALLSIGN-SSID"
            let parts = speaker.components(separatedBy: "-")
            let speakerCallSign = parts.first ?? ""
            let speakerSsid = parts.count > 1 ? (Int(parts.last ?? "") ?? 0) : 0

            // 查找最近的匹配通话记录并更新 transcription（匹配 callSign + ssid）
            if let index = callHistory.firstIndex(where: {
                $0.callSign == speakerCallSign && $0.ssid == speakerSsid && !$0.isSelf
            }) {
                // 创建更新后的记录
                var updatedRecord = callHistory[index]
                updatedRecord.transcription = text
                callHistory[index] = updatedRecord
                saveCallHistory()
                print("[PTTViewModel] Updated transcription for \(speaker): \(text)")
            }

            // 清空当前识别状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.transcriptionSpeaker == speaker {
                    self?.currentTranscription = ""
                    self?.transcriptionSpeaker = nil
                }
            }
        }
    }

    // MARK: - 用户操作

    /// 登录 PTT 服务器
    public func login() async {
        // 验证服务器地址
        let trimmedServerUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServerUrl.isEmpty else {
            loginError = "请输入服务器地址"
            return
        }
        guard trimmedServerUrl.hasPrefix("http://") || trimmedServerUrl.hasPrefix("https://") else {
            loginError = "请输入有效的服务器地址 (http:// 或 https://)"
            return
        }

        guard !username.isEmpty, !password.isEmpty else {
            loginError = "请输入用户名和密码"
            return
        }

        isLoggingIn = true
        loginError = nil

        do {
            // 0. 设置服务器地址
            apiService.setServerUrl(trimmedServerUrl)

            // 1. 调用 API 登录
            print("[PTTViewModel] Logging in to \(trimmedServerUrl)...")
            _ = try await apiService.login(username: username, password: password)

            // 2. 获取用户信息
            print("[PTTViewModel] Getting user info...")
            let userInfo = try await apiService.getUserInfo()

            // 3. 更新状态
            currentUser = userInfo
            callSign = userInfo.callsign
            ssid = userInfo.ssid > 0 ? userInfo.ssid : kAppDefaultSsid
            isAdmin = userInfo.isAdmin
            userId = userInfo.id
            dmrid = userInfo.dmrid ?? ""
            mdcid = userInfo.mdcid ?? ""
            serverHost = apiService.extractUdpHost()

            // 4. 保存设置
            saveSettings()

            isLoggedIn = true
            isLoggingIn = false

            print("[PTTViewModel] Login success: \(callSign)-\(ssid)")

            // 5. 加载对讲组
            await loadGroups()

            // 6. 从服务器获取当前设备所在的群组
            await fetchCurrentDeviceGroup()

            print("[PTTViewModel] After fetchCurrentDeviceGroup, currentGroup = \(currentGroup?.name ?? "nil")")

            // 7. 自动连接 UDP 服务器
            await connect()

        } catch {
            // 检查是否为 Token 过期（虽然登录时不太可能，但保持一致性）
            if checkAndHandleTokenExpired(error) {
                isLoggingIn = false
                return
            }
            loginError = error.localizedDescription
            isLoggingIn = false
            print("[PTTViewModel] Login failed: \(error)")
        }
    }

    // MARK: - 平台服务器选择

    /// 获取平台服务器列表
    public func fetchPlatformServers() async {
        isLoadingPlatformServers = true
        platformServerError = nil
        do {
            platformServers = try await PttApiService.fetchPlatformList()
            print("[PTTViewModel] Loaded \(platformServers.count) platform servers")

            // 如果有保存的服务器，尝试匹配
            let savedUrl = UserDefaults.standard.string(forKey: "ptt_server_url") ?? ""
            if !savedUrl.isEmpty {
                selectedPlatformServer = platformServers.first { $0.url == savedUrl }
            }
        } catch {
            print("[PTTViewModel] Failed to load platform servers: \(error)")
            platformServerError = "获取服务器列表失败"
        }
        isLoadingPlatformServers = false
    }

    /// 选择平台服务器
    public func selectPlatformServer(_ server: PlatformServer) {
        selectedPlatformServer = server
        serverUrl = server.url  // https://host (不带端口)

        // UDP 服务器地址
        serverHost = server.host
        serverPort = server.udpPort  // UDP 端口 (如 60050)

        print("[PTTViewModel] Selected server: \(server.name) -> API: \(server.url), UDP: \(server.host):\(server.udpPort)")
    }

    // MARK: - 自定义服务器管理

    /// 自定义服务器存储路径
    private var customServersFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("custom_servers.json")
    }

    /// 加载自定义服务器
    public func loadCustomServers() {
        guard FileManager.default.fileExists(atPath: customServersFileURL.path) else {
            print("[PTTViewModel] No custom servers found")
            return
        }

        do {
            let data = try Data(contentsOf: customServersFileURL)
            customServers = try JSONDecoder().decode([PlatformServer].self, from: data)
            print("[PTTViewModel] Loaded \(customServers.count) custom servers")
        } catch {
            print("[PTTViewModel] Failed to load custom servers: \(error)")
        }
    }

    /// 保存自定义服务器
    private func saveCustomServers() {
        do {
            let data = try JSONEncoder().encode(customServers)
            try data.write(to: customServersFileURL, options: .atomic)
            print("[PTTViewModel] Saved \(customServers.count) custom servers")
        } catch {
            print("[PTTViewModel] Failed to save custom servers: \(error)")
        }
    }

    /// 添加自定义服务器
    /// - Note: UI 层负责输入验证，此处只做后备检查
    public func addCustomServer(name: String, host: String, port: String) -> Bool {
        // 验证输入（后备检查，UI 已做验证）
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedHost.isEmpty else { return false }
        guard let portNum = UInt16(trimmedPort), portNum > 0 else { return false }

        // 检查是否已存在
        let serverId = "\(trimmedHost):\(trimmedPort)"
        if customServers.contains(where: { $0.id == serverId }) {
            return false
        }

        // 创建并添加
        let serverName = trimmedName.isEmpty ? trimmedHost : trimmedName
        let server = PlatformServer(name: serverName, host: trimmedHost, port: trimmedPort)
        customServers.append(server)
        saveCustomServers()

        print("[PTTViewModel] Added custom server: \(server.name) (\(server.host):\(server.port))")
        return true
    }

    /// 删除自定义服务器
    public func deleteCustomServer(_ server: PlatformServer) {
        customServers.removeAll { $0.id == server.id }
        saveCustomServers()

        // 如果删除的是当前选中的服务器，清除选择
        if selectedPlatformServer?.id == server.id {
            selectedPlatformServer = nil
        }

        print("[PTTViewModel] Deleted custom server: \(server.name)")
    }

    /// 加载对讲组
    public func loadGroups() async {
        do {
            groups = try await apiService.getGroups()
            print("[PTTViewModel] Loaded \(groups.count) groups")
        } catch {
            // 检查是否为 Token 过期
            if checkAndHandleTokenExpired(error) {
                return
            }
            print("[PTTViewModel] Load groups failed: \(error)")
        }
    }

    /// 创建群组
    public func createGroup(name: String, type: Int, note: String?) async throws -> Int {
        let groupId = try await apiService.createGroup(name: name, type: type, note: note)
        await loadGroups()  // 刷新群组列表
        print("[PTTViewModel] Created group: id=\(groupId), name=\(name)")
        return groupId
    }

    /// 更新群组
    public func updateGroup(id: Int, name: String, type: Int, note: String?) async throws {
        try await apiService.updateGroup(id: id, name: name, type: type, note: note)
        await loadGroups()  // 刷新群组列表
        print("[PTTViewModel] Updated group: id=\(id)")
    }

    /// 删除群组
    public func deleteGroup(id: Int) async throws {
        try await apiService.deleteGroup(id: id)
        await loadGroups()  // 刷新群组列表
        print("[PTTViewModel] Deleted group: id=\(id)")
    }

    /// 获取群组详情（设备列表）
    public func getGroupDetail(groupId: Int) async throws -> GroupDetail {
        isLoadingGroupDetail = true
        defer { isLoadingGroupDetail = false }

        let detail = try await apiService.getGroupDetail(groupId: groupId)
        currentGroupDetail = detail
        print("[PTTViewModel] Loaded group detail: \(detail.devices.count) devices, \(detail.onlineCount) online")
        return detail
    }

    /// 获取我的设备列表
    public func getMyDevices() async throws -> [PttDevice] {
        let devices = try await apiService.getMyDevices()
        print("[PTTViewModel] Loaded my devices: \(devices.count)")
        return devices
    }

    /// 将设备移动到指定群组
    public func moveDeviceToGroup(device: PttDevice, targetGroupId: Int) async throws {
        _ = try await apiService.changeDeviceGroup(
            callsign: device.callsign,
            ssid: device.ssid,
            newGroupId: targetGroupId
        )
        print("[PTTViewModel] Moved device \(device.displayName) to group \(targetGroupId)")
    }

    /// 加入群组
    public func joinGroup(_ group: PttGroup) async throws {
        guard !callSign.isEmpty else {
            throw PTTViewModelError.notLoggedIn
        }

        print("[PTTViewModel] Joining group: \(group.name) (id=\(group.id))")
        let success = try await apiService.joinGroup(groupId: group.id, callsign: callSign, ssid: ssid)

        if success {
            currentGroup = group
            // 保存当前群组
            UserDefaults.standard.set(group.id, forKey: "ptt_current_group_id")
            UserDefaults.standard.set(group.name, forKey: "ptt_current_group_name")
            print("[PTTViewModel] Joined group: \(group.name)")
        } else {
            throw PTTViewModelError.joinGroupFailed
        }
    }

    /// 刷新当前群组详情（同时检查设备是否被换组）
    public func refreshGroupDetail() async {
        // 先检查当前设备的群组是否变化（别人可能帮我换组）
        await syncCurrentDeviceGroup()

        // 再刷新群组详情
        guard let group = currentGroup else { return }
        _ = try? await getGroupDetail(groupId: group.id)
    }

    /// 同步当前设备所在的群组（检查是否被别人换组）
    public func syncCurrentDeviceGroup() async {
        await fetchCurrentDeviceGroup()
    }

    /// 选择默认群组或第一个群组
    private func selectDefaultGroup() {
        guard !groups.isEmpty else {
            print("[PTTViewModel] No groups available to select")
            return
        }

        // 优先选择默认群组
        if let defaultGroup = groups.first(where: { $0.isDefault }) {
            currentGroup = defaultGroup
            UserDefaults.standard.set(defaultGroup.id, forKey: "ptt_current_group_id")
            UserDefaults.standard.set(defaultGroup.name, forKey: "ptt_current_group_name")
            print("[PTTViewModel] Selected default group: \(defaultGroup.name) (id=\(defaultGroup.id))")
        } else {
            // 没有默认群组，选择第一个
            let firstGroup = groups[0]
            currentGroup = firstGroup
            UserDefaults.standard.set(firstGroup.id, forKey: "ptt_current_group_id")
            UserDefaults.standard.set(firstGroup.name, forKey: "ptt_current_group_name")
            print("[PTTViewModel] Selected first group: \(firstGroup.name) (id=\(firstGroup.id))")
        }
    }

    /// 从服务器获取当前设备所在的群组
    private func fetchCurrentDeviceGroup() async {
        do {
            print("[PTTViewModel] Fetching my devices to get current group...")
            let myDevices = try await apiService.getMyDevices()
            print("[PTTViewModel] Got \(myDevices.count) devices")

            // 查找当前设备（通过 callsign 和 ssid 匹配）
            if let currentDevice = myDevices.first(where: { $0.callsign == callSign && $0.ssid == ssid }) {
                let deviceGroupId = currentDevice.groupId
                print("[PTTViewModel] Current device groupId = \(deviceGroupId)")

                if deviceGroupId > 0, let group = groups.first(where: { $0.id == deviceGroupId }) {
                    currentGroup = group
                    UserDefaults.standard.set(group.id, forKey: "ptt_current_group_id")
                    UserDefaults.standard.set(group.name, forKey: "ptt_current_group_name")
                    print("[PTTViewModel] Set current group from device: \(group.name) (id=\(group.id))")
                    return
                }
            } else {
                print("[PTTViewModel] Current device not found in myDevices, callSign=\(callSign), ssid=\(ssid)")
                // 打印所有设备帮助调试
                for device in myDevices {
                    print("[PTTViewModel]   - Device: \(device.callsign)-\(device.ssid), groupId=\(device.groupId)")
                }
            }
        } catch {
            print("[PTTViewModel] Failed to fetch my devices: \(error)")
        }

        // 如果从服务器获取失败，选择默认群组
        print("[PTTViewModel] Falling back to default group selection")
        selectDefaultGroup()
    }

    // MARK: - 设备管理

    /// 设置设备禁收状态
    public func setDeviceMuteReceive(callsign: String, ssid: Int, mute: Bool) async throws -> Bool {
        return try await apiService.setDeviceMuteReceive(callsign: callsign, ssid: ssid, mute: mute)
    }

    /// 设置设备禁发状态
    public func setDeviceMuteTransmit(callsign: String, ssid: Int, mute: Bool) async throws -> Bool {
        return try await apiService.setDeviceMuteTransmit(callsign: callsign, ssid: ssid, mute: mute)
    }

    /// 更改设备所属群组
    public func changeDeviceGroup(callsign: String, ssid: Int, newGroupId: Int) async throws -> Bool {
        return try await apiService.changeDeviceGroup(callsign: callsign, ssid: ssid, newGroupId: newGroupId)
    }

    /// 登出
    public func logout() async {
        // 1. 先停止后台保活
        stopBackgroundKeepAlive()

        // 2. 停止所有定时器
        stopTalkingTimer()
        stopStatsTimer()

        // 3. 断开连接
        if isConnected {
            await disconnect()
        }

        // 4. 清除 API token
        apiService.logout()

        // 5. 清理所有状态（在设置 isLoggedIn = false 之前）
        callSign = ""
        // 如果没有勾选"记住密码"，清除用户名和密码
        if !rememberMe {
            username = ""
            password = ""
        }
        ssid = 0
        groups = []
        currentGroup = nil
        currentGroupDetail = nil
        errorMessage = nil
        isTalking = false
        isConnecting = false
        currentSpeaker = nil
        volumeLevel = 0
        talkingDuration = 0

        // 清除保存的设置（保留 serverUrl、username、password 如果记住密码）
        UserDefaults.standard.removeObject(forKey: "ptt_callsign")
        UserDefaults.standard.removeObject(forKey: "ptt_current_group_id")
        UserDefaults.standard.removeObject(forKey: "ptt_current_group_name")

        // 6. 最后设置 isLoggedIn = false，触发视图切换到登录页面
        // 确保在主线程执行 UI 状态更新
        await MainActor.run {
            isLoggedIn = false
        }
    }

    /// 连接到 UDP 服务器
    public func connect() async {
        guard isLoggedIn else {
            errorMessage = "请先登录"
            return
        }

        guard !callSign.isEmpty else {
            errorMessage = "请先设置呼号"
            return
        }

        guard !isConnected else { return }

        isConnecting = true
        errorMessage = nil

        let config = UserConfig(
            host: serverHost,
            port: serverPort,
            callSign: callSign,
            ssid: ssid,
            groupId: currentGroup?.id ?? 0,
            dmrID: dmrid.isEmpty ? nil : dmrid
        )

        // 尝试连接，最多重试2次
        var lastError: Error?
        for attempt in 1...3 {
            do {
                print("[PTTViewModel] Connecting to \(serverHost):\(serverPort) (attempt \(attempt))...")
                try await pttService.connect(config: config)

                // 连接成功后，同步所有设置到 PTTService
                syncSettingsToService()

                // 启动 Live Activity（灵动岛/锁屏）
                startLiveActivity()

                print("[PTTViewModel] Connected!")
                isConnecting = false
                return
            } catch {
                lastError = error
                print("[PTTViewModel] Connect attempt \(attempt) failed: \(error)")

                if attempt < 3 {
                    // iOS 首次连接可能因网络权限失败，等待后重试
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }

        // 所有重试都失败
        errorMessage = "连接失败，请检查网络"
        if let error = lastError {
            print("[PTTViewModel] All connect attempts failed: \(error)")
        }
        isConnecting = false
    }

    /// 断开连接
    public func disconnect() async {
        // 结束 Live Activity
        await endLiveActivity()

        await pttService.disconnect()
    }

    // MARK: - 后台保活

    /// App 进入后台时调用
    public func onEnterBackground() {
        pttService.onEnterBackground()
    }

    /// App 进入前台时调用
    public func onEnterForeground() {
        pttService.onEnterForeground()
    }

    /// 停止后台保活（登出/Token 过期时调用）
    public func stopBackgroundKeepAlive() {
        pttService.stopBackgroundKeepAlive()
    }

    /// 手动触发重连（供 UI 调用）
    public func manualReconnect() {
        pttService.manualReconnect()
    }

    /// PTT 按下（长按模式）
    public func pttDown() async {
        // 检查连接状态
        guard isConnected else {
            errorMessage = "未连接到服务器"
            return
        }

        // 检查是否已经在发射
        guard !isTalking else { return }

        // 全双工模式：始终允许发射（可抢麦）

        // 检查麦克风权限
        let micPermission = await checkMicrophonePermission()
        guard micPermission else {
            errorMessage = "需要麦克风权限，请在设置中开启"
            return
        }

        do {
            try await pttService.startTalking()
            errorMessage = nil // 清除之前的错误
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 检查麦克风权限
    private func checkMicrophonePermission() async -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission
        switch status {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// PTT 释放（长按模式）
    public func pttUp() async {
        // 直接读取 Service 状态（单一真实来源）
        guard pttService.isTalking else { return }
        await pttService.stopTalking()
        // isTalking 由 handleStateChange 回调更新
        stopTalkingTimer()
    }

    /// PTT 点击（切换模式）
    public func pttTap() async {
        // 直接读取 Service 状态（单一真实来源）
        if pttService.isTalking {
            await pttUp()
        } else {
            await pttDown()
        }
    }

    /// 清除错误
    public func clearError() {
        errorMessage = nil
    }

    /// 清除登录错误
    public func clearLoginError() {
        loginError = nil
    }

    // MARK: - 音频控制

    /// 设置静音状态
    public func setMuted(_ muted: Bool) {
        pttService.setMuted(muted)
    }

    /// 设置扬声器音量 (0~1)
    public func setSpeakerVolume(_ volume: Float) {
        pttService.setSpeakerVolume(volume)
    }

    /// 设置麦克风音量 (0~1)
    public func setMicVolume(_ volume: Float) {
        pttService.setMicVolume(volume)
    }

    /// 设置扬声器/听筒模式
    public func setSpeakerMode(_ speakerOn: Bool) {
        pttService.setSpeakerMode(speakerOn)
    }

    /// 设置 TX 编码格式 (G.711 / Opus)
    public func setTxCodec(_ codec: TxAudioCodec) {
        txCodec = codec
    }

    /// 处理 Token 过期 (401/403)
    public func handleTokenExpired() {
        // 立即停止重连，防止无限重试
        pttService.cancelReconnect()
        // 立即停止后台保活
        stopBackgroundKeepAlive()
        showTokenExpiredAlert = true
    }

    /// Token 过期弹窗确认后调用
    public func onTokenExpiredAlertDismissed() async {
        showTokenExpiredAlert = false
        await logout()
    }

    /// 检查错误是否为 Token 过期
    private func checkAndHandleTokenExpired(_ error: Error) -> Bool {
        if let apiError = error as? PttApiError, apiError.isTokenExpired {
            handleTokenExpired()
            return true
        }
        return false
    }

    // MARK: - Live Activity (灵动岛/锁屏)

    /// 启动 Live Activity
    private func startLiveActivity() {
        guard #available(iOS 16.2, *) else { return }

        let channelName = currentGroup?.name ?? "PTT"
        let channelId = currentGroup?.id ?? 0
        let onlineCount = currentGroupDetail?.onlineCount ?? 0

        PTTLiveActivityService.shared.start(
            channelName: channelName,
            channelId: channelId,
            myCallSign: "\(callSign)-\(ssid)",
            onlineCount: onlineCount
        )
    }

    /// 重启 Live Activity（切换房间时调用）
    private func restartLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard PTTLiveActivityService.shared.isActive else { return }

        // 直接调用 start，它会自动结束旧的并启动新的
        startLiveActivity()
    }

    /// 更新 Live Activity 说话者
    private func updateLiveActivitySpeaker(_ speaker: String?) {
        guard #available(iOS 16.2, *) else { return }

        let onlineCount = currentGroupDetail?.onlineCount ?? 0
        PTTLiveActivityService.shared.updateSpeaker(speaker, onlineCount: onlineCount)
    }

    /// 更新 Live Activity 为发射状态
    private func updateLiveActivityTransmitting() {
        guard #available(iOS 16.2, *) else { return }

        let onlineCount = currentGroupDetail?.onlineCount ?? 0
        PTTLiveActivityService.shared.updateTransmitting(duration: talkingDuration, onlineCount: onlineCount)
    }

    /// 结束 Live Activity
    private func endLiveActivity() async {
        guard #available(iOS 16.2, *) else { return }

        await PTTLiveActivityService.shared.end()
    }

    // MARK: - 计时器

    private func startTalkingTimer() {
        talkingDuration = 0
        talkingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.talkingDuration += 1
                // 更新 Live Activity 发射时长
                self?.updateLiveActivityTransmitting()
            }
        }
    }

    private func stopTalkingTimer() {
        talkingTimer?.invalidate()
        talkingTimer = nil
        talkingDuration = 0
        // 更新 Live Activity 为守听状态
        if #available(iOS 16.2, *) {
            PTTLiveActivityService.shared.updateListening(onlineCount: currentGroupDetail?.onlineCount ?? 0)
        }
    }

    private func startStatsTimer() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStats()
            }
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func updateStats() {
        let stats = pttService.stats
        packetsReceived = stats.packetsReceived
        packetsLost = stats.packetsLost
        lossRate = stats.lossRate
        bufferLevelMs = stats.bufferLevelMs
    }

    // MARK: - 持久化

    private func loadSavedSettings() {
        let defaults = UserDefaults.standard

        // 服务器地址
        serverUrl = defaults.string(forKey: "ptt_server_url") ?? "https://"
        serverHost = defaults.string(forKey: "ptt_host") ?? "ptt.pgarlic.com"
        serverPort = UInt16(defaults.integer(forKey: "ptt_port"))
        if serverPort == 0 { serverPort = 60050 }

        // 记住密码
        rememberMe = defaults.bool(forKey: "ptt_remember_me")
        if rememberMe {
            username = defaults.string(forKey: "ptt_username") ?? ""
            // 从 Keychain 读取密码（安全存储）
            password = KeychainHelper.shared.get(forKey: "ptt_password") ?? ""

            // 迁移旧版本明文密码到 Keychain
            if password.isEmpty, let oldPassword = defaults.string(forKey: "ptt_password"), !oldPassword.isEmpty {
                password = oldPassword
                KeychainHelper.shared.save(oldPassword, forKey: "ptt_password")
                defaults.removeObject(forKey: "ptt_password")  // 删除明文密码
                print("[PTTViewModel] Migrated password from UserDefaults to Keychain")
            }
        }

        ssid = defaults.integer(forKey: "ptt_ssid")
        if ssid == 0 { ssid = kAppDefaultSsid }

        // 音量设置
        let savedSpeakerVolume = defaults.float(forKey: "ptt_speaker_volume")
        if savedSpeakerVolume > 0 {
            speakerVolume = savedSpeakerVolume
        }
        let savedMicVolume = defaults.float(forKey: "ptt_mic_volume")
        if savedMicVolume > 0 {
            micVolume = savedMicVolume
        }

        // 每次启动默认设置（不从 UserDefaults 恢复）
        pttMode = .toggleToTalk       // 点击切换模式
        isFullDuplex = true           // 全双工模式
        txCodec = .g711               // G711 编码
        noiseReductionEnabled = true  // 降噪开启

        // 语音识别设置（从 UserDefaults 恢复）
        speechRecognitionEnabled = defaults.bool(forKey: "ptt_speech_recognition")

        // 注意：不自动恢复登录状态，每次启动都需要重新登录
    }

    /// 同步所有设置到 PTTService（连接后调用）
    private func syncSettingsToService() {
        // 同步音频设置
        pttService.playbackVolume = speakerVolume
        pttService.recordingVolume = micVolume

        // 同步编码设置
        pttService.txCodec = txCodec

        // 同步降噪/EQ设置
        pttService.noiseReductionEnabled = noiseReductionEnabled
        pttService.voiceEQEnabled = noiseReductionEnabled

        // 同步语音识别设置
        pttService.speechRecognitionEnabled = speechRecognitionEnabled
        pttService.onTranscriptionUpdate = { [weak self] speaker, sessionId, text, isFinal in
            DispatchQueue.main.async {
                self?.handleTranscriptionUpdate(speaker: speaker, sessionId: sessionId, text: text, isFinal: isFinal)
            }
        }

        // 全双工模式始终启用，无需同步

        print("[PTTViewModel] Settings synced: txCodec=\(txCodec.rawValue), noiseReduction=\(noiseReductionEnabled), speechRecognition=\(speechRecognitionEnabled)")
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(serverUrl, forKey: "ptt_server_url")
        defaults.set(serverHost, forKey: "ptt_host")
        defaults.set(Int(serverPort), forKey: "ptt_port")
        defaults.set(rememberMe, forKey: "ptt_remember_me")

        if rememberMe {
            defaults.set(username, forKey: "ptt_username")
            // 密码存储到 Keychain（安全存储）
            KeychainHelper.shared.save(password, forKey: "ptt_password")
        } else {
            defaults.removeObject(forKey: "ptt_username")
            // 从 Keychain 删除密码
            KeychainHelper.shared.delete(forKey: "ptt_password")
        }

        defaults.set(callSign, forKey: "ptt_callsign")
        defaults.set(ssid, forKey: "ptt_ssid")
        defaults.set(pttMode.rawValue, forKey: "ptt_mode")

        // 音量设置
        defaults.set(speakerVolume, forKey: "ptt_speaker_volume")
        defaults.set(micVolume, forKey: "ptt_mic_volume")

        // 全双工模式
        defaults.set(isFullDuplex, forKey: "ptt_full_duplex")

        // 语音降噪
        defaults.set(noiseReductionEnabled, forKey: "ptt_noise_reduction")

        // 语音识别
        defaults.set(speechRecognitionEnabled, forKey: "ptt_speech_recognition")

        // TX 编码格式
        defaults.set(txCodec.rawValue, forKey: "ptt_tx_codec")
    }

    // MARK: - 辅助方法

    /// 格式化时长
    public func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - 通话记录管理

    /// 获取当前群组的通话记录
    public var currentGroupCallHistory: [CallRecord] {
        guard let groupId = currentGroup?.id else {
            return callHistory
        }
        return callHistory.filter { $0.groupId == groupId }
    }

    /// 播放录音
    public func playRecord(_ record: CallRecord) {
        print("[PTTViewModel] playRecord: id=\(record.id), audioData=\(record.audioData.count) bytes, codec=\(record.codec)")

        // 如果正在播放同一个录音，停止
        if playingRecordId == record.id {
            stopPlayback()
            return
        }

        // 停止之前的播放
        stopPlayback()

        // 检查音频数据
        guard !record.audioData.isEmpty else {
            print("[PTTViewModel] ERROR: Audio data is empty!")
            return
        }

        // 使用 PTTService 的 AudioUnitEngine 播放（传入 codec）
        pttService.playRecordAudio(record.audioData, codec: record.codec)
        playingRecordId = record.id

        // 计算播放时长，设置定时器自动清除播放状态
        let durationSec: Double
        switch record.codec {
        case .g711:
            // G711: 8000 samples/s, 1 byte/sample
            let durationMs = Double(record.audioData.count) / 8.0
            durationSec = durationMs / 1000.0
        case .opus:
            // Opus: 使用记录的时长（已知开始和结束时间）
            durationSec = record.duration
        }

        print("[PTTViewModel] Playing record, duration: \(durationSec)s, codec: \(record.codec)")

        // 播放完成后清除状态（使用 weak self 避免循环引用）
        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(durationSec * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self?.playingRecordId == record.id {
                self?.playingRecordId = nil
                print("[PTTViewModel] Playback finished")
            }
        }
    }

    /// 停止播放
    public func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        pttService.stopRecordPlayback()
        playingRecordId = nil
    }

    /// 删除单条录音
    public func deleteRecord(_ record: CallRecord) {
        callHistory.removeAll { $0.id == record.id }
        saveCallHistory()
    }

    /// 删除选中的消息（语音 + 文本）
    public func deleteSelectedRecords() {
        // 删除选中的语音记录
        callHistory.removeAll { selectedRecordIds.contains($0.id) }
        // 删除选中的文本消息
        textMessages.removeAll { selectedRecordIds.contains($0.id) }

        selectedRecordIds.removeAll()
        isMultiSelectMode = false

        saveCallHistory()
        saveTextMessages()
    }

    /// 清空当前群组的通话记录和文字消息
    public func clearCurrentGroupHistory() {
        guard let groupId = currentGroup?.id else {
            callHistory.removeAll()
            textMessages.removeAll()
            saveCallHistory()
            saveTextMessages()
            return
        }
        callHistory.removeAll { $0.groupId == groupId }
        textMessages.removeAll { $0.groupId == groupId }
        saveCallHistory()
        saveTextMessages()
    }

    /// 清空所有通话记录和文字消息
    public func clearAllHistory() {
        callHistory.removeAll()
        textMessages.removeAll()
        saveCallHistory()
        saveTextMessages()
    }

    /// 保存通话记录到磁盘（原子写入）
    private func saveCallHistory() {
        do {
            let data = try JSONEncoder().encode(callHistory)
            try data.write(to: callHistoryFileURL, options: .atomic)
            print("[PTTViewModel] Saved \(callHistory.count) call records")
        } catch {
            print("[PTTViewModel] Failed to save call history: \(error)")
        }
    }

    /// 从磁盘加载通话记录
    private func loadCallHistory() {
        guard FileManager.default.fileExists(atPath: callHistoryFileURL.path) else {
            print("[PTTViewModel] No saved call history found")
            return
        }

        do {
            let data = try Data(contentsOf: callHistoryFileURL)
            var loaded = try JSONDecoder().decode([CallRecord].self, from: data)

            // 过滤小于0.5秒的语音包（清理历史数据）
            let beforeCount = loaded.count
            loaded = loaded.filter { $0.duration >= 0.5 }
            let filtered = beforeCount - loaded.count

            callHistory = loaded
            print("[PTTViewModel] Loaded \(callHistory.count) call records (filtered \(filtered) short records)")

            // 如果有过滤，保存清理后的数据
            if filtered > 0 {
                saveCallHistory()
            }
        } catch {
            print("[PTTViewModel] Failed to load call history: \(error)")
        }
    }

    /// 保存文本消息到磁盘（原子写入）
    private func saveTextMessages() {
        do {
            let data = try JSONEncoder().encode(textMessages)
            try data.write(to: textMessagesFileURL, options: .atomic)
            print("[PTTViewModel] Saved \(textMessages.count) text messages")
        } catch {
            print("[PTTViewModel] Failed to save text messages: \(error)")
        }
    }

    /// 从磁盘加载文本消息
    private func loadTextMessages() {
        guard FileManager.default.fileExists(atPath: textMessagesFileURL.path) else {
            print("[PTTViewModel] No saved text messages found")
            return
        }

        do {
            let data = try Data(contentsOf: textMessagesFileURL)
            textMessages = try JSONDecoder().decode([TextMessage].self, from: data)
            print("[PTTViewModel] Loaded \(textMessages.count) text messages")
        } catch {
            print("[PTTViewModel] Failed to load text messages: \(error)")
        }
    }

    /// 获取缓存大小
    public func getCacheSize() -> String {
        var totalSize: Int64 = 0

        // 计算所有缓存文件大小
        let cacheFiles = [
            callHistoryFileURL,      // 通话记录
            textMessagesFileURL,     // 文本消息
            serverNodesFileURL,      // 服务器节点
            customServersFileURL     // 自定义服务器
        ]

        for fileURL in cacheFiles {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        // 格式化大小
        if totalSize < 1024 {
            return "\(totalSize) B"
        } else if totalSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalSize) / 1024)
        } else {
            return String(format: "%.1f MB", Double(totalSize) / 1024 / 1024)
        }
    }

    // MARK: - 服务器节点管理

    /// 加载服务器节点
    private func loadServerNodes() {
        if FileManager.default.fileExists(atPath: serverNodesFileURL.path) {
            do {
                let data = try Data(contentsOf: serverNodesFileURL)
                serverNodes = try JSONDecoder().decode([ServerNode].self, from: data)
                print("[PTTViewModel] Loaded \(serverNodes.count) server nodes")
            } catch {
                print("[PTTViewModel] Failed to load server nodes: \(error)")
                serverNodes = [ServerNode.defaultNode]
            }
        } else {
            // 首次使用，添加默认节点
            serverNodes = [ServerNode.defaultNode]
            saveServerNodes()
        }

        // 设置当前节点
        if let defaultNode = serverNodes.first(where: { $0.isDefault }) {
            currentServerNode = defaultNode
        } else if let firstNode = serverNodes.first {
            currentServerNode = firstNode
        }
    }

    /// 保存服务器节点
    private func saveServerNodes() {
        do {
            let data = try JSONEncoder().encode(serverNodes)
            try data.write(to: serverNodesFileURL, options: .atomic)
            print("[PTTViewModel] Saved \(serverNodes.count) server nodes")
        } catch {
            print("[PTTViewModel] Failed to save server nodes: \(error)")
        }
    }

    /// 添加服务器节点
    public func addServerNode(name: String, url: String) {
        let node = ServerNode(name: name, url: url, isDefault: serverNodes.isEmpty)
        serverNodes.append(node)
        saveServerNodes()

        if serverNodes.count == 1 {
            currentServerNode = node
        }
    }

    /// 更新服务器节点
    public func updateServerNode(_ node: ServerNode) {
        if let index = serverNodes.firstIndex(where: { $0.id == node.id }) {
            serverNodes[index] = node
            saveServerNodes()

            if currentServerNode?.id == node.id {
                currentServerNode = node
            }
        }
    }

    /// 删除服务器节点
    public func deleteServerNode(_ node: ServerNode) {
        serverNodes.removeAll { $0.id == node.id }

        // 如果删除的是当前节点，切换到第一个
        if currentServerNode?.id == node.id {
            currentServerNode = serverNodes.first
        }

        // 确保至少有一个默认节点
        if serverNodes.isEmpty {
            serverNodes = [ServerNode.defaultNode]
            currentServerNode = serverNodes.first
        }

        saveServerNodes()
    }

    /// 设置默认节点
    public func setDefaultServerNode(_ node: ServerNode) {
        for i in serverNodes.indices {
            serverNodes[i].isDefault = (serverNodes[i].id == node.id)
        }
        saveServerNodes()
    }

    /// 切换服务器节点
    public func switchServerNode(_ node: ServerNode) async {
        currentServerNode = node
        serverUrl = node.url
        serverHost = node.host

        // 更新 API 服务和 PTT 服务
        apiService.setServerUrl(node.url)

        // 如果已登录，需要重新连接
        if isLoggedIn {
            await logout()
        }

        print("[PTTViewModel] Switched to server: \(node.name) (\(node.url))")
    }

    /// 测试服务器连接
    public func testServerConnection(url: String) async -> (success: Bool, message: String) {
        do {
            guard let testUrl = URL(string: "\(url)/platform/info") else {
                return (false, "无效的 URL")
            }

            var request = URLRequest(url: testUrl)
            request.timeoutInterval = 5

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                return (true, "连接成功")
            } else {
                return (false, "服务器响应异常")
            }
        } catch {
            return (false, "连接失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 修改密码

    /// 修改密码
    /// - Note: oldPassword 参数保留用于兼容 UI 调用，但后端不验证旧密码
    public func changePassword(oldPassword: String, newPassword: String) async throws {
        try await apiService.changePassword(userId: userId, newPassword: newPassword)
        print("[PTTViewModel] Password changed successfully")
    }

    /// 更新 DMR ID
    public func updateDmrId(_ newDmrId: String) async throws {
        guard userId > 0 else {
            throw PTTViewModelError.notLoggedIn
        }
        // 先获取完整的用户信息，再更新（避免覆盖其他字段）
        let fullUser = try await apiService.getCurrentUserAsPttUser(userId: userId)
        let success = try await apiService.updateUser(originalUser: fullUser, dmrid: newDmrId)
        if success {
            dmrid = newDmrId
            // 刷新用户信息
            if let updatedUser = try? await apiService.getUserInfo() {
                currentUser = updatedUser
            }
            print("[PTTViewModel] DMR ID updated to: \(newDmrId)")
        }
    }

    /// 更新 MDC ID
    public func updateMdcId(_ newMdcId: String) async throws {
        guard userId > 0 else {
            throw PTTViewModelError.notLoggedIn
        }
        // 先获取完整的用户信息，再更新（避免覆盖其他字段）
        let fullUser = try await apiService.getCurrentUserAsPttUser(userId: userId)
        let success = try await apiService.updateUser(originalUser: fullUser, mdcid: newMdcId)
        if success {
            mdcid = newMdcId
            // 刷新用户信息
            if let updatedUser = try? await apiService.getUserInfo() {
                currentUser = updatedUser
            }
            print("[PTTViewModel] MDC ID updated to: \(newMdcId)")
        }
    }
}

// MARK: - PTT 模式

public enum PTTMode: String, CaseIterable {
    case holdToTalk = "hold"
    case toggleToTalk = "toggle"

    public var displayName: String {
        switch self {
        case .holdToTalk:
            return "按住说话"
        case .toggleToTalk:
            return "点击说话"
        }
    }
}

// MARK: - ViewModel 错误

public enum PTTViewModelError: Error, LocalizedError {
    case notLoggedIn
    case joinGroupFailed

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "请先登录"
        case .joinGroupFailed:
            return "加入群组失败"
        }
    }
}

// MARK: - 服务器节点模型

public struct ServerNode: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var url: String
    public var isDefault: Bool

    public init(id: UUID = UUID(), name: String, url: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.isDefault = isDefault
    }

    /// 从 URL 提取主机名
    public var host: String {
        guard let url = URL(string: self.url) else { return self.url }
        return url.host ?? self.url
    }

    /// 预设的默认节点
    public static let defaultNode = ServerNode(
        name: "默认服务器",
        url: "https://ptt.pgarlic.com",
        isDefault: true
    )
}
