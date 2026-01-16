//
//  PTTLiveActivityLiveActivity.swift
//  PTTLiveActivity
//
//  Created by Guanghui Liu on 2026/1/24.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - PTT 状态

/// PTT Live Activity 状态
public enum PTTLiveStatus: String, Codable, Hashable {
    case listening
    case receiving
    case transmitting

    var displayText: String {
        switch self {
        case .listening: return "守听中"
        case .receiving: return "接收中"
        case .transmitting: return "发射中"
        }
    }

    var iconName: String {
        switch self {
        case .listening: return "antenna.radiowaves.left.and.right"
        case .receiving: return "speaker.wave.2.fill"
        case .transmitting: return "mic.fill"
        }
    }
}

// MARK: - Activity Attributes

public struct PTTActivityAttributes: ActivityAttributes {
    public var channelName: String
    public var channelId: Int
    public var myCallSign: String

    public struct ContentState: Codable, Hashable {
        public var status: PTTLiveStatus
        public var speaker: String?
        public var speakingDuration: Int
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

// MARK: - Live Activity Widget

struct PTTLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PTTActivityAttributes.self) { context in
            // 锁屏视图
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - 锁屏视图

private struct LockScreenView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            StatusIconView(status: context.state.status)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.channelName)
                    .font(.headline)
                    .fontWeight(.semibold)

                if let speaker = context.state.speaker {
                    HStack(spacing: 4) {
                        Image(systemName: "person.wave.2.fill")
                            .font(.caption)
                        Text(speaker)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.orange)
                } else {
                    Text(context.state.status.displayText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if context.state.onlineCount > 0 {
                VStack(spacing: 2) {
                    Text("\(context.state.onlineCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("在线")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island 紧凑态

private struct CompactLeadingView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        Image(systemName: context.state.status.iconName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch context.state.status {
        case .listening: return .gray
        case .receiving: return .orange
        case .transmitting: return .red
        }
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        if let speaker = context.state.speaker {
            Text(speaker.prefix(8))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .lineLimit(1)
        } else {
            Text(context.attributes.channelName.prefix(6))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
    }
}

// MARK: - Dynamic Island 最小态

private struct MinimalView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        Image(systemName: context.state.status.iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        switch context.state.status {
        case .listening: return .gray
        case .receiving: return .orange
        case .transmitting: return .red
        }
    }
}

// MARK: - Dynamic Island 展开态

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        StatusIconView(status: context.state.status)
            .frame(width: 36, height: 36)
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        if context.state.onlineCount > 0 {
            VStack(spacing: 2) {
                Text("\(context.state.onlineCount)")
                    .font(.system(size: 18, weight: .bold))
                Text("在线")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct ExpandedCenterView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        VStack(spacing: 2) {
            Text(context.attributes.channelName)
                .font(.system(size: 14, weight: .semibold))

            if let speaker = context.state.speaker {
                Text(speaker)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
            } else {
                Text(context.state.status.displayText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<PTTActivityAttributes>

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                Text(context.attributes.myCallSign)
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)

            Spacer()

            if context.state.speakingDuration > 0 {
                Text(formatDuration(context.state.speakingDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 4)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - 状态图标

private struct StatusIconView: View {
    let status: PTTLiveStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            Image(systemName: status.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .listening: return .gray
        case .receiving: return .orange
        case .transmitting: return .red
        }
    }
}

// MARK: - 预览
// Note: Live Activity previews require iOS 17+
