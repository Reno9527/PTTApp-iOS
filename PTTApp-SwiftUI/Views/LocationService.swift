//
//  LocationService.swift
//  PTT 互联
//
//  Created by 刘光辉 (BG4QG) on 2024.
//  Copyright © 2024-2026 刘光辉. All rights reserved.
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - 位置服务

/// 位置服务管理器（使用苹果 CoreLocation）
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // MARK: - Published 属性

    /// 自己的当前位置
    @Published var myLocation: CLLocationCoordinate2D?

    /// 其他用户位置表
    @Published var peers: [String: PeerLocation] = [:]

    /// 位置设置
    @Published var settings = LocationSettings()

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 是否正在定位
    @Published var isLocating: Bool = false

    /// 后台保活增强模式（使用定位服务保持后台运行）
    @Published var backgroundKeepAliveEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(backgroundKeepAliveEnabled, forKey: "background_keepalive_enabled")
            updateBackgroundLocationMode()
        }
    }

    /// 是否有"始终"定位权限
    var hasAlwaysAuthorization: Bool {
        return authorizationStatus == .authorizedAlways
    }

    // MARK: - 轨迹存储

    /// 所有用户的轨迹
    private var tracks: [String: UserTrack] = [:]

    // MARK: - 定位管理器

    private var locationManager: CLLocationManager?

    // MARK: - 位置共享

    /// 位置发送回调 (latitude, longitude) - 用于发送位置消息 (type=5, [loc]lat,lon)
    var onSendLocation: ((Double, Double) -> Void)?

    /// 位置发送定时器
    private var locationSendTimer: Timer?

    // MARK: - 初始化

    private override init() {
        super.init()
        setupLocationManager()
        loadSettings()
    }

    // MARK: - 定位配置

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10  // 10米更新一次
        locationManager?.pausesLocationUpdatesAutomatically = false

        // 获取当前授权状态
        authorizationStatus = locationManager?.authorizationStatus ?? .notDetermined

        // 加载后台保活设置
        backgroundKeepAliveEnabled = UserDefaults.standard.bool(forKey: "background_keepalive_enabled")
        updateBackgroundLocationMode()
    }

    /// 更新后台定位模式
    private func updateBackgroundLocationMode() {
        if backgroundKeepAliveEnabled && hasAlwaysAuthorization {
            // 启用后台定位
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.showsBackgroundLocationIndicator = false  // 不显示蓝条
            print("[LocationService] 后台定位已启用")
        } else {
            // 禁用后台定位
            locationManager?.allowsBackgroundLocationUpdates = false
            print("[LocationService] 后台定位已禁用")
        }
    }

    // MARK: - 定位控制

    /// 请求定位权限（前台使用）
    func requestAuthorization() {
        locationManager?.requestWhenInUseAuthorization()
    }

    /// 请求"始终"定位权限（后台保活需要）
    func requestAlwaysAuthorization() {
        locationManager?.requestAlwaysAuthorization()
    }

    /// 启用后台保活（用户打开开关时调用）
    /// - Returns: 是否成功启用（如果需要请求权限则返回 false）
    @discardableResult
    func enableBackgroundKeepAlive() -> Bool {
        if hasAlwaysAuthorization {
            // 已有权限，直接启用
            backgroundKeepAliveEnabled = true
            if settings.locationShareEnabled {
                startLocating()
            }
            return true
        } else if authorizationStatus == .authorizedWhenInUse {
            // 有前台权限，请求升级到"始终"
            requestAlwaysAuthorization()
            return false  // 等待用户授权
        } else {
            // 没有权限，先请求
            requestAlwaysAuthorization()
            return false
        }
    }

    /// 禁用后台保活
    func disableBackgroundKeepAlive() {
        backgroundKeepAliveEnabled = false
    }

    /// 开始定位
    func startLocating() {
        guard settings.locationShareEnabled else { return }

        isLocating = true
        locationManager?.startUpdatingLocation()
        // 通过文本消息 (type=5) 发送位置 (格式: [loc]lat,lon)
        startLocationSendTimer()
    }

    /// 停止定位
    func stopLocating() {
        isLocating = false
        locationManager?.stopUpdatingLocation()
        stopLocationSendTimer()
    }

    /// 启动位置发送定时器 (每 3 秒发送一次)
    private func startLocationSendTimer() {
        stopLocationSendTimer()

        print("[LocationService] Starting location send timer (3s interval)")

        locationSendTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.settings.locationShareEnabled else {
                print("[LocationService] Location share disabled")
                return
            }
            guard let myLoc = self.myLocation else {
                print("[LocationService] No location available")
                return
            }

            if self.onSendLocation != nil {
                print("[LocationService] Sending location: \(myLoc.latitude), \(myLoc.longitude)")
                self.onSendLocation?(myLoc.latitude, myLoc.longitude)
            } else {
                print("[LocationService] onSendLocation callback not set")
            }
        }
    }

    /// 停止位置发送定时器
    private func stopLocationSendTimer() {
        locationSendTimer?.invalidate()
        locationSendTimer = nil
    }

    /// 单次定位
    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        locationManager?.requestLocation()
        // 注意：结果会通过 delegate 回调
    }

    // MARK: - Peers 管理

    /// 更新用户位置（收到心跳包时调用）
    func updatePeer(callsign: String, latitude: Double, longitude: Double, rssi: Int? = nil, snr: Double? = nil) {
        let now = Date()

        if var peer = peers[callsign] {
            // 更新现有用户
            peer.latitude = latitude
            peer.longitude = longitude
            peer.updatedAt = now
            peer.lastHeardAt = now
            peer.rssi = rssi
            peer.snr = snr
            peers[callsign] = peer
        } else {
            // 新用户
            let peer = PeerLocation(
                id: callsign,
                callsign: callsign,
                latitude: latitude,
                longitude: longitude,
                updatedAt: now,
                lastHeardAt: now,
                rssi: rssi,
                snr: snr
            )
            peers[callsign] = peer
        }

        // 记录轨迹
        if settings.trackLocalRecordingEnabled {
            addTrackPoint(callsign: callsign, latitude: latitude, longitude: longitude, timestamp: now)
        }
    }

    /// 移除用户
    func removePeer(callsign: String) {
        peers.removeValue(forKey: callsign)
    }

    /// 清空所有用户
    func clearPeers() {
        peers.removeAll()
    }

    /// 获取排序后的用户列表
    func sortedPeers(myCallsign: String?) -> [PeerLocation] {
        var result = Array(peers.values)

        result.sort { a, b in
            // 自己置顶
            if let my = myCallsign {
                if a.callsign == my { return true }
                if b.callsign == my { return false }
            }

            let statusA = a.status
            let statusB = b.status

            // 在线状态优先级
            let priorityA = statusPriority(statusA)
            let priorityB = statusPriority(statusB)

            if priorityA != priorityB {
                return priorityA < priorityB
            }

            // 同状态
            if statusA == .offline && statusB == .offline {
                return a.lastHeardAt > b.lastHeardAt
            } else {
                if let myLoc = myLocation {
                    return a.distance(to: myLoc) < b.distance(to: myLoc)
                }
                return a.lastHeardAt > b.lastHeardAt
            }
        }

        return result
    }

    private func statusPriority(_ status: OnlineStatus) -> Int {
        switch status {
        case .online: return 0
        case .recent: return 1
        case .offline: return 2
        }
    }

    /// 根据筛选条件过滤用户
    func filteredPeers(myCallsign: String?, searchText: String = "", favoritesOnly: Bool = false, favorites: Set<String> = []) -> [PeerLocation] {
        var result = sortedPeers(myCallsign: myCallsign)

        // 时间筛选
        let cutoff = Date().addingTimeInterval(-Double(settings.filterMinutes * 60))
        result = result.filter { $0.lastHeardAt >= cutoff || $0.callsign == myCallsign }

        // 搜索筛选
        if !searchText.isEmpty {
            result = result.filter { $0.callsign.localizedCaseInsensitiveContains(searchText) }
        }

        // 收藏筛选
        if favoritesOnly {
            result = result.filter { favorites.contains($0.callsign) || $0.callsign == myCallsign }
        }

        return result
    }

    // MARK: - 轨迹管理

    /// 添加轨迹点
    private func addTrackPoint(callsign: String, latitude: Double, longitude: Double, timestamp: Date) {
        if tracks[callsign] == nil {
            tracks[callsign] = UserTrack(callsign: callsign)
        }
        tracks[callsign]?.addPoint(latitude: latitude, longitude: longitude, timestamp: timestamp)
    }

    /// 获取用户轨迹
    func getTrack(callsign: String) -> UserTrack? {
        return tracks[callsign]
    }

    /// 清空用户轨迹
    func clearTrack(callsign: String) {
        tracks[callsign]?.clear()
    }

    /// 清空所有轨迹
    func clearAllTracks() {
        tracks.values.forEach { $0.clear() }
    }

    // MARK: - 设置管理

    private func loadSettings() {
        let defaults = UserDefaults.standard
        settings.locationShareEnabled = defaults.bool(forKey: "location_share_enabled", default: true)
        settings.trackLocalRecordingEnabled = defaults.bool(forKey: "track_local_recording", default: true)
        settings.showDistance = defaults.bool(forKey: "location_show_distance", default: true)
        settings.filterMinutes = defaults.integer(forKey: "location_filter_minutes", default: 5)

        if let mapTypeRaw = defaults.string(forKey: "location_map_type"),
           let mapType = MapDisplayType(rawValue: mapTypeRaw) {
            settings.mapType = mapType
        }
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(settings.locationShareEnabled, forKey: "location_share_enabled")
        defaults.set(settings.trackLocalRecordingEnabled, forKey: "track_local_recording")
        defaults.set(settings.showDistance, forKey: "location_show_distance")
        defaults.set(settings.filterMinutes, forKey: "location_filter_minutes")
        defaults.set(settings.mapType.rawValue, forKey: "location_map_type")
    }

    // MARK: - 导航

    /// 打开苹果地图导航到指定位置
    func navigateTo(coordinate: CLLocationCoordinate2D, name: String) {
        let appleMapUrl = "http://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d"
        if let url = URL(string: appleMapUrl) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // 转换为 GCJ-02 坐标（中国地图偏移修正）
            myLocation = location.coordinate.gcj02
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus

        print("[LocationService] 授权状态变化: \(oldStatus.rawValue) -> \(authorizationStatus.rawValue)")

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // 如果用户授权了"始终"，且开关是开的，启用后台定位
            if authorizationStatus == .authorizedAlways && backgroundKeepAliveEnabled {
                updateBackgroundLocationMode()
                print("[LocationService] 已获得始终权限，后台保活已启用")
            }
            startLocating()
        }

        // 如果用户拒绝了"始终"权限，但开关是开的，需要关闭开关
        if backgroundKeepAliveEnabled && authorizationStatus != .authorizedAlways {
            // 如果从"始终"降级到其他状态，关闭后台保活
            if oldStatus == .authorizedAlways {
                backgroundKeepAliveEnabled = false
                print("[LocationService] 始终权限被撤销，后台保活已禁用")
            }
        }
    }
}

// MARK: - UserDefaults 扩展

extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return bool(forKey: key)
    }

    func integer(forKey key: String, default defaultValue: Int) -> Int {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return integer(forKey: key)
    }
}
