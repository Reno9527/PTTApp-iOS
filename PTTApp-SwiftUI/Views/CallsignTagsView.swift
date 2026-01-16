//
//  CallsignTagsView.swift
//  PTT 互联
//
//  Created by 刘光辉 (BG4QG) on 2024.
//  Copyright © 2024-2026 刘光辉. All rights reserved.
//

import SwiftUI
import CoreLocation

// MARK: - 呼号标签视图

/// 底部呼号标签滚动视图
struct CallsignTagsView: View {
    var peers: [PeerLocation]
    var myCallsign: String?
    @Binding var selectedCallsign: String?
    var myLocation: CLLocationCoordinate2D?
    var showDistance: Bool
    var onSelect: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)

            // 标签滚动区
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(peers) { peer in
                        CallsignTagView(
                            peer: peer,
                            isMe: peer.callsign == myCallsign,
                            isSelected: peer.callsign == selectedCallsign,
                            distance: distanceText(for: peer),
                            bearing: bearingTo(peer: peer),
                            showDistance: showDistance
                        )
                        .onTapGesture {
                            selectedCallsign = peer.callsign
                            onSelect?(peer.callsign)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: 60)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }

    private func distanceText(for peer: PeerLocation) -> String? {
        guard showDistance, let myLoc = myLocation else { return nil }
        if peer.callsign == myCallsign { return nil }
        return peer.formattedDistance(to: myLoc)
    }

    /// 计算到目标的方位角 (0-360, 0=北)
    private func bearingTo(peer: PeerLocation) -> Double? {
        guard showDistance, let myLoc = myLocation else { return nil }
        if peer.callsign == myCallsign { return nil }

        let lat1 = myLoc.latitude * .pi / 180
        let lat2 = peer.latitude * .pi / 180
        let dLon = (peer.longitude - myLoc.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi

        if bearing < 0 {
            bearing += 360
        }
        return bearing
    }
}

// MARK: - 单个呼号标签

/// 单个呼号标签视图
struct CallsignTagView: View {
    var peer: PeerLocation
    var isMe: Bool
    var isSelected: Bool
    var distance: String?
    var bearing: Double?  // 方位角 (0-360, 0=北)
    var showDistance: Bool

    var body: some View {
        HStack(spacing: 6) {
            // 状态点
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // 呼号
            Text(peer.callsign)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .primary)

            // 距离 + 方向箭头
            if let dist = distance, showDistance {
                HStack(spacing: 2) {
                    // 方向箭头
                    if let angle = bearing {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            .rotationEffect(.degrees(angle))
                    }
                    Text(dist)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            // 时间
            if !isMe {
                Text(peer.formattedUpdateTime)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundView)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isMe ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var statusColor: Color {
        switch peer.status {
        case .online:
            return .green
        case .recent:
            return .yellow
        case .offline:
            return .gray
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            // 选中状态用渐变
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(.systemGray6)
        }
    }
}

// MARK: - 预览

#if DEBUG
struct CallsignTagsView_Previews: PreviewProvider {
    static var samplePeers: [PeerLocation] = [
        PeerLocation(id: "BG4QG", callsign: "BG4QG", latitude: 39.9, longitude: 116.4, updatedAt: Date(), lastHeardAt: Date(), rssi: -80, snr: 10.5),
        PeerLocation(id: "BH4RPN", callsign: "BH4RPN", latitude: 39.91, longitude: 116.41, updatedAt: Date(), lastHeardAt: Date().addingTimeInterval(-60), rssi: -90, snr: 8.0),
        PeerLocation(id: "BG6FCS", callsign: "BG6FCS", latitude: 39.92, longitude: 116.42, updatedAt: Date(), lastHeardAt: Date().addingTimeInterval(-180), rssi: nil, snr: nil)
    ]

    static var previews: some View {
        VStack {
            Spacer()
            CallsignTagsView(
                peers: samplePeers,
                myCallsign: "BG4QG",
                selectedCallsign: .constant("BH4RPN"),
                myLocation: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                showDistance: true
            )
        }
    }
}
#endif
