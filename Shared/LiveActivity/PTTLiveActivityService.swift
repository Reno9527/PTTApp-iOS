import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// PTT Live Activity 服务
///
/// 管理 Live Activity 的生命周期（启动、更新、结束）
@available(iOS 16.2, *)
public final class PTTLiveActivityService: ObservableObject {

    // MARK: - 单例

    public static let shared = PTTLiveActivityService()

    // MARK: - 状态

    /// 当前活跃的 Live Activity
    @Published public private(set) var currentActivity: Activity<PTTActivityAttributes>?

    /// 是否有活跃的 Live Activity
    public var isActive: Bool {
        currentActivity != nil
    }

    // MARK: - 防抖

    /// 上次更新时间
    private var lastUpdateTime: Date = .distantPast

    /// 上次更新的状态（用于去重）
    private var lastState: PTTActivityAttributes.ContentState?

    /// 最小更新间隔（毫秒）
    private let minUpdateInterval: TimeInterval = 0.5  // 500ms

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 启动 Live Activity
    ///
    /// - Parameters:
    ///   - channelName: 频道名称
    ///   - channelId: 频道 ID
    ///   - myCallSign: 我的呼号
    ///   - onlineCount: 在线人数
    /// - Returns: 是否启动成功
    @discardableResult
    public func start(
        channelName: String,
        channelId: Int,
        myCallSign: String,
        onlineCount: Int = 0
    ) -> Bool {
        // 检查是否支持 Live Activity
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities are not enabled")
            return false
        }

        // 先捕获所有需要结束的旧 Activity ID
        let oldActivityIds = Activity<PTTActivityAttributes>.activities.map { $0.id }
        currentActivity = nil

        // 创建属性
        let attributes = PTTActivityAttributes(
            channelName: channelName,
            channelId: channelId,
            myCallSign: myCallSign
        )

        // 初始状态
        let initialState = PTTActivityAttributes.ContentState(
            status: .listening,
            speaker: nil,
            speakingDuration: 0,
            onlineCount: onlineCount
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil  // 不使用 APNs 推送
            )

            currentActivity = activity
            print("[LiveActivity] Started: \(channelName), id=\(activity.id)")

            // 创建新 Activity 后，异步结束旧的（只结束之前捕获的 ID）
            Task {
                for oldActivity in Activity<PTTActivityAttributes>.activities {
                    if oldActivityIds.contains(oldActivity.id) {
                        await oldActivity.end(nil, dismissalPolicy: .immediate)
                        print("[LiveActivity] Ended old activity: \(oldActivity.id)")
                    }
                }
            }

            return true

        } catch {
            print("[LiveActivity] Failed to start: \(error)")
            return false
        }
    }

    /// 更新 Live Activity 状态
    ///
    /// - Parameters:
    ///   - status: 当前状态
    ///   - speaker: 说话者呼号
    ///   - speakingDuration: 说话时长
    ///   - onlineCount: 在线人数
    ///   - force: 强制更新（忽略防抖）
    public func update(
        status: PTTLiveStatus,
        speaker: String? = nil,
        speakingDuration: Int = 0,
        onlineCount: Int = 0,
        force: Bool = false
    ) {
        guard let activity = currentActivity else {
            return
        }

        let newState = PTTActivityAttributes.ContentState(
            status: status,
            speaker: speaker,
            speakingDuration: speakingDuration,
            onlineCount: onlineCount
        )

        // 防抖：检查是否需要更新
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)

        // 状态相同且在最小间隔内，跳过更新
        if !force && elapsed < minUpdateInterval {
            if let last = lastState, last.status == newState.status &&
               last.speaker == newState.speaker &&
               last.onlineCount == newState.onlineCount {
                return  // 跳过重复更新
            }
        }

        // 更新状态记录
        lastUpdateTime = now
        lastState = newState

        Task {
            await activity.update(
                ActivityContent(state: newState, staleDate: nil)
            )
        }
    }

    /// 更新说话者
    ///
    /// - Parameter speaker: 说话者呼号，nil 表示无人说话
    public func updateSpeaker(_ speaker: String?, onlineCount: Int = 0) {
        let status: PTTLiveStatus = speaker != nil ? .receiving : .listening
        update(status: status, speaker: speaker, onlineCount: onlineCount)
    }

    /// 更新为发射状态
    ///
    /// - Parameter duration: 发射时长
    public func updateTransmitting(duration: Int = 0, onlineCount: Int = 0) {
        update(status: .transmitting, speaker: nil, speakingDuration: duration, onlineCount: onlineCount)
    }

    /// 更新为守听状态
    public func updateListening(onlineCount: Int = 0) {
        update(status: .listening, speaker: nil, onlineCount: onlineCount)
    }

    /// 结束 Live Activity
    ///
    /// - Parameter immediately: 是否立即移除（否则保留在锁屏上一段时间）
    public func end(immediately: Bool = false) async {
        guard let activity = currentActivity else {
            return
        }

        let finalState = PTTActivityAttributes.ContentState(
            status: .listening,
            speaker: nil,
            speakingDuration: 0,
            onlineCount: 0
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: immediately ? .immediate : .default
        )

        currentActivity = nil
        print("[LiveActivity] Ended")
    }

    /// 结束所有 Live Activity（App 启动时清理）
    public func endAll() async {
        for activity in Activity<PTTActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        print("[LiveActivity] Ended all activities")
    }
}

#else

// MARK: - 非 iOS 平台的空实现

/// PTT Live Activity 服务（非 iOS 平台空实现）
public final class PTTLiveActivityService: ObservableObject {
    public static let shared = PTTLiveActivityService()
    public var isActive: Bool { false }

    private init() {}

    @discardableResult
    public func start(channelName: String, channelId: Int, myCallSign: String, onlineCount: Int = 0) -> Bool {
        false
    }

    public func update(status: PTTLiveStatus, speaker: String? = nil, speakingDuration: Int = 0, onlineCount: Int = 0) {}
    public func updateSpeaker(_ speaker: String?, onlineCount: Int = 0) {}
    public func updateTransmitting(duration: Int = 0, onlineCount: Int = 0) {}
    public func updateListening(onlineCount: Int = 0) {}
    public func end(immediately: Bool = false) async {}
    public func endAll() async {}
}

#endif
