import Foundation
import Network

// MARK: - 网络统计

/// 网络统计信息
public struct NetworkStats: Sendable {
    /// 收到的包数
    public let packetsReceived: UInt64

    /// 发送的包数
    public let packetsSent: UInt64

    /// 丢包数
    public let packetsLost: UInt64

    /// 乱序率 (0.0 ~ 1.0)
    public let outOfOrderRate: Double

    /// 当前抖动 (毫秒)
    public let currentJitterMs: Int

    /// 缓冲区深度 (包数)
    public let bufferDepthPackets: Int

    /// 缓冲区深度 (毫秒)
    public let bufferDepthMs: Int

    public init(
        packetsReceived: UInt64 = 0,
        packetsSent: UInt64 = 0,
        packetsLost: UInt64 = 0,
        outOfOrderRate: Double = 0,
        currentJitterMs: Int = 0,
        bufferDepthPackets: Int = 0,
        bufferDepthMs: Int = 0
    ) {
        self.packetsReceived = packetsReceived
        self.packetsSent = packetsSent
        self.packetsLost = packetsLost
        self.outOfOrderRate = outOfOrderRate
        self.currentJitterMs = currentJitterMs
        self.bufferDepthPackets = bufferDepthPackets
        self.bufferDepthMs = bufferDepthMs
    }
}

/// UDP 客户端
///
/// 使用 NWConnection 实现 UDP 通信
public final class UDPClient: @unchecked Sendable {

    // MARK: - 属性

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.pgarlic.pttapp.udp", qos: .userInteractive)

    private var _isConnected = false
    public var isConnected: Bool { _isConnected }

    // 统计
    private var _packetsReceived: UInt64 = 0
    private var _packetsSent: UInt64 = 0

    // 连接就绪回调（用于 waitForReady）
    private var onReadyCallback: ((Result<Void, Error>) -> Void)?
    private let callbackLock = NSLock()

    /// Continuation 状态包装器（防止重复 resume）
    private final class ContinuationState: @unchecked Sendable {
        private var resumed = false
        private let lock = NSLock()

        /// 尝试标记为已 resume，返回 true 表示首次调用
        func tryResume() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !resumed else { return false }
            resumed = true
            return true
        }
    }

    // MARK: - 回调

    /// 数据接收回调
    public var onReceive: ((Data) -> Void)?

    /// 连接状态变化回调
    public var onStateChanged: ((Bool) -> Void)?

    /// 错误回调
    public var onError: ((Error) -> Void)?

    // MARK: - 初始化

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - 连接

    /// 连接到 UDP 服务器
    /// - Parameters:
    ///   - host: 服务器地址
    ///   - port: 服务器端口
    public func connect(host: String, port: UInt16) async throws {
        // 断开现有连接
        disconnect()

        // 创建 UDP 连接
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw UDPError.invalidPort(port)
        }
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        // 设置服务类型为语音（提高优先级）
        parameters.serviceClass = .interactiveVoice

        let conn = NWConnection(to: endpoint, using: parameters)
        self.connection = conn

        // 设置状态处理
        conn.stateUpdateHandler = { [weak self] state in
            self?.handleStateUpdate(state)
        }

        // 启动连接
        conn.start(queue: queue)

        // 等待连接就绪
        try await waitForReady()

        // 开始接收
        startReceiving()

        print("[UDPClient] Connected to \(host):\(port)")
    }

    /// 等待连接就绪
    private func waitForReady() async throws {
        // 如果已经连接，直接返回
        if _isConnected { return }

        guard connection != nil else {
            throw UDPError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // 使用独立的状态对象防止 continuation 被多次 resume
            let state = ContinuationState()

            // 设置就绪回调（handleStateUpdate 会调用）
            callbackLock.lock()
            onReadyCallback = { [weak self] result in
                // 确保只 resume 一次（即使 self 为 nil 也能正确工作）
                guard state.tryResume() else { return }
                self?.callbackLock.lock()
                self?.onReadyCallback = nil
                self?.callbackLock.unlock()

                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            callbackLock.unlock()

            // 设置超时（3秒，加快失败检测）
            queue.asyncAfter(deadline: .now() + 3) { [weak self] in
                // 确保只 resume 一次
                guard state.tryResume() else { return }
                if self?._isConnected != true {
                    self?.callbackLock.lock()
                    self?.onReadyCallback = nil
                    self?.callbackLock.unlock()
                    continuation.resume(throwing: UDPError.timeout)
                }
            }
        }
    }

    /// 断开连接
    public func disconnect() {
        // 清理就绪回调
        callbackLock.lock()
        onReadyCallback = nil
        callbackLock.unlock()

        connection?.cancel()
        connection = nil
        _isConnected = false
        _packetsReceived = 0
        _packetsSent = 0
        onStateChanged?(false)
        print("[UDPClient] Disconnected")
    }

    // MARK: - 发送

    /// 发送数据
    /// - Parameter data: 要发送的数据
    public func send(_ data: Data) async throws {
        guard let conn = connection, _isConnected else {
            throw UDPError.notConnected
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._packetsSent += 1
                    continuation.resume()
                }
            })
        }
    }

    /// 发送数据（非阻塞）
    public func sendAsync(_ data: Data) {
        guard let conn = connection, _isConnected else { return }

        conn.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.onError?(error)
            } else {
                self?._packetsSent += 1
            }
        })
    }

    // MARK: - 接收

    private func startReceiving() {
        guard let conn = connection, _isConnected else { return }

        conn.receiveMessage { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.onError?(error)
                return
            }

            if let data = content {
                self._packetsReceived += 1
                self.onReceive?(data)
            }

            // 继续接收（在队列中调度，避免栈溢出）
            if self._isConnected {
                self.queue.async { [weak self] in
                    self?.startReceiving()
                }
            }
        }
    }

    // MARK: - 状态处理

    private func handleStateUpdate(_ state: NWConnection.State) {
        switch state {
        case .ready:
            _isConnected = true
            onStateChanged?(true)
            // 通知 waitForReady
            callbackLock.lock()
            let callback = onReadyCallback
            callbackLock.unlock()
            callback?(.success(()))
            print("[UDPClient] Connection ready")

        case .failed(let error):
            _isConnected = false
            onStateChanged?(false)
            onError?(error)
            // 通知 waitForReady
            callbackLock.lock()
            let callback = onReadyCallback
            callbackLock.unlock()
            callback?(.failure(error))
            print("[UDPClient] Connection failed: \(error)")

        case .cancelled:
            _isConnected = false
            onStateChanged?(false)
            // 通知 waitForReady
            callbackLock.lock()
            let callback = onReadyCallback
            callbackLock.unlock()
            callback?(.failure(UDPError.cancelled))
            print("[UDPClient] Connection cancelled")

        case .waiting(let error):
            print("[UDPClient] Connection waiting: \(error)")

        default:
            break
        }
    }

    // MARK: - 统计

    public var stats: NetworkStats {
        NetworkStats(
            packetsReceived: _packetsReceived,
            packetsSent: _packetsSent,
            packetsLost: 0,  // JitterBuffer 负责统计
            outOfOrderRate: 0,
            currentJitterMs: 0,
            bufferDepthPackets: 0,
            bufferDepthMs: 0
        )
    }
}

// MARK: - 错误类型

public enum UDPError: Error, CustomStringConvertible {
    case notConnected
    case timeout
    case cancelled
    case sendFailed(Error)
    case invalidPort(UInt16)

    public var description: String {
        switch self {
        case .notConnected:
            return "Not connected"
        case .timeout:
            return "Connection timeout"
        case .cancelled:
            return "Connection cancelled"
        case .sendFailed(let error):
            return "Send failed: \(error)"
        case .invalidPort(let port):
            return "Invalid port: \(port)"
        }
    }
}
