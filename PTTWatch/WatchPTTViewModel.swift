import Foundation
import WatchConnectivity
import WatchKit
import AVFoundation

/// Watch 端 PTT ViewModel
/// 通过 WatchConnectivity 与 iPhone 通信
class WatchPTTViewModel: NSObject, ObservableObject {

    // MARK: - Published 状态

    /// 是否已连接（iPhone 已连接服务器）
    @Published var isConnected = false

    /// 是否正在发射
    @Published var isTalking = false

    /// 当前讲话者
    @Published var currentSpeaker: String?

    /// 房间名称
    @Published var roomName = "PTT 互联"

    /// Watch 是否可达 iPhone
    @Published var isPhoneReachable = false

    // MARK: - Private

    private let audioManager = WatchAudioManager()
    private var session: WCSession?

    // MARK: - 初始化

    override init() {
        super.init()
        activateSession()
    }

    /// 激活 WatchConnectivity Session
    private func activateSession() {
        guard WCSession.isSupported() else {
            print("[WatchPTT] WCSession not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[WatchPTT] Session activating...")
    }

    // MARK: - PTT 操作

    /// 开始讲话
    func startTalking() {
        guard !isTalking else { return }
        guard session?.isReachable == true else {
            print("[WatchPTT] iPhone not reachable")
            return
        }

        isTalking = true

        // 触觉反馈
        WKInterfaceDevice.current().play(.start)

        // 发送 PTT 开始指令到 iPhone
        session?.sendMessage(["ptt": "start"], replyHandler: nil) { error in
            print("[WatchPTT] Send start failed: \(error)")
        }

        // 启动 Watch 录音
        audioManager.startRecording { [weak self] pcmData in
            // 发送音频数据到 iPhone
            self?.session?.sendMessageData(pcmData, replyHandler: nil, errorHandler: nil)
        }

        print("[WatchPTT] Started talking")
    }

    /// 停止讲话
    func stopTalking() {
        guard isTalking else { return }

        isTalking = false

        // 触觉反馈
        WKInterfaceDevice.current().play(.stop)

        // 停止录音
        audioManager.stopRecording()

        // 发送 PTT 停止指令到 iPhone
        session?.sendMessage(["ptt": "stop"], replyHandler: nil) { error in
            print("[WatchPTT] Send stop failed: \(error)")
        }

        print("[WatchPTT] Stopped talking")
    }

    /// 更新状态（从 iPhone 接收）
    private func updateStatus(_ status: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let connected = status["connected"] as? Bool {
                self.isConnected = connected
            }
            if let talking = status["talking"] as? Bool {
                // 仅当我们不是主动发射方时更新
                if !self.isTalking {
                    self.isTalking = talking
                }
            }
            if let speaker = status["speaker"] as? String, !speaker.isEmpty {
                self.currentSpeaker = speaker
            } else {
                self.currentSpeaker = nil
            }
            if let room = status["room"] as? String, !room.isEmpty {
                self.roomName = room
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchPTTViewModel: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
            print("[WatchPTT] Session activated: \(activationState.rawValue), reachable: \(session.isReachable)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isPhoneReachable = session.isReachable
            print("[WatchPTT] Reachability changed: \(session.isReachable)")

            // 不可达时重置状态
            if !session.isReachable {
                self?.isConnected = false
                self?.currentSpeaker = nil
            }
        }
    }

    /// 接收 iPhone 发来的消息（状态更新）
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WatchPTT] Received message: \(message.keys)")

        if let status = message["status"] as? [String: Any] {
            updateStatus(status)
        }
    }

    /// 接收 iPhone 发来的音频数据
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("[WatchPTT] Received audio data: \(messageData.count) bytes")

        // 播放收到的 PCM 音频
        audioManager.playAudio(messageData)

        // 触觉反馈（收到语音）
        WKInterfaceDevice.current().play(.notification)
    }

    /// 接收带回复的消息
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("[WatchPTT] Received message with reply: \(message.keys)")

        if let status = message["status"] as? [String: Any] {
            updateStatus(status)
        }

        // 回复确认
        replyHandler(["received": true])
    }
}
