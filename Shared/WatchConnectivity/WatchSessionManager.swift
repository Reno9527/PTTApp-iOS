import Foundation
import WatchConnectivity
import Combine

/// iPhone 端 WatchConnectivity 管理器
/// 负责与 Apple Watch 通信
@MainActor
public class WatchSessionManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = WatchSessionManager()

    // MARK: - Published 状态

    /// Watch 是否可达
    @Published public var isWatchReachable = false

    /// Watch 是否已配对
    @Published public var isWatchPaired = false

    /// Watch App 是否已安装
    @Published public var isWatchAppInstalled = false

    // MARK: - Callbacks

    /// PTT 开始回调
    public var onPTTStart: (() async throws -> Void)?

    /// PTT 停止回调
    public var onPTTStop: (() async -> Void)?

    /// 收到 Watch 音频数据回调
    public var onWatchAudioData: ((Data) -> Void)?

    // MARK: - Private

    private var session: WCSession?

    // MARK: - 初始化

    private override init() {
        super.init()
    }

    /// 激活 WatchConnectivity Session
    public func activate() {
        guard WCSession.isSupported() else {
            print("[WatchSession] WCSession not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[WatchSession] Session activating...")
    }

    // MARK: - 发送到 Watch

    /// 发送状态更新到 Watch
    public func sendStatusToWatch(
        isConnected: Bool,
        isTalking: Bool,
        speaker: String?,
        roomName: String?
    ) {
        guard let session = session, session.isReachable else {
            return
        }

        let status: [String: Any] = [
            "connected": isConnected,
            "talking": isTalking,
            "speaker": speaker ?? "",
            "room": roomName ?? ""
        ]

        session.sendMessage(["status": status], replyHandler: nil) { error in
            print("[WatchSession] Send status failed: \(error)")
        }
    }

    /// 发送音频数据到 Watch 播放
    public func sendAudioToWatch(_ pcmData: Data) {
        guard let session = session, session.isReachable else {
            return
        }

        session.sendMessageData(pcmData, replyHandler: nil) { error in
            print("[WatchSession] Send audio failed: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.updateSessionState(session)
            print("[WatchSession] Activation complete: \(activationState.rawValue)")
            if let error = error {
                print("[WatchSession] Activation error: \(error)")
            }
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        print("[WatchSession] Session became inactive")
    }

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        print("[WatchSession] Session deactivated")
        // 重新激活（在 iPhone 切换配对的 Watch 时需要）
        session.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            print("[WatchSession] Reachability changed: \(session.isReachable)")
        }
    }

    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateSessionState(session)
            print("[WatchSession] Watch state changed")
        }
    }

    /// 接收 Watch 发来的消息
    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[WatchSession] Received message: \(message.keys)")

        Task { @MainActor in
            await self.handleWatchMessage(message)
        }
    }

    /// 接收 Watch 发来的带回复消息
    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("[WatchSession] Received message with reply: \(message.keys)")

        Task { @MainActor in
            await self.handleWatchMessage(message)
            replyHandler(["received": true])
        }
    }

    /// 接收 Watch 发来的音频数据
    nonisolated public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("[WatchSession] Received audio data: \(messageData.count) bytes")

        Task { @MainActor in
            self.onWatchAudioData?(messageData)
        }
    }

    // MARK: - Private

    @MainActor
    private func updateSessionState(_ session: WCSession) {
        isWatchReachable = session.isReachable
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
    }

    @MainActor
    private func handleWatchMessage(_ message: [String: Any]) async {
        // 处理 PTT 指令
        if let command = message["ptt"] as? String {
            switch command {
            case "start":
                print("[WatchSession] PTT start from Watch")
                do {
                    try await onPTTStart?()
                } catch {
                    print("[WatchSession] PTT start failed: \(error)")
                }
            case "stop":
                print("[WatchSession] PTT stop from Watch")
                await onPTTStop?()
            default:
                break
            }
        }
    }
}
