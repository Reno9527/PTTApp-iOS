//
//  LocationTabView.swift
//  PTT 互联
//
//  Created by 刘光辉 (BG4QG) on 2024.
//  Copyright © 2024-2026 刘光辉. All rights reserved.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - 位置 Tab 视图

/// 位置页面主视图
struct LocationTabView: View {
    @ObservedObject private var locationService = LocationService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedCallsign: String?
    @State private var showSettings: Bool = false
    @State private var searchText: String = ""
    @State private var favoritesOnly: Bool = false
    @State private var favorites: Set<String> = []
    @State private var mapType: MKMapType = .standard
    @State private var showUserDetail: Bool = false
    @State private var heading: Double = 0  // 地图旋转角度
    @State private var shouldResetHeading: Bool = false  // 触发重置朝北
    @State private var showingTracks: Set<String> = []  // 正在显示轨迹的呼号

    var myCallsign: String?

    var body: some View {
        ZStack {
            // 苹果地图
            MapViewRepresentable(
                region: $region,
                heading: $heading,
                shouldResetHeading: $shouldResetHeading,
                mapType: mapType,
                annotations: allAnnotations,
                tracks: trackOverlays,
                selectedCallsign: $selectedCallsign,
                myCallsign: myCallsign,
                onAnnotationTap: { callsign in
                    selectedCallsign = callsign
                    showUserDetail = true
                }
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar

                Spacer()

                HStack(alignment: .bottom) {
                    // 左侧：标尺
                    MapScaleView(region: region)
                        .padding(.leading, 12)
                        .padding(.bottom, 8)

                    Spacer()

                    // 右侧：指南针 + 地图类型
                    VStack(spacing: 8) {
                        // 指南针（点击重置朝北）
                        CompassView(heading: heading)
                            .frame(width: 44, height: 44)
                            .onTapGesture {
                                resetMapHeading()
                            }

                        // 地图类型切换
                        mapTypeButtons
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                }

                // 底部呼号标签
                CallsignTagsView(
                    peers: peersWithMe,
                    myCallsign: myCallsign,
                    selectedCallsign: $selectedCallsign,
                    myLocation: locationService.myLocation,
                    showDistance: locationService.settings.showDistance,
                    onSelect: { callsign in
                        focusOn(callsign: callsign)
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            LocationSettingsView()
        }
        .sheet(isPresented: $showUserDetail) {
            if let callsign = selectedCallsign {
                UserDetailSheet(
                    callsign: callsign,
                    peer: getPeer(callsign: callsign),
                    myLocation: locationService.myLocation,
                    isFavorite: favorites.contains(callsign),
                    isShowingTrack: showingTracks.contains(callsign),
                    trackPointCount: locationService.getTrack(callsign: callsign)?.pointCount ?? 0,
                    onNavigate: {
                        navigateToUser(callsign: callsign)
                    },
                    onToggleFavorite: {
                        toggleFavorite(callsign: callsign)
                    },
                    onToggleTrack: {
                        toggleTrack(callsign: callsign)
                    }
                )
                .modifier(MediumSheetModifier())
            }
        }
        .onAppear {
            locationService.requestAuthorization()
            locationService.startLocating()
            loadFavorites()

            // 如果有自己的位置，居中显示
            if let myLoc = locationService.myLocation {
                region.center = myLoc
            }
        }
    }

    // MARK: - 地图类型按钮

    private var mapTypeButtons: some View {
        VStack(spacing: 4) {
            Button {
                mapType = .standard
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 14))
                    .foregroundColor(mapType == .standard ? .blue : .primary)
            }
            .buttonStyle(SmallToolbarButtonStyle())

            Button {
                mapType = .satellite
            } label: {
                Image(systemName: "globe.asia.australia")
                    .font(.system(size: 14))
                    .foregroundColor(mapType == .satellite ? .blue : .primary)
            }
            .buttonStyle(SmallToolbarButtonStyle())

            Button {
                mapType = .hybrid
            } label: {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 14))
                    .foregroundColor(mapType == .hybrid ? .blue : .primary)
            }
            .buttonStyle(SmallToolbarButtonStyle())
        }
        .padding(4)
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - 计算属性

    private var filteredPeers: [PeerLocation] {
        locationService.filteredPeers(
            myCallsign: myCallsign,
            searchText: searchText,
            favoritesOnly: favoritesOnly,
            favorites: favorites
        )
    }

    /// 包含自己在内的标签列表
    private var peersWithMe: [PeerLocation] {
        var result: [PeerLocation] = []

        // 先添加自己
        if let myLoc = locationService.myLocation, let callsign = myCallsign {
            // 如果关闭位置共享，自己也显示为离线
            let lastHeard = locationService.settings.locationShareEnabled ? Date() : Date.distantPast
            let me = PeerLocation(
                id: callsign,
                callsign: callsign,
                latitude: myLoc.latitude,
                longitude: myLoc.longitude,
                updatedAt: Date(),
                lastHeardAt: lastHeard,
                rssi: nil,
                snr: nil
            )
            result.append(me)
        }

        // 添加其他用户（排除自己避免重复）
        let others = filteredPeers.filter { $0.callsign != myCallsign }
        result.append(contentsOf: others)

        return result
    }

    private var allAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []

        // 添加自己
        if let myLoc = locationService.myLocation, let callsign = myCallsign {
            // 如果关闭位置共享，自己也显示为离线
            let myStatus: OnlineStatus = locationService.settings.locationShareEnabled ? .online : .offline
            items.append(MapAnnotationItem(
                id: callsign,
                callsign: callsign,
                coordinate: myLoc,
                status: myStatus
            ))
        }

        // 添加其他用户
        for peer in filteredPeers {
            if peer.callsign != myCallsign {
                items.append(MapAnnotationItem(
                    id: peer.id,
                    callsign: peer.callsign,
                    coordinate: peer.coordinate,
                    status: peer.status
                ))
            }
        }

        return items
    }

    /// 轨迹叠加层数据
    private var trackOverlays: [TrackOverlayItem] {
        var items: [TrackOverlayItem] = []

        for callsign in showingTracks {
            if let track = locationService.getTrack(callsign: callsign) {
                let points = track.points(within: locationService.settings.filterMinutes)
                if !points.isEmpty {
                    // 根据呼号分配颜色
                    let color = trackColor(for: callsign)
                    items.append(TrackOverlayItem(id: callsign, points: points, color: color))
                }
            }
        }

        return items
    }

    /// 根据呼号分配轨迹颜色
    private func trackColor(for callsign: String) -> UIColor {
        // 使用呼号的 hash 值分配颜色
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemPink, .systemTeal
        ]
        let index = abs(callsign.hashValue) % colors.count
        return colors[index]
    }

    // MARK: - 顶部工具栏

    private var topToolbar: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索呼号", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // 收藏筛选
            Button {
                favoritesOnly.toggle()
            } label: {
                Image(systemName: favoritesOnly ? "star.fill" : "star")
                    .foregroundColor(favoritesOnly ? .yellow : .primary)
            }
            .buttonStyle(ToolbarButtonStyle())

            // 定位到自己
            Button {
                if let myLoc = locationService.myLocation {
                    withAnimation {
                        region.center = myLoc
                    }
                }
            } label: {
                Image(systemName: "location")
            }
            .buttonStyle(ToolbarButtonStyle())

            // 设置
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - 方法

    private func focusOn(callsign: String) {
        selectedCallsign = callsign

        // 放大到合适的缩放级别
        let zoomedSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)

        if callsign == myCallsign {
            if let myLoc = locationService.myLocation {
                withAnimation {
                    region = MKCoordinateRegion(center: myLoc, span: zoomedSpan)
                }
            }
        } else if let peer = locationService.peers[callsign] {
            withAnimation {
                region = MKCoordinateRegion(center: peer.coordinate, span: zoomedSpan)
            }
        }
    }

    private func loadFavorites() {
        if let saved = UserDefaults.standard.stringArray(forKey: "location_favorites") {
            favorites = Set(saved)
        }
    }

    private func getPeer(callsign: String) -> PeerLocation? {
        if callsign == myCallsign, let myLoc = locationService.myLocation {
            return PeerLocation(
                id: callsign,
                callsign: callsign,
                latitude: myLoc.latitude,
                longitude: myLoc.longitude,
                updatedAt: Date(),
                lastHeardAt: Date(),
                rssi: nil,
                snr: nil
            )
        }
        return locationService.peers[callsign]
    }

    private func navigateToUser(callsign: String) {
        guard let peer = getPeer(callsign: callsign) else { return }
        let coordinate = peer.coordinate
        let url = URL(string: "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d")!
        UIApplication.shared.open(url)
        showUserDetail = false
    }

    private func toggleFavorite(callsign: String) {
        if favorites.contains(callsign) {
            favorites.remove(callsign)
        } else {
            favorites.insert(callsign)
        }
        UserDefaults.standard.set(Array(favorites), forKey: "location_favorites")
    }

    private func toggleTrack(callsign: String) {
        if showingTracks.contains(callsign) {
            showingTracks.remove(callsign)
        } else {
            showingTracks.insert(callsign)
        }
    }

    private func resetMapHeading() {
        shouldResetHeading = true
    }
}

// MARK: - 地图标注数据

struct MapAnnotationItem: Identifiable {
    let id: String
    let callsign: String
    let coordinate: CLLocationCoordinate2D
    let status: OnlineStatus
}

// MARK: - 呼号标记视图

struct CallsignMarker: View {
    let callsign: String
    let status: OnlineStatus
    let isMe: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            // 呼号标签
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(callsign)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue : Color(.systemBackground).opacity(0.95))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isMe ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            // 指示箭头
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .blue : Color(.systemBackground).opacity(0.95))
        }
    }

    private var statusColor: Color {
        switch status {
        case .online: return .green
        case .recent: return .yellow
        case .offline: return .gray
        }
    }
}

// MARK: - 工具栏按钮样式

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundColor(.primary)
            .frame(width: 36, height: 36)
            .background(Color(.systemBackground).opacity(0.95))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SmallToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(Color.clear)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
    }
}

// MARK: - 轨迹数据项

struct TrackOverlayItem: Identifiable {
    let id: String  // callsign
    let points: [TrackPoint]
    let color: UIColor
}

// MARK: - 自定义 Polyline（带呼号标识）

class CallsignPolyline: MKPolyline {
    var callsign: String = ""
    var trackColor: UIColor = .systemBlue
}

// MARK: - MapView 预加载器

/// MapView 预加载管理器（单例）
/// 在应用启动时预先创建 MKMapView，避免首次打开位置页面时的延迟
final class MapViewPreloader {
    static let shared = MapViewPreloader()

    /// 预加载的 MapView（主线程访问）
    private var preloadedMapView: MKMapView?

    /// 是否已预加载
    private(set) var isPreloaded: Bool = false

    private init() {}

    /// 预加载 MapView（在主线程调用）
    @MainActor
    func preload() {
        guard !isPreloaded else { return }

        // 在主线程创建 MKMapView
        let mapView = MKMapView()
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        preloadedMapView = mapView
        isPreloaded = true
        print("[MapViewPreloader] MapView preloaded")
    }

    /// 获取预加载的 MapView（获取后清空，只能使用一次）
    @MainActor
    func getPreloadedMapView() -> MKMapView? {
        let mapView = preloadedMapView
        preloadedMapView = nil
        isPreloaded = false
        return mapView
    }
}

// MARK: - MKMapView 封装

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var heading: Double  // 地图旋转角度
    @Binding var shouldResetHeading: Bool  // 重置朝北
    var mapType: MKMapType
    var annotations: [MapAnnotationItem]
    var tracks: [TrackOverlayItem]  // 轨迹数据
    @Binding var selectedCallsign: String?
    var myCallsign: String?
    var onAnnotationTap: ((String) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        // 优先使用预加载的 MapView
        let mapView: MKMapView
        if let preloaded = MapViewPreloader.shared.getPreloadedMapView() {
            mapView = preloaded
            print("[MapViewRepresentable] Using preloaded MapView")
        } else {
            mapView = MKMapView()
            mapView.showsCompass = false
            mapView.showsScale = false
            mapView.showsUserLocation = false
            mapView.isRotateEnabled = true
            mapView.isPitchEnabled = true
            print("[MapViewRepresentable] Created new MapView")
        }

        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType

        // 重置朝北
        if shouldResetHeading {
            let camera = mapView.camera
            camera.heading = 0
            mapView.setCamera(camera, animated: true)
            DispatchQueue.main.async {
                self.shouldResetHeading = false
                self.heading = 0
            }
        }

        // 更新区域
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // 更新标注
        updateAnnotations(mapView)

        // 更新轨迹
        updateTracks(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateAnnotations(_ mapView: MKMapView) {
        // 移除旧标注
        mapView.removeAnnotations(mapView.annotations)

        // 添加新标注
        for item in annotations {
            let annotation = CallsignPointAnnotation()
            annotation.coordinate = item.coordinate
            annotation.title = item.callsign
            annotation.callsign = item.callsign
            annotation.status = item.status
            annotation.isMe = item.callsign == myCallsign
            annotation.isSelected = item.callsign == selectedCallsign
            mapView.addAnnotation(annotation)
        }
    }

    private func updateTracks(_ mapView: MKMapView) {
        // 移除旧轨迹
        mapView.removeOverlays(mapView.overlays)

        // 添加新轨迹
        for track in tracks {
            guard track.points.count >= 2 else { continue }

            var coordinates = track.points.map { $0.coordinate }
            let polyline = CallsignPolyline(coordinates: &coordinates, count: coordinates.count)
            polyline.callsign = track.id
            polyline.trackColor = track.color
            mapView.addOverlay(polyline)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var isUserInteracting = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isUserInteracting = false
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                // 更新地图旋转角度（用于指南针）
                self.parent.heading = mapView.camera.heading
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let callsignAnn = annotation as? CallsignPointAnnotation else { return nil }

            let identifier = "CallsignAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? CallsignMKAnnotationView

            if annotationView == nil {
                annotationView = CallsignMKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }

            annotationView?.annotation = annotation
            annotationView?.configure(
                callsign: callsignAnn.callsign,
                status: callsignAnn.status,
                isMe: callsignAnn.isMe,
                isSelected: callsignAnn.isSelected
            )

            return annotationView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let callsignAnn = view.annotation as? CallsignPointAnnotation {
                parent.onAnnotationTap?(callsignAnn.callsign)
            }
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        // MARK: - 轨迹渲染

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? CallsignPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.trackColor
                renderer.lineWidth = 3
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

class CallsignPointAnnotation: MKPointAnnotation {
    var callsign: String = ""
    var status: OnlineStatus = .offline
    var isMe: Bool = false
    var isSelected: Bool = false
}

// MARK: - 原生 UIKit 标注视图

class CallsignMKAnnotationView: MKAnnotationView {
    private let containerView = UIView()
    private let callsignLabel = UILabel()
    private let dotView = UIView()
    private let arrowView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        canShowCallout = false
        clipsToBounds = false

        // 容器
        containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 2
        containerView.layer.shadowOpacity = 0.2
        containerView.clipsToBounds = false
        addSubview(containerView)

        // 状态点
        dotView.layer.cornerRadius = 4
        containerView.addSubview(dotView)

        // 呼号标签
        callsignLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        callsignLabel.textColor = .label
        containerView.addSubview(callsignLabel)

        // 箭头
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        arrowView.image = UIImage(systemName: "arrowtriangle.down.fill", withConfiguration: config)
        arrowView.tintColor = UIColor.systemBackground.withAlphaComponent(0.95)
        arrowView.contentMode = .scaleAspectFit
        addSubview(arrowView)
    }

    func configure(callsign: String, status: OnlineStatus, isMe: Bool, isSelected: Bool) {
        callsignLabel.text = callsign
        callsignLabel.sizeToFit()

        // 状态颜色
        switch status {
        case .online:
            dotView.backgroundColor = .systemGreen
        case .recent:
            dotView.backgroundColor = .systemYellow
        case .offline:
            dotView.backgroundColor = .systemGray
        }

        // 选中状态
        if isSelected {
            containerView.backgroundColor = UIColor.systemBlue
            callsignLabel.textColor = .white
            arrowView.tintColor = .systemBlue
        } else {
            containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            callsignLabel.textColor = .label
            arrowView.tintColor = UIColor.systemBackground.withAlphaComponent(0.95)
        }

        // 自己用蓝色边框
        if isMe && !isSelected {
            containerView.layer.borderWidth = 2
            containerView.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            containerView.layer.borderWidth = 0
        }

        // 布局计算
        let padding: CGFloat = 8
        let dotSize: CGFloat = 8
        let spacing: CGFloat = 4
        let arrowHeight: CGFloat = 10

        let labelSize = callsignLabel.frame.size
        let containerWidth = padding + dotSize + spacing + labelSize.width + padding
        let containerHeight = max(labelSize.height, dotSize) + padding * 2
        let totalHeight = containerHeight + arrowHeight

        // 设置 frame 大小（annotation view 的大小）
        frame = CGRect(x: 0, y: 0, width: containerWidth, height: totalHeight)

        // 容器位于顶部
        containerView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        dotView.frame = CGRect(x: padding, y: (containerHeight - dotSize) / 2, width: dotSize, height: dotSize)
        callsignLabel.frame = CGRect(x: padding + dotSize + spacing, y: (containerHeight - labelSize.height) / 2, width: labelSize.width, height: labelSize.height)

        // 箭头在容器下方居中
        arrowView.frame = CGRect(x: (containerWidth - 10) / 2, y: containerHeight, width: 10, height: arrowHeight)

        // 设置锚点偏移（使箭头尖端对准坐标点）
        centerOffset = CGPoint(x: 0, y: -totalHeight / 2)
    }
}

// MARK: - 地图标尺视图

struct MapScaleView: View {
    var region: MKCoordinateRegion

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 标尺线
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 8)
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: scaleWidth, height: 2)
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 8)
            }

            // 距离文字
            Text(scaleText)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        }
        .padding(6)
        .background(Color(.systemBackground).opacity(0.85))
        .cornerRadius(6)
    }

    private var scaleWidth: CGFloat {
        // 根据实际距离计算宽度，目标宽度 60-100 点
        let targetWidth: CGFloat = 80
        return targetWidth
    }

    private var scaleText: String {
        // 根据地图 span 计算合适的标尺距离
        let metersPerDegree: Double = 111320  // 赤道附近每度约 111km
        let latMeters = region.span.latitudeDelta * metersPerDegree
        let screenWidth: Double = 400  // 假设屏幕宽度
        let metersPerPoint = latMeters / screenWidth
        let scaleMeters = metersPerPoint * 80  // 80 点宽度对应的米数

        // 选择合适的显示单位
        if scaleMeters < 100 {
            let rounded = roundToNice(scaleMeters)
            return "\(Int(rounded))m"
        } else if scaleMeters < 1000 {
            let rounded = roundToNice(scaleMeters)
            return "\(Int(rounded))m"
        } else {
            let km = scaleMeters / 1000
            let rounded = roundToNice(km)
            if rounded < 10 {
                return String(format: "%.1fkm", rounded)
            } else {
                return "\(Int(rounded))km"
            }
        }
    }

    private func roundToNice(_ value: Double) -> Double {
        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude
        let nice: Double
        if normalized <= 1 {
            nice = 1
        } else if normalized <= 2 {
            nice = 2
        } else if normalized <= 5 {
            nice = 5
        } else {
            nice = 10
        }
        return nice * magnitude
    }
}

// MARK: - 指南针视图

struct CompassView: View {
    var heading: Double

    var body: some View {
        ZStack {
            // 背景
            Circle()
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // 指南针
            ZStack {
                // N 标记
                Text("N")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                    .offset(y: -14)

                // 指针
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 8, height: 10)
                    Triangle()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 8, height: 10)
                        .rotationEffect(.degrees(180))
                }
            }
            .rotationEffect(.degrees(-heading))
        }
    }
}

// MARK: - 用户详情弹窗

struct UserDetailSheet: View {
    var callsign: String
    var peer: PeerLocation?
    var myLocation: CLLocationCoordinate2D?
    var isFavorite: Bool
    var isShowingTrack: Bool
    var trackPointCount: Int
    var onNavigate: () -> Void
    var onToggleFavorite: () -> Void
    var onToggleTrack: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let peer = peer {
                    // 头部信息
                    HStack(spacing: 12) {
                        // 状态指示
                        Circle()
                            .fill(statusColor(peer.status))
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.callsign)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(statusText(peer.status))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 收藏按钮
                        Button(action: onToggleFavorite) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(isFavorite ? .yellow : .gray)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    // 详细信息
                    VStack(spacing: 12) {
                        if let myLoc = myLocation {
                            InfoRow(icon: "location.fill", label: "距离", value: peer.formattedDistance(to: myLoc))

                            // 方位角
                            let bearing = calculateBearing(from: myLoc, to: peer.coordinate)
                            InfoRow(icon: "location.north.fill", label: "方位", value: String(format: "%.0f°", bearing))
                        }

                        InfoRow(
                            icon: "mappin.and.ellipse",
                            label: "坐标",
                            value: String(format: "%.5f, %.5f", peer.latitude, peer.longitude)
                        )

                        InfoRow(icon: "clock", label: "更新时间", value: peer.formattedUpdateTime + " 前")

                        if let rssi = peer.rssi {
                            InfoRow(icon: "antenna.radiowaves.left.and.right", label: "RSSI", value: "\(rssi) dBm")
                        }

                        if let snr = peer.snr {
                            InfoRow(icon: "waveform", label: "SNR", value: String(format: "%.1f dB", snr))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    Spacer()

                    // 操作按钮
                    VStack(spacing: 12) {
                        // 轨迹按钮
                        Button(action: onToggleTrack) {
                            HStack {
                                Image(systemName: isShowingTrack ? "line.3.crossed.swirl.circle.fill" : "line.3.crossed.swirl.circle")
                                Text(isShowingTrack ? "隐藏轨迹" : "显示轨迹")
                                if trackPointCount > 0 {
                                    Text("(\(trackPointCount)点)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isShowingTrack ? Color.orange : Color(.secondarySystemBackground))
                            .foregroundColor(isShowingTrack ? .white : .primary)
                            .cornerRadius(12)
                        }

                        // 导航按钮
                        Button(action: onNavigate) {
                            Label("导航到此位置", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    Text("无法获取用户信息")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("用户详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func statusColor(_ status: OnlineStatus) -> Color {
        switch status {
        case .online: return .green
        case .recent: return .yellow
        case .offline: return .gray
        }
    }

    private func statusText(_ status: OnlineStatus) -> String {
        switch status {
        case .online: return "在线"
        case .recent: return "最近活跃"
        case .offline: return "离线"
        }
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi

        if bearing < 0 {
            bearing += 360
        }
        return bearing
    }
}

struct InfoRow: View {
    var icon: String
    var label: String
    var value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - iOS 15/16 兼容

struct MediumSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}

// MARK: - 位置设置视图

struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("位置分享")) {
                    Toggle("启用位置分享", isOn: $locationService.settings.locationShareEnabled)
                        .onChange(of: locationService.settings.locationShareEnabled) { newValue in
                            if newValue {
                                locationService.startLocating()
                            } else {
                                locationService.stopLocating()
                            }
                            locationService.saveSettings()
                        }
                }

                Section(header: Text("轨迹")) {
                    Toggle("本地轨迹记录", isOn: $locationService.settings.trackLocalRecordingEnabled)
                        .onChange(of: locationService.settings.trackLocalRecordingEnabled) { _ in
                            locationService.saveSettings()
                        }

                    Button("清空所有轨迹") {
                        locationService.clearAllTracks()
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("显示")) {
                    Toggle("显示距离", isOn: $locationService.settings.showDistance)
                        .onChange(of: locationService.settings.showDistance) { _ in
                            locationService.saveSettings()
                        }

                    Picker("筛选时间", selection: $locationService.settings.filterMinutes) {
                        Text("5 分钟").tag(5)
                        Text("15 分钟").tag(15)
                        Text("30 分钟").tag(30)
                        Text("1 小时").tag(60)
                        Text("全部").tag(1440)
                    }
                    .onChange(of: locationService.settings.filterMinutes) { _ in
                        locationService.saveSettings()
                    }
                }
            }
            .navigationTitle("位置设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 预览

#if DEBUG
struct LocationTabView_Previews: PreviewProvider {
    static var previews: some View {
        LocationTabView(myCallsign: "BG4QG")
    }
}
#endif
