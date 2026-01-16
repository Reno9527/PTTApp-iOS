//
//  LocationModels.swift
//  PTT 互联
//
//  Created by 刘光辉 (BG4QG) on 2024.
//  Copyright © 2024-2026 刘光辉. All rights reserved.
//

import Foundation
import CoreLocation

// MARK: - 在线状态

/// 在线状态枚举
enum OnlineStatus: Equatable {
    case online      // 0~30s 绿色
    case recent      // 30s~2min 黄色
    case offline     // >2min 灰色
    
    /// 根据最后更新时间计算状态
    static func from(lastHeardAt: Date) -> OnlineStatus {
        let elapsed = Date().timeIntervalSince(lastHeardAt)
        if elapsed <= 30 {
            return .online
        } else if elapsed <= 120 {
            return .recent
        } else {
            return .offline
        }
    }
    
    /// 状态颜色名称
    var colorName: String {
        switch self {
        case .online: return "green"
        case .recent: return "yellow"
        case .offline: return "gray"
        }
    }
}

// MARK: - 用户位置信息

/// 用户位置信息（在线表）
struct PeerLocation: Identifiable, Equatable {
    let id: String  // callsign 作为 ID
    var callsign: String
    var latitude: Double
    var longitude: Double
    var updatedAt: Date
    var lastHeardAt: Date
    var rssi: Int?
    var snr: Double?
    
    /// 在线状态
    var status: OnlineStatus {
        OnlineStatus.from(lastHeardAt: lastHeardAt)
    }
    
    /// CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 计算与另一个位置的距离（米）
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
    
    /// 格式化距离显示
    func formattedDistance(to other: CLLocationCoordinate2D) -> String {
        let dist = distance(to: other)
        if dist < 1000 {
            return String(format: "%.0fm", dist)
        } else {
            return String(format: "%.1fkm", dist / 1000)
        }
    }
    
    /// 格式化更新时间显示
    var formattedUpdateTime: String {
        let elapsed = Int(Date().timeIntervalSince(lastHeardAt))
        if elapsed < 60 {
            return "\(elapsed)s"
        } else if elapsed < 3600 {
            return "\(elapsed / 60)m"
        } else {
            return "\(elapsed / 3600)h"
        }
    }
}

// MARK: - 轨迹点

/// 轨迹点
struct TrackPoint: Equatable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 环形缓冲区

/// 环形缓冲区（用于存储轨迹点）
class RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private var count = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }
    
    func toArray() -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        
        if count < capacity {
            // 未满，从头开始
            for i in 0..<count {
                if let element = buffer[i] {
                    result.append(element)
                }
            }
        } else {
            // 已满，从 writeIndex 开始（最旧的）
            for i in 0..<capacity {
                let index = (writeIndex + i) % capacity
                if let element = buffer[index] {
                    result.append(element)
                }
            }
        }
        return result
    }
    
    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }
    var currentCount: Int { count }
    
    func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
    
    /// 获取最后一个元素
    var last: T? {
        guard count > 0 else { return nil }
        let lastIndex = (writeIndex - 1 + capacity) % capacity
        return buffer[lastIndex]
    }
}

// MARK: - 轨迹管理

/// 用户轨迹
class UserTrack {
    let callsign: String
    private let buffer: RingBuffer<TrackPoint>
    private let distanceThreshold: Double = 10.0  // 10米阈值
    private let timeThreshold: TimeInterval = 5.0  // 5秒阈值
    
    init(callsign: String, maxPoints: Int = 2000) {
        self.callsign = callsign
        self.buffer = RingBuffer<TrackPoint>(capacity: maxPoints)
    }
    
    /// 添加轨迹点（带采样过滤）
    func addPoint(latitude: Double, longitude: Double, timestamp: Date) {
        let newPoint = TrackPoint(latitude: latitude, longitude: longitude, timestamp: timestamp)
        
        // 检查是否需要记录
        if let lastPoint = buffer.last {
            let distance = CLLocation(latitude: latitude, longitude: longitude)
                .distance(from: CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude))
            let timeDiff = timestamp.timeIntervalSince(lastPoint.timestamp)
            
            // 距离超过阈值 或 时间超过阈值 才记录
            if distance > distanceThreshold || timeDiff > timeThreshold {
                buffer.append(newPoint)
            }
        } else {
            // 第一个点直接记录
            buffer.append(newPoint)
        }
    }
    
    /// 获取所有轨迹点
    var points: [TrackPoint] {
        buffer.toArray()
    }
    
    /// 获取指定时间范围内的轨迹点
    func points(within minutes: Int) -> [TrackPoint] {
        let cutoff = Date().addingTimeInterval(-Double(minutes * 60))
        return points.filter { $0.timestamp >= cutoff }
    }
    
    /// 清空轨迹
    func clear() {
        buffer.clear()
    }
    
    var isEmpty: Bool {
        buffer.isEmpty
    }
    
    var pointCount: Int {
        buffer.currentCount
    }
}

// MARK: - 坐标转换 (WGS-84 ↔ GCJ-02)

/// 坐标转换工具（中国地图偏移修正）
struct CoordinateTransformer {
    // 椭球参数
    private static let a: Double = 6378245.0  // 长半轴
    private static let ee: Double = 0.00669342162296594323  // 偏心率平方

    /// 判断是否在中国境内（粗略）
    static func isInChina(latitude: Double, longitude: Double) -> Bool {
        return longitude >= 72.004 && longitude <= 137.8347 &&
               latitude >= 0.8293 && latitude <= 55.8271
    }

    /// WGS-84 → GCJ-02 (GPS坐标转火星坐标)
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> (lat: Double, lng: Double) {
        if !isInChina(latitude: latitude, longitude: longitude) {
            return (latitude, longitude)
        }

        var dLat = transformLat(x: longitude - 105.0, y: latitude - 35.0)
        var dLng = transformLng(x: longitude - 105.0, y: latitude - 35.0)

        let radLat = latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)

        let gcjLat = latitude + dLat
        let gcjLng = longitude + dLng

        return (gcjLat, gcjLng)
    }

    /// GCJ-02 → WGS-84 (火星坐标转GPS坐标，迭代法)
    static func gcj02ToWgs84(latitude: Double, longitude: Double) -> (lat: Double, lng: Double) {
        if !isInChina(latitude: latitude, longitude: longitude) {
            return (latitude, longitude)
        }

        let gcj = wgs84ToGcj02(latitude: latitude, longitude: longitude)
        let dLat = gcj.lat - latitude
        let dLng = gcj.lng - longitude

        return (latitude - dLat, longitude - dLng)
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLng(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}

/// CLLocationCoordinate2D 扩展
extension CLLocationCoordinate2D {
    /// 转换为 GCJ-02 坐标（用于中国地图显示）
    var gcj02: CLLocationCoordinate2D {
        let result = CoordinateTransformer.wgs84ToGcj02(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng)
    }

    /// 从 GCJ-02 转换为 WGS-84（实际 GPS 坐标）
    var wgs84: CLLocationCoordinate2D {
        let result = CoordinateTransformer.gcj02ToWgs84(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2D(latitude: result.lat, longitude: result.lng)
    }
}

// MARK: - 位置设置

/// 位置相关设置
struct LocationSettings {
    var locationShareEnabled: Bool = true
    var trackLocalRecordingEnabled: Bool = true
    var trackUploadEnabled: Bool = false  // 预留
    var mapType: MapDisplayType = .standard
    var showDistance: Bool = true
    var filterMinutes: Int = 5  // 仅显示最近 N 分钟活跃
}

/// 地图显示类型
enum MapDisplayType: String, CaseIterable {
    case standard = "standard"
    case satellite = "satellite"
    case terrain = "terrain"
    
    var displayName: String {
        switch self {
        case .standard: return "标准"
        case .satellite: return "卫星"
        case .terrain: return "地形"
        }
    }
    
    var iconName: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.asia.australia"
        case .terrain: return "mountain.2"
        }
    }
}

// MARK: - 轨迹回放状态

/// 轨迹回放状态
enum TrackPlaybackState {
    case stopped
    case playing
    case paused
}

/// 轨迹回放控制
class TrackPlaybackController: ObservableObject {
    @Published var state: TrackPlaybackState = .stopped
    @Published var currentIndex: Int = 0
    @Published var followMode: Bool = true
    @Published var playbackSpeed: Double = 1.0  // 1x, 2x, 4x
    
    var track: UserTrack?
    var displayMinutes: Int = 30
    
    private var timer: Timer?
    
    func play() {
        guard let track = track else { return }
        let points = track.points(within: displayMinutes)
        guard !points.isEmpty else { return }
        
        state = .playing
        startTimer()
    }
    
    func pause() {
        state = .paused
        stopTimer()
    }
    
    func stop() {
        state = .stopped
        currentIndex = 0
        stopTimer()
    }
    
    func seekTo(index: Int) {
        guard let track = track else { return }
        let points = track.points(within: displayMinutes)
        currentIndex = min(max(0, index), points.count - 1)
    }
    
    private func startTimer() {
        stopTimer()
        let interval = 1.0 / playbackSpeed
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard let track = track else { return }
        let points = track.points(within: displayMinutes)
        
        if currentIndex < points.count - 1 {
            currentIndex += 1
        } else {
            stop()
        }
    }
}
