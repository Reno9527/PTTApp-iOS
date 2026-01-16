import Foundation

// MARK: - PTT 状态（通用，不依赖 ActivityKit）

/// PTT Live Activity 状态
public enum PTTLiveStatus: String, Codable, Hashable {
    /// 守听中（无人说话）
    case listening

    /// 有人发言
    case receiving

    /// 我在发射
    case transmitting
}

// MARK: - 便捷扩展

public extension PTTLiveStatus {

    /// 状态显示文本
    var displayText: String {
        switch self {
        case .listening:
            return "守听中"
        case .receiving:
            return "接收中"
        case .transmitting:
            return "发射中"
        }
    }

    /// 状态图标名称 (SF Symbol)
    var iconName: String {
        switch self {
        case .listening:
            return "antenna.radiowaves.left.and.right"
        case .receiving:
            return "speaker.wave.2.fill"
        case .transmitting:
            return "mic.fill"
        }
    }
}

// MARK: - ActivityKit 数据模型（iOS 16.1+）

#if canImport(ActivityKit)
import ActivityKit

/// PTT Live Activity 数据模型
///
/// 用于 Dynamic Island 和锁屏 Widget 显示
@available(iOS 16.2, *)
public struct PTTActivityAttributes: ActivityAttributes {

    // MARK: - 静态数据（启动时确定，不可变）

    /// 频道/房间名称
    public var channelName: String

    /// 频道 ID
    public var channelId: Int

    /// 我的呼号
    public var myCallSign: String

    // MARK: - 动态数据（可实时更新）

    public struct ContentState: Codable, Hashable {
        /// 当前状态
        public var status: PTTLiveStatus

        /// 当前说话者呼号（nil 表示无人说话）
        public var speaker: String?

        /// 说话持续时间（秒）
        public var speakingDuration: Int

        /// 在线人数
        public var onlineCount: Int

        public init(
            status: PTTLiveStatus = .listening,
            speaker: String? = nil,
            speakingDuration: Int = 0,
            onlineCount: Int = 0
        ) {
            self.status = status
            self.speaker = speaker
            self.speakingDuration = speakingDuration
            self.onlineCount = onlineCount
        }
    }

    public init(channelName: String, channelId: Int, myCallSign: String) {
        self.channelName = channelName
        self.channelId = channelId
        self.myCallSign = myCallSign
    }
}
#endif
