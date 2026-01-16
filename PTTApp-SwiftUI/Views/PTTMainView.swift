import SwiftUI
import AVFoundation
import PTTInfra

// MARK: - PTT 效果模板系统

/// PTT 效果类型枚举
enum PTTEffectType: String, CaseIterable, Identifiable {
    case ripple = "ripple"
    case dotMatrix = "dotMatrix"
    case spectrum = "spectrum"
    case particle = "particle"
    case glowPulse = "glowPulse"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ripple: return "水波扩散"
        case .dotMatrix: return "点阵波纹"
        case .spectrum: return "频谱柱状"
        case .particle: return "发光粒子"
        case .glowPulse: return "呼吸光环"
        }
    }

    var icon: String {
        switch self {
        case .ripple: return "drop.circle"
        case .dotMatrix: return "circle.grid.3x3"
        case .spectrum: return "chart.bar"
        case .particle: return "sparkles"
        case .glowPulse: return "circle.circle"
        }
    }

    /// 从 UserDefaults 获取当前选择的效果
    static var current: PTTEffectType {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ptt_effect_type"),
               let type = PTTEffectType(rawValue: raw) {
                return type
            }
            return .ripple  // 默认水波扩散
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ptt_effect_type")
        }
    }
}

// MARK: - 频谱样式系统

/// 接收频谱样式枚举
enum SpectrumStyle: String, CaseIterable, Identifiable {
    case classic = "classic"           // 经典5条
    case standard = "standard"         // 标准频谱
    case textTop = "textTop"           // 文字在上
    case symmetric = "symmetric"       // 对称频谱
    case wideBar = "wideBar"           // 宽条频谱
    case compact = "compact"           // 紧凑模式

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "经典模式"
        case .standard: return "标准频谱"
        case .textTop: return "上文下频"
        case .symmetric: return "对称频谱"
        case .wideBar: return "宽条模式"
        case .compact: return "紧凑模式"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "waveform"
        case .standard: return "chart.bar.fill"
        case .textTop: return "rectangle.split.2x1"
        case .symmetric: return "arrow.left.and.right"
        case .wideBar: return "rectangle.3.group"
        case .compact: return "text.alignleft"
        }
    }

    var description: String {
        switch self {
        case .classic: return "简洁的5条动态波形"
        case .standard: return "15条渐变色频谱"
        case .textTop: return "呼号在上，长频谱在下"
        case .symmetric: return "左右对称频谱，呼号居中"
        case .wideBar: return "8条宽频谱条"
        case .compact: return "单行紧凑频谱"
        }
    }

    /// 从 UserDefaults 获取当前选择的样式
    static var current: SpectrumStyle {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ptt_spectrum_style"),
               let style = SpectrumStyle(rawValue: raw) {
                return style
            }
            return .symmetric  // 默认对称频谱
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ptt_spectrum_style")
        }
    }
}

// MARK: - 会议模式主题系统

/// 会议模式 UI 主题枚举
enum ConferenceUITheme: String, CaseIterable, Identifiable {
    case radio = "radio"           // 无线电风格 (默认)
    case modern = "modern"         // 现代简约
    case military = "military"     // 军事风格
    case retro = "retro"           // 复古风格

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .radio: return "无线电风格"
        case .modern: return "现代简约"
        case .military: return "军事风格"
        case .retro: return "复古风格"
        }
    }

    var icon: String {
        switch self {
        case .radio: return "antenna.radiowaves.left.and.right"
        case .modern: return "sparkles.rectangle.stack"
        case .military: return "shield.checkered"
        case .retro: return "dial.low"
        }
    }

    var description: String {
        switch self {
        case .radio: return "经典无线电台设计，深蓝黑底色"
        case .modern: return "简洁现代风格，暗色主题"
        case .military: return "军事通信风格，橄榄绿配色"
        case .retro: return "复古怀旧风格，琥珀色调"
        }
    }

    /// 从 UserDefaults 获取当前选择的主题
    static var current: ConferenceUITheme {
        get {
            if let raw = UserDefaults.standard.string(forKey: "conference_ui_theme"),
               let theme = ConferenceUITheme(rawValue: raw) {
                return theme
            }
            return .radio  // 默认无线电风格
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "conference_ui_theme")
        }
    }
}

/// 会议模式主题配色方案
struct ConferenceThemeColors {
    let background: Color
    let cardBackground: Color
    let txColor: Color          // 发射红
    let rxColor: Color          // 接收绿
    let meColor: Color          // 自己蓝
    let offlineColor: Color     // 离线灰
    let primaryText: Color
    let secondaryText: Color
    let sMeterLow: Color        // S-Meter 低
    let sMeterMid: Color        // S-Meter 中
    let sMeterHigh: Color       // S-Meter 高
    let pttButtonGradient: [Color]
    let pttButtonActiveGradient: [Color]
    let accentColor: Color

    static func colors(for theme: ConferenceUITheme) -> ConferenceThemeColors {
        switch theme {
        case .radio:
            return ConferenceThemeColors(
                background: Color(hex: "1A1A2E"),
                cardBackground: Color(hex: "16213E"),
                txColor: Color(hex: "FF3B30"),
                rxColor: Color(hex: "30D158"),
                meColor: Color(hex: "007AFF"),
                offlineColor: Color(hex: "6B7280"),
                primaryText: .white,
                secondaryText: Color(hex: "9CA3AF"),
                sMeterLow: Color(hex: "30D158"),
                sMeterMid: Color(hex: "FFCC00"),
                sMeterHigh: Color(hex: "FF3B30"),
                pttButtonGradient: [Color(hex: "3B3B4F"), Color(hex: "1F1F2E")],
                pttButtonActiveGradient: [Color(hex: "FF3B30"), Color(hex: "CC2F26")],
                accentColor: Color(hex: "00D4FF")
            )
        case .modern:
            return ConferenceThemeColors(
                background: Color(hex: "0F0F0F"),
                cardBackground: Color(hex: "1C1C1E"),
                txColor: Color(hex: "FF453A"),
                rxColor: Color(hex: "32D74B"),
                meColor: Color(hex: "0A84FF"),
                offlineColor: Color(hex: "48484A"),
                primaryText: .white,
                secondaryText: Color(hex: "8E8E93"),
                sMeterLow: Color(hex: "32D74B"),
                sMeterMid: Color(hex: "FFD60A"),
                sMeterHigh: Color(hex: "FF453A"),
                pttButtonGradient: [Color(hex: "2C2C2E"), Color(hex: "1C1C1E")],
                pttButtonActiveGradient: [Color(hex: "FF453A"), Color(hex: "D93632")],
                accentColor: Color(hex: "BF5AF2")
            )
        case .military:
            return ConferenceThemeColors(
                background: Color(hex: "1A1F16"),
                cardBackground: Color(hex: "252B1F"),
                txColor: Color(hex: "FF6B35"),
                rxColor: Color(hex: "7CB342"),
                meColor: Color(hex: "42A5F5"),
                offlineColor: Color(hex: "5D6352"),
                primaryText: Color(hex: "E8E8D0"),
                secondaryText: Color(hex: "9E9E80"),
                sMeterLow: Color(hex: "7CB342"),
                sMeterMid: Color(hex: "FDD835"),
                sMeterHigh: Color(hex: "FF6B35"),
                pttButtonGradient: [Color(hex: "4A5240"), Color(hex: "2D3327")],
                pttButtonActiveGradient: [Color(hex: "FF6B35"), Color(hex: "D4572C")],
                accentColor: Color(hex: "8BC34A")
            )
        case .retro:
            return ConferenceThemeColors(
                background: Color(hex: "1A1510"),
                cardBackground: Color(hex: "2A2318"),
                txColor: Color(hex: "FF8C00"),
                rxColor: Color(hex: "FFB347"),
                meColor: Color(hex: "87CEEB"),
                offlineColor: Color(hex: "5C5040"),
                primaryText: Color(hex: "FFD700"),
                secondaryText: Color(hex: "D4A574"),
                sMeterLow: Color(hex: "FFB347"),
                sMeterMid: Color(hex: "FFA500"),
                sMeterHigh: Color(hex: "FF4500"),
                pttButtonGradient: [Color(hex: "4A4030"), Color(hex: "2A2318")],
                pttButtonActiveGradient: [Color(hex: "FF8C00"), Color(hex: "CC7000")],
                accentColor: Color(hex: "FFD700")
            )
        }
    }
}

/// Color 扩展：支持 hex 颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 会议模式 UI 组件

/// LED 状态枚举
enum LEDStatus {
    case tx      // 发射 - 红色闪烁
    case rx      // 接收 - 绿色常亮
    case me      // 自己 - 蓝色常亮
    case off     // 离线 - 灰色

    func color(theme: ConferenceThemeColors) -> Color {
        switch self {
        case .tx: return theme.txColor
        case .rx: return theme.rxColor
        case .me: return theme.meColor
        case .off: return theme.offlineColor
        }
    }

    var shouldBlink: Bool {
        self == .tx
    }
}

/// LED 指示灯视图
struct LEDIndicatorView: View {
    let status: LEDStatus
    let size: CGFloat
    let theme: ConferenceThemeColors

    @State private var isBlinking = false

    var body: some View {
        ZStack {
            // 外圈光晕
            Circle()
                .fill(status.color(theme: theme).opacity(status == .off ? 0 : 0.3))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: size * 0.3)

            // LED 主体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            status.color(theme: theme).opacity(status.shouldBlink && isBlinking ? 1.0 : (status == .off ? 0.3 : 0.9)),
                            status.color(theme: theme).opacity(status.shouldBlink && isBlinking ? 0.8 : (status == .off ? 0.1 : 0.6))
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // 高光点
            Circle()
                .fill(Color.white.opacity(status == .off ? 0.1 : 0.6))
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.15, y: -size * 0.15)
        }
        .onAppear {
            if status.shouldBlink {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
        }
        .onChange(of: status) { newStatus in
            if newStatus.shouldBlink {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            } else {
                isBlinking = false
            }
        }
    }
}

/// S-Meter 信号强度表视图
struct SMeterView: View {
    let level: Float      // 0.0 ~ 1.0
    let theme: ConferenceThemeColors
    let barCount: Int = 15

    var body: some View {
        VStack(spacing: 4) {
            // S-Meter 标签
            HStack {
                Text("S")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.primaryText)
                Spacer()
                // 数值显示
                Text(sMeterValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
            }

            // 信号条
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let threshold = Float(index) / Float(barCount)
                    let isActive = level > threshold

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isActive ? barColor(for: index) : theme.offlineColor.opacity(0.3))
                        .frame(width: 8, height: isActive ? 16 + CGFloat(index) * 0.5 : 12)
                        .animation(.easeOut(duration: 0.1), value: level)
                }
            }

            // 刻度标签
            HStack {
                Text("1")
                Spacer()
                Text("5")
                Spacer()
                Text("9")
                Spacer()
                Text("+20")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.cardBackground.opacity(0.5))
        .cornerRadius(8)
    }

    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / Float(barCount)
        if ratio < 0.4 {
            return theme.sMeterLow
        } else if ratio < 0.7 {
            return theme.sMeterMid
        } else {
            return theme.sMeterHigh
        }
    }

    private var currentColor: Color {
        if level < 0.4 {
            return theme.sMeterLow
        } else if level < 0.7 {
            return theme.sMeterMid
        } else {
            return theme.sMeterHigh
        }
    }

    private var sMeterValue: String {
        let sValue = Int(level * 9) + 1
        if sValue <= 9 {
            return "S\(sValue)"
        } else {
            let db = (sValue - 9) * 10
            return "S9+\(db)"
        }
    }
}

/// 会议成员卡片视图
struct ConferenceMemberCard: View {
    let callsign: String
    let status: LEDStatus
    let isSpeaking: Bool
    let theme: ConferenceThemeColors

    var body: some View {
        VStack(spacing: 6) {
            // LED 指示灯
            LEDIndicatorView(status: status, size: 12, theme: theme)

            // 头像 (呼号前缀)
            ZStack {
                Circle()
                    .fill(theme.cardBackground)
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(status.color(theme: theme), lineWidth: isSpeaking ? 3 : 1)
                    .frame(width: 44, height: 44)

                Text(avatarPrefix)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.primaryText)
            }
            .scaleEffect(isSpeaking ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isSpeaking)

            // 呼号
            Text(callsign)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            // 状态文字
            Text(statusText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(status.color(theme: theme))
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: status == .tx ? theme.txColor.opacity(0.5) : .clear, radius: 8)
        )
    }

    private var avatarPrefix: String {
        // 提取呼号前缀 (如 BG4QG-106 → BG4)
        let base = callsign.components(separatedBy: "-").first ?? callsign
        return String(base.prefix(3)).uppercased()
    }

    private var statusText: String {
        switch status {
        case .tx: return "TX"
        case .rx: return "RX"
        case .me: return "ME"
        case .off: return "OFF"
        }
    }
}

/// 会议成员列表横向滚动视图
struct ConferenceMemberListView: View {
    let devices: [PttDevice]
    let currentSpeaker: String?
    let myCallsign: String
    let theme: ConferenceThemeColors

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 只显示在线设备，使用 id 作为唯一标识（支持同呼号不同SSID）
                ForEach(onlineDevices, id: \.id) { device in
                    let fullCallsign = "\(device.callsign)-\(device.ssid)"
                    let isMe = fullCallsign == myCallsign
                    let isSpeaking = currentSpeaker == fullCallsign
                    let status = memberStatus(device: device, isMe: isMe, isSpeaking: isSpeaking)

                    ConferenceMemberCard(
                        callsign: fullCallsign,
                        status: status,
                        isSpeaking: isSpeaking,
                        theme: theme
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// 只显示在线设备，按说话者 > 自己 > 呼号排序
    private var onlineDevices: [PttDevice] {
        devices
            .filter { $0.isOnline }
            .sorted { d1, d2 in
                let c1 = "\(d1.callsign)-\(d1.ssid)"
                let c2 = "\(d2.callsign)-\(d2.ssid)"

                // 说话者优先
                if c1 == currentSpeaker { return true }
                if c2 == currentSpeaker { return false }

                // 自己次之
                if c1 == myCallsign { return true }
                if c2 == myCallsign { return false }

                // 按呼号排序
                return c1 < c2
            }
    }

    private func memberStatus(device: PttDevice, isMe: Bool, isSpeaking: Bool) -> LEDStatus {
        if isSpeaking { return .tx }
        if isMe { return .me }
        return .rx  // 在线设备都显示 RX 状态
    }
}

// MARK: - 全屏沉浸式会议模式

/// 动态粒子背景
struct ConferenceParticleBackground: View {
    @State private var animationTrigger = false
    @State private var particleTimer: Timer?
    let particleCount = 40

    // 使用固定的粒子位置偏移来模拟动画
    @State private var yOffsets: [CGFloat] = []

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // 深色渐变背景
                LinearGradient(
                    colors: [
                        Color(hex: "0D0D1A"),
                        Color(hex: "1A1A2E"),
                        Color(hex: "16213E"),
                        Color(hex: "0D0D1A")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 粒子层
                ForEach(0..<particleCount, id: \.self) { i in
                    let baseX = CGFloat(i % 10) / 10.0 * size.width + CGFloat.random(in: -20...20)
                    let baseY = CGFloat(i / 10) / 4.0 * size.height
                    let particleSize = CGFloat(2 + (i % 4))
                    let opacity = 0.15 + Double(i % 5) * 0.08

                    Circle()
                        .fill(Color(hex: "00D4FF").opacity(opacity))
                        .frame(width: particleSize, height: particleSize)
                        .blur(radius: particleSize / 3)
                        .position(
                            x: baseX,
                            y: yOffsets.indices.contains(i)
                                ? (baseY + yOffsets[i]).truncatingRemainder(dividingBy: size.height + 20) - 10
                                : baseY
                        )
                }
            }
            .onAppear {
                initOffsets()
                startAnimation(height: size.height)
            }
            .onDisappear {
                particleTimer?.invalidate()
                particleTimer = nil
            }
        }
        .ignoresSafeArea()
    }

    private func initOffsets() {
        yOffsets = (0..<particleCount).map { _ in CGFloat.random(in: 0...100) }
    }

    private func startAnimation(height: CGFloat) {
        particleTimer?.invalidate()
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in yOffsets.indices {
                let speed = CGFloat(1 + (i % 3))
                yOffsets[i] -= speed
                if yOffsets[i] < -height {
                    yOffsets[i] = 100
                }
            }
        }
    }
}

/// 圆形音频波纹效果
struct ConferenceAudioWaveView: View {
    let isActive: Bool
    let color: Color
    @State private var wave1: CGFloat = 1
    @State private var wave2: CGFloat = 1
    @State private var wave3: CGFloat = 1
    @State private var opacity1: Double = 0.8
    @State private var opacity2: Double = 0.8
    @State private var opacity3: Double = 0.8

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .scaleEffect(wave1)
                    .opacity(opacity1)

                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(wave2)
                    .opacity(opacity2)

                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(wave3)
                    .opacity(opacity3)
            }
        }
        .onAppear {
            if isActive { startWaves() }
        }
        .onChange(of: isActive) { active in
            if active {
                resetWaves()
                startWaves()
            } else {
                resetWaves()
            }
        }
    }

    private func resetWaves() {
        wave1 = 1; wave2 = 1; wave3 = 1
        opacity1 = 0.8; opacity2 = 0.8; opacity3 = 0.8
    }

    private func startWaves() {
        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
            wave1 = 2.5
            opacity1 = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                wave2 = 2.2
                opacity2 = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                wave3 = 1.8
                opacity3 = 0
            }
        }
    }
}

/// 霓虹大圆形PTT按钮（带环形音量指示）
struct ConferenceNeonPTTButton: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var isPressed = false
    @State private var glowPulse = false
    @State private var rotation: Double = 0

    private let buttonSize: CGFloat = 180
    private let ringSize: CGFloat = 240  // 音量环尺寸
    private let activeColor = Color(hex: "FF3B30")
    private let idleColor = Color(hex: "00D4FF")

    var body: some View {
        let isTalking = viewModel.isTalking
        let isReceiving = viewModel.currentSpeaker != nil
        let currentColor = isTalking ? activeColor : idleColor

        ZStack {
            // 最外层：环形音量指示
            ConferenceVolumeRing(
                level: viewModel.volumeLevel,
                isActive: isTalking || isReceiving,
                size: ringSize
            )

            // 外层旋转光环
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            currentColor.opacity(0),
                            currentColor.opacity(0.3),
                            currentColor.opacity(0.6),
                            currentColor.opacity(0.3),
                            currentColor.opacity(0)
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: buttonSize + 40, height: buttonSize + 40)
                .rotationEffect(.degrees(rotation))
                .blur(radius: 2)

            // 发光光晕
            Circle()
                .fill(currentColor.opacity(glowPulse ? 0.15 : 0.25))
                .frame(width: buttonSize + 30, height: buttonSize + 30)
                .blur(radius: 20)

            // 外层霓虹边框
            Circle()
                .stroke(currentColor.opacity(0.8), lineWidth: 3)
                .frame(width: buttonSize + 10, height: buttonSize + 10)
                .shadow(color: currentColor.opacity(0.8), radius: 15)

            // 主按钮背景
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "2A2A3E"),
                            Color(hex: "1A1A2E"),
                            Color(hex: "0D0D1A")
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: buttonSize / 2
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear,
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 10, y: 5)

            // 内层发光环
            Circle()
                .stroke(currentColor.opacity(glowPulse ? 0.4 : 0.7), lineWidth: 2)
                .frame(width: buttonSize - 20, height: buttonSize - 20)
                .shadow(color: currentColor, radius: glowPulse ? 5 : 10)

            // 波纹效果
            ConferenceAudioWaveView(isActive: isTalking, color: activeColor)
                .frame(width: buttonSize - 40, height: buttonSize - 40)

            // 中心内容
            VStack(spacing: 8) {
                Image(systemName: isTalking ? "waveform" : "mic.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(currentColor)
                    .shadow(color: currentColor.opacity(0.8), radius: 10)

                if isTalking {
                    Text(formattedDuration)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(activeColor)
                        .shadow(color: activeColor.opacity(0.8), radius: 5)
                } else {
                    Text("PTT")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        handlePTTPress()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    handlePTTRelease()
                }
        )
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var formattedDuration: String {
        let minutes = viewModel.talkingDuration / 60
        let seconds = viewModel.talkingDuration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func handlePTTPress() {
        if viewModel.pttMode == .holdToTalk {
            Task { await viewModel.pttDown() }
        } else {
            Task { await viewModel.pttTap() }
        }
    }

    private func handlePTTRelease() {
        if viewModel.pttMode == .holdToTalk {
            Task { await viewModel.pttUp() }
        }
    }
}

/// 环形成员卡片
struct ConferenceCircleMemberCard: View {
    let callsign: String
    let isOnline: Bool
    let isSpeaking: Bool
    let isMe: Bool
    @State private var speakPulse = false
    @State private var ledBlink = false

    private var statusColor: Color {
        if isSpeaking { return Color(hex: "FF3B30") }
        if isMe { return Color(hex: "007AFF") }
        if isOnline { return Color(hex: "30D158") }
        return Color(hex: "6B7280")
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 发言时的发光效果
                if isSpeaking {
                    Circle()
                        .fill(statusColor.opacity(speakPulse ? 0.2 : 0.5))
                        .frame(width: 58, height: 58)
                        .blur(radius: 10)
                }

                // 头像背景
                Circle()
                    .fill(Color(hex: "1A1A2E"))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(statusColor, lineWidth: isSpeaking ? 2.5 : 1)
                    )
                    .shadow(color: statusColor.opacity(0.6), radius: isSpeaking ? 10 : 3)
                    .scaleEffect(isSpeaking && speakPulse ? 1.05 : 1.0)

                // 呼号前缀
                Text(callsignPrefix)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // LED指示灯（发言时闪烁）
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor, radius: isSpeaking ? 5 : 3)
                    .opacity(isSpeaking ? (ledBlink ? 0.4 : 1.0) : 1.0)
                    .offset(x: 16, y: -16)
            }
            .animation(.easeInOut(duration: 0.3), value: isSpeaking)

            // 完整呼号
            Text(callsign)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isSpeaking ? statusColor : Color.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(width: 60)
        .onAppear {
            startAnimationsIfNeeded()
        }
        .onChange(of: isSpeaking) { speaking in
            if speaking {
                startAnimationsIfNeeded()
            } else {
                speakPulse = false
                ledBlink = false
            }
        }
    }

    private func startAnimationsIfNeeded() {
        guard isSpeaking else { return }
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            speakPulse = true
        }
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            ledBlink = true
        }
    }

    private var callsignPrefix: String {
        let base = callsign.components(separatedBy: "-").first ?? callsign
        if base.count > 4 {
            return String(base.suffix(4)).uppercased()
        }
        return base.uppercased()
    }
}

/// 底部成员滚动列表
struct ConferenceBottomMemberList: View {
    let devices: [PttDevice]
    let currentSpeaker: String?
    let myCallsign: String

    /// 只显示在线设备，按说话者 > 自己 > 呼号排序
    private var onlineDevices: [PttDevice] {
        devices
            .filter { $0.isOnline }
            .sorted { d1, d2 in
                let c1 = "\(d1.callsign)-\(d1.ssid)"
                let c2 = "\(d2.callsign)-\(d2.ssid)"

                // 说话者优先
                if c1 == currentSpeaker { return true }
                if c2 == currentSpeaker { return false }

                // 自己次之
                if c1 == myCallsign { return true }
                if c2 == myCallsign { return false }

                // 按呼号排序
                return c1 < c2
            }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 使用 callsign-ssid 作为唯一ID，支持同一呼号不同SSID
                ForEach(onlineDevices, id: \.id) { device in
                    let fullCallsign = "\(device.callsign)-\(device.ssid)"
                    ConferenceCircleMemberCard(
                        callsign: fullCallsign,
                        isOnline: device.isOnline,
                        isSpeaking: currentSpeaker == fullCallsign,
                        isMe: fullCallsign == myCallsign
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

/// 音频控制面板
struct ConferenceAudioControlPanel: View {
    @Binding var speakerVolume: Float      // 扬声器音量 0~1
    @Binding var micVolume: Float          // 麦克风音量 0~1
    @Binding var isMuted: Bool             // 是否静音
    let isTalking: Bool                    // 是否正在发言
    // 会议模式锁定 G711，不需要编码切换
    @State private var showVolumeSlider = false
    @State private var activeControl: AudioControlType? = nil

    enum AudioControlType {
        case speaker, mic
    }

    var body: some View {
        HStack(spacing: 20) {
            // 静音按钮
            audioButton(
                icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                isActive: !isMuted,
                color: isMuted ? Color(hex: "FF3B30") : Color(hex: "00D4FF")
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMuted.toggle()
                }
            }

            // 扬声器音量（点击显示滑块）
            audioButtonWithSlider(
                icon: "speaker.wave.3.fill",
                value: $speakerVolume,
                color: Color(hex: "00D4FF"),
                controlType: .speaker
            )

            // 麦克风音量（点击显示滑块）
            audioButtonWithSlider(
                icon: "mic.fill",
                value: $micVolume,
                color: Color(hex: "30D158"),
                controlType: .mic
            )

            // 编码格式切换 G.711 / Opus
            codecButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func audioButton(icon: String, isActive: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(isActive ? 0.2 : 0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isActive ? color : Color.white.opacity(0.5))
            }
        }
    }

    private func audioButtonWithSlider(icon: String, value: Binding<Float>, color: Color, controlType: AudioControlType) -> some View {
        ZStack {
            // 滑块（显示时）
            if activeControl == controlType {
                VStack(spacing: 8) {
                    // 音量值
                    Text("\(Int(value.wrappedValue * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(color)

                    // 垂直滑块
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            // 背景
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))

                            // 填充
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(height: geo.size.height * CGFloat(value.wrappedValue))
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let newValue = 1 - Float(drag.location.y / geo.size.height)
                                    value.wrappedValue = max(0, min(1, newValue))
                                }
                        )
                    }
                    .frame(width: 24, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1A1A2E"))
                        .shadow(color: .black.opacity(0.5), radius: 10)
                )
                .offset(y: -70)
                .transition(.scale.combined(with: .opacity))
            }

            // 按钮
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if activeControl == controlType {
                        activeControl = nil
                    } else {
                        activeControl = controlType
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    // 音量指示环
                    Circle()
                        .trim(from: 0, to: CGFloat(value.wrappedValue))
                        .stroke(color, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
            }
        }
    }

    /// 编码格式按钮 - 会议模式锁定 G711
    /// 常亮显示，不可点击
    private var codecButton: some View {
        ZStack {
            // 背景 - G711 蓝色常亮
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "00D4FF").opacity(0.2))
                .frame(width: 52, height: 44)

            // 文字标签 - G711 常亮
            Text("G711")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "00D4FF"))
        }
        // 会议模式锁定，不可点击
    }
}

/// 环形音量指示器（围绕PTT按钮）
struct ConferenceVolumeRing: View {
    let level: Float  // 0~1
    let isActive: Bool
    let size: CGFloat

    @State private var animatedLevel: Float = 0

    private let segmentCount = 36
    private let activeColor = Color(hex: "00D4FF")
    private let txColor = Color(hex: "FF3B30")

    var body: some View {
        ZStack {
            // 背景环
            ForEach(0..<segmentCount, id: \.self) { i in
                VolumeSement(index: i, total: segmentCount, size: size)
                    .fill(Color.white.opacity(0.1))
            }

            // 音量环
            ForEach(0..<segmentCount, id: \.self) { i in
                let threshold = Float(i) / Float(segmentCount)
                if animatedLevel > threshold {
                    VolumeSement(index: i, total: segmentCount, size: size)
                        .fill(segmentColor(for: i))
                        .shadow(color: segmentColor(for: i).opacity(0.6), radius: 3)
                }
            }
        }
        .onChange(of: level) { newLevel in
            withAnimation(.easeOut(duration: 0.1)) {
                animatedLevel = isActive ? newLevel : 0
            }
        }
        .onChange(of: isActive) { active in
            if !active {
                withAnimation(.easeOut(duration: 0.3)) {
                    animatedLevel = 0
                }
            }
        }
    }

    private func segmentColor(for index: Int) -> Color {
        let ratio = Float(index) / Float(segmentCount)
        if ratio < 0.5 {
            return activeColor
        } else if ratio < 0.75 {
            return Color(hex: "FFCC00")
        } else {
            return txColor
        }
    }
}

/// 音量环的单个扇形
struct VolumeSement: Shape {
    let index: Int
    let total: Int
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        let anglePerSegment = 360.0 / Double(total)
        let gap = 2.0  // 间隔角度
        let startAngle = Angle(degrees: Double(index) * anglePerSegment - 90 + gap / 2)
        let endAngle = Angle(degrees: Double(index + 1) * anglePerSegment - 90 - gap / 2)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = size / 2
        let innerRadius = outerRadius - 6

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// 顶部状态栏
struct ConferenceTopBar: View {
    let groupName: String
    let channelNumber: String
    let onlineCount: Int
    let sessionDuration: Int  // 会议时长（秒）
    let latency: Int?  // 网络延迟（毫秒）
    let groups: [PttGroup]  // 可切换的群组列表
    let currentGroupId: Int?  // 当前群组ID
    let onExit: () -> Void
    let onSwitchRoom: (PttGroup) -> Void  // 切换房间回调

    @State private var showRoomPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 主状态栏
            HStack {
                // 返回按钮
                Button {
                    onExit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("返回群组")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // 中央信息 + 切换按钮
                Button {
                    showRoomPicker = true
                } label: {
                    HStack(spacing: 6) {
                        VStack(spacing: 2) {
                            Text(groupName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 6) {
                                Text(channelNumber)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(hex: "00D4FF"))

                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.white.opacity(0.3))

                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color(hex: "30D158"))
                                        .frame(width: 5, height: 5)
                                    Text("\(onlineCount)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "30D158"))
                                }
                            }
                        }

                        // 切换箭头
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "00D4FF"))
                    }
                }
                .sheet(isPresented: $showRoomPicker) {
                    ConferenceRoomPickerSheet(
                        groups: groups,
                        currentGroupId: currentGroupId,
                        onSelect: { group in
                            showRoomPicker = false
                            onSwitchRoom(group)
                        }
                    )
                }

                Spacer()

                // 右侧：会议时长 + 延迟
                VStack(alignment: .trailing, spacing: 2) {
                    // 会议时长
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatDuration(sessionDuration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(Color.white.opacity(0.7))

                    // 网络延迟
                    if let ms = latency {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(latencyColor(ms))
                                .frame(width: 5, height: 5)
                            Text("\(ms)ms")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(latencyColor(ms))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 50 { return Color(hex: "30D158") }  // 绿
        if ms < 100 { return Color(hex: "FFCC00") }  // 黄
        return Color(hex: "FF3B30")  // 红
    }
}

/// 房间选择 Sheet
struct ConferenceRoomPickerSheet: View {
    let groups: [PttGroup]
    let currentGroupId: Int?
    let onSelect: (PttGroup) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(groups, id: \.id) { group in
                    Button {
                        if group.id != currentGroupId {
                            onSelect(group)
                        }
                    } label: {
                        HStack {
                            // 群组图标
                            ZStack {
                                Circle()
                                    .fill(group.isConferenceMode ? Color(hex: "FF3B30").opacity(0.2) : Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)

                                Image(systemName: group.isConferenceMode ? "person.3.fill" : "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(group.isConferenceMode ? Color(hex: "FF3B30") : .blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)

                                Text("CH-\(group.id)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // 在线人数 / 总人数
                            HStack(spacing: 2) {
                                Text("\(group.onlineCount)/\(group.memberCount)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(group.onlineCount > 0 ? Color(hex: "30D158") : .secondary)
                                Text("人")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            // 当前选中标记
                            if group.id == currentGroupId {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "00D4FF"))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(group.id == currentGroupId)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("切换会议房间")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 主页面房间选择器（简洁样式）
struct MainRoomPickerSheet: View {
    let groups: [PttGroup]
    let currentGroupId: Int?
    let onSelect: (PttGroup) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(groups, id: \.id) { group in
                    Button {
                        if group.id != currentGroupId {
                            onSelect(group)
                        }
                    } label: {
                        HStack {
                            // 群组图标
                            ZStack {
                                Circle()
                                    .fill(group.isConferenceMode ? Color(hex: "FF3B30").opacity(0.2) : Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)

                                Image(systemName: group.isConferenceMode ? "person.3.fill" : "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(group.isConferenceMode ? Color(hex: "FF3B30") : .blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)

                                Text("CH-\(group.id)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // 在线人数
                            HStack(spacing: 2) {
                                Text("\(group.onlineCount)/\(group.memberCount)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(group.onlineCount > 0 ? Color(hex: "30D158") : .secondary)
                                Text("人")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            // 当前选中标记
                            if group.id == currentGroupId {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .disabled(group.id == currentGroupId)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("切换房间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 中央说话者信息
struct ConferenceSpeakerInfo: View {
    let speaker: String?
    let isTalking: Bool
    let myCallsign: String
    @State private var textPulse = false

    var body: some View {
        VStack(spacing: 8) {
            if let speaker = speaker {
                // 有人在说话
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color(hex: "FF3B30"), radius: 5)
                        .opacity(textPulse ? 0.5 : 1)

                    Text(speaker)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text("正在发言")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "FF3B30"))

            } else if isTalking {
                // 自己在说话
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "FF3B30"))
                        .frame(width: 10, height: 10)
                        .shadow(color: Color(hex: "FF3B30"), radius: 5)
                        .opacity(textPulse ? 0.5 : 1)

                    Text(myCallsign)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Text("我正在发言")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "FF3B30"))

            } else {
                // 空闲
                Text("会议进行中")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))

                Text("按住下方按钮发言")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                textPulse = true
            }
        }
    }
}

/// 会议模式主视图 - 全屏沉浸式
struct ConferenceModeView: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var refreshTimer: Timer?
    @State private var sessionTimer: Timer?
    @State private var sessionDuration: Int = 0  // 会议时长（秒）
    @State private var joinTime: Date = Date()
    @State private var isSwitchingRoom: Bool = false

    // 音频控制状态
    @State private var speakerVolume: Float = 0.8
    @State private var micVolume: Float = 0.8
    @State private var isMuted: Bool = false
    // 会议模式锁定 G711，不需要 useOpusCodec 状态

    // 弹幕状态
    @State private var showDanmakuInput: Bool = false
    @State private var danmakuText: String = ""
    @FocusState private var isDanmakuFocused: Bool

    // 当前发言追踪
    @State private var currentSpeakerStartTime: Date?

    // 文字弹幕自动隐藏
    @State private var showTextDanmaku: Bool = false
    @State private var danmakuHideTimer: Timer?

    var onExit: (() -> Void)?

    private let refreshInterval: TimeInterval = 5

    private var channelNumber: String {
        if let groupId = viewModel.currentGroup?.id {
            return "CH-\(groupId)"
        }
        return "CH-0000"
    }

    private var myCallsign: String {
        "\(viewModel.callSign)-\(viewModel.ssid)"
    }

    /// 底部固定区域高度（成员列表 + 输入框 + 安全区域）
    private let bottomFixedHeight: CGFloat = 160

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 动态粒子背景
                ConferenceParticleBackground()

                // 主内容区域
                VStack(spacing: 0) {
                    // 顶部状态栏（紧贴安全区域）
                    ConferenceTopBar(
                        groupName: viewModel.currentGroup?.name ?? "会议",
                        channelNumber: channelNumber,
                        onlineCount: viewModel.currentGroupDetail?.onlineCount ?? 0,
                        sessionDuration: sessionDuration,
                        latency: viewModel.latency,
                        groups: viewModel.groups,
                        currentGroupId: viewModel.currentGroup?.id,
                        onExit: { onExit?() },
                        onSwitchRoom: { group in
                            switchToRoom(group)
                        }
                    )
                    .padding(.top, geometry.safeAreaInsets.top)

                    Spacer(minLength: 8)

                    // 文字弹幕区域（B站风格循环飘动）
                    if !viewModel.currentGroupTextMessages.isEmpty {
                        ConferenceDanmakuView(messages: viewModel.currentGroupTextMessages)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // 实时字幕（当前发言的语音转文字，自动滚动到最新）
                    if !viewModel.currentTranscription.isEmpty {
                        LiveTranscriptionView(transcription: viewModel.currentTranscription)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }

                    // 说话者信息
                    ConferenceSpeakerInfo(
                        speaker: viewModel.currentSpeaker,
                        isTalking: viewModel.isTalking,
                        myCallsign: myCallsign
                    )
                    .padding(.bottom, 20)

                    // 大圆形PTT按钮（带环形音量指示）
                    ConferenceNeonPTTButton(viewModel: viewModel)
                        .frame(height: 260)  // 为音量环留出空间

                    // 音频控制面板（会议模式锁定 G711）
                    ConferenceAudioControlPanel(
                        speakerVolume: $speakerVolume,
                        micVolume: $micVolume,
                        isMuted: $isMuted,
                        isTalking: viewModel.isTalking
                    )
                    .padding(.top, 20)
                    .onChange(of: isMuted) { muted in
                        // 同步静音状态到 ViewModel/Service
                        viewModel.setMuted(muted)
                    }
                    .onChange(of: speakerVolume) { volume in
                        // 同步扬声器音量
                        viewModel.setSpeakerVolume(volume)
                    }
                    .onChange(of: micVolume) { volume in
                        // 同步麦克风音量
                        viewModel.setMicVolume(volume)
                    }
                }
                .padding(.bottom, bottomFixedHeight + geometry.safeAreaInsets.bottom)

                // 底部固定区域
                VStack(spacing: 0) {
                    // 在线成员标题
                    HStack {
                        Text("在线成员")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))

                        Text("(\(viewModel.currentGroupDetail?.onlineCount ?? 0))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "00D4FF"))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    // 底部成员列表
                    if let detail = viewModel.currentGroupDetail {
                        ConferenceBottomMemberList(
                            devices: detail.devices,
                            currentSpeaker: viewModel.currentSpeaker,
                            myCallsign: myCallsign
                        )
                        .frame(height: 80)
                    }

                    // 弹幕输入区域
                    ConferenceDanmakuInputView(
                        showInput: $showDanmakuInput,
                        text: $danmakuText,
                        isFocused: $isDanmakuFocused,
                        onSend: {
                            sendDanmaku()
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // 底部安全区域（稍微贴近底部）
                    Color.clear.frame(height: max(0, geometry.safeAreaInsets.bottom - 5))
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            joinTime = Date()
            sessionDuration = 0
            Task { await viewModel.refreshGroupDetail() }
            startRefreshTimer()
            startSessionTimer()
            // 初始检查是否有消息需要显示
            if !viewModel.currentGroupTextMessages.isEmpty {
                showTextDanmakuWithTimer()
            }
        }
        .onDisappear {
            stopRefreshTimer()
            stopSessionTimer()
            danmakuHideTimer?.invalidate()
        }
        .onChange(of: viewModel.currentSpeaker) { speaker in
            // 追踪当前发言开始时间
            if speaker != nil {
                currentSpeakerStartTime = Date()
            } else {
                currentSpeakerStartTime = nil
            }
        }
        .onChange(of: viewModel.currentGroupTextMessages.first?.id) { _ in
            // 有新文字消息时显示弹幕并重置隐藏计时器
            showTextDanmakuWithTimer()
        }
    }

    /// 显示文字弹幕并启动5秒隐藏计时器
    private func showTextDanmakuWithTimer() {
        // 取消之前的计时器
        danmakuHideTimer?.invalidate()

        // 显示弹幕
        withAnimation(.easeOut(duration: 0.3)) {
            showTextDanmaku = true
        }

        // 5秒后隐藏
        danmakuHideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showTextDanmaku = false
            }
        }
    }

    private func startRefreshTimer() {
        // 不再定时刷新，避免网络请求和UI更新导致语音卡顿
        // 群组详情只在进入时刷新一次
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func startSessionTimer() {
        stopSessionTimer()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            sessionDuration = Int(Date().timeIntervalSince(joinTime))
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    /// 切换到其他房间
    private func switchToRoom(_ group: PttGroup) {
        guard !isSwitchingRoom else { return }
        isSwitchingRoom = true

        Task {
            do {
                // 加入新群组
                try await viewModel.joinGroup(group)
                // 重置会议时长
                joinTime = Date()
                sessionDuration = 0
                // 刷新群组详情
                await viewModel.refreshGroupDetail()
            } catch {
                print("[ConferenceModeView] switchToRoom failed: \(error)")
            }
            isSwitchingRoom = false
        }
    }

    /// 发送弹幕
    private func sendDanmaku() {
        let text = danmakuText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.sendText(text)
        danmakuText = ""
        showDanmakuInput = false
        isDanmakuFocused = false
    }
}

// MARK: - 会议弹幕显示组件（B站风格飘动弹幕）
struct ConferenceDanmakuView: View {
    let messages: [TextMessage]

    /// 显示的消息（最多6条，6个轨道）
    private var displayMessages: [TextMessage] {
        Array(messages.prefix(6))
    }

    var body: some View {
        if !displayMessages.isEmpty {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(displayMessages.enumerated()), id: \.element.id) { index, message in
                        FloatingDanmakuRow(
                            message: message,
                            containerWidth: geometry.size.width,
                            trackIndex: index
                        )
                    }
                }
            }
            .frame(height: CGFloat(min(displayMessages.count, 6)) * 28)
            .clipped()
        }
    }
}

/// 单条飘动弹幕
struct FloatingDanmakuRow: View {
    let message: TextMessage
    let containerWidth: CGFloat
    let trackIndex: Int

    @State private var offsetX: CGFloat = 0
    @State private var textWidth: CGFloat = 200
    @State private var opacity: Double = 1.0
    @State private var hasStarted: Bool = false

    /// 时间格式化器
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 根据文字长度计算飘动时长（长文字飘得更久）
    private var floatDuration: Double {
        // 基础时长 + 根据文字长度增加
        // 短文字约12秒，长文字可达25秒
        let baseTime: Double = 12.0
        let extraTime = Double(message.content.count) * 0.3
        return min(baseTime + extraTime, 25.0)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(Self.timeFormatter.string(from: message.timestamp))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            Text("\(message.sender)：\(message.content)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .cornerRadius(14)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    textWidth = geo.size.width
                    // 获取到宽度后再开始飘动
                    if !hasStarted {
                        hasStarted = true
                        startFloating()
                    }
                }
                .onChange(of: geo.size.width) { newWidth in
                    textWidth = newWidth
                }
            }
        )
        .offset(x: offsetX)
        .opacity(opacity)
        .onChange(of: message.id) { _ in
            // 消息变化时重新开始飘动
            hasStarted = false
            opacity = 1.0
            startFloating()
        }
    }

    private func startFloating() {
        // 初始位置：从右边开始（加上轨道偏移，错开起始位置）
        let trackOffset = CGFloat(trackIndex) * (containerWidth * 0.25)
        offsetX = containerWidth + trackOffset
        opacity = 1.0

        // 延迟一帧确保初始位置设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // 只飘一次，飘完消失
            withAnimation(.linear(duration: floatDuration)) {
                offsetX = -textWidth - 50
            }

            // 飘完后淡出消失
            DispatchQueue.main.asyncAfter(deadline: .now() + floatDuration - 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
            }
        }
    }
}

/// 单条弹幕消息行（静态版本，保留备用）
struct DanmakuMessageRowStatic: View {
    let message: TextMessage
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // 时间（小字灰色）
            Text(timeFormatter.string(from: message.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            // 呼号 + 内容（可多行）
            Text("\(message.sender)：\(message.content)")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeOut(duration: 0.3), value: message.id)
    }
}

// MARK: - 实时字幕组件（自动滚动到最新）
struct LiveTranscriptionView: View {
    let transcription: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Text(transcription)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .id("transcriptionEnd")
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .onChange(of: transcription) { _ in
                // 文字变化时滚动到末尾
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("transcriptionEnd", anchor: .trailing)
                }
            }
            .onAppear {
                // 初始滚动到末尾
                proxy.scrollTo("transcriptionEnd", anchor: .trailing)
            }
        }
    }
}

// MARK: - 语音发言记录组件
struct ConferenceVoiceRecordView: View {
    let callHistory: [CallRecord]
    let currentSpeaker: String?
    let currentSpeakerStartTime: Date?
    let isTalking: Bool
    let myCallsign: String

    /// 显示的历史记录（最多3条，避免布局跳动）
    private var recentRecords: [CallRecord] {
        Array(callHistory.prefix(3))
    }

    /// 时间格式化器
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 当前正在发言（如果有）
            if let speaker = currentSpeaker, let startTime = currentSpeakerStartTime {
                VoiceRecordRow(
                    callSign: speaker,
                    duration: Date().timeIntervalSince(startTime),
                    timestamp: startTime,
                    isLive: true,
                    isSelf: false,
                    timeFormatter: Self.timeFormatter
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            } else if isTalking {
                // 自己正在发言
                VoiceRecordRow(
                    callSign: myCallsign,
                    duration: 0,
                    timestamp: Date(),
                    isLive: true,
                    isSelf: true,
                    timeFormatter: Self.timeFormatter
                )
            }

            // 历史发言记录
            ForEach(recentRecords) { record in
                VoiceRecordRow(
                    callSign: "\(record.callSign)-\(record.ssid)",
                    duration: record.duration,
                    timestamp: record.startTime,
                    isLive: false,
                    isSelf: record.isSelf,
                    timeFormatter: Self.timeFormatter
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .frame(maxWidth: 320)
    }
}

/// 单条语音发言记录行
struct VoiceRecordRow: View {
    let callSign: String
    let duration: TimeInterval
    let timestamp: Date
    let isLive: Bool
    let isSelf: Bool
    let timeFormatter: DateFormatter

    /// 实时更新的时长（用于正在发言的情况）
    @State private var liveDuration: TimeInterval = 0
    @State private var timer: Timer?

    /// 根据时长计算气泡宽度（对数关系，最大为黄金分割）
    private var bubbleWidth: CGFloat {
        let dur = isLive ? liveDuration : duration
        let screenWidth = UIScreen.main.bounds.width
        let minWidth: CGFloat = 30
        let maxWidth = (screenWidth - 120) * 0.618  // 减去边距后的黄金分割
        // 对数关系：log10(duration + 1)
        let logValue = log10(dur + 1)
        let width = minWidth + logValue * 50
        return min(maxWidth, max(minWidth, width))
    }

    /// 格式化时长
    private var durationText: String {
        let dur = isLive ? liveDuration : duration
        if dur < 60 {
            // 最小显示1秒（向上取整）
            let seconds = max(1, Int(ceil(dur)))
            return "\(seconds)秒"
        } else {
            let minutes = Int(dur) / 60
            let seconds = Int(dur) % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // 时间
            Text(timeFormatter.string(from: timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            // 呼号
            HStack(spacing: 4) {
                if isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
                Text(callSign)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelf ? Color(hex: "00D4FF") : .white)
            }

            // 时长气泡
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelf ? Color(hex: "00D4FF").opacity(0.6) : Color.white.opacity(0.3))
                .frame(width: bubbleWidth, height: 16)
                .overlay(
                    Text(durationText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                )
                .animation(.easeOut(duration: 0.1), value: bubbleWidth)

            Spacer()
        }
        .onAppear {
            if isLive {
                liveDuration = duration
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isLive) { live in
            if live {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            liveDuration += 0.5
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 会议弹幕输入组件
struct ConferenceDanmakuInputView: View {
    @Binding var showInput: Bool
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        if showInput {
            // 展开状态：输入框 + 发送 + 关闭
            HStack(spacing: 8) {
                TextField("输入弹幕...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .focused(isFocused)
                    .onSubmit {
                        onSend()
                    }

                Button(action: onSend) {
                    Text("发送")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "00D4FF"))
                        .cornerRadius(20)
                }

                Button {
                    showInput = false
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
        } else {
            // 收起状态：右下角小按钮
            HStack {
                Spacer()
                Button {
                    showInput = true
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "00D4FF"))
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
    }
}

/// 会议模式主题选择器
struct ConferenceThemePickerView: View {
    @Binding var selectedTheme: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 当前主题 - 霓虹科技风格
                    currentThemeCard

                    // 即将推出提示
                    comingSoonSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("会议模式样式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    // 当前主题卡片
    private var currentThemeCard: some View {
        VStack(spacing: 16) {
            // 预览图
            ZStack {
                // 模拟背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "0D0D1A"),
                                Color(hex: "1A1A2E"),
                                Color(hex: "16213E")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)

                // 模拟粒子
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: "00D4FF").opacity(0.3))
                        .frame(width: CGFloat(3 + i % 3), height: CGFloat(3 + i % 3))
                        .offset(
                            x: CGFloat(-80 + (i * 25)),
                            y: CGFloat(-60 + (i * 18))
                        )
                }

                // PTT 按钮预览
                VStack(spacing: 8) {
                    // 音量环
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "00D4FF").opacity(0.3), lineWidth: 3)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(Color(hex: "1A1A2E"))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "00D4FF"), lineWidth: 2)
                            )
                            .shadow(color: Color(hex: "00D4FF").opacity(0.5), radius: 10)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "00D4FF"))
                    }

                    Text("PTT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }

                // 选中标记
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "30D158"))
                            .background(Circle().fill(.white).padding(2))
                            .padding(12)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 主题信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "00D4FF"))
                        Text("霓虹科技")
                            .font(.headline)
                    }

                    Text("深色背景、动态粒子、霓虹发光效果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("当前")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "00D4FF"))
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // 即将推出区域
    private var comingSoonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("更多样式")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("即将推出")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // 即将推出的样式预览
            HStack(spacing: 12) {
                comingSoonCard(name: "军事风格", icon: "shield.checkered", colors: ["#1B2838", "#2D4A3E"])
                comingSoonCard(name: "复古风格", icon: "dial.low", colors: ["#2C1810", "#4A3728"])
                comingSoonCard(name: "简约风格", icon: "rectangle.3.group", colors: ["#1C1C1E", "#2C2C2E"])
            }

            Text("更多个性化样式正在开发中，敬请期待...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func comingSoonCard(name: String, icon: String, colors: [String]) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: colors.map { Color(hex: String($0.dropFirst())) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 60)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))

                // 锁定图标
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(4)
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(0.6)
    }
}

/// PTT 效果视图 - 根据类型动态切换
struct PTTEffectView: View {
    let effectType: PTTEffectType
    let amplitude: CGFloat
    let color: Color

    var body: some View {
        switch effectType {
        case .ripple:
            RippleEffectView(amplitude: amplitude, color: color)
        case .dotMatrix:
            DotMatrixEffectView(amplitude: amplitude, color: color)
        case .spectrum:
            SpectrumEffectView(amplitude: amplitude, color: color)
        case .particle:
            ParticleEffectView(amplitude: amplitude, color: color)
        case .glowPulse:
            GlowPulseEffectView(amplitude: amplitude, color: color)
        }
    }
}

// MARK: - 效果1: 水波扩散

struct RippleEffectView: View {
    let amplitude: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = size * 0.48
            let minRadius = size * 0.15

            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSince1970
                    let effectiveAmplitude = min(amplitude * 1.8 + 0.1, 1.0)
                    let rippleCount = 3 + Int(effectiveAmplitude * 3)

                    for i in 0..<rippleCount {
                        let phaseOffset = CGFloat(i) / CGFloat(rippleCount)
                        let rawProgress = (CGFloat(now.truncatingRemainder(dividingBy: 1.5)) / 1.5 + phaseOffset).truncatingRemainder(dividingBy: 1.0)
                        let progress = easeOutQuad(rawProgress)
                        let radius = minRadius + (maxRadius - minRadius) * progress

                        let fadeIn = min(rawProgress * 4, 1.0)
                        let fadeOut = 1.0 - rawProgress
                        let baseOpacity = fadeIn * fadeOut * 0.7
                        let opacity = baseOpacity * (0.4 + effectiveAmplitude * 0.6)
                        let lineWidth: CGFloat = (2.5 + effectiveAmplitude * 3) * (1.0 - progress * 0.5)

                        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Circle().path(in: rect), with: .color(color.opacity(opacity)), lineWidth: lineWidth)
                    }

                    // 中心发光
                    let glowRadius = minRadius * (0.8 + effectiveAmplitude * 0.4)
                    for j in stride(from: 1.0, through: 0.1, by: -0.1) {
                        let r = glowRadius * CGFloat(j)
                        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(0.03 * effectiveAmplitude * (1.0 - j + 0.3))))
                    }
                }
            }
        }
    }

    private func easeOutQuad(_ t: CGFloat) -> CGFloat {
        return 1 - (1 - t) * (1 - t)
    }
}

// MARK: - 效果2: 点阵波纹

struct DotMatrixEffectView: View {
    let amplitude: CGFloat
    let color: Color
    let dotCount: Int = 32

    @State private var phase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let effectiveAmplitude = min(amplitude * 1.5 + 0.2, 1.0)
            let baseRadius = size * 0.32
            let maxOffset = size * 0.18 * effectiveAmplitude

            TimelineView(.animation(minimumInterval: 0.016)) { _ in
                Canvas { context, _ in
                    // 外层光晕
                    let glowRadius = baseRadius + size * 0.08 + size * 0.06 * effectiveAmplitude
                    let glowRect = CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
                    context.fill(Circle().path(in: glowRect), with: .color(color.opacity(0.08 * Double(effectiveAmplitude))))

                    // 外圈点阵
                    let outerDotCount = dotCount + 8
                    let outerBaseRadius = size * 0.42
                    let outerMaxOffset = size * 0.12 * effectiveAmplitude

                    for i in 0..<outerDotCount {
                        let angle = (CGFloat(i) / CGFloat(outerDotCount)) * .pi * 2
                        let waveOffset = sin(angle * 4 + phase * 1.3) * outerMaxOffset
                        let radius = outerBaseRadius + waveOffset
                        let x = center.x + cos(angle) * radius
                        let y = center.y + sin(angle) * radius
                        let dotSize: CGFloat = 3 + effectiveAmplitude * 3
                        let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(0.4)))
                    }

                    // 内圈点阵
                    for i in 0..<dotCount {
                        let angle = (CGFloat(i) / CGFloat(dotCount)) * .pi * 2
                        let wave1 = sin(angle * 3 + phase) * maxOffset
                        let wave2 = sin(angle * 5 - phase * 0.7) * maxOffset * 0.4
                        let waveOffset = wave1 + wave2
                        let radius = baseRadius + waveOffset
                        let x = center.x + cos(angle) * radius
                        let y = center.y + sin(angle) * radius
                        let dotSize: CGFloat = 5 + effectiveAmplitude * 6
                        let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(0.9)))
                    }
                }
            }
        }
        .scaleEffect(pulseScale)
        .onAppear {
            withAnimation(.linear(duration: 0.5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                pulseScale = 1.0 + CGFloat(amplitude) * 0.08
            }
        }
    }
}

// MARK: - 效果3: 频谱柱状图

struct SpectrumEffectView: View {
    let amplitude: CGFloat
    let color: Color
    let barCount: Int = 24

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let innerRadius = size * 0.22
            let maxBarHeight = size * 0.25

            TimelineView(.animation(minimumInterval: 0.033)) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSince1970
                    let effectiveAmplitude = min(amplitude * 1.5 + 0.15, 1.0)

                    for i in 0..<barCount {
                        let angle = (CGFloat(i) / CGFloat(barCount)) * .pi * 2 - .pi / 2

                        // 随机化每个柱子的高度
                        let seed = sin(CGFloat(i) * 1.5 + CGFloat(now * 8))
                        let heightFactor = (0.3 + seed * 0.3 + 0.4) * effectiveAmplitude
                        let barHeight = maxBarHeight * heightFactor

                        let barWidth: CGFloat = size * 0.04
                        let startRadius = innerRadius
                        let endRadius = innerRadius + barHeight

                        let startX = center.x + cos(angle) * startRadius
                        let startY = center.y + sin(angle) * startRadius
                        let endX = center.x + cos(angle) * endRadius
                        let endY = center.y + sin(angle) * endRadius

                        var path = Path()
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))

                        let opacity = 0.5 + heightFactor * 0.5
                        context.stroke(path, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
                    }

                    // 中心圆
                    let centerRect = CGRect(x: center.x - innerRadius * 0.6, y: center.y - innerRadius * 0.6, width: innerRadius * 1.2, height: innerRadius * 1.2)
                    context.fill(Circle().path(in: centerRect), with: .color(color.opacity(0.1 * effectiveAmplitude)))
                }
            }
        }
    }
}

// MARK: - 效果4: 发光粒子

struct ParticleEffectView: View {
    let amplitude: CGFloat
    let color: Color

    @State private var particles: [ParticleData] = []

    struct ParticleData: Identifiable {
        let id = UUID()
        var angle: CGFloat
        var speed: CGFloat
        var size: CGFloat
        var birth: TimeInterval
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSince1970
                    let effectiveAmplitude = min(amplitude * 1.5 + 0.1, 1.0)
                    let particleCount = 15 + Int(effectiveAmplitude * 20)

                    for i in 0..<particleCount {
                        let seed = CGFloat(i) / CGFloat(particleCount)
                        let angle = seed * .pi * 2 + CGFloat(now * 0.5)
                        let cycleTime = 2.0 + seed * 1.0
                        let progress = CGFloat((now + Double(seed) * cycleTime).truncatingRemainder(dividingBy: cycleTime)) / CGFloat(cycleTime)

                        let minRadius = size * 0.12
                        let maxRadius = size * 0.45
                        let radius = minRadius + (maxRadius - minRadius) * progress

                        let x = center.x + cos(angle) * radius
                        let y = center.y + sin(angle) * radius

                        let fadeIn = min(progress * 3, 1.0)
                        let fadeOut = 1.0 - progress
                        let opacity = fadeIn * fadeOut * effectiveAmplitude

                        let particleSize = (3 + effectiveAmplitude * 5) * (1.0 - progress * 0.5)
                        let rect = CGRect(x: x - particleSize/2, y: y - particleSize/2, width: particleSize, height: particleSize)

                        // 发光效果
                        let glowRect = CGRect(x: x - particleSize, y: y - particleSize, width: particleSize * 2, height: particleSize * 2)
                        context.fill(Circle().path(in: glowRect), with: .color(color.opacity(opacity * 0.3)))
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(opacity)))
                    }

                    // 中心光晕
                    let glowRadius = size * 0.15 * (0.8 + effectiveAmplitude * 0.4)
                    for j in stride(from: 1.0, through: 0.2, by: -0.2) {
                        let r = glowRadius * CGFloat(j)
                        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(0.05 * effectiveAmplitude * (1.0 - j + 0.3))))
                    }
                }
            }
        }
    }
}

// MARK: - 效果5: 呼吸光环

struct GlowPulseEffectView: View {
    let amplitude: CGFloat
    let color: Color

    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            TimelineView(.animation(minimumInterval: 0.016)) { timeline in
                Canvas { context, _ in
                    let now = timeline.date.timeIntervalSince1970
                    let effectiveAmplitude = min(amplitude * 1.5 + 0.2, 1.0)

                    // 呼吸脉冲
                    let breathCycle = sin(CGFloat(now * 3)) * 0.5 + 0.5
                    let pulseScale = 0.85 + breathCycle * 0.15 * effectiveAmplitude

                    // 多层光环
                    let ringCount = 4
                    for i in 0..<ringCount {
                        let ringProgress = CGFloat(i) / CGFloat(ringCount)
                        let baseRadius = size * (0.25 + ringProgress * 0.2) * pulseScale

                        let phaseOffset = CGFloat(now * 2) + ringProgress * .pi
                        let waveAmount = sin(phaseOffset) * size * 0.02 * effectiveAmplitude
                        let radius = baseRadius + waveAmount

                        let opacity = (1.0 - ringProgress * 0.6) * effectiveAmplitude * 0.6
                        let lineWidth: CGFloat = (3 + effectiveAmplitude * 2) * (1.0 - ringProgress * 0.3)

                        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Circle().path(in: rect), with: .color(color.opacity(opacity)), lineWidth: lineWidth)
                    }

                    // 内部填充光晕
                    let innerRadius = size * 0.2 * pulseScale
                    for j in stride(from: 1.0, through: 0.1, by: -0.1) {
                        let r = innerRadius * CGFloat(j)
                        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                        let glowOpacity = 0.08 * effectiveAmplitude * (1.0 - j + 0.2)
                        context.fill(Circle().path(in: rect), with: .color(color.opacity(glowOpacity)))
                    }
                }
            }
        }
    }
}

// MARK: - PTT 效果选择器视图

struct PTTEffectPickerView: View {
    @Binding var selectedEffect: String
    @Environment(\.dismiss) private var dismiss
    @State private var previewAmplitude: CGFloat = 0.5

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览区域
                    VStack(spacing: 12) {
                        Text("效果预览")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 160, height: 160)

                            PTTEffectView(
                                effectType: PTTEffectType(rawValue: selectedEffect) ?? .ripple,
                                amplitude: previewAmplitude,
                                color: .red
                            )
                            .frame(width: 150, height: 150)

                            Image(systemName: "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red.opacity(0.8))
                        }

                        // 音量模拟滑块
                        VStack(spacing: 4) {
                            Text("模拟音量: \(Int(previewAmplitude * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $previewAmplitude, in: 0...1)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 效果列表
                    VStack(spacing: 0) {
                        ForEach(PTTEffectType.allCases) { effect in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedEffect = effect.rawValue
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    // 效果图标
                                    ZStack {
                                        Circle()
                                            .fill(selectedEffect == effect.rawValue ? Color.purple : Color.gray.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: effect.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedEffect == effect.rawValue ? .white : .gray)
                                    }

                                    // 效果名称
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(effect.displayName)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.primary)

                                        Text(effectDescription(effect))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // 选中标记
                                    if selectedEffect == effect.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }

                            if effect != PTTEffectType.allCases.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("PTT 效果样式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    private func effectDescription(_ effect: PTTEffectType) -> String {
        switch effect {
        case .ripple:
            return "像水滴落下，一圈圈向外扩散"
        case .dotMatrix:
            return "围绕按钮的点阵随音量起伏"
        case .spectrum:
            return "环形排列的频谱柱状图跳动"
        case .particle:
            return "从中心向外飘散的发光粒子"
        case .glowPulse:
            return "简洁的光环随音量脉冲呼吸"
        }
    }
}

// MARK: - 频谱样式选择器视图

struct SpectrumStylePickerView: View {
    @Binding var selectedStyle: String
    @Environment(\.dismiss) private var dismiss
    @State private var previewVolume: Float = 0.5

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 预览区域
                    VStack(spacing: 12) {
                        Text("效果预览")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        // 状态栏预览
                        SpeakingStatusBarPreview(
                            style: SpectrumStyle(rawValue: selectedStyle) ?? .standard,
                            volumeLevel: previewVolume
                        )

                        // 音量模拟滑块
                        VStack(spacing: 4) {
                            Text("模拟音量: \(Int(previewVolume * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $previewVolume, in: 0...1)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // 样式列表
                    VStack(spacing: 0) {
                        ForEach(SpectrumStyle.allCases) { style in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStyle = style.rawValue
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    // 样式图标
                                    ZStack {
                                        Circle()
                                            .fill(selectedStyle == style.rawValue ? Color.green : Color.gray.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: style.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedStyle == style.rawValue ? .white : .gray)
                                    }

                                    // 样式名称
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(style.displayName)
                                            .font(.system(size: 17, weight: .medium))
                                            .foregroundColor(.primary)

                                        Text(style.description)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // 选中标记
                                    if selectedStyle == style.rawValue {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                            }

                            if style != SpectrumStyle.allCases.last {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("接收频谱样式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }
}

/// 频谱样式预览组件
struct SpeakingStatusBarPreview: View {
    let style: SpectrumStyle
    let volumeLevel: Float

    @State private var animationPhase: CGFloat = 0
    @State private var pulseOpacity: Double = 1.0

    private let barColor: Color = .green
    private let speaker: String = "BG7ABC"

    var body: some View {
        SwiftUI.Group {
            switch style {
            case .classic:
                classicPreview
            case .standard:
                standardPreview
            case .textTop:
                textTopPreview
            case .symmetric:
                symmetricPreview
            case .wideBar:
                wideBarPreview
            case .compact:
                compactPreview
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }

    private var classicPreview: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: previewBarHeight(for: i, pattern: [0.35, 0.75, 1.0, 0.65, 0.4]))
                        .animation(.easeInOut(duration: 0.1), value: volumeLevel)
                }
            }
            .frame(width: 32, height: 36)
            Text("\(speaker) 正在讲话...")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            previewVolumeDots
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(previewBackground)
    }

    private var standardPreview: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(previewGradientColor(for: i, total: 15))
                        .frame(width: 3, height: previewSpectrumHeight(for: i, total: 15))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                }
            }
            .frame(width: 60, height: 36)
            Text("\(speaker) 正在讲话...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            previewVolumeDots
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(previewBackground)
    }

    private var textTopPreview: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(speaker) 正在讲话...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                previewVolumeDots
            }
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(previewGradientColor(for: i, total: 20))
                        .frame(height: previewSpectrumHeight(for: i, total: 20, maxHeight: 20))
                        .animation(.easeInOut(duration: 0.06), value: volumeLevel)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(previewBackground)
    }

    private var symmetricPreview: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(previewGradientColor(for: 7 - i, total: 8))
                        .frame(width: 3, height: previewSymmetricHeight(for: 7 - i))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                }
            }
            .frame(width: 36, height: 32)
            Spacer()
            VStack(spacing: 2) {
                Text(speaker)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("正在讲话")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(previewGradientColor(for: i, total: 8))
                        .frame(width: 3, height: previewSymmetricHeight(for: i))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                }
            }
            .frame(width: 36, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(previewBackground)
    }

    private var wideBarPreview: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(previewGradientColor(for: i, total: 8))
                        .frame(width: 6, height: previewSpectrumHeight(for: i, total: 8))
                        .animation(.easeInOut(duration: 0.1), value: volumeLevel)
                }
            }
            .frame(width: 60, height: 36)
            Text("\(speaker) 正在讲话...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            previewVolumeDots
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(previewBackground)
    }

    private var compactPreview: some View {
        HStack(spacing: 8) {
            HStack(spacing: 1.5) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(previewGradientColor(for: i, total: 10))
                        .frame(width: 2.5, height: previewSpectrumHeight(for: i, total: 10, maxHeight: 20))
                        .animation(.easeInOut(duration: 0.06), value: volumeLevel)
                }
            }
            .frame(width: 36, height: 24)
            Text(speaker)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text("正在讲话")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Circle()
                .fill(volumeLevel > 0.5 ? Color.white : Color.white.opacity(0.4))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(previewBackground)
    }

    private var previewVolumeDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(volumeLevel >= [0.0, 0.35, 0.65][i] ? 0.9 : 0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.trailing, 4)
    }

    private var previewBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(
                    colors: [barColor, barColor.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.15 * pulseOpacity * Double(volumeLevel)))
        }
    }

    private func previewBarHeight(for index: Int, pattern: [CGFloat]) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 32
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)
        let variation = effectiveVolume * (maxHeight - baseHeight)
        return baseHeight + variation * pattern[min(index, pattern.count - 1)]
    }

    private func previewSpectrumHeight(for index: Int, total: Int, maxHeight: CGFloat = 32) -> CGFloat {
        let baseHeight: CGFloat = 4
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)
        let centerIndex = CGFloat(total) / 2.0
        let distanceFromCenter = abs(CGFloat(index) - centerIndex) / centerIndex
        let basePattern = 1.0 - pow(distanceFromCenter, 1.5)
        let randomSeed = sin(Double(index) * 1.5 + Double(animationPhase) * 3.14)
        let randomVariation = CGFloat(randomSeed) * 0.2
        let normalizedHeight = min(max((basePattern + randomVariation) * effectiveVolume, 0.1), 1.0)
        return baseHeight + normalizedHeight * (maxHeight - baseHeight)
    }

    private func previewSymmetricHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 28
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)
        let pattern: [CGFloat] = [0.3, 0.45, 0.6, 0.75, 0.85, 0.95, 1.0, 0.9]
        let baseMultiplier = pattern[min(index, pattern.count - 1)]
        let randomSeed = sin(Double(index) * 2.0 + Double(animationPhase) * 2.5)
        let variation = CGFloat(randomSeed) * 0.15
        return baseHeight + (baseMultiplier + variation) * effectiveVolume * (maxHeight - baseHeight)
    }

    private func previewGradientColor(for index: Int, total: Int) -> Color {
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)
        let centerIndex = CGFloat(total) / 2.0
        let distanceFromCenter = abs(CGFloat(index) - centerIndex) / centerIndex
        let basePattern = 1.0 - pow(distanceFromCenter, 1.5)
        let randomSeed = sin(Double(index) * 1.5 + Double(animationPhase) * 3.14)
        let randomVariation = CGFloat(randomSeed) * 0.2
        let normalizedHeight = min(max((basePattern + randomVariation) * effectiveVolume, 0.1), 1.0)

        if normalizedHeight < 0.4 {
            return .green
        } else if normalizedHeight < 0.7 {
            let t = (normalizedHeight - 0.4) / 0.3
            return Color(red: t, green: 1.0, blue: 0)
        } else {
            let t = (normalizedHeight - 0.7) / 0.3
            return Color(red: 1.0, green: 1.0 - t, blue: 0)
        }
    }
}

/// PTT 主界面 - 匹配Flutter UI风格
public struct PTTMainView: View {
    @StateObject private var viewModel = PTTViewModel()
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showMainRoomPicker = false  // 主页面房间切换

    public init() {}

    public var body: some View {
        NavigationView {
            SwiftUI.Group {
                if viewModel.isLoggedIn {
                    mainContent
                } else {
                    LoginView(viewModel: viewModel)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                // 退出登录时重置 tab 到首页
                selectedTab = 0
            }
        }
        // 位置共享：心跳包只存本地，不透传
        // 收到其他用户心跳时更新 peers 显示（仅限服务器返回的心跳响应）
        .onAppear {
            setupLocationCallbacks()
        }
        // Token 过期弹窗
        .alert("登录已过期", isPresented: $viewModel.showTokenExpiredAlert) {
            Button("确定") {
                Task {
                    await viewModel.onTokenExpiredAlertDismissed()
                }
            }
        } message: {
            Text("请重新登录")
        }
        // 后台保活：监听 App 前后台切换
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                viewModel.onEnterForeground()
            case .background:
                viewModel.onEnterBackground()
            case .inactive:
                // 不处理 inactive 状态
                break
            @unknown default:
                break
            }
        }
    }

    /// 设置位置相关回调
    private func setupLocationCallbacks() {
        // 收到 LOC 文本消息时，更新 LocationService.peers
        viewModel.onPeerLocationReceived = { callSign, ssid, latitude, longitude in
            if let lat = latitude, let lon = longitude {
                LocationService.shared.updatePeer(
                    callsign: "\(callSign)-\(ssid)",
                    latitude: lat,
                    longitude: lon
                )
            }
        }

        // 位置发送回调 - 通过文本消息 (type=5) 发送位置 (格式: [loc]lat,lon)
        LocationService.shared.onSendLocation = { [weak viewModel] latitude, longitude in
            guard LocationService.shared.settings.locationShareEnabled else { return }
            let locMessage = String(format: "[loc]%.6f,%.6f", latitude, longitude)
            viewModel?.sendText(locMessage)
        }
    }

    /// 是否处于会议模式全屏显示
    private var isInConferenceFullscreen: Bool {
        selectedTab == 0 && viewModel.currentGroup?.isConferenceMode == true
    }

    private var mainContent: some View {
        ZStack {
            // 普通内容
            VStack(spacing: 0) {
                // 顶部导航栏
                headerBar

                // TabBar
                tabBar

                // 内容区域（禁用滑动切换，只能点击标签切换）
                tabContent
            }
            .background(Color(UIColor.systemGroupedBackground))
            .opacity(isInConferenceFullscreen ? 0 : 1)

            // 会议模式全屏覆盖
            if isInConferenceFullscreen {
                ConferenceModeView(viewModel: viewModel, onExit: {
                    // 退出会议：切换到群组列表页面
                    withAnimation {
                        selectedTab = 1
                    }
                })
                .transition(.opacity)
            }
        }
        .onChange(of: selectedTab) { newTab in
            // 切换到群组 Tab 时静默刷新群组列表
            if newTab == 1 {
                Task {
                    await viewModel.loadGroups()
                }
            }
        }
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            // 会议模式全屏显示在 mainContent 的 ZStack 中，这里只显示普通语音页面
            if viewModel.currentGroup?.isConferenceMode == true {
                // 会议模式时这里显示占位（实际由全屏覆盖层显示）
                Color.clear
            } else {
                VoiceTabView(viewModel: viewModel)
            }
        case 1:
            GroupsTabView(viewModel: viewModel, onEnterConferenceMode: {
                // 进入会议模式：切换到通话页面
                withAnimation {
                    selectedTab = 0
                }
            })
        case 2:
            LocationTabView(myCallsign: "\(viewModel.callSign)-\(viewModel.ssid)")
        case 3:
            SettingsTabView(viewModel: viewModel)
        default:
            VoiceTabView(viewModel: viewModel)
        }
    }

    // MARK: - 顶部导航栏

    private var headerBar: some View {
        HStack {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("PTT 互联")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("\(viewModel.callSign)-\(viewModel.ssid)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
            }

            Spacer()

            // 当前群组显示（点击切换房间）
            if let group = viewModel.currentGroup {
                Button {
                    showMainRoomPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(group.name)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .sheet(isPresented: $showMainRoomPicker) {
                    MainRoomPickerSheet(
                        groups: viewModel.groups,
                        currentGroupId: viewModel.currentGroup?.id,
                        onSelect: { group in
                            Task {
                                do {
                                    try await viewModel.joinGroup(group)
                                    await viewModel.refreshGroupDetail()
                                    showMainRoomPicker = false
                                } catch {
                                    print("[PTTMainView] switchRoom failed: \(error)")
                                    showMainRoomPicker = false
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - TabBar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "headphones", title: "通话", index: 0)
            tabButton(icon: "person.3.fill", title: "群组", index: 1)
            tabButton(icon: "location.fill", title: "位置", index: 2)
            tabButton(icon: "gearshape.fill", title: "设置", index: 3)
        }
        .background(Color.white)
    }

    private func tabButton(icon: String, title: String, index: Int) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == index ? .blue : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .overlay(
            Rectangle()
                .fill(selectedTab == index ? Color.blue : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
    }
}

// MARK: - 登录页面

struct LoginView: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var obscurePassword = true
    @State private var showServerPicker = false

    // 渐变色（青→蓝，和 Logo 呼应）
    private let gradientColors = [
        Color(red: 0.4, green: 0.8, blue: 0.75),  // 青色
        Color(red: 0.2, green: 0.4, blue: 0.6)    // 深蓝
    ]

    // 服务器状态指示颜色
    private var serverStatusColor: Color {
        if viewModel.isLoadingPlatformServers {
            return .gray  // 加载中
        } else if viewModel.platformServerError != nil {
            return .red   // 获取失败（网络错误等）
        } else if viewModel.platformServers.isEmpty {
            return .orange // 无可用服务器
        } else {
            return .green // 正常
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - 顶部渐变区域
                ZStack {
                    // 渐变背景
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 16) {
                        Spacer().frame(height: 60)

                        // Logo 带光晕
                        ZStack {
                            // 光晕效果
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .blur(radius: 20)

                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }

                        // 标题
                        Text("互联")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        // 副标题（带服务器状态指示）
                        HStack(spacing: 6) {
                            Circle()
                                .fill(serverStatusColor)
                                .frame(width: 8, height: 8)
                            Text("NRL21 · Low Latency Voice")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .tracking(1)
                        }

                        Spacer().frame(height: 40)
                    }
                }
                .frame(height: 320)

                // MARK: - 输入区域
                VStack(spacing: 20) {
                    Spacer().frame(height: 30)

                    // 输入框卡片
                    VStack(spacing: 0) {
                        // 服务器选择
                        Button {
                            showServerPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.65))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let server = viewModel.selectedPlatformServer {
                                        Text(server.name)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(server.onlineInfo)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if viewModel.isLoadingPlatformServers {
                                        Text("加载服务器列表...")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("选择服务器")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding()

                        Divider().padding(.leading, 48)

                        // 用户名
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.65))
                                .frame(width: 24)
                            TextField("用户名", text: $viewModel.username)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        .padding()

                        Divider().padding(.leading, 48)

                        // 密码
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.65))
                                .frame(width: 24)
                            if obscurePassword {
                                SecureField("密码", text: $viewModel.password)
                            } else {
                                TextField("密码", text: $viewModel.password)
                                    .textInputAutocapitalization(.never)
                            }
                            Button {
                                obscurePassword.toggle()
                            } label: {
                                Image(systemName: obscurePassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)

                    // 记住密码
                    HStack {
                        Button {
                            viewModel.rememberMe.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.rememberMe ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(viewModel.rememberMe ? Color(red: 0.3, green: 0.6, blue: 0.7) : .gray)
                                Text("记住账号密码")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                    }

                    // 错误信息
                    if let error = viewModel.loginError {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                            Spacer()
                            Button {
                                viewModel.clearLoginError()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // 连接按钮
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("连接服务器")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: Color(red: 0.3, green: 0.5, blue: 0.65).opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .disabled(viewModel.isLoggingIn)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(UIColor.systemGray6))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            // 获取服务器列表（触发网络权限 + 更新状态指示）
            Task {
                await viewModel.fetchPlatformServers()
            }
        }
        .sheet(isPresented: $showServerPicker) {
            ServerPickerSheet(
                servers: viewModel.platformServers,
                customServers: viewModel.customServers,
                selectedServer: viewModel.selectedPlatformServer,
                isLoading: viewModel.isLoadingPlatformServers,
                onSelect: { server in
                    viewModel.selectPlatformServer(server)
                    showServerPicker = false
                },
                onRefresh: {
                    Task {
                        await viewModel.fetchPlatformServers()
                    }
                },
                onAddCustom: { name, host, port in
                    viewModel.addCustomServer(name: name, host: host, port: port)
                },
                onDeleteCustom: { server in
                    viewModel.deleteCustomServer(server)
                }
            )
        }
    }
}

// MARK: - 服务器选择 Sheet

struct ServerPickerSheet: View {
    let servers: [PlatformServer]
    let customServers: [PlatformServer]
    let selectedServer: PlatformServer?
    let isLoading: Bool
    let onSelect: (PlatformServer) -> Void
    let onRefresh: () -> Void
    let onAddCustom: (String, String, String) -> Bool
    let onDeleteCustom: (PlatformServer) -> Void

    // 排序后的服务器列表（按在线人数降序）
    @State private var sortedServers: [PlatformServer] = []
    @State private var showAddCustomSheet = false

    // 配色
    private let serverNameColor = Color(red: 0.04, green: 0.48, blue: 0.55)  // 深青色
    private let onlineColor = Color(red: 0.2, green: 0.65, blue: 0.33)       // 绿色
    private let totalColor = Color(red: 0.96, green: 0.65, blue: 0.14)       // 橙色
    private let customColor = Color(red: 0.55, green: 0.27, blue: 0.68)      // 紫色

    var body: some View {
        NavigationView {
            List {
                // 在线服务器 Section
                if !sortedServers.isEmpty {
                    Section(header: Text("在线服务器")) {
                        ForEach(sortedServers) { server in
                            serverRow(server: server, isCustom: false)
                        }
                    }
                }

                // 自定义服务器 Section
                Section(header: Text("自定义服务器")) {
                    // 已保存的自定义服务器
                    ForEach(customServers) { server in
                        serverRow(server: server, isCustom: true)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onDeleteCustom(customServers[index])
                        }
                    }

                    // 添加自定义服务器按钮
                    Button {
                        showAddCustomSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("添加自定义服务器")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                // 加载中或空状态
                if isLoading && servers.isEmpty && customServers.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("加载服务器列表...")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("选择服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button {
                            onRefresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                // 如果服务器列表为空，自动获取
                if servers.isEmpty {
                    onRefresh()
                } else if sortedServers.isEmpty {
                    // 按在线人数降序排序
                    sortedServers = servers.sorted { $0.online > $1.online }
                }
            }
            .onChange(of: servers) { newServers in
                // 按在线人数降序排序
                sortedServers = newServers.sorted { $0.online > $1.online }
            }
            .sheet(isPresented: $showAddCustomSheet) {
                AddCustomServerSheet(onAdd: onAddCustom)
            }
        }
    }

    @ViewBuilder
    private func serverRow(server: PlatformServer, isCustom: Bool) -> some View {
        Button {
            onSelect(server)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // 服务器名称
                    HStack(spacing: 6) {
                        if isCustom {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(customColor)
                        }
                        Text(server.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isCustom ? customColor : serverNameColor)
                            .lineLimit(2)
                    }

                    // 第二行信息
                    HStack(spacing: 16) {
                        if isCustom {
                            Text("自定义")
                                .font(.system(size: 13))
                                .foregroundColor(customColor)
                        } else {
                            // 在线人数 - 绿色 + 图标
                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 11))
                                Text("在线:\(server.online)")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(server.online > 0 ? onlineColor : .gray)

                            // 总数 - 橙色
                            Text("总数:\(server.total)")
                                .font(.system(size: 13))
                                .foregroundColor(totalColor)
                        }

                        Spacer()

                        // 主机地址 - 灰色
                        Text("\(server.host):\(server.port)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // 选中勾号
                if selectedServer?.id == server.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 添加自定义服务器 Sheet

struct AddCustomServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, String, String) -> Bool

    @State private var serverName = ""
    @State private var serverHost = ""
    @State private var serverPort = "60050"
    @State private var errorMessage: String?

    /// 验证表单输入
    private var validationError: String? {
        let host = serverHost.trimmingCharacters(in: .whitespaces)
        if host.isEmpty {
            return "请输入服务器地址"
        }

        let portStr = serverPort.trimmingCharacters(in: .whitespaces)
        if portStr.isEmpty {
            return "请输入端口号"
        }

        guard let port = UInt16(portStr), port > 0 else {
            return "端口号必须是 1-65535 之间的数字"
        }

        return nil
    }

    /// 表单是否有效
    private var isFormValid: Bool {
        validationError == nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器信息")) {
                    TextField("名称 (可选)", text: $serverName)
                        .autocapitalization(.none)

                    TextField("服务器地址", text: $serverHost)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .textContentType(.URL)

                    TextField("UDP 端口", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section(footer: Text("输入 NRL 服务器的地址和 UDP 端口。\n例如：ptt.example.com:60050")) {
                    EmptyView()
                }
            }
            .navigationTitle("添加自定义服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        // 先验证输入
                        if let error = validationError {
                            errorMessage = error
                            return
                        }

                        if onAdd(serverName, serverHost, serverPort) {
                            dismiss()
                        } else {
                            errorMessage = "添加失败，服务器可能已存在"
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
}

// MARK: - 通话视图

struct VoiceTabView: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var messageText = ""
    @State private var contextMenuRecord: CallRecord?
    @State private var contextMenuTextMessage: TextMessage?
    @State private var contextMenuPosition: CGPoint = .zero

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 多选模式工具栏
                if viewModel.isMultiSelectMode {
                    multiSelectToolbar
                }

                // 讲话者指示（始终显示）
                if let speaker = viewModel.currentSpeaker, !viewModel.isTalking {
                    speakerIndicator(speaker: speaker)
                }

                // 通话历史列表
                callHistoryList

                // PTT控制区域（多选模式下隐藏）
                if !viewModel.isMultiSelectMode {
                    pttControlArea

                    // 消息输入框
                    messageInputBar
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .overlay(
                // PTT 放大切换按钮（屏幕右边缘固定位置）
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPTTExpanded.toggle()
                        // 放大模式下关闭音量弹窗
                        if isPTTExpanded {
                            showSpeakerSlider = false
                            showMicSlider = false
                        }
                    }
                } label: {
                    Image(systemName: isPTTExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                        )
                }
                .padding(.trailing, 8)
                .padding(.bottom, 120),  // 在 PTT 区域右侧
                alignment: .bottomTrailing
            )

            // 微信风格的小气泡菜单 - 语音消息
            if let record = contextMenuRecord {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            contextMenuRecord = nil
                        }
                    }

                VoiceContextMenu(
                    position: contextMenuPosition,
                    onMultiSelect: {
                        viewModel.isMultiSelectMode = true
                        viewModel.selectedRecordIds.insert(record.id)
                        contextMenuRecord = nil
                    },
                    onDelete: {
                        viewModel.deleteRecord(record)
                        contextMenuRecord = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }

            // 微信风格的小气泡菜单 - 文本消息
            if let message = contextMenuTextMessage {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            contextMenuTextMessage = nil
                        }
                    }

                VoiceContextMenu(
                    position: contextMenuPosition,
                    onMultiSelect: {
                        viewModel.isMultiSelectMode = true
                        viewModel.selectedRecordIds.insert(message.id)
                        contextMenuTextMessage = nil
                    },
                    onDelete: {
                        viewModel.deleteTextMessage(message)
                        contextMenuTextMessage = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - 多选模式工具栏

    private var multiSelectToolbar: some View {
        HStack {
            Button("取消") {
                viewModel.isMultiSelectMode = false
                viewModel.selectedRecordIds.removeAll()
            }

            Spacer()

            Text("已选择 \(viewModel.selectedRecordIds.count) 条")
                .font(.subheadline)

            Spacer()

            Button(role: .destructive) {
                viewModel.deleteSelectedRecords()
            } label: {
                Text("删除")
                    .foregroundColor(viewModel.selectedRecordIds.isEmpty ? .gray : .red)
            }
            .disabled(viewModel.selectedRecordIds.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    // MARK: - 讲话者指示

    private func speakerIndicator(speaker: String) -> some View {
        VStack(spacing: 4) {
            SpeakingStatusBar(speaker: speaker, volumeLevel: viewModel.volumeLevel, codec: viewModel.receiveCodec, dmrID: viewModel.currentSpeakerDmrID)

            // 实时语音识别字幕
            if viewModel.speechRecognitionEnabled,
               !viewModel.currentTranscription.isEmpty,
               viewModel.transcriptionSpeaker == speaker {
                Text(viewModel.currentTranscription)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentTranscription)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - 通话历史列表

    /// 合并的消息列表（语音 + 文本）按时间排序
    private var combinedMessages: [(id: String, timestamp: Date, isVoice: Bool, voiceRecord: CallRecord?, textMessage: TextMessage?)] {
        var items: [(id: String, timestamp: Date, isVoice: Bool, voiceRecord: CallRecord?, textMessage: TextMessage?)] = []

        // 添加语音记录
        for record in viewModel.currentGroupCallHistory {
            items.append((id: record.id, timestamp: record.startTime, isVoice: true, voiceRecord: record, textMessage: nil))
        }

        // 添加文本消息（按当前群组过滤）
        for message in viewModel.currentGroupTextMessages {
            items.append((id: message.id, timestamp: message.timestamp, isVoice: false, voiceRecord: nil, textMessage: message))
        }

        // 按时间正序排列（最新的在下面）
        return items.sorted { $0.timestamp < $1.timestamp }
    }

    private var callHistoryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(combinedMessages, id: \.id) { item in
                        if item.isVoice, let record = item.voiceRecord {
                            callHistoryBubble(record: record)
                                .id(item.id)
                        } else if let message = item.textMessage {
                            textMessageBubble(message: message)
                                .id(item.id)
                        }
                    }
                    // 底部锚点
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onAppear {
                // 初始滚动到底部
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: combinedMessages.count) { _ in
                // 新消息时滚动到底部
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 文本消息气泡

    private func textMessageBubble(message: TextMessage) -> some View {
        let isMe = message.isSelf
        let timeStr = formatTime(message.timestamp)
        let isSelected = viewModel.selectedRecordIds.contains(message.id)

        return HStack {
            // 多选模式显示选择框
            if viewModel.isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 22))
                    .onTapGesture {
                        if isSelected {
                            viewModel.selectedRecordIds.remove(message.id)
                        } else {
                            viewModel.selectedRecordIds.insert(message.id)
                        }
                    }
            }

            if isMe { Spacer() }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                // 时间和呼号
                HStack(spacing: 4) {
                    if !isMe {
                        Text(message.displayName)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text(timeStr)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if isMe {
                        Text("我")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // 文本气泡
                TextBubble(
                    message: message,
                    onTap: {
                        if viewModel.isMultiSelectMode {
                            if isSelected {
                                viewModel.selectedRecordIds.remove(message.id)
                            } else {
                                viewModel.selectedRecordIds.insert(message.id)
                            }
                        }
                    },
                    onLongPress: { position in
                        if !viewModel.isMultiSelectMode {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            contextMenuPosition = position
                            contextMenuTextMessage = message
                        }
                    }
                )
            }

            if !isMe { Spacer() }
        }
    }

    private func callHistoryBubble(record: CallRecord) -> some View {
        let isMe = record.isSelf
        let timeStr = formatTime(record.startTime)
        let durationStr = "\(max(1, Int(ceil(record.duration))))\""
        let isPlaying = viewModel.playingRecordId == record.id
        let isSelected = viewModel.selectedRecordIds.contains(record.id)

        return HStack {
            // 多选模式显示选择框
            if viewModel.isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 22))
                    .onTapGesture {
                        if isSelected {
                            viewModel.selectedRecordIds.remove(record.id)
                        } else {
                            viewModel.selectedRecordIds.insert(record.id)
                        }
                    }
            }

            if isMe { Spacer() }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                // 时间和呼号
                HStack(spacing: 4) {
                    if !isMe {
                        Text("\(record.callSign)-\(record.ssid)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text(timeStr)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if isMe {
                        Text("我")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                // 气泡
                VoiceBubble(
                    record: record,
                    isPlaying: isPlaying,
                    durationStr: durationStr,
                    onTap: {
                        if viewModel.isMultiSelectMode {
                            // 多选模式下点击切换选中状态
                            if isSelected {
                                viewModel.selectedRecordIds.remove(record.id)
                            } else {
                                viewModel.selectedRecordIds.insert(record.id)
                            }
                        } else {
                            // 正常模式下点击播放
                            print("[VoiceTabView] Tapped record: \(record.id)")
                            viewModel.playRecord(record)
                        }
                    },
                    onLongPress: { position in
                        if !viewModel.isMultiSelectMode {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            contextMenuPosition = position
                            contextMenuRecord = record
                        }
                    }
                )

                // 语音识别文字（如果有）
                if let transcription = record.transcription, !transcription.isEmpty {
                    Text(transcription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: 200, alignment: isMe ? .trailing : .leading)
                }
            }

            if !isMe { Spacer() }
        }
    }

    // MARK: - PTT控制区域

    private var pttControlArea: some View {
        VStack(spacing: 8) {
            // 第一行：4个控制按钮 + PTT按钮居中
            HStack(spacing: 12) {
                // 左侧：音量、麦克风（放大模式下隐藏）
                Group {
                    CompactControlButton(
                        icon: "speaker.wave.2.fill",
                        value: viewModel.speakerVolume,
                        color: .blue,
                        onTap: { showSpeakerSlider.toggle() }
                    )
                    .overlay(
                        CompactVolumePopover(
                            isPresented: $showSpeakerSlider,
                            value: $viewModel.speakerVolume,
                            icon: "speaker.wave.2.fill",
                            color: .blue
                        ),
                        alignment: .top
                    )

                    CompactControlButton(
                        icon: "mic.fill",
                        value: viewModel.micVolume,
                        color: .orange,
                        onTap: { showMicSlider.toggle() }
                    )
                    .overlay(
                        CompactVolumePopover(
                            isPresented: $showMicSlider,
                            value: $viewModel.micVolume,
                            icon: "mic.fill",
                            color: .orange
                        ),
                        alignment: .top
                    )
                }
                .opacity(isPTTExpanded ? 0 : 1)
                .scaleEffect(isPTTExpanded ? 0.8 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPTTExpanded)

                // 中间：紧凑PTT按钮（放大模式下 2 倍，向上扩展）
                CompactPTTButton(viewModel: viewModel)
                    .scaleEffect(isPTTExpanded ? 2.0 : 1, anchor: .bottom)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPTTExpanded)

                // 右侧：编码切换、降噪（放大模式下隐藏）
                Group {
                    CompactCodecButton(
                        useOpus: viewModel.txCodec == .opus,
                        isTalking: viewModel.isTalking,
                        isConferenceMode: viewModel.isConferenceMode,
                        onTap: {
                            // 会议模式下锁定 G711，不允许切换
                            guard !viewModel.isConferenceMode else { return }
                            if viewModel.txCodec == .opus {
                                // 切换到 G711
                                viewModel.txCodec = .g711
                            } else {
                                // 切换到 Opus，必须开启降噪
                                viewModel.txCodec = .opus
                                viewModel.noiseReductionEnabled = true
                            }
                        }
                    )

                    CompactNoiseButton(
                        isEnabled: viewModel.noiseReductionEnabled,
                        isLocked: viewModel.txCodec == .opus,  // Opus模式下锁定
                        isTalking: viewModel.isTalking,  // 发言时禁用
                        onTap: {
                            // Opus模式下或发言时不能更改
                            if viewModel.txCodec != .opus && !viewModel.isTalking {
                                viewModel.noiseReductionEnabled.toggle()
                            }
                        }
                    )
                }
                .opacity(isPTTExpanded ? 0 : 1)
                .scaleEffect(isPTTExpanded ? 0.8 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPTTExpanded)
            }
            .padding(.horizontal, 16)

            // 第二行：状态文字（放大模式下隐藏）
            Group {
                if viewModel.isTalking {
                    HStack(spacing: 4) {
                        Text(viewModel.pttMode == PTTMode.holdToTalk ? "松开结束" : "再按结束")
                            .foregroundColor(.red)
                        Text(viewModel.formatDuration(viewModel.talkingDuration))
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                } else if viewModel.currentSpeaker == nil {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .opacity(isPTTExpanded ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isPTTExpanded)
        }
        .padding(.vertical, 10)
    }

    @State private var showSpeakerSlider = false
    @State private var showMicSlider = false
    @State private var isPTTExpanded = false  // PTT放大模式

    private var statusText: String {
        if viewModel.isTalking {
            return viewModel.pttMode == PTTMode.holdToTalk ? "松开 结束" : "再按 结束"
        } else if viewModel.currentSpeaker != nil {
            return "\(viewModel.currentSpeaker!) 正在讲话"
        } else if viewModel.isConnected {
            return viewModel.pttMode == PTTMode.holdToTalk ? "按住 说话" : "点击 说话"
        } else {
            return "未连接"
        }
    }

    // MARK: - 消息输入框

    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $messageText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(20)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(messageText.isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color.white)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        viewModel.sendText(text)
        messageText = ""
    }

    // MARK: - 辅助方法

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 群组视图

struct GroupsTabView: View {
    @ObservedObject var viewModel: PTTViewModel
    /// 进入会议模式回调（切换到通话tab）
    var onEnterConferenceMode: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showCreateGroupSheet = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框和创建按钮
            searchBar

            // 群组网格
            ScrollView {
                if viewModel.groups.isEmpty && !isRefreshing {
                    emptyView
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(sortedAndFilteredGroups) { group in
                            GroupCardWithGesture(
                                group: group,
                                isSelected: viewModel.currentGroup?.id == group.id,
                                viewModel: viewModel,
                                onJoinGroup: { joinGroup(group) },
                                onEnterConferenceMode: onEnterConferenceMode
                            )
                        }
                    }
                    .padding()
                }
            }
            .refreshable {
                await viewModel.loadGroups()
            }
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            GroupEditSheet(viewModel: viewModel, mode: .create, onComplete: {
                showCreateGroupSheet = false
            })
        }
    }

    /// 静默刷新（供外部调用）
    func silentRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await viewModel.loadGroups()
            isRefreshing = false
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("搜索群组名称或ID...", text: $searchText)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            // 管理员可创建群组
            if viewModel.isAdmin {
                Button(action: {
                    showCreateGroupSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无群组")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    /// 排序并过滤后的群组列表（按 ID 升序）
    private var sortedAndFilteredGroups: [PttGroup] {
        let sorted = viewModel.groups.sorted { $0.id < $1.id }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            String($0.id).contains(searchText)
        }
    }

    private func joinGroup(_ group: PttGroup) {
        Task {
            do {
                try await viewModel.joinGroup(group)
                await viewModel.refreshGroupDetail()
                await viewModel.loadGroups()
            } catch {
                print("[GroupsTab] Join group failed: \(error)")
            }
        }
    }
}

// MARK: - 群组卡片（带手势处理）

struct GroupCardWithGesture: View {
    let group: PttGroup
    let isSelected: Bool
    @ObservedObject var viewModel: PTTViewModel
    let onJoinGroup: () -> Void
    /// 进入会议模式回调（切换到通话tab）
    var onEnterConferenceMode: (() -> Void)? = nil

    @State private var isLongPressing = false
    @State private var navigateToDetail = false

    var body: some View {
        GroupCardContent(
            group: group,
            isSelected: isSelected,
            onEnterConference: group.isConferenceMode ? {
                // 会议群组：加入并进入会议模式
                enterConferenceRoom()
            } : nil
        )
        .scaleEffect(isLongPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        .background(
            NavigationLink(
                destination: GroupDetailFullScreenView(viewModel: viewModel, group: group),
                isActive: $navigateToDetail,
                label: { EmptyView() }
            )
            .hidden()
        )
        .onAppear {
            // 每次卡片出现时重置导航状态，防止重复进入问题
            navigateToDetail = false
        }
        .onChange(of: navigateToDetail) { newValue in
            // 从详情页返回时刷新群组列表
            if !newValue {
                Task {
                    await viewModel.loadGroups()
                }
            }
        }
        .onTapGesture {
            // 会议群组：点击卡片空白区域进入详情
            // 普通群组：短按进入详情
            guard !navigateToDetail else { return }
            navigateToDetail = true
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isLongPressing = pressing
        }, perform: {
            // 长按切换群组
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onJoinGroup()
        })
    }

    /// 进入会议房间
    private func enterConferenceRoom() {
        Task {
            // 1. 加入群组（如果不是当前群组）
            if viewModel.currentGroup?.id != group.id {
                do {
                    try await viewModel.joinGroup(group)
                    await viewModel.refreshGroupDetail()
                } catch {
                    print("[GroupCard] Join conference group failed: \(error)")
                    return
                }
            }
            // 2. 回调切换到通话页面（tab 0），自动显示会议模式
            await MainActor.run {
                onEnterConferenceMode?()
            }
        }
    }
}

// MARK: - 群组卡片内容（纯显示）

struct GroupCardContent: View {
    let group: PttGroup
    let isSelected: Bool
    /// 会议群组的进入回调
    var onEnterConference: (() -> Void)? = nil

    var body: some View {
        if group.isConferenceMode {
            // 会议群组特殊 UI
            conferenceGroupCard
        } else {
            // 普通群组卡片
            normalGroupCard
        }
    }

    // MARK: - 会议群组卡片

    private var conferenceGroupCard: some View {
        VStack(spacing: 10) {
            // 图标
            Image(systemName: "person.3.fill")
                .font(.system(size: 28))
                .foregroundColor(isHighlighted ? .white : .gray)

            // 群组名
            Text(group.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isHighlighted ? .white : .primary)
                .lineLimit(1)

            // 会议模式标签
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("会议模式")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isHighlighted ? .white.opacity(0.9) : .red)

            // 在线人数
            Text("在线: \(group.onlineCount) 人")
                .font(.caption)
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .gray)

            // 进入会议房间按钮
            Button {
                onEnterConference?()
            } label: {
                HStack(spacing: 4) {
                    Text("进入会议房间")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isHighlighted ? .blue : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHighlighted ? Color.white : Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(conferenceCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.5), lineWidth: isSelected ? 2 : 0)
        )
    }

    // MARK: - 普通群组卡片

    private var normalGroupCard: some View {
        VStack(spacing: 12) {
            Image(systemName: group.typeIcon)
                .font(.system(size: 32))
                .foregroundColor(isHighlighted ? .white : .gray)

            Text(group.name)
                .font(.headline)
                .foregroundColor(isHighlighted ? .white : .primary)
                .lineLimit(1)

            Text("ID: \(group.id)")
                .font(.caption)
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .gray)

            Text("在线: \(group.onlineCount)/\(group.memberCount)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isHighlighted ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(isHighlighted ? .white : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBackground)
        .cornerRadius(16)
    }

    private var isHighlighted: Bool {
        isSelected || group.hasOnlineMembers
    }

    private var cardBackground: Color {
        if isSelected {
            return .blue
        } else if group.hasOnlineMembers {
            return Color.green.opacity(0.8)
        } else {
            return Color(UIColor.systemGray4).opacity(0.5)
        }
    }

    private var conferenceCardBackground: Color {
        if isSelected {
            return Color(hex: "1A1A2E")  // 深蓝黑（会议主题色）
        } else if group.hasOnlineMembers {
            return Color(hex: "16213E")  // 深蓝
        } else {
            return Color(UIColor.systemGray4).opacity(0.5)
        }
    }
}

struct GroupCard: View {
    let group: PttGroup
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isLongPressing = false
    @GestureState private var isDetectingLongPress = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: group.typeIcon)
                .font(.system(size: 32))
                .foregroundColor(isHighlighted ? .white : .gray)

            Text(group.name)
                .font(.headline)
                .foregroundColor(isHighlighted ? .white : .primary)
                .lineLimit(1)

            Text("ID: \(group.id)")
                .font(.caption)
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .gray)

            Text("在线: \(group.onlineCount)/\(group.memberCount)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isHighlighted ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(isHighlighted ? .white : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBackground)
        .cornerRadius(16)
        .scaleEffect(isDetectingLongPress ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDetectingLongPress)
        .gesture(
            // 使用 ExclusiveGesture 确保长按和点击不会同时触发
            ExclusiveGesture(
                // 长按手势 - 切换群组
                LongPressGesture(minimumDuration: 0.5)
                    .updating($isDetectingLongPress) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
                    .onEnded { _ in
                        // 触发震动反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onLongPress()
                    },
                // 点击手势 - 进入详情
                TapGesture()
                    .onEnded {
                        onTap()
                    }
            )
        )
    }

    /// 是否高亮（当前群组或有在线成员）
    private var isHighlighted: Bool {
        isSelected || group.hasOnlineMembers
    }

    /// 卡片背景色：当前蓝色，有在线绿色，无人灰色
    private var cardBackground: Color {
        if isSelected {
            return .blue
        } else if group.hasOnlineMembers {
            return Color.green.opacity(0.8)
        } else {
            return Color(UIColor.systemGray4).opacity(0.5)
        }
    }
}

// MARK: - 群组详情视图

struct GroupDetailView: View {
    @ObservedObject var viewModel: PTTViewModel
    let group: PttGroup
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var devices: [PttDevice] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showChangeGroupSheet = false
    @State private var selectedDeviceForGroupChange: PttDevice?
    @State private var isOperating = false
    @State private var selectedDeviceForEdit: PttDevice?
    @State private var selectedDeviceForAT: PttDevice?
    @State private var deviceToDelete: PttDevice?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 群组信息头部
                groupHeader

                // 搜索框
                searchBar

                // 设备列表
                deviceList
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadDevices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await loadDevices()
        }
        .sheet(item: $selectedDeviceForGroupChange) { device in
            ChangeGroupSheet(
                viewModel: viewModel,
                device: device,
                currentGroupId: group.id,
                onComplete: {
                    selectedDeviceForGroupChange = nil
                    Task { await loadDevices() }
                }
            )
        }
        .sheet(item: $selectedDeviceForEdit) { device in
            DeviceEditSheet(viewModel: viewModel, device: device) {
                selectedDeviceForEdit = nil
                Task { await loadDevices() }
            }
        }
        .sheet(item: $selectedDeviceForAT) { device in
            ATCommandSheet(viewModel: viewModel, device: device)
        }
        .overlay {
            if isOperating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                deviceToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let device = deviceToDelete {
                    deleteDevice(device)
                }
            }
        } message: {
            if let device = deviceToDelete {
                Text("此操作将删除设备 \(device.displayName)，设备上线后会重新创建设备，是否继续？")
            }
        }
    }

    // MARK: - 群组信息头部

    private var groupHeader: some View {
        HStack(spacing: 16) {
            // 群组类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                Image(systemName: group.typeIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.id) - \(group.name)")
                    .font(.headline)

                Text("类型: \(group.typeName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("在线: \(onlineCount)/\(devices.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 加入按钮
            joinButton
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }

    private var joinButton: some View {
        let isCurrentGroup = viewModel.currentGroup?.id == group.id

        return Button {
            joinGroup()
        } label: {
            Text(isCurrentGroup ? "当前群组" : "加入群组")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isCurrentGroup ? Color.gray : Color.blue)
                .cornerRadius(20)
        }
        .disabled(isCurrentGroup)
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索呼号或设备名称...", text: $searchText)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .padding()
    }

    // MARK: - 设备列表

    private var deviceList: some View {
        SwiftUI.Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red.opacity(0.7))
                    Text(error)
                        .foregroundColor(.red)
                    Button("重试") {
                        Task { await loadDevices() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredDevices.isEmpty {
                Text(searchText.isEmpty ? "暂无设备" : "未找到匹配的设备")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredDevices) { device in
                        DeviceRow(
                            device: device,
                            isAdmin: viewModel.isAdmin,
                            onToggleMuteReceive: { toggleMuteReceive(device) },
                            onToggleMuteTransmit: { toggleMuteTransmit(device) },
                            onChangeGroup: { selectedDeviceForGroupChange = device },
                            onEdit: { selectedDeviceForEdit = device },
                            onAT: { selectedDeviceForAT = device },
                            onDelete: {
                                deviceToDelete = device
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 计算属性

    private var onlineCount: Int {
        devices.filter { $0.isOnline }.count
    }

    /// 过滤并排序的设备列表（在线设备置顶）
    private var filteredDevices: [PttDevice] {
        let filtered: [PttDevice]
        if searchText.isEmpty {
            filtered = devices
        } else {
            let query = searchText.lowercased()
            filtered = devices.filter {
                $0.callsign.lowercased().contains(query) ||
                ($0.name?.lowercased().contains(query) ?? false)
            }
        }
        // 在线设备置顶，同状态按呼号排序
        return filtered.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline  // 在线设备排在前面
            }
            return lhs.callsign < rhs.callsign
        }
    }

    // MARK: - 操作方法

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            let detail = try await viewModel.getGroupDetail(groupId: group.id)
            devices = detail.devices
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func joinGroup() {
        Task {
            isOperating = true
            do {
                try await viewModel.joinGroup(group)
                await viewModel.refreshGroupDetail()
                await viewModel.loadGroups()
            } catch {
                print("[GroupDetail] Join group failed: \(error)")
            }
            isOperating = false
        }
    }

    private func toggleMuteReceive(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.setDeviceMuteReceive(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    mute: !device.isMuteReceive
                )
                await loadDevices()
            } catch {
                print("[GroupDetail] Toggle mute receive failed: \(error)")
            }
            isOperating = false
        }
    }

    private func toggleMuteTransmit(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.setDeviceMuteTransmit(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    mute: !device.isMuteTransmit
                )
                await loadDevices()
            } catch {
                print("[GroupDetail] Toggle mute transmit failed: \(error)")
            }
            isOperating = false
        }
    }

    private func deleteDevice(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                let success = try await viewModel.apiService.deleteDevice(device: device)
                if success {
                    // 从本地列表中移除
                    await MainActor.run {
                        devices.removeAll { $0.id == device.id }
                    }
                }
            } catch {
                print("[GroupDetail] Delete device failed: \(error)")
            }
            deviceToDelete = nil
            isOperating = false
        }
    }
}

// MARK: - 全屏群组详情视图（匹配 Flutter UI）

struct GroupDetailFullScreenView: View {
    @ObservedObject var viewModel: PTTViewModel
    let group: PttGroup
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var devices: [PttDevice] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var selectedDeviceForGroupChange: PttDevice?
    @State private var isOperating = false
    @State private var showChangeGroupAlert = false

    // 新增：我的设备 & 只显示在线
    @State private var myDevices: [PttDevice] = []
    @State private var showOnlyOnline = false
    @State private var isMyDevicesSectionExpanded = false

    // 新增：群组编辑
    @State private var showEditGroupSheet = false

    // 新增：设备配置和AT指令
    @State private var selectedDeviceForEdit: PttDevice?
    @State private var selectedDeviceForAT: PttDevice?

    // 新增：设备删除
    @State private var deviceToDelete: PttDevice?
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 自定义顶部导航栏
            customNavigationBar

            // 群组信息头部
            groupHeader

            // 搜索框
            searchBar

            // 设备列表
            deviceList
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .task {
            await loadDevices()
        }
        .alert("选择目标群组", isPresented: $showChangeGroupAlert) {
            ForEach(viewModel.groups.sorted { $0.id < $1.id }) { targetGroup in
                if targetGroup.id != group.id {
                    Button(targetGroup.name) {
                        if let device = selectedDeviceForGroupChange {
                            changeDeviceGroup(device: device, to: targetGroup)
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {
                selectedDeviceForGroupChange = nil
            }
        } message: {
            if let device = selectedDeviceForGroupChange {
                Text("将 \(device.displayName) 移至哪个群组？")
            }
        }
        .overlay {
            if isOperating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onDisappear {
            // 返回群组列表时延迟刷新，避免干扰导航动画
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒延迟
                await viewModel.loadGroups()
            }
        }
        .sheet(isPresented: $showEditGroupSheet) {
            GroupEditSheet(viewModel: viewModel, mode: .edit(group), onComplete: {
                showEditGroupSheet = false
                // 编辑或删除后返回列表
                dismiss()
            })
        }
        .sheet(item: $selectedDeviceForEdit) { device in
            DeviceEditSheet(viewModel: viewModel, device: device) {
                selectedDeviceForEdit = nil
                Task { await loadDevices() }
            }
        }
        .sheet(item: $selectedDeviceForAT) { device in
            ATCommandSheet(viewModel: viewModel, device: device)
        }
        .alert("删除设备", isPresented: $showDeleteAlert, presenting: deviceToDelete) { device in
            Button("取消", role: .cancel) {
                deviceToDelete = nil
            }
            Button("删除", role: .destructive) {
                deleteDevice(device)
            }
        } message: { device in
            Text("此操作将删除设备 \(device.displayName)，设备上线后会重新创建设备，是否继续？")
        }
    }

    // MARK: - 删除设备

    private func deleteDevice(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                let success = try await viewModel.apiService.deleteDevice(device: device)
                if success {
                    // 从本地列表中移除
                    await MainActor.run {
                        devices.removeAll { $0.id == device.id }
                    }
                }
            } catch {
                print("[GroupDetailFullScreen] Delete device failed: \(error)")
            }
            deviceToDelete = nil
            isOperating = false
        }
    }

    // MARK: - 自定义顶部导航栏

    private var customNavigationBar: some View {
        HStack {
            // 返回按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 44, height: 44)

            Spacer()

            // 标题
            Text(group.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // 管理员编辑按钮
            if viewModel.isAdmin {
                Button {
                    showEditGroupSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }
                .frame(width: 44, height: 44)
            }

            // 刷新按钮
            Button {
                Task { await loadDevices() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color.white)
    }

    // MARK: - 群组信息头部

    private var groupHeader: some View {
        HStack(spacing: 16) {
            // 群组类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
                    .frame(width: 70, height: 70)
                Image(systemName: group.typeIcon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text("\(group.id) - \(group.name)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("类型: \(group.typeName)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("在线: \(onlineCount)/\(devices.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 加入按钮
            joinButton
        }
        .padding(16)
        .background(Color.blue.opacity(0.08))
    }

    private var joinButton: some View {
        let isCurrentGroup = viewModel.currentGroup?.id == group.id

        return Button {
            joinGroup()
        } label: {
            Text(isCurrentGroup ? "当前群组" : "加入群组")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isCurrentGroup ? Color.gray.opacity(0.6) : Color.blue)
                .cornerRadius(20)
        }
        .disabled(isCurrentGroup)
    }

    // MARK: - 搜索框和过滤器

    private var searchBar: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
                TextField("搜索呼号或设备名称...", text: $searchText)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)

            // 只显示在线开关
            HStack {
                Toggle(isOn: $showOnlyOnline) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("只显示在线")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 设备列表

    private var deviceList: some View {
        SwiftUI.Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red.opacity(0.6))
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await loadDevices() }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // 我的设备快捷加入区
                        if !myDevicesNotInGroup.isEmpty {
                            myDevicesSection
                        }

                        // 群组设备列表
                        if filteredDevices.isEmpty {
                            Text(searchText.isEmpty && !showOnlyOnline ? "暂无设备" : "未找到匹配的设备")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(filteredDevices) { device in
                                DeviceCardView(
                                    device: device,
                                    isAdmin: viewModel.isAdmin,
                                    onToggleMuteReceive: { toggleMuteReceive(device) },
                                    onToggleMuteTransmit: { toggleMuteTransmit(device) },
                                    onChangeGroup: {
                                        selectedDeviceForGroupChange = device
                                        showChangeGroupAlert = true
                                    },
                                    onEdit: { selectedDeviceForEdit = device },
                                    onAT: { selectedDeviceForAT = device },
                                    onDelete: {
                                        deviceToDelete = device
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await loadDevices()
                }
            }
        }
    }

    // MARK: - 我的设备快捷加入区

    private var myDevicesSection: some View {
        VStack(spacing: 0) {
            // 折叠标题
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMyDevicesSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("我的设备加入")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("(\(myDevicesNotInGroup.count))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: isMyDevicesSectionExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)

            // 设备列表
            if isMyDevicesSectionExpanded {
                VStack(spacing: 8) {
                    ForEach(myDevicesNotInGroup) { device in
                        HStack {
                            Image(systemName: device.devModelIcon)
                                .foregroundColor(device.isOnline ? .green : .gray)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(device.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                    // 显示当前所在房间名
                                    if let groupName = groupName(for: device.groupId) {
                                        Text("[\(groupName)]")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                    }
                                }
                                if let name = device.name, !name.isEmpty {
                                    Text(name)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                moveDeviceToCurrentGroup(device)
                            } label: {
                                Text("加入")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 计算属性

    private var onlineCount: Int {
        devices.filter { $0.isOnline }.count
    }

    /// 过滤并排序的设备列表（在线设备置顶，支持只显示在线）
    private var filteredDevices: [PttDevice] {
        var filtered: [PttDevice]

        // 先应用搜索过滤
        if searchText.isEmpty {
            filtered = devices
        } else {
            let query = searchText.lowercased()
            filtered = devices.filter {
                $0.callsign.lowercased().contains(query) ||
                ($0.name?.lowercased().contains(query) ?? false)
            }
        }

        // 应用"只显示在线"过滤
        if showOnlyOnline {
            filtered = filtered.filter { $0.isOnline }
        }

        // 在线设备置顶，同状态按呼号排序
        return filtered.sorted { lhs, rhs in
            if lhs.isOnline != rhs.isOnline {
                return lhs.isOnline  // 在线设备排在前面
            }
            return lhs.callsign < rhs.callsign
        }
    }

    /// 不在当前群组的"我的设备"
    private var myDevicesNotInGroup: [PttDevice] {
        myDevices.filter { $0.groupId != group.id }
    }

    /// 根据群组 ID 获取群组名称
    private func groupName(for groupId: Int) -> String? {
        viewModel.groups.first { $0.id == groupId }?.name
    }

    // MARK: - 操作方法

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            // 并行加载群组设备和我的设备
            async let groupDetailTask = viewModel.getGroupDetail(groupId: group.id)
            async let myDevicesTask = viewModel.getMyDevices()

            let detail = try await groupDetailTask
            devices = detail.devices

            // 加载我的设备（忽略错误）
            if let myDevs = try? await myDevicesTask {
                myDevices = myDevs
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func joinGroup() {
        Task {
            isOperating = true
            do {
                try await viewModel.joinGroup(group)
                await viewModel.refreshGroupDetail()
                await viewModel.loadGroups()
            } catch {
                print("[GroupDetail] Join group failed: \(error)")
            }
            isOperating = false
        }
    }

    /// 将我的设备加入当前群组
    private func moveDeviceToCurrentGroup(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                try await viewModel.moveDeviceToGroup(device: device, targetGroupId: group.id)
                try await viewModel.joinGroup(group)  // 也切换当前群组
                await viewModel.refreshGroupDetail()   // 刷新UI
                await loadDevices()  // 刷新设备列表
            } catch {
                print("[GroupDetail] Move device to group failed: \(error)")
            }
            isOperating = false
        }
    }

    private func toggleMuteReceive(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.setDeviceMuteReceive(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    mute: !device.isMuteReceive
                )
                await loadDevices()
            } catch {
                print("[GroupDetail] Toggle mute receive failed: \(error)")
            }
            isOperating = false
        }
    }

    private func toggleMuteTransmit(_ device: PttDevice) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.setDeviceMuteTransmit(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    mute: !device.isMuteTransmit
                )
                await loadDevices()
            } catch {
                print("[GroupDetail] Toggle mute transmit failed: \(error)")
            }
            isOperating = false
        }
    }

    private func changeDeviceGroup(device: PttDevice, to targetGroup: PttGroup) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.changeDeviceGroup(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    newGroupId: targetGroup.id
                )
                try await viewModel.joinGroup(targetGroup)  // 切换当前群组
                await viewModel.refreshGroupDetail()         // 刷新UI
                await loadDevices()
            } catch {
                print("[GroupDetail] Change group failed: \(error)")
            }
            selectedDeviceForGroupChange = nil
            isOperating = false
        }
    }
}

// MARK: - 设备卡片视图（匹配 Flutter UI）

struct DeviceCardView: View {
    let device: PttDevice
    let isAdmin: Bool  // 是否管理员（控制操作按钮显示）
    let onToggleMuteReceive: () -> Void
    let onToggleMuteTransmit: () -> Void
    let onChangeGroup: () -> Void
    var onEdit: (() -> Void)? = nil  // 配置回调
    var onAT: (() -> Void)? = nil    // AT指令回调
    var onDelete: (() -> Void)? = nil  // 删除回调

    @State private var isExpanded = false

    // 是否是硬件设备（支持AT指令）
    private var isHardwareDevice: Bool {
        return device.devModel < 100 || device.devModel == 200
    }

    var body: some View {
        VStack(spacing: 0) {
            // 主内容行
            HStack(spacing: 8) {
                // 设备型号图标
                Image(systemName: device.devModelIcon)
                    .font(.system(size: 22))
                    .foregroundColor(device.isOnline ? Color(red: 0.2, green: 0.7, blue: 0.3) : .gray)
                    .frame(width: 36)

                // 呼号-SSID 一排显示（点击展开区域）
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(device.callsign)-\(device.ssid)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(device.isOnline ? .primary : .secondary)
                        .lineLimit(1)

                    if let name = device.name, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 12))
                            .foregroundColor(device.isOnline ? Color(red: 0.2, green: 0.6, blue: 0.3) : .secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

                Spacer(minLength: 4)

                // 操作按钮（仅管理员可见）
                if isAdmin {
                    HStack(spacing: 6) {
                        Button(action: onToggleMuteReceive) {
                            Text("禁收")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(device.isMuteReceive ? .orange : .gray)
                                .frame(width: 40, height: 28)
                                .background(device.isMuteReceive ? Color.orange.opacity(0.15) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(device.isMuteReceive ? Color.orange : Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .cornerRadius(5)
                        }

                        Button(action: onToggleMuteTransmit) {
                            Text("禁发")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(device.isMuteTransmit ? .red : .gray)
                                .frame(width: 40, height: 28)
                                .background(device.isMuteTransmit ? Color.red.opacity(0.15) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(device.isMuteTransmit ? Color.red : Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .cornerRadius(5)
                        }

                        // 删除按钮
                        if let deleteAction = onDelete {
                            Button(action: deleteAction) {
                                Text("删除")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(width: 40, height: 28)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                                    .cornerRadius(5)
                            }
                        }

                        Button(action: onChangeGroup) {
                            Text("换组")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                                .frame(width: 40, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.green, lineWidth: 1)
                                )
                                .cornerRadius(5)
                        }
                    }
                    .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            // 展开详情
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .padding(.horizontal, 16)

                    HStack(alignment: .top, spacing: 16) {
                        // 左侧：设备详情
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRowNew(label: "状态", value: device.statusText)
                            DetailRowNew(label: "设备型号", value: device.devModelName)
                            if device.rfType != 0 {
                                DetailRowNew(label: "射频类型", value: device.rfTypeName)
                            }
                            if let qth = device.qth, !qth.isEmpty {
                                DetailRowNew(label: "QTH", value: qth)
                            }
                            if let lastVoice = device.formattedLastVoiceTime {
                                DetailRowNew(label: "最后通话", value: lastVoice)
                            }
                        }

                        Spacer()

                        // 右侧：操作按钮（仅管理员可见）
                        if isAdmin {
                            VStack(spacing: 8) {
                                // 配置按钮
                                if let onEdit = onEdit {
                                    Button(action: onEdit) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "gearshape.fill")
                                            Text("配置")
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 72)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                    }
                                }

                                // AT指令按钮（仅硬件设备显示）
                                if let onAT = onAT, isHardwareDevice {
                                    Button(action: onAT) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "terminal.fill")
                                            Text("AT")
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 72)
                                        .padding(.vertical, 8)
                                        .background(Color.purple)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(device.isOnline ? Color.green.opacity(0.12) : Color.white)
        .cornerRadius(12)
        // 长按菜单
        .contextMenu {
            if isAdmin {
                Button {
                    onToggleMuteReceive()
                } label: {
                    Label(device.isMuteReceive ? "解除禁收" : "禁止接收", systemImage: device.isMuteReceive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }

                Button {
                    onToggleMuteTransmit()
                } label: {
                    Label(device.isMuteTransmit ? "解除禁发" : "禁止发送", systemImage: device.isMuteTransmit ? "mic.fill" : "mic.slash.fill")
                }

                Button {
                    onChangeGroup()
                } label: {
                    Label("更换群组", systemImage: "arrow.left.arrow.right")
                }

                Divider()

                if let onEdit = onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("设备配置", systemImage: "gearshape.fill")
                    }
                }

                if let onAT = onAT, isHardwareDevice {
                    Button {
                        onAT()
                    } label: {
                        Label("AT 指令", systemImage: "terminal.fill")
                    }
                }
            }

            // 删除选项（所有用户可见）
            if let deleteAction = onDelete {
                Divider()

                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    Label("删除设备", systemImage: "trash.fill")
                }
            }
        }
    }
}

// MARK: - 新版标签按钮

struct TagButtonNew: View {
    let label: String
    let isActive: Bool
    let activeColor: Color
    var borderColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? activeColor : (borderColor ?? Color.gray))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? activeColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? activeColor : (borderColor ?? Color.gray.opacity(0.4)), lineWidth: 1)
                )
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 新版详情行

struct DetailRowNew: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - 设备行视图（新版 - 修复点击冲突）

struct DeviceRowNew: View {
    let device: PttDevice
    let onToggleMuteReceive: () -> Void
    let onToggleMuteTransmit: () -> Void
    let onChangeGroup: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 主行 - 点击展开详情
            HStack(spacing: 12) {
                // 图标（根据设备型号显示）
                Image(systemName: device.devModelIcon)
                    .font(.system(size: 24))
                    .foregroundColor(device.isOnline ? .green : .gray)

                // 信息（点击区域）
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.headline)
                        .foregroundColor(device.isOnline ? .primary : .secondary)
                    if let name = device.name, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(device.isOnline ? .green : .secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }

                Spacer()

                // 操作按钮（独立点击区域，不会触发展开）
                HStack(spacing: 8) {
                    TagButton(
                        label: "禁收",
                        isActive: device.isMuteReceive,
                        activeColor: .orange,
                        action: onToggleMuteReceive
                    )

                    TagButton(
                        label: "禁发",
                        isActive: device.isMuteTransmit,
                        activeColor: .red,
                        action: onToggleMuteTransmit
                    )

                    TagButton(
                        label: "换组",
                        isActive: false,
                        activeColor: .green,
                        borderColor: .green,
                        action: onChangeGroup
                    )
                }

                // 展开指示器
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
                    .frame(width: 20)
            }
            .padding(.vertical, 8)

            // 展开详情
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "状态", value: device.statusText)
                    if device.rfType != 0 {
                        DetailRow(label: "射频类型", value: device.rfTypeName)
                    }
                    if let qth = device.qth, !qth.isEmpty {
                        DetailRow(label: "QTH", value: qth)
                    }
                    if let lastVoice = device.formattedLastVoiceTime {
                        DetailRow(label: "最后通话", value: lastVoice)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
        }
        .listRowBackground(device.isOnline ? Color.green.opacity(0.1) : Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - 旧版设备行视图（保留兼容性）

struct DeviceRow: View {
    let device: PttDevice
    let isAdmin: Bool  // 是否管理员（控制操作按钮显示）
    let onToggleMuteReceive: () -> Void
    let onToggleMuteTransmit: () -> Void
    let onChangeGroup: () -> Void
    var onEdit: (() -> Void)? = nil  // 配置回调
    var onAT: (() -> Void)? = nil    // AT指令回调
    var onDelete: (() -> Void)? = nil  // 删除回调

    @State private var isExpanded = false

    // 是否是硬件设备（支持AT指令）
    private var isHardwareDevice: Bool {
        // 硬件设备: 1-25, 200 (NRL系列、车载电台、服务器等)
        // 非硬件设备: 100-106 (小程序、APP等)
        return device.devModel < 100 || device.devModel == 200
    }

    var body: some View {
        VStack(spacing: 0) {
            // 主行
            HStack(spacing: 12) {
                // 图标（根据设备型号显示）
                Image(systemName: device.devModelIcon)
                    .font(.system(size: 24))
                    .foregroundColor(device.isOnline ? .green : .gray)

                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.headline)
                        .foregroundColor(device.isOnline ? .primary : .secondary)
                    if let name = device.name, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(device.isOnline ? .green : .secondary)
                    }
                }

                Spacer()

                // 操作按钮（仅管理员可见）
                if isAdmin {
                    HStack(spacing: 8) {
                        TagButton(
                            label: "禁收",
                            isActive: device.isMuteReceive,
                            activeColor: .orange,
                            action: onToggleMuteReceive
                        )

                        TagButton(
                            label: "禁发",
                            isActive: device.isMuteTransmit,
                            activeColor: .red,
                            action: onToggleMuteTransmit
                        )

                        // 删除按钮
                        if let deleteAction = onDelete {
                            TagButton(
                                label: "删除",
                                isActive: false,
                                activeColor: .red,
                                borderColor: .red,
                                action: deleteAction
                            )
                        }

                        TagButton(
                            label: "换组",
                            isActive: false,
                            activeColor: .green,
                            borderColor: .green,
                            action: onChangeGroup
                        )
                    }
                }

                // 展开按钮
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)

            // 展开详情
            if isExpanded {
                HStack(alignment: .top, spacing: 16) {
                    // 左侧：设备详情
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "状态", value: device.statusText)
                        DetailRow(label: "设备型号", value: device.devModelName)
                        if device.rfType != 0 {
                            DetailRow(label: "射频类型", value: device.rfTypeName)
                        }
                        if let qth = device.qth, !qth.isEmpty {
                            DetailRow(label: "QTH", value: qth)
                        }
                        if let lastVoice = device.formattedLastVoiceTime {
                            DetailRow(label: "最后通话", value: lastVoice)
                        }
                    }

                    Spacer()

                    // 右侧：操作按钮（仅管理员可见）
                    if isAdmin {
                        VStack(spacing: 8) {
                            // 配置按钮
                            if let onEdit = onEdit {
                                Button(action: onEdit) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape.fill")
                                        Text("配置")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                            }

                            // AT指令按钮（仅硬件设备显示）
                            if let onAT = onAT, isHardwareDevice {
                                Button(action: onAT) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "terminal.fill")
                                        Text("AT")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 80)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - 标签按钮

struct TagButton: View {
    let label: String
    let isActive: Bool
    let activeColor: Color
    var borderColor: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isActive ? activeColor : (borderColor ?? .gray))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? activeColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? activeColor : (borderColor ?? Color.gray.opacity(0.5)), lineWidth: 1)
                )
                .cornerRadius(4)
        }
    }
}

// MARK: - 详情行

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - 换组弹窗

struct ChangeGroupSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    let device: PttDevice
    let currentGroupId: Int
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isOperating = false

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.groups) { group in
                    let isCurrentGroup = group.id == currentGroupId

                    Button {
                        if !isCurrentGroup {
                            changeGroup(to: group)
                        }
                    } label: {
                        HStack {
                            Image(systemName: group.typeIcon)
                                .foregroundColor(isCurrentGroup ? .blue : .gray)

                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .foregroundColor(.primary)
                                Text("ID: \(group.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isCurrentGroup {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(isCurrentGroup)
                }
            }
            .navigationTitle("将 \(device.displayName) 移至")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay {
                if isOperating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }

    private func changeGroup(to group: PttGroup) {
        Task {
            isOperating = true
            do {
                _ = try await viewModel.changeDeviceGroup(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    newGroupId: group.id
                )
                try await viewModel.joinGroup(group)    // 切换当前群组
                await viewModel.refreshGroupDetail()     // 刷新UI
                dismiss()
                onComplete()
            } catch {
                print("[ChangeGroupSheet] Change group failed: \(error)")
            }
            isOperating = false
        }
    }
}

// MARK: - 设置视图

struct SettingsTabView: View {
    @ObservedObject var viewModel: PTTViewModel
    @ObservedObject private var locationService = LocationService.shared
    @State private var showClearCacheAlert = false
    @State private var showEffectPicker = false
    @State private var showSpectrumStylePicker = false
    @State private var showConferenceThemePicker = false
    @State private var showUserProfile = false
    @State private var showPermissionInfo = false
    @State private var showHelpInfo = false
    @State private var showAboutView = false
    @AppStorage("ptt_effect_type") private var effectTypeRaw: String = PTTEffectType.ripple.rawValue
    @AppStorage("ptt_spectrum_style") private var spectrumStyleRaw: String = SpectrumStyle.symmetric.rawValue
    @AppStorage("conference_ui_theme") private var conferenceThemeRaw: String = ConferenceUITheme.radio.rawValue

    private var currentEffect: PTTEffectType {
        PTTEffectType(rawValue: effectTypeRaw) ?? .ripple
    }

    private var currentSpectrumStyle: SpectrumStyle {
        SpectrumStyle(rawValue: spectrumStyleRaw) ?? .standard
    }

    private var currentConferenceTheme: ConferenceUITheme {
        ConferenceUITheme(rawValue: conferenceThemeRaw) ?? .radio
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 用户信息卡片
                Button {
                    showUserProfile = true
                } label: {
                    userInfoCard
                }
                .buttonStyle(PlainButtonStyle())

                // PTT设置
                settingsSection(title: "PTT 设置") {
                    settingRow(
                        icon: "hand.tap.fill",
                        iconColor: .orange,
                        title: "PTT 操作模式",
                        subtitle: viewModel.pttMode == PTTMode.holdToTalk
                            ? "按住说话（按住开始，松开停止）"
                            : "点击切换（按一下开始，再按一下停止）",
                        trailing: {
                            Toggle("", isOn: Binding(
                                get: { viewModel.pttMode == PTTMode.toggleToTalk },
                                set: { viewModel.pttMode = $0 ? .toggleToTalk : .holdToTalk }
                            ))
                        }
                    )

                    // 全双工模式已默认启用，不再显示切换开关

                    settingRow(
                        icon: "phone.fill",
                        iconColor: viewModel.isConferenceMode ? .blue : (viewModel.txCodec == .opus ? .purple : .gray),
                        title: "发射编码格式",
                        subtitle: viewModel.isConferenceMode
                            ? "会议模式仅支持 G.711"
                            : (viewModel.txCodec == .opus
                                ? "Opus (实验性) - 16kHz, 低延迟"
                                : "G.711 - 8kHz, 兼容性强"),
                        trailing: {
                            Toggle("", isOn: Binding(
                                get: { viewModel.txCodec == .opus },
                                set: { newValue in
                                    // 会议模式或发射中禁止切换
                                    if !viewModel.isConferenceMode && !viewModel.isTalking {
                                        viewModel.txCodec = newValue ? .opus : .g711
                                    }
                                }
                            ))
                            .disabled(viewModel.isConferenceMode || viewModel.isTalking)
                        }
                    )
                    .onChange(of: viewModel.txCodec) { newCodec in
                        // Opus TX 建议开启降噪（非会议模式）
                        if newCodec == .opus && !viewModel.noiseReductionEnabled {
                            viewModel.noiseReductionEnabled = true
                        }
                    }

                    settingRow(
                        icon: "person.wave.2.fill",
                        iconColor: viewModel.noiseReductionEnabled ? .green : .gray,
                        title: "人声增强（RNNoise 降噪）",
                        subtitle: viewModel.txCodec == .opus
                            ? "Opus 模式必须开启降噪（16kHz 编码）"
                            : (viewModel.noiseReductionEnabled
                                ? "已开启：48kHz 采集 → AI 降噪 → 8kHz 编码"
                                : "关闭：直接使用 8kHz 采集"),
                        trailing: {
                            Toggle("", isOn: Binding(
                                get: { viewModel.noiseReductionEnabled },
                                set: { newValue in
                                    // Opus 模式或发射中禁止切换
                                    if viewModel.txCodec == .opus || viewModel.isTalking {
                                        viewModel.noiseReductionEnabled = true
                                    } else {
                                        viewModel.noiseReductionEnabled = newValue
                                    }
                                }
                            ))
                            .disabled(viewModel.txCodec == .opus || viewModel.isTalking)
                        }
                    )

                    // 语音识别（实时字幕）
                    settingRow(
                        icon: "text.bubble.fill",
                        iconColor: viewModel.speechRecognitionEnabled ? .blue : .gray,
                        title: "语音识别（实时字幕）",
                        subtitle: viewModel.speechRecognitionEnabled
                            ? "已开启：接收语音时显示实时字幕"
                            : "关闭：不进行语音识别",
                        trailing: {
                            Toggle("", isOn: $viewModel.speechRecognitionEnabled)
                        }
                    )

                    // 后台保活增强
                    settingRow(
                        icon: "location.fill",
                        iconColor: locationService.backgroundKeepAliveEnabled ? .blue : .gray,
                        title: "后台保活增强",
                        subtitle: locationService.backgroundKeepAliveEnabled
                            ? (locationService.hasAlwaysAuthorization
                                ? "已开启：电话期间保持连接（使用定位服务）"
                                : "⚠️ 需要「始终」定位权限")
                            : "关闭：电话超过30秒可能断线",
                        trailing: {
                            Toggle("", isOn: Binding(
                                get: { locationService.backgroundKeepAliveEnabled },
                                set: { newValue in
                                    if newValue {
                                        // 用户打开开关，尝试启用后台保活
                                        locationService.enableBackgroundKeepAlive()
                                    } else {
                                        // 用户关闭开关
                                        locationService.disableBackgroundKeepAlive()
                                    }
                                }
                            ))
                        }
                    )

                    // PTT 效果样式选择
                    Button {
                        showEffectPicker = true
                    } label: {
                        settingRow(
                            icon: currentEffect.icon,
                            iconColor: .purple,
                            title: "PTT 效果样式",
                            subtitle: currentEffect.displayName,
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }

                    // 接收频谱样式选择
                    Button {
                        showSpectrumStylePicker = true
                    } label: {
                        settingRow(
                            icon: currentSpectrumStyle.icon,
                            iconColor: .green,
                            title: "接收频谱样式",
                            subtitle: currentSpectrumStyle.displayName,
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }

                    // 会议模式 UI 样式选择
                    Button {
                        showConferenceThemePicker = true
                    } label: {
                        settingRow(
                            icon: currentConferenceTheme.icon,
                            iconColor: .cyan,
                            title: "会议模式样式",
                            subtitle: currentConferenceTheme.displayName,
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }
                }

                // 管理功能 (仅管理员可见)
                if viewModel.isAdmin {
                    settingsSection(title: "管理功能") {
                        NavigationLink {
                            ServerNodeListView(viewModel: viewModel)
                        } label: {
                            settingRow(
                                icon: "server.rack",
                                iconColor: .orange,
                                title: "节点管理",
                                subtitle: "管理服务器互联节点",
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            )
                        }

                        NavigationLink {
                            UserManagementFullView(viewModel: viewModel)
                        } label: {
                            settingRow(
                                icon: "person.2.badge.gearshape.fill",
                                iconColor: .blue,
                                title: "用户管理",
                                subtitle: "管理用户账号、权限",
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            )
                        }

                        NavigationLink {
                            RegistrationManagementFullView(viewModel: viewModel)
                        } label: {
                            settingRow(
                                icon: "person.crop.circle.badge.plus",
                                iconColor: .purple,
                                title: "注册管理",
                                subtitle: "审核用户注册申请",
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                            )
                        }
                    }
                }

                // 数据管理
                settingsSection(title: "数据管理") {
                    settingRow(
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        title: "通话记录",
                        subtitle: "\(viewModel.callHistory.count) 条记录",
                        trailing: {
                            Text(viewModel.getCacheSize())
                                .foregroundColor(.gray)
                        }
                    )

                    Button {
                        showClearCacheAlert = true
                    } label: {
                        settingRow(
                            icon: "trash.fill",
                            iconColor: .red,
                            title: "清除通话记录",
                            subtitle: "删除所有群组的通话记录",
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }
                }

                // 关于
                settingsSection(title: "关于") {
                    Button {
                        showAboutView = true
                    } label: {
                        settingRow(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "关于 PTT 互联",
                            subtitle: "协议说明 · 版权信息",
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        showPermissionInfo = true
                    } label: {
                        settingRow(
                            icon: "shield.fill",
                            iconColor: .purple,
                            title: "权限说明",
                            subtitle: nil,
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        showHelpInfo = true
                    } label: {
                        settingRow(
                            icon: "questionmark.circle",
                            iconColor: .green,
                            title: "帮助",
                            subtitle: nil,
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // MARK: - 底部版本信息
                VStack(spacing: 4) {
                    Text("PTT 互联 v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("© 2024-2026 刘光辉 (BG4QG)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .padding(.bottom, 10)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("清除通话记录", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                viewModel.clearAllHistory()
            }
        } message: {
            Text("确定要删除所有通话记录吗？此操作不可恢复。")
        }
        .sheet(isPresented: $showEffectPicker) {
            PTTEffectPickerView(selectedEffect: $effectTypeRaw)
        }
        .sheet(isPresented: $showSpectrumStylePicker) {
            SpectrumStylePickerView(selectedStyle: $spectrumStyleRaw)
        }
        .sheet(isPresented: $showConferenceThemePicker) {
            ConferenceThemePickerView(selectedTheme: $conferenceThemeRaw)
        }
        .sheet(isPresented: $showUserProfile) {
            UserProfileView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                showUserProfile = false
                showEffectPicker = false
                showSpectrumStylePicker = false
            }
        }
        .sheet(isPresented: $showPermissionInfo) {
            PermissionInfoView()
        }
        .sheet(isPresented: $showHelpInfo) {
            HelpInfoView()
        }
        .sheet(isPresented: $showAboutView) {
            AboutView()
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        HStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "person.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.username)
                    .font(.headline)
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(viewModel.callSign)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    if !viewModel.dmrid.isEmpty {
                        Text("DMR: \(viewModel.dmrid)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            Spacer()

            // 状态和退出按钮
            VStack(spacing: 8) {
                Button {
                    if !viewModel.isConnected {
                        viewModel.manualReconnect()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isConnected ? "在线" : "离线")
                        if !viewModel.isConnected {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(viewModel.isConnected ? Color.green.opacity(0.2) : Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isConnected)

                Button {
                    Task { await viewModel.logout() }
                } label: {
                    Text("退出")
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - 设置区块

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    private func settingRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            trailing()
        }
        .padding()
    }
}

// MARK: - 节点管理视图 (服务器互联)

struct ServerNodeListView: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var nodes: [PttServerNode] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showAddNode = false
    @State private var showEditNode = false
    @State private var editingNode: PttServerNode?
    @State private var showDeleteAlert = false
    @State private var nodeToDelete: PttServerNode?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏和新建按钮
            HStack(spacing: 12) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索名称、呼号", text: $searchText)
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)

                // 新建按钮
                Button {
                    showAddNode = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("新建")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 内容区域
            if isLoading && nodes.isEmpty {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if nodes.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无节点")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredNodes) { node in
                            ServerNodeCard(
                                node: node,
                                onToggleStatus: {
                                    toggleNodeStatus(node)
                                },
                                onEdit: {
                                    editingNode = node
                                    showEditNode = true
                                },
                                onDelete: {
                                    nodeToDelete = node
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await loadNodes()
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("节点管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddNode) {
            PttServerNodeEditSheet(viewModel: viewModel, mode: .add) {
                Task { await loadNodes() }
            }
        }
        .sheet(isPresented: $showEditNode) {
            if let node = editingNode {
                PttServerNodeEditSheet(viewModel: viewModel, mode: .edit(node)) {
                    Task { await loadNodes() }
                }
            }
        }
        .alert("删除节点", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let node = nodeToDelete {
                    deleteNode(node)
                }
            }
        } message: {
            if let node = nodeToDelete {
                Text("确定要删除节点「\(node.name)」吗？")
            }
        }
        .alert("错误", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadNodes()
        }
    }

    private var filteredNodes: [PttServerNode] {
        if searchText.isEmpty {
            return nodes
        }
        return nodes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.owerCallsign?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func loadNodes() async {
        isLoading = true
        errorMessage = nil
        do {
            nodes = try await viewModel.apiService.getServerNodes()
            print("[ServerNodeListView] Loaded \(nodes.count) nodes")
        } catch {
            print("[ServerNodeListView] Load error: \(error)")
            // 只有在没有数据时才显示错误
            if nodes.isEmpty {
                errorMessage = "加载失败: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    private func toggleNodeStatus(_ node: PttServerNode) {
        Task {
            do {
                _ = try await viewModel.apiService.toggleServerNodeStatus(node: node)
                await loadNodes()
            } catch {
                errorMessage = "操作失败: \(error.localizedDescription)"
            }
        }
    }

    private func deleteNode(_ node: PttServerNode) {
        Task {
            do {
                _ = try await viewModel.apiService.deleteServerNode(id: node.id)
                await loadNodes()
            } catch {
                errorMessage = "删除失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 节点卡片视图

struct ServerNodeCard: View {
    let node: PttServerNode
    let onToggleStatus: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 上半部分：图标、名称、状态
            HStack(alignment: .top, spacing: 12) {
                // 左侧图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }

                // 中间信息
                VStack(alignment: .leading, spacing: 8) {
                    // 名称和状态
                    HStack {
                        Text(node.name)
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                        // 状态标签
                        HStack(spacing: 4) {
                            Circle()
                                .fill(node.isEnabled ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(node.isEnabled ? "运行中" : "已停止")
                                .font(.system(size: 13))
                                .foregroundColor(node.isEnabled ? .green : .gray)
                        }
                    }

                    // 地址
                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text("\(node.addressDisplay):\(node.udpPort)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    // 所有者
                    if let owner = node.owerCallsign, !owner.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text("所有者: \(owner)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(16)

            // 分隔线
            Divider()
                .padding(.horizontal, 16)

            // 底部操作栏
            HStack {
                // 配置按钮
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                        Text("配置")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                }

                Spacer().frame(width: 24)

                // 删除按钮
                Button {
                    onDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("删除")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                // ON/OFF 开关
                HStack(spacing: 8) {
                    Text("ON")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(node.isEnabled ? .green : .gray)
                    Toggle("", isOn: Binding(
                        get: { node.isEnabled },
                        set: { _ in onToggleStatus() }
                    ))
                    .labelsHidden()
                    .tint(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 节点编辑表单

struct PttServerNodeEditSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case add
        case edit(PttServerNode)
    }

    let mode: Mode
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var serverType: Int = 1
    @State private var ipAddr: String = ""
    @State private var dnsName: String = ""
    @State private var udpPort: String = "60050"
    @State private var note: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let serverTypes = [
        (1, "专用服务器"),
        (2, "普通PC"),
        (3, "小主机"),
        (4, "树莓派等开发板")
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!ipAddr.trimmingCharacters(in: .whitespaces).isEmpty ||
         !dnsName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var title: String {
        switch mode {
        case .add: return "新建节点"
        case .edit: return "编辑节点"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("节点名称", text: $name)

                    Picker("服务器类型", selection: $serverType) {
                        ForEach(serverTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                } header: {
                    Text("基本信息")
                }

                Section {
                    TextField("IP 地址", text: $ipAddr)
                        .keyboardType(.numbersAndPunctuation)
                        .autocapitalization(.none)
                    TextField("域名", text: $dnsName)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("UDP 端口", text: $udpPort)
                        .keyboardType(.numberPad)
                } header: {
                    Text("网络配置")
                } footer: {
                    Text("IP地址和域名至少填写一项，端口默认60050")
                }

                Section {
                    TextField("备注", text: $note)
                } header: {
                    Text("其他")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveNode()
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .onAppear {
                if case .edit(let node) = mode {
                    name = node.name
                    serverType = node.serverType
                    ipAddr = node.ipAddr ?? ""
                    dnsName = node.dnsName ?? ""
                    udpPort = String(node.udpPort)
                    note = node.note ?? ""
                }
            }
        }
    }

    private func saveNode() {
        isLoading = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedIp = ipAddr.trimmingCharacters(in: .whitespaces)
        let trimmedDns = dnsName.trimmingCharacters(in: .whitespaces)
        let port = Int(udpPort) ?? 60050
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                switch mode {
                case .add:
                    _ = try await viewModel.apiService.createServerNode(
                        name: trimmedName,
                        serverType: serverType,
                        ipAddr: trimmedIp.isEmpty ? nil : trimmedIp,
                        dnsName: trimmedDns.isEmpty ? nil : trimmedDns,
                        udpPort: port,
                        note: trimmedNote.isEmpty ? nil : trimmedNote
                    )
                case .edit(let node):
                    _ = try await viewModel.apiService.updateServerNode(
                        id: node.id,
                        name: trimmedName,
                        serverType: serverType,
                        ipAddr: trimmedIp.isEmpty ? nil : trimmedIp,
                        dnsName: trimmedDns.isEmpty ? nil : trimmedDns,
                        udpPort: port,
                        status: node.status,
                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                        owerId: node.owerId,
                        owerCallsign: node.owerCallsign
                    )
                }
                isLoading = false
                onSave()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 用户信息编辑视图

struct UserProfileView: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showChangePassword = false
    @State private var showEditDmrId = false
    @State private var showEditMdcId = false

    var body: some View {
        NavigationView {
            List {
                // 用户信息
                Section {
                    infoRow(title: "呼号", value: viewModel.callSign)
                    // DMR ID (可编辑)
                    Button {
                        showEditDmrId = true
                    } label: {
                        HStack {
                            Text("DMR ID")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(viewModel.dmrid.isEmpty ? "未设置" : viewModel.dmrid)
                                .foregroundColor(viewModel.dmrid.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    // MDC ID (可编辑)
                    Button {
                        showEditMdcId = true
                    } label: {
                        HStack {
                            Text("MDC ID")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(viewModel.mdcid.isEmpty ? "未设置" : viewModel.mdcid)
                                .foregroundColor(viewModel.mdcid.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    infoRow(title: "SSID", value: "\(viewModel.ssid)")
                    infoRow(title: "用户名", value: viewModel.username)
                    if viewModel.isAdmin {
                        infoRow(title: "角色", value: "管理员")
                    }
                    if let groupId = viewModel.currentGroup?.id {
                        infoRow(title: "当前群组", value: viewModel.currentGroup?.name ?? "群组 \(groupId)")
                    }
                } header: {
                    Text("基本信息")
                }

                // 连接信息
                Section {
                    infoRow(title: "服务器", value: viewModel.serverUrl)
                    infoRow(title: "连接状态", value: viewModel.isConnected ? "已连接" : "未连接")
                } header: {
                    Text("连接信息")
                }

                // 账号操作
                Section {
                    Button {
                        showChangePassword = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                            Text("修改密码")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("账号安全")
                }

                // 退出登录
                Section {
                    Button {
                        Task {
                            await viewModel.logout()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("用户信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditDmrId) {
                EditIdSheet(viewModel: viewModel, idType: .dmr)
            }
            .sheet(isPresented: $showEditMdcId) {
                EditIdSheet(viewModel: viewModel, idType: .mdc)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - DMR ID / MDC ID 编辑表单

enum IdType {
    case dmr
    case mdc

    var title: String {
        switch self {
        case .dmr: return "DMR ID"
        case .mdc: return "MDC ID"
        }
    }

    var hint: String {
        switch self {
        case .dmr: return "DMR ID 通常为 7-9 位数字"
        case .mdc: return "MDC ID 通常为 4 位数字"
        }
    }
}

struct EditIdSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    let idType: IdType
    @Environment(\.dismiss) private var dismiss

    @State private var idValue: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(idType.title, text: $idValue)
                        .keyboardType(.numberPad)
                } footer: {
                    Text(idType.hint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task {
                            await saveId()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("保存")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("修改 \(idType.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                idValue = idType == .dmr ? viewModel.dmrid : viewModel.mdcid
            }
        }
    }

    private func saveId() async {
        isLoading = true
        errorMessage = nil

        do {
            if idType == .dmr {
                try await viewModel.updateDmrId(idValue)
            } else {
                try await viewModel.updateMdcId(idValue)
            }
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "保存失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

// MARK: - 修改密码表单

struct ChangePasswordSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private var isValid: Bool {
        !oldPassword.isEmpty &&
        newPassword.count >= 6 &&
        newPassword == confirmPassword
    }

    private var passwordError: String? {
        if newPassword.isEmpty { return nil }
        if newPassword.count < 6 { return "密码至少6位" }
        if !confirmPassword.isEmpty && newPassword != confirmPassword { return "两次密码不一致" }
        return nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("当前密码", text: $oldPassword)
                } header: {
                    Text("验证身份")
                }

                Section {
                    SecureField("新密码", text: $newPassword)
                    SecureField("确认新密码", text: $confirmPassword)
                } header: {
                    Text("设置新密码")
                } footer: {
                    if let error = passwordError {
                        Text(error)
                            .foregroundColor(.red)
                    } else {
                        Text("密码至少6位")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        changePassword()
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .alert("密码修改成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("请使用新密码重新登录")
            }
        }
    }

    private func changePassword() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.changePassword(oldPassword: oldPassword, newPassword: newPassword)
                isLoading = false
                showSuccess = true
            } catch {
                isLoading = false
                errorMessage = "修改失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 语音气泡组件

struct VoiceBubble: View {
    let record: CallRecord
    let isPlaying: Bool
    let durationStr: String
    let onTap: () -> Void
    let onLongPress: (CGPoint) -> Void

    @State private var bubbleFrame: CGRect = .zero
    @GestureState private var isLongPressing = false

    /// 录音气泡颜色：G711 绿色，Opus 紫色
    private var bubbleColor: Color {
        if isPlaying {
            return .orange
        }
        switch record.codec {
        case PTTInfra.AudioCodec.g711:
            return .green
        case PTTInfra.AudioCodec.opus:
            return .purple
        }
    }

    /// 根据时长计算气泡宽度（对数关系，最大为屏幕宽度的黄金分割）
    private var bubbleWidth: CGFloat {
        let duration = record.duration
        let screenWidth = UIScreen.main.bounds.width
        let minWidth: CGFloat = 90  // 最小宽度增大，避免大肚子
        let maxWidth = screenWidth * 0.618
        // 对数关系：log10(duration + 1) 使得增长前快后慢
        // 1秒≈90pt, 5秒≈120pt, 15秒≈150pt, 60秒≈180pt
        let logValue = log10(duration + 1)
        let width = minWidth + logValue * 60  // 降低增长系数，曲线更平缓
        return min(maxWidth, width)
    }

    var body: some View {
        Button(action: {
            print("[VoiceBubble] Button tapped - calling onTap")
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 14))
                Spacer()
                Text(durationStr)
                    .font(.system(size: 14))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: bubbleWidth)
            .background(bubbleColor)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isLongPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    bubbleFrame = geo.frame(in: .global)
                }.onChange(of: geo.frame(in: .global)) { newFrame in
                    bubbleFrame = newFrame
                }
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .updating($isLongPressing) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    let position = CGPoint(x: bubbleFrame.midX, y: bubbleFrame.minY - 10)
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onLongPress(position)
                }
        )
    }
}

// MARK: - 文本消息气泡组件

struct TextBubble: View {
    let message: TextMessage
    let onTap: () -> Void
    let onLongPress: (CGPoint) -> Void

    @State private var bubbleFrame: CGRect = .zero
    @GestureState private var isLongPressing = false

    var body: some View {
        let isMe = message.isSelf

        Button(action: {
            onTap()
        }) {
            Text(message.content)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMe ? Color.blue : Color(UIColor.systemGray5))
                .foregroundColor(isMe ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isLongPressing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    bubbleFrame = geo.frame(in: .global)
                }.onChange(of: geo.frame(in: .global)) { newFrame in
                    bubbleFrame = newFrame
                }
            }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .updating($isLongPressing) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    let position = CGPoint(x: bubbleFrame.midX, y: bubbleFrame.minY - 10)
                    onLongPress(position)
                }
        )
    }
}

// MARK: - 气泡位置 PreferenceKey (保留兼容)

struct BubblePositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - 微信风格长按菜单

struct VoiceContextMenu: View {
    let position: CGPoint
    let onMultiSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 菜单内容
            HStack(spacing: 0) {
                // 多选按钮
                Button(action: onMultiSelect) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 18))
                        Text("多选")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(width: 56, height: 50)
                }

                // 分隔线
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 0.5, height: 30)

                // 删除按钮
                Button(action: onDelete) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                        Text("删除")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                    .frame(width: 56, height: 50)
                }
            }
            .background(Color(white: 0.2))
            .cornerRadius(8)

            // 小三角箭头
            Triangle()
                .fill(Color(white: 0.2))
                .frame(width: 12, height: 6)
        }
        .position(x: position.x, y: position.y - 30)
    }
}

// MARK: - 三角形

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 水波纹动画视图

struct WaveformView: View {
    let amplitude: CGFloat  // 0.0 ~ 1.0
    let color: Color
    let waveCount: Int

    @State private var phase: CGFloat = 0

    init(amplitude: CGFloat, color: Color, waveCount: Int = 3) {
        self.amplitude = amplitude
        self.color = color
        self.waveCount = waveCount
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let maxAmplitude = size.height * 0.3 * amplitude

                // 绘制多层波形
                for i in 0..<waveCount {
                    let wavePhase = phase + CGFloat(i) * .pi / CGFloat(waveCount)
                    let waveAmplitude = maxAmplitude * (1.0 - CGFloat(i) * 0.2)
                    let opacity = 1.0 - Double(i) * 0.25

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: midY))

                    for x in stride(from: 0, through: size.width, by: 2) {
                        let relativeX = x / size.width
                        let sine = sin(relativeX * .pi * 4 + wavePhase)
                        let y = midY + sine * waveAmplitude
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    context.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        lineWidth: 2
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - 专业PTT按钮

struct ProfessionalPTTButton: View {
    @ObservedObject var viewModel: PTTViewModel
    @AppStorage("ptt_effect_type") private var effectTypeRaw: String = PTTEffectType.ripple.rawValue

    private var effectType: PTTEffectType {
        PTTEffectType(rawValue: effectTypeRaw) ?? .ripple
    }

    var body: some View {
        let isHoldMode = viewModel.pttMode == .holdToTalk

        Button {
            if !isHoldMode {
                Task { await viewModel.pttTap() }
            }
        } label: {
            ZStack {
                // 外圈
                Circle()
                    .stroke(borderColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 160, height: 160)

                // 背景填充
                Circle()
                    .fill(fillGradient)
                    .frame(width: 150, height: 150)

                // PTT 效果（发射或接收时显示）- 使用模板系统
                if viewModel.isTalking || viewModel.currentSpeaker != nil {
                    PTTEffectView(
                        effectType: effectType,
                        amplitude: CGFloat(viewModel.volumeLevel),
                        color: dotColor
                    )
                    .frame(width: 150, height: 150)
                }

                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 45, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isHoldMode && !viewModel.isTalking && viewModel.isConnected {
                        Task { await viewModel.pttDown() }
                    }
                }
                .onEnded { _ in
                    if isHoldMode && viewModel.isTalking {
                        Task { await viewModel.pttUp() }
                    }
                }
        )
        .scaleEffect(viewModel.isTalking ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isTalking)
    }

    /// 接收状态颜色：G711 绿色，Opus 紫色
    private var receiveColor: Color {
        viewModel.receiveCodec == PTTInfra.AudioCodec.opus ? .purple : .green
    }

    private var borderColor: Color {
        if viewModel.isTalking {
            return .red
        } else if viewModel.currentSpeaker != nil {
            return receiveColor
        } else {
            return .blue
        }
    }

    private var fillGradient: LinearGradient {
        if viewModel.isTalking {
            return LinearGradient(
                colors: [Color.red.opacity(0.15), Color.red.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if viewModel.currentSpeaker != nil {
            return LinearGradient(
                colors: [receiveColor.opacity(0.15), receiveColor.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.white, Color.gray.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var dotColor: Color {
        if viewModel.isTalking {
            return .red
        } else {
            return receiveColor
        }
    }

    private var iconColor: Color {
        if viewModel.isTalking {
            return .red
        } else if viewModel.currentSpeaker != nil {
            return receiveColor
        } else {
            return .gray
        }
    }
}

// MARK: - 紧凑版 PTT 控制组件

/// 紧凑版 PTT 按钮（70pt，保留效果模板）
struct CompactPTTButton: View {
    @ObservedObject var viewModel: PTTViewModel
    @AppStorage("ptt_effect_type") private var effectTypeRaw: String = PTTEffectType.ripple.rawValue

    private var effectType: PTTEffectType {
        PTTEffectType(rawValue: effectTypeRaw) ?? .ripple
    }

    private let buttonSize: CGFloat = 70

    var body: some View {
        let isHoldMode = viewModel.pttMode == .holdToTalk

        Button {
            if !isHoldMode {
                Task { await viewModel.pttTap() }
            }
        } label: {
            ZStack {
                // 外圈
                Circle()
                    .stroke(borderColor.opacity(0.5), lineWidth: 2)
                    .frame(width: buttonSize + 6, height: buttonSize + 6)

                // 背景填充
                Circle()
                    .fill(fillGradient)
                    .frame(width: buttonSize, height: buttonSize)

                // PTT 效果（发射或接收时显示）
                if viewModel.isTalking || viewModel.currentSpeaker != nil {
                    PTTEffectView(
                        effectType: effectType,
                        amplitude: CGFloat(viewModel.volumeLevel),
                        color: dotColor
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .clipShape(Circle())
                }

                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isHoldMode && !viewModel.isTalking && viewModel.isConnected {
                        Task { await viewModel.pttDown() }
                    }
                }
                .onEnded { _ in
                    if isHoldMode && viewModel.isTalking {
                        Task { await viewModel.pttUp() }
                    }
                }
        )
        .scaleEffect(viewModel.isTalking ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: viewModel.isTalking)
    }

    private var receiveColor: Color {
        viewModel.receiveCodec == .opus ? .purple : .green
    }

    private var borderColor: Color {
        if viewModel.isTalking { return .red }
        else if viewModel.currentSpeaker != nil { return receiveColor }
        else { return .blue }
    }

    private var fillGradient: LinearGradient {
        if viewModel.isTalking {
            return LinearGradient(colors: [Color.red.opacity(0.2), Color.red.opacity(0.35)], startPoint: .top, endPoint: .bottom)
        } else if viewModel.currentSpeaker != nil {
            return LinearGradient(colors: [receiveColor.opacity(0.2), receiveColor.opacity(0.35)], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var dotColor: Color {
        viewModel.isTalking ? .red : receiveColor
    }

    private var iconColor: Color {
        if viewModel.isTalking { return .white }
        else if viewModel.currentSpeaker != nil { return receiveColor }
        else { return .blue }
    }
}

/// 紧凑版控制按钮（音量/麦克风）
struct CompactControlButton: View {
    let icon: String
    let value: Float
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 背景
                Circle()
                    .fill(Color(UIColor.systemGray6))
                    .frame(width: 40, height: 40)

                // 进度环
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, lineWidth: 2.5)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                // 图标
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
        }
    }
}

/// 紧凑版音量弹出滑块
struct CompactVolumePopover: View {
    @Binding var isPresented: Bool
    @Binding var value: Float
    let icon: String
    let color: Color

    /// 根据音量值返回对应的音量图标
    private var volumeIconName: String {
        let percent = Int(value * 100)
        if percent == 0 {
            return "speaker.slash.fill"
        } else if percent < 33 {
            return "speaker.wave.1.fill"
        } else if percent < 66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        if isPresented {
            VStack(spacing: 4) {
                // 音量图标（根据音量级别变化）
                Image(systemName: volumeIconName)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(height: 20)

                // 只显示数字，使用等宽字体确保宽度一致
                Text("\(Int(value * 100))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)

                // 垂直滑块
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemGray5))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(height: geo.size.height * CGFloat(value))
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let newValue = 1 - Float(drag.location.y / geo.size.height)
                                value = max(0, min(1, newValue))
                            }
                    )
                }
                .frame(width: 28, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // 底部图标
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .offset(y: -130)
            .onTapGesture { }  // 防止穿透
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// 紧凑版编码切换按钮（G711/Opus）
struct CompactCodecButton: View {
    let useOpus: Bool
    let isTalking: Bool
    var isConferenceMode: Bool = false  // 会议模式锁定 G711
    let onTap: () -> Void

    /// 是否禁用（发言中或会议模式）
    private var isDisabled: Bool {
        isTalking || isConferenceMode
    }

    var body: some View {
        Button {
            guard !isDisabled else { return }
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(buttonBackgroundColor)
                    .frame(width: 44, height: 40)

                Text(displayText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
            }
        }
        .disabled(isDisabled)
    }

    /// 按钮背景色
    private var buttonBackgroundColor: Color {
        if isTalking {
            return Color(UIColor.systemGray5)
        }
        // 会议模式锁定 G711，显示蓝色常亮
        if isConferenceMode {
            return Color.blue.opacity(0.15)
        }
        return useOpus ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15)
    }

    /// 显示文字
    private var displayText: String {
        // 会议模式固定显示 G711
        if isConferenceMode {
            return "G711"
        }
        return useOpus ? "Opus" : "G711"
    }

    /// 文字颜色
    private var textColor: Color {
        if isTalking {
            return .gray
        }
        // 会议模式锁定 G711，显示蓝色常亮
        if isConferenceMode {
            return .blue
        }
        return useOpus ? .orange : .blue
    }
}

/// 紧凑版降噪按钮
struct CompactNoiseButton: View {
    let isEnabled: Bool
    var isLocked: Bool = false  // Opus模式下锁定，不能关闭
    var isTalking: Bool = false  // 发言时禁用
    let onTap: () -> Void

    private var isDisabled: Bool {
        isLocked || isTalking
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isDisabled
                        ? Color(UIColor.systemGray5)
                        : (isEnabled ? Color.green.opacity(0.15) : Color(UIColor.systemGray6)))
                    .frame(width: 40, height: 40)

                // 锁定时显示边框
                if isLocked && isEnabled && !isTalking {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 40, height: 40)
                }

                Image(systemName: isEnabled ? "waveform.path.ecg" : "waveform.path")
                    .font(.system(size: 16))
                    .foregroundColor(isDisabled ? .gray : (isEnabled ? .green : .gray))
            }
        }
        .disabled(isDisabled)
    }
}

// MARK: - 顶部讲话状态横条 - 多频谱样式版

struct SpeakingStatusBar: View {
    let speaker: String
    let volumeLevel: Float
    let codec: PTTInfra.AudioCodec
    let dmrID: String?

    @AppStorage("ptt_spectrum_style") private var spectrumStyleRaw: String = SpectrumStyle.symmetric.rawValue
    @State private var animationPhase: CGFloat = 0
    @State private var pulseOpacity: Double = 1.0

    private var spectrumStyle: SpectrumStyle {
        SpectrumStyle(rawValue: spectrumStyleRaw) ?? .standard
    }

    /// 状态栏颜色：G711 绿色，Opus 紫色
    private var barColor: Color {
        codec == PTTInfra.AudioCodec.opus ? .purple : .green
    }

    var body: some View {
        SwiftUI.Group {
            switch spectrumStyle {
            case .classic:
                classicStyleView
            case .standard:
                standardStyleView
            case .textTop:
                textTopStyleView
            case .symmetric:
                symmetricStyleView
            case .wideBar:
                wideBarStyleView
            case .compact:
                compactStyleView
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        }
    }

    // MARK: - 样式1: 经典模式 (5条白色波形)

    private var classicStyleView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: 4, height: classicBarHeight(for: i))
                        .animation(.easeInOut(duration: 0.1), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.15), value: animationPhase)
                }
            }
            .frame(width: 32, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(speaker) 正在讲话...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if let dmrID = dmrID, !dmrID.isEmpty {
                    Text("DMR ID: \(dmrID)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            volumeDotsView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(statusBarBackground)
    }

    // MARK: - 样式2: 标准频谱 (15条渐变色)

    private var standardStyleView: some View {
        HStack(spacing: 8) {
            // 15条渐变色频谱
            HStack(spacing: 2) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(spectrumBarGradientColor(for: i, total: 15))
                        .frame(width: 3, height: spectrumBarHeight(for: i, total: 15))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.12), value: animationPhase)
                }
            }
            .frame(width: 60, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(speaker) 正在讲话...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let dmrID = dmrID, !dmrID.isEmpty {
                    Text("DMR ID: \(dmrID)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            volumeDotsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusBarBackground)
    }

    // MARK: - 样式3: 上文下频 (呼号在上，长频谱在下)

    private var textTopStyleView: some View {
        VStack(spacing: 6) {
            // 顶部：呼号和状态
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(speaker) 正在讲话...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if let dmrID = dmrID, !dmrID.isEmpty {
                    Text("DMR: \(dmrID)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                volumeDotsView
            }

            // 底部：长频谱条
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(spectrumBarGradientColor(for: i, total: 20))
                        .frame(height: spectrumBarHeight(for: i, total: 20, maxHeight: 20))
                        .animation(.easeInOut(duration: 0.06), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.1), value: animationPhase)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(statusBarBackground)
    }

    // MARK: - 样式4: 对称频谱 (左右对称，呼号居中)

    private var symmetricStyleView: some View {
        HStack(spacing: 0) {
            // 左侧频谱 (从外向内递增)
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(spectrumBarGradientColor(for: 7 - i, total: 8))
                        .frame(width: 3, height: symmetricBarHeight(for: 7 - i))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.1), value: animationPhase)
                }
            }
            .frame(width: 36, height: 32)

            Spacer()

            // 中间：呼号
            VStack(spacing: 2) {
                Text(speaker)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("正在讲话")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
                if let dmrID = dmrID, !dmrID.isEmpty {
                    Text("DMR ID: \(dmrID)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // 右侧频谱 (镜像)
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(spectrumBarGradientColor(for: i, total: 8))
                        .frame(width: 3, height: symmetricBarHeight(for: i))
                        .animation(.easeInOut(duration: 0.08), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.1), value: animationPhase)
                }
            }
            .frame(width: 36, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusBarBackground)
    }

    // MARK: - 样式5: 宽条模式 (8条宽频谱)

    private var wideBarStyleView: some View {
        HStack(spacing: 10) {
            // 8条宽频谱
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(spectrumBarGradientColor(for: i, total: 8))
                        .frame(width: 6, height: wideBarHeight(for: i))
                        .animation(.easeInOut(duration: 0.1), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.12), value: animationPhase)
                }
            }
            .frame(width: 60, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(speaker) 正在讲话...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let dmrID = dmrID, !dmrID.isEmpty {
                    Text("DMR ID: \(dmrID)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            volumeDotsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(statusBarBackground)
    }

    // MARK: - 样式6: 紧凑模式 (单行紧凑)

    private var compactStyleView: some View {
        HStack(spacing: 8) {
            // 小型频谱
            HStack(spacing: 1.5) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(spectrumBarGradientColor(for: i, total: 10))
                        .frame(width: 2.5, height: compactBarHeight(for: i))
                        .animation(.easeInOut(duration: 0.06), value: volumeLevel)
                        .animation(.easeInOut(duration: 0.1), value: animationPhase)
                }
            }
            .frame(width: 36, height: 24)

            Text(speaker)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            Text("正在讲话")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))

            if let dmrID = dmrID, !dmrID.isEmpty {
                Text("DMR: \(dmrID)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // 简化的音量指示
            Circle()
                .fill(volumeLevel > 0.5 ? Color.white : Color.white.opacity(0.4))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(statusBarBackground)
    }

    // MARK: - 共用组件

    private var volumeDotsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(dotOpacity(for: i)))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.trailing, 4)
    }

    private var statusBarBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(
                    colors: [barColor, barColor.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.white.opacity(0.15 * pulseOpacity * Double(volumeLevel)))
        }
    }

    // MARK: - 频谱条颜色渐变 (绿 → 黄 → 红)

    private func spectrumBarGradientColor(for index: Int, total: Int) -> Color {
        let normalizedHeight = spectrumBarNormalizedHeight(for: index, total: total)

        if normalizedHeight < 0.4 {
            return .green
        } else if normalizedHeight < 0.7 {
            // 绿到黄的渐变
            let t = (normalizedHeight - 0.4) / 0.3
            return Color(
                red: t,
                green: 1.0,
                blue: 0
            )
        } else {
            // 黄到红的渐变
            let t = (normalizedHeight - 0.7) / 0.3
            return Color(
                red: 1.0,
                green: 1.0 - t,
                blue: 0
            )
        }
    }

    private func spectrumBarNormalizedHeight(for index: Int, total: Int) -> CGFloat {
        // 灵敏度调高：30%音量时显示满格
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)

        // 生成类似音频频谱的波形图案
        let centerIndex = CGFloat(total) / 2.0
        let distanceFromCenter = abs(CGFloat(index) - centerIndex) / centerIndex

        // 中间高，两边低的分布
        let basePattern = 1.0 - pow(distanceFromCenter, 1.5)

        // 添加随机变化
        let randomSeed = sin(Double(index) * 1.5 + Double(animationPhase) * 3.14)
        let randomVariation = CGFloat(randomSeed) * 0.2

        return min(max((basePattern + randomVariation) * effectiveVolume, 0.1), 1.0)
    }

    // MARK: - 各样式的条高度计算

    private func classicBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 32
        // 灵敏度调高：30%音量时显示满格
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)
        let variation = effectiveVolume * (maxHeight - baseHeight)
        let baseOffsets: [CGFloat] = [0.35, 0.75, 1.0, 0.65, 0.4]
        let phaseOffsets: [CGFloat] = [0.1, -0.05, 0, 0.05, -0.1]
        let dynamicOffset = baseOffsets[index] + phaseOffsets[index] * animationPhase
        return baseHeight + variation * dynamicOffset
    }

    private func spectrumBarHeight(for index: Int, total: Int, maxHeight: CGFloat = 32) -> CGFloat {
        let baseHeight: CGFloat = 4
        let normalizedHeight = spectrumBarNormalizedHeight(for: index, total: total)
        return baseHeight + normalizedHeight * (maxHeight - baseHeight)
    }

    private func symmetricBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 28
        // 灵敏度调高：30%音量时显示满格
        let effectiveVolume = min(CGFloat(volumeLevel) * 3.5 + 0.3, 1.0)

        // 从外到内递增的模式
        let pattern: [CGFloat] = [0.3, 0.45, 0.6, 0.75, 0.85, 0.95, 1.0, 0.9]
        let baseMultiplier = pattern[min(index, pattern.count - 1)]

        let randomSeed = sin(Double(index) * 2.0 + Double(animationPhase) * 2.5)
        let variation = CGFloat(randomSeed) * 0.15

        return baseHeight + (baseMultiplier + variation) * effectiveVolume * (maxHeight - baseHeight)
    }

    private func wideBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 32
        let normalizedHeight = spectrumBarNormalizedHeight(for: index, total: 8)
        return baseHeight + normalizedHeight * (maxHeight - baseHeight)
    }

    private func compactBarHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let normalizedHeight = spectrumBarNormalizedHeight(for: index, total: 10)
        return baseHeight + normalizedHeight * (maxHeight - baseHeight)
    }

    private func dotOpacity(for index: Int) -> Double {
        let thresholds: [Float] = [0.0, 0.35, 0.65]
        return volumeLevel >= thresholds[index] ? 0.9 : 0.3
    }
}

// MARK: - 专业音量滑块

struct ProfessionalVolumeSlider: View {
    @Binding var value: Float
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            // 图标按钮
            ZStack {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            // 垂直滑块
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 8)

                    // 填充
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 8, height: geometry.size.height * CGFloat(value))
                }
                .frame(maxWidth: .infinity)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = 1.0 - Float(gesture.location.y / geometry.size.height)
                            value = max(0, min(1, newValue))
                        }
                )
            }
            .frame(width: 40, height: 100)

            // 百分比
            Text("\(Int(value * 100))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)

            // 标签
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - 群组编辑表单

enum GroupEditMode {
    case create
    case edit(PttGroup)

    var title: String {
        switch self {
        case .create: return "创建群组"
        case .edit: return "编辑群组"
        }
    }
}

struct GroupEditSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    let mode: GroupEditMode
    let onComplete: () -> Void

    @State private var name: String = ""
    @State private var selectedType: Int = 0
    @State private var note: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss

    // 群组类型列表
    private let groupTypes: [(value: Int, name: String, icon: String)] = [
        (0, "公共房间", "antenna.radiowaves.left.and.right"),
        (1, "中继互联", "point.3.connected.trianglepath.dotted"),
        (2, "设备互联", "cable.connector"),
        (3, "守听", "headphones"),
        (4, "数模互联", "waveform.and.magnifyingglass"),
        (5, "俱乐部", "star.fill"),
        (6, "车友会", "car.fill"),
        (7, "会议组", "person.3.fill"),
        (8, "私人房间", "lock.fill")
    ]

    private var editingGroup: PttGroup? {
        if case .edit(let group) = mode {
            return group
        }
        return nil
    }

    var body: some View {
        NavigationView {
            Form {
                // 群组名称
                Section(header: Text("群组名称")) {
                    TextField("请输入群组名称", text: $name)
                }

                // 群组类型
                Section(header: Text("群组类型")) {
                    Picker("类型", selection: $selectedType) {
                        ForEach(groupTypes, id: \.value) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.name)
                            }
                            .tag(type.value)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 群组描述
                Section(header: Text("群组描述")) {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }

                // 错误信息
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                // 删除按钮（仅编辑模式）
                if case .edit = mode {
                    Section {
                        Button(role: .destructive, action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("删除群组")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveGroup) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .onAppear {
                // 编辑模式下填充现有数据
                if let group = editingGroup {
                    name = group.name
                    selectedType = group.type
                    note = group.description ?? ""
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("确定要删除群组「\(editingGroup?.name ?? "")」吗？此操作不可恢复。")
            }
        }
    }

    private func saveGroup() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .create:
                    _ = try await viewModel.createGroup(name: name, type: selectedType, note: note.isEmpty ? nil : note)
                case .edit(let group):
                    try await viewModel.updateGroup(id: group.id, name: name, type: selectedType, note: note.isEmpty ? nil : note)
                }
                await viewModel.loadGroups()
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func deleteGroup() {
        guard let group = editingGroup else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await viewModel.deleteGroup(id: group.id)
                await viewModel.loadGroups()
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 设备管理视图

struct DeviceListView: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var devices: [PttDevice] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filterOnline: Bool? = nil  // nil=全部, true=在线, false=离线
    @State private var isEditMode = false
    @State private var selectedDevices: Set<Int> = []
    @State private var showATSheet = false
    @State private var showEditSheet = false
    @State private var selectedDevice: PttDevice?
    @State private var showBatchActionSheet = false
    @State private var lastRefreshTime: Date?
    @State private var deviceToDelete: PttDevice?
    @State private var showDeleteConfirmation = false

    // 自动刷新定时器
    private let refreshInterval: TimeInterval = 30

    var filteredDevices: [PttDevice] {
        var result = devices

        // 搜索过滤
        if !searchText.isEmpty {
            result = result.filter {
                $0.callsign.localizedCaseInsensitiveContains(searchText) ||
                ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 在线状态过滤
        if let filterOnline = filterOnline {
            result = result.filter { $0.isOnline == filterOnline }
        }

        return result
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏和筛选
                VStack(spacing: 12) {
                    // 搜索框
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索设备呼号或名称", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    // 筛选按钮
                    HStack(spacing: 10) {
                        FilterChip(title: "全部", isSelected: filterOnline == nil) {
                            filterOnline = nil
                        }
                        FilterChip(title: "在线", isSelected: filterOnline == true) {
                            filterOnline = true
                        }
                        FilterChip(title: "离线", isSelected: filterOnline == false) {
                            filterOnline = false
                        }
                        Spacer()

                        // 最后刷新时间
                        if let lastRefresh = lastRefreshTime {
                            Text(formatRefreshTime(lastRefresh))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()

                // 设备列表
                if isLoading && devices.isEmpty {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                } else if let error = errorMessage, devices.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            Task { await loadDevices() }
                        }
                    }
                    Spacer()
                } else if filteredDevices.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "暂无设备" : "未找到匹配的设备")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDevices) { device in
                                DeviceCard(
                                    device: device,
                                    isEditMode: isEditMode,
                                    isSelected: selectedDevices.contains(device.id),
                                    onToggleSelect: {
                                        if selectedDevices.contains(device.id) {
                                            selectedDevices.remove(device.id)
                                        } else {
                                            selectedDevices.insert(device.id)
                                        }
                                    },
                                    onEdit: {
                                        selectedDevice = device
                                        showEditSheet = true
                                    },
                                    onAT: {
                                        selectedDevice = device
                                        showATSheet = true
                                    },
                                    onDelete: {
                                        deviceToDelete = device
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadDevices()
                    }
                }

                // 批量操作栏 (编辑模式时显示)
                if isEditMode {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            Text("已选择 \(selectedDevices.count) 个设备")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button {
                                showBatchActionSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "ellipsis.circle")
                                    Text("批量操作")
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedDevices.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(selectedDevices.isEmpty)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
            .navigationTitle("设备管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "完成" : "编辑") {
                        withAnimation {
                            isEditMode.toggle()
                            if !isEditMode {
                                selectedDevices.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadDevices()
            startAutoRefresh()
        }
        .sheet(isPresented: $showATSheet) {
            if let device = selectedDevice {
                ATCommandSheet(viewModel: viewModel, device: device)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let device = selectedDevice {
                DeviceEditSheet(viewModel: viewModel, device: device) {
                    Task { await loadDevices() }
                }
            }
        }
        .confirmationDialog("批量操作", isPresented: $showBatchActionSheet, titleVisibility: .visible) {
            Button("禁止接收") {
                Task { await batchSetStatus(muteReceive: true, muteTransmit: nil) }
            }
            Button("禁止发送") {
                Task { await batchSetStatus(muteReceive: nil, muteTransmit: true) }
            }
            Button("解除禁收") {
                Task { await batchSetStatus(muteReceive: false, muteTransmit: nil) }
            }
            Button("解除禁发") {
                Task { await batchSetStatus(muteReceive: nil, muteTransmit: false) }
            }
            Button("全部解禁") {
                Task { await batchSetStatus(muteReceive: false, muteTransmit: false) }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                deviceToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let device = deviceToDelete {
                    Task { await deleteDevice(device) }
                }
            }
        } message: {
            if let device = deviceToDelete {
                Text("此操作将删除设备 \(device.displayName)，设备上线后会重新创建设备，是否继续？")
            }
        }
    }

    private func loadDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前群组的设备列表
            if let groupId = viewModel.currentGroup?.id {
                let detail = try await viewModel.apiService.getGroupDetail(groupId: groupId)
                await MainActor.run {
                    devices = detail.devices
                    lastRefreshTime = Date()
                    isLoading = false
                }
            } else {
                // 如果没有当前群组，获取所有设备
                let myDevices = try await viewModel.apiService.getMyDevices()
                await MainActor.run {
                    devices = myDevices
                    lastRefreshTime = Date()
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func startAutoRefresh() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                await loadDevices()
            }
        }
    }

    private func formatRefreshTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 {
            return "刚刚更新"
        } else if seconds < 3600 {
            return "\(seconds / 60)分钟前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }

    private func batchSetStatus(muteReceive: Bool?, muteTransmit: Bool?) async {
        let selectedDeviceList = devices.filter { selectedDevices.contains($0.id) }

        for device in selectedDeviceList {
            var newStatus = device.status

            if let mr = muteReceive {
                if mr {
                    newStatus = newStatus | 1  // 设置 bit0
                } else {
                    newStatus = newStatus & ~1  // 清除 bit0
                }
            }

            if let mt = muteTransmit {
                if mt {
                    newStatus = newStatus | 2  // 设置 bit1
                } else {
                    newStatus = newStatus & ~2  // 清除 bit1
                }
            }

            do {
                _ = try await viewModel.apiService.updateDevice(device: device, status: newStatus)
            } catch {
                print("Update device \(device.displayName) failed: \(error)")
            }
        }

        // 刷新列表
        await loadDevices()

        // 退出编辑模式
        await MainActor.run {
            isEditMode = false
            selectedDevices.removeAll()
        }
    }

    private func deleteDevice(_ device: PttDevice) async {
        isLoading = true
        do {
            let success = try await viewModel.apiService.deleteDevice(device: device)
            if success {
                await MainActor.run {
                    devices.removeAll { $0.id == device.id }
                }
            }
        } catch {
            print("[DeviceList] Delete device failed: \(error)")
        }
        deviceToDelete = nil
        isLoading = false
    }
}

// MARK: - 筛选按钮组件

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - 设备卡片

struct DeviceCard: View {
    let device: PttDevice
    let isEditMode: Bool
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onEdit: () -> Void
    let onAT: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // 上半部分: 设备信息
            HStack(alignment: .top, spacing: 12) {
                // 编辑模式时显示选择框
                if isEditMode {
                    Button(action: onToggleSelect) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .gray)
                    }
                }

                // 设备图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(device.isOnline ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: device.devModelIcon)
                        .font(.system(size: 22))
                        .foregroundColor(device.isOnline ? .green : .gray)
                }

                // 设备信息
                VStack(alignment: .leading, spacing: 6) {
                    // 呼号和状态
                    HStack {
                        Text(device.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        // 在线状态
                        HStack(spacing: 4) {
                            Circle()
                                .fill(device.isOnline ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(device.isOnline ? "在线" : "离线")
                                .font(.caption)
                                .foregroundColor(device.isOnline ? .green : .gray)
                        }
                    }

                    // 昵称
                    if let name = device.name, !name.isEmpty {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 设备型号和状态
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption)
                            Text(device.devModelName)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        // 禁收/禁发状态
                        if device.isMuteReceive || device.isMuteTransmit {
                            HStack(spacing: 4) {
                                if device.isMuteReceive {
                                    Label("禁收", systemImage: "speaker.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                if device.isMuteTransmit {
                                    Label("禁发", systemImage: "mic.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .padding()

            // 编辑模式下不显示操作栏
            if !isEditMode {
                Divider()

                // 底部操作栏
                HStack(spacing: 0) {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape")
                            Text("配置")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .frame(height: 20)

                    Button(action: onAT) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                            Text("AT指令")
                        }
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    if let onDelete = onDelete {
                        Divider()
                            .frame(height: 20)

                        Button(action: onDelete) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("删除")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 设备配置 Sheet

struct DeviceEditSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    let device: PttDevice
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedGroupId: Int = 0
    @State private var selectedDevModel: Int = 0
    @State private var selectedRfType: Int = 0
    @State private var selectedPriority: Int = 0
    @State private var muteReceive: Bool = false
    @State private var muteTransmit: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 设备型号选项
    private let devModelOptions: [(value: Int, name: String)] = [
        (0, "未知"),
        (1, "NRL-2100"),
        (2, "NRL-2200"),
        (3, "NRL-2300"),
        (4, "win-PC"),
        (5, "IOS"),
        (6, "Android"),
        (7, "树莓派"),
        (8, "NRL-2600"),
        (9, "NR-3188"),
        (10, "NRL-7100"),
        (11, "NRL-FT891"),
        (12, "NRL-TS480"),
        (13, "NRL-IC2720"),
        (14, "NRL-2730"),
        (15, "NRL-FT7900"),
        (16, "NRL-V71/D710"),
        (17, "NRL-3100"),
        (18, "NRL-8100-HF"),
        (19, "DR-635"),
        (20, "FTM-300D"),
        (21, "FTM-400D"),
        (22, "ESP32"),
        (23, "MMDVM"),
        (25, "4G便携"),
        (100, "微信小程序"),
        (101, "安卓APP"),
        (102, "苹果APP"),
        (106, "救援APP"),
        (200, "NRL-Server")
    ]

    // 射频类型选项
    private let rfTypeOptions: [(value: Int, name: String)] = [
        (0, "无射频"),
        (1, "1W模块"),
        (2, "2W模块"),
        (3, "Moto3188/3688"),
        (5, "Yaesu"),
        (6, "ICOM"),
        (7, "其它")
    ]

    var body: some View {
        NavigationView {
            Form {
                // 基本信息 (呼号只读)
                Section(header: Text("基本信息")) {
                    HStack {
                        Text("呼号")
                        Spacer()
                        Text(device.displayName)
                            .foregroundColor(.secondary)
                    }

                    Picker("设备型号", selection: $selectedDevModel) {
                        ForEach(devModelOptions, id: \.value) { option in
                            Text(option.name).tag(option.value)
                        }
                    }

                    Picker("射频类型", selection: $selectedRfType) {
                        ForEach(rfTypeOptions, id: \.value) { option in
                            Text(option.name).tag(option.value)
                        }
                    }
                }

                // 可编辑信息
                Section(header: Text("设备设置")) {
                    HStack {
                        Text("昵称")
                        TextField("设备昵称", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("所属群组", selection: $selectedGroupId) {
                        ForEach(viewModel.groups) { group in
                            Text(group.name).tag(group.id)
                        }
                    }

                    HStack {
                        Text("语音优先级")
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                if selectedPriority > 0 {
                                    selectedPriority -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(selectedPriority > 0 ? .blue : .gray)
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPriority <= 0)

                            TextField("0", value: $selectedPriority, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: selectedPriority) { newValue in
                                    if newValue < 0 { selectedPriority = 0 }
                                    if newValue > 255 { selectedPriority = 255 }
                                }

                            Button {
                                if selectedPriority < 255 {
                                    selectedPriority += 1
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(selectedPriority < 255 ? .blue : .gray)
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedPriority >= 255)
                        }
                    }
                    Text("数值越大优先级越高 (0-255)，高优先级可打断低优先级发言")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 权限控制
                Section(header: Text("权限控制")) {
                    Toggle(isOn: $muteReceive) {
                        HStack {
                            Image(systemName: "speaker.slash.fill")
                                .foregroundColor(.orange)
                            Text("禁止接收")
                        }
                    }

                    Toggle(isOn: $muteTransmit) {
                        HStack {
                            Image(systemName: "mic.slash.fill")
                                .foregroundColor(.red)
                            Text("禁止发送")
                        }
                    }
                }

                // 错误信息
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("设备配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveDevice()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                name = device.name ?? ""
                selectedGroupId = device.groupId
                selectedDevModel = device.devModel
                selectedRfType = device.rfType
                selectedPriority = device.priority
                muteReceive = device.isMuteReceive
                muteTransmit = device.isMuteTransmit
            }
        }
    }

    private func saveDevice() {
        isLoading = true
        errorMessage = nil

        // 计算新状态
        var newStatus = 0
        if muteReceive { newStatus = newStatus | 1 }
        if muteTransmit { newStatus = newStatus | 2 }

        Task {
            do {
                // 更新设备
                _ = try await viewModel.apiService.updateDevice(
                    device: device,
                    name: name.trimmingCharacters(in: .whitespaces),
                    groupId: selectedGroupId != device.groupId ? selectedGroupId : nil,
                    status: newStatus != device.status ? newStatus : nil,
                    devModel: selectedDevModel != device.devModel ? selectedDevModel : nil,
                    rfType: selectedRfType != device.rfType ? selectedRfType : nil,
                    priority: selectedPriority != device.priority ? selectedPriority : nil
                )

                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "保存失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - AT 指令 Sheet

struct ATCommandSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    let device: PttDevice

    @Environment(\.dismiss) private var dismiss
    @State private var command: String = ""
    @State private var isLoading = false
    @State private var history: [(command: String, response: String, isError: Bool)] = []

    // 常用指令
    private let commonCommands = [
        ("AT+INFO", "查询设备信息"),
        ("AT+VER", "查询固件版本"),
        ("AT+RESET", "重启设备"),
        ("AT+STATUS", "查询状态"),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 设备信息
                HStack {
                    Image(systemName: device.devModelIcon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(device.displayName)
                            .font(.headline)
                        Text(device.devModelName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(device.isOnline ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))

                // 常用指令
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commonCommands, id: \.0) { cmd, desc in
                            Button {
                                command = cmd
                            } label: {
                                Text(cmd)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))

                Divider()

                // 历史记录
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(history.enumerated()), id: \.offset) { index, item in
                                VStack(alignment: .leading, spacing: 4) {
                                    // 发送的指令
                                    HStack {
                                        Text("> ")
                                            .foregroundColor(.green)
                                        Text(item.command)
                                            .foregroundColor(.primary)
                                    }
                                    .font(.system(.body, design: .monospaced))

                                    // 响应
                                    HStack {
                                        Text("< ")
                                            .foregroundColor(item.isError ? .red : .blue)
                                        Text(item.response)
                                            .foregroundColor(item.isError ? .red : .secondary)
                                    }
                                    .font(.system(.body, design: .monospaced))
                                }
                                .id(index)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: history.count) { _ in
                        if let lastIndex = history.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // 输入区域
                HStack(spacing: 12) {
                    TextField("输入 AT 指令", text: $command)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    Button {
                        sendCommand()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(width: 60)
                        } else {
                            Text("发送")
                                .fontWeight(.semibold)
                                .frame(width: 60)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(command.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("AT 指令")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        history.removeAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(history.isEmpty)
                }
            }
        }
    }

    private func sendCommand() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        guard !trimmedCommand.isEmpty else { return }

        isLoading = true

        Task {
            do {
                let response = try await viewModel.apiService.sendATCommand(
                    callsign: device.callsign,
                    ssid: device.ssid,
                    command: trimmedCommand
                )

                await MainActor.run {
                    history.append((command: trimmedCommand, response: response, isError: false))
                    command = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    history.append((command: trimmedCommand, response: error.localizedDescription, isError: true))
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - 用户管理全屏视图 (用于 NavigationLink)

struct UserManagementFullView: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var users: [PttUser] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showAddUser = false
    @State private var showEditUser = false
    @State private var editingUser: PttUser?
    @State private var showDeleteAlert = false
    @State private var userToDelete: PttUser?
    @State private var errorMessage: String?

    private var filteredUsers: [PttUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.callsign.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏和新建按钮
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索用户名、呼号", text: $searchText)
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)

                Button {
                    showAddUser = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if users.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无用户")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredUsers) { user in
                            UserCardView(
                                user: user,
                                onEdit: {
                                    editingUser = user
                                    showEditUser = true
                                },
                                onDelete: {
                                    userToDelete = user
                                    showDeleteAlert = true
                                },
                                onToggleStatus: { enabled in
                                    toggleUserStatus(user: user, enabled: enabled)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("用户管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loadUsers()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadUsers()
        }
        .alert("删除用户", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let user = userToDelete {
                    deleteUser(user)
                }
            }
        } message: {
            Text("确定要删除用户 \(userToDelete?.displayName ?? "") 吗？")
        }
        .sheet(isPresented: $showAddUser) {
            UserEditSheet(viewModel: viewModel, mode: .add) {
                loadUsers()
            }
        }
        .sheet(isPresented: $showEditUser) {
            if let user = editingUser {
                UserEditSheet(viewModel: viewModel, mode: .edit(user)) {
                    loadUsers()
                }
            }
        }
    }

    private func loadUsers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await viewModel.apiService.getUserList()
                await MainActor.run {
                    // 按 id 逆序排列，最新用户在最上面
                    users = result.sorted { $0.id > $1.id }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func toggleUserStatus(user: PttUser, enabled: Bool) {
        Task {
            do {
                _ = try await viewModel.apiService.toggleUserStatus(user: user, enabled: enabled)
                loadUsers()
            } catch {
                await MainActor.run {
                    errorMessage = "更新状态失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteUser(_ user: PttUser) {
        Task {
            do {
                _ = try await viewModel.apiService.deleteUser(userId: user.id)
                await MainActor.run {
                    users.removeAll { $0.id == user.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 注册管理全屏视图 (用于 NavigationLink)

struct RegistrationManagementFullView: View {
    @ObservedObject var viewModel: PTTViewModel
    @State private var registrations: [PttRegistration] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showReviewSheet = false
    @State private var selectedRegistration: PttRegistration?

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if registrations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无注册申请")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(registrations) { registration in
                            RegistrationCardView(
                                registration: registration,
                                onReview: {
                                    selectedRegistration = registration
                                    showReviewSheet = true
                                },
                                onDelete: {
                                    deleteRegistration(registration)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("注册管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loadRegistrations()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadRegistrations()
        }
        .sheet(isPresented: $showReviewSheet) {
            if let registration = selectedRegistration {
                RegistrationReviewSheet(
                    viewModel: viewModel,
                    registration: registration
                ) {
                    loadRegistrations()
                }
            }
        }
    }

    private func loadRegistrations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await viewModel.apiService.getRegistrationList()
                await MainActor.run {
                    // 按 id 逆序排列，最新注册的在最上面
                    registrations = result.sorted { $0.id > $1.id }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func deleteRegistration(_ reg: PttRegistration) {
        Task {
            do {
                _ = try await viewModel.apiService.deleteRegistration(regId: reg.id)
                await MainActor.run {
                    loadRegistrations()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 用户管理视图

struct UserManagementView: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var users: [PttUser] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showAddUser = false
    @State private var showEditUser = false
    @State private var editingUser: PttUser?
    @State private var showDeleteAlert = false
    @State private var userToDelete: PttUser?
    @State private var errorMessage: String?

    private var filteredUsers: [PttUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.callsign.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏和新建按钮
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索用户名、呼号", text: $searchText)
                    }
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    Button {
                        showAddUser = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }
                }
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无用户")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredUsers) { user in
                                UserCardView(
                                    user: user,
                                    onEdit: {
                                        editingUser = user
                                        showEditUser = true
                                    },
                                    onDelete: {
                                        userToDelete = user
                                        showDeleteAlert = true
                                    },
                                    onToggleStatus: { enabled in
                                        toggleUserStatus(user: user, enabled: enabled)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("用户管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadUsers()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadUsers()
            }
            .alert("删除用户", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let user = userToDelete {
                        deleteUser(user)
                    }
                }
            } message: {
                Text("确定要删除用户 \(userToDelete?.displayName ?? "") 吗？")
            }
            .sheet(isPresented: $showAddUser) {
                UserEditSheet(viewModel: viewModel, mode: .add) {
                    loadUsers()
                }
            }
            .sheet(isPresented: $showEditUser) {
                if let user = editingUser {
                    UserEditSheet(viewModel: viewModel, mode: .edit(user)) {
                        loadUsers()
                    }
                }
            }
        }
    }

    private func loadUsers() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await viewModel.apiService.getUserList()
                await MainActor.run {
                    // 按 id 逆序排列，最新用户在最上面
                    users = result.sorted { $0.id > $1.id }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func toggleUserStatus(user: PttUser, enabled: Bool) {
        Task {
            do {
                _ = try await viewModel.apiService.toggleUserStatus(user: user, enabled: enabled)
                // 刷新用户列表
                loadUsers()
            } catch {
                await MainActor.run {
                    errorMessage = "更新状态失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteUser(_ user: PttUser) {
        Task {
            do {
                _ = try await viewModel.apiService.deleteUser(userId: user.id)
                await MainActor.run {
                    loadUsers()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 用户卡片视图

struct UserCardView: View {
    let user: PttUser
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleStatus: (Bool) -> Void
    @State private var isEnabled: Bool

    init(user: PttUser, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void, onToggleStatus: @escaping (Bool) -> Void) {
        self.user = user
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleStatus = onToggleStatus
        self._isEnabled = State(initialValue: user.isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 用户头像
                ZStack {
                    Circle()
                        .fill(user.isAdmin ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: user.isAdmin ? "person.badge.shield.checkmark.fill" : "person.fill")
                        .font(.system(size: 22))
                        .foregroundColor(user.isAdmin ? .orange : .blue)
                }

                // 用户信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.displayName)
                            .font(.headline)
                        if user.isAdmin {
                            Text("管理员")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                    if !user.name.isEmpty {
                        Text("姓名: \(user.name)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text("手机: \(user.phone)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let createTime = user.createTime {
                        Text("创建: \(createTime)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // 启用/禁用开关
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(.green)
                    .onChange(of: isEnabled) { newValue in
                        onToggleStatus(newValue)
                    }
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // 操作栏
            HStack {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                        Text("编辑")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Button {
                    onDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("删除")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 用户编辑表单

struct UserEditSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case add
        case edit(PttUser)
    }

    let mode: Mode
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var callsign: String = ""
    @State private var isAdmin: Bool = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        switch mode {
        case .add:
            return !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !password.isEmpty
        case .edit:
            return !phone.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var title: String {
        switch mode {
        case .add: return "添加用户"
        case .edit: return "编辑用户"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    if case .add = mode {
                        SecureField("密码", text: $password)
                    } else {
                        SecureField("新密码（留空不修改）", text: $password)
                    }
                } header: {
                    Text("账号信息")
                }

                Section {
                    TextField("姓名", text: $name)
                    TextField("呼号", text: $callsign)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                } header: {
                    Text("个人信息")
                }

                Section {
                    Toggle("管理员权限", isOn: $isAdmin)
                } header: {
                    Text("权限设置")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveUser()
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .onAppear {
                if case .edit(let user) = mode {
                    name = user.name
                    phone = user.phone
                    callsign = user.callsign
                    isAdmin = user.isAdmin
                }
            }
        }
    }

    private func saveUser() {
        isLoading = true
        errorMessage = nil

        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCallsign = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        let roles = isAdmin ? ["admin"] : ["ham"]

        Task {
            do {
                switch mode {
                case .add:
                    _ = try await viewModel.apiService.addUser(
                        phone: trimmedPhone,
                        password: password,
                        name: trimmedName.isEmpty ? nil : trimmedName,
                        callsign: trimmedCallsign.isEmpty ? nil : trimmedCallsign,
                        roles: roles
                    )
                case .edit(let user):
                    // 使用新的 updateUser 函数，保留原始用户的所有字段（如头像、生日等）
                    _ = try await viewModel.apiService.updateUser(
                        originalUser: user,
                        phone: trimmedPhone,
                        password: password.isEmpty ? nil : password,
                        name: trimmedName,
                        callsign: trimmedCallsign,
                        roles: roles
                    )
                }
                isLoading = false
                onSave()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = "保存失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 注册管理视图

struct RegistrationManagementView: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var registrations: [PttRegistration] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showReviewSheet = false
    @State private var reviewingRegistration: PttRegistration?
    @State private var showDeleteAlert = false
    @State private var regToDelete: PttRegistration?
    @State private var errorMessage: String?

    private var filteredRegistrations: [PttRegistration] {
        if searchText.isEmpty {
            return registrations
        }
        return registrations.filter {
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.callsign.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索用户名、呼号", text: $searchText)
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if registrations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无注册申请")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRegistrations) { reg in
                                RegistrationCardView(
                                    registration: reg,
                                    onReview: {
                                        reviewingRegistration = reg
                                        showReviewSheet = true
                                    },
                                    onDelete: {
                                        regToDelete = reg
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("注册管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadRegistrations()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadRegistrations()
            }
            .alert("删除申请", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let reg = regToDelete {
                        deleteRegistration(reg)
                    }
                }
            } message: {
                Text("确定要删除此注册申请吗？")
            }
            .sheet(isPresented: $showReviewSheet) {
                if let reg = reviewingRegistration {
                    RegistrationReviewSheet(viewModel: viewModel, registration: reg) {
                        loadRegistrations()
                    }
                }
            }
        }
    }

    private func loadRegistrations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await viewModel.apiService.getRegistrationList()
                await MainActor.run {
                    // 按 id 逆序排列，最新注册的在最上面
                    registrations = result.sorted { $0.id > $1.id }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func deleteRegistration(_ reg: PttRegistration) {
        Task {
            do {
                _ = try await viewModel.apiService.deleteRegistration(regId: reg.id)
                await MainActor.run {
                    loadRegistrations()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 注册卡片视图

struct RegistrationCardView: View {
    let registration: PttRegistration
    let onReview: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch registration.status {
        case 0: return .orange  // 待审核
        case 2: return .green   // 已通过
        default: return .red    // 已拒绝
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: registration.status == 0 ? "clock.fill" :
                            (registration.status == 2 ? "checkmark.circle.fill" : "xmark.circle.fill"))
                        .font(.system(size: 22))
                        .foregroundColor(statusColor)
                }

                // 注册信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(registration.callsign)-\(registration.ssid)")
                            .font(.headline)
                        Text(registration.statusText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(4)
                    }
                    Text("用户名: \(registration.username)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let createTime = registration.createTime {
                        Text("申请时间: \(createTime)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    if let note = registration.note, !note.isEmpty {
                        Text("备注: \(note)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // 操作栏
            HStack {
                if registration.status == 0 {
                    Button {
                        onReview()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                            Text("审核")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Text(registration.status == 2 ? "已通过" : "已拒绝")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                Button {
                    onDelete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("删除")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 注册审核表单

struct RegistrationReviewSheet: View {
    @ObservedObject var viewModel: PTTViewModel
    @Environment(\.dismiss) private var dismiss

    let registration: PttRegistration
    let onComplete: () -> Void

    @State private var note: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("呼号")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(registration.callsign)-\(registration.ssid)")
                    }
                    HStack {
                        Text("用户名")
                            .foregroundColor(.gray)
                        Spacer()
                        Text(registration.username)
                    }
                    if let createTime = registration.createTime {
                        HStack {
                            Text("申请时间")
                                .foregroundColor(.gray)
                            Spacer()
                            Text(createTime)
                        }
                    }
                } header: {
                    Text("申请信息")
                }

                if let imageUrl = registration.imageUrl, !imageUrl.isEmpty {
                    Section {
                        HStack {
                            Text("查看执照图片")
                            Spacer()
                            Image(systemName: "photo")
                                .foregroundColor(.blue)
                        }
                    } header: {
                        Text("证件图片")
                    }
                }

                Section {
                    TextField("审核备注（可选）", text: $note)
                } header: {
                    Text("审核意见")
                }

                Section {
                    Button {
                        reviewRegistration(approve: true)
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("通过申请")
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.green)

                    Button {
                        reviewRegistration(approve: false)
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                Text("拒绝申请")
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.red)
                }
                .disabled(isLoading)

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("审核注册申请")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func reviewRegistration(approve: Bool) {
        isLoading = true
        errorMessage = nil

        let status = approve ? 2 : 1  // 2=通过, 1=拒绝

        Task {
            do {
                _ = try await viewModel.apiService.reviewRegistration(
                    regId: registration.id,
                    status: status,
                    note: note.isEmpty ? nil : note
                )
                isLoading = false
                onComplete()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = "操作失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 权限说明视图

struct PermissionInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    permissionItem(
                        icon: "mic.fill",
                        color: .red,
                        title: "麦克风",
                        description: "用于语音对讲功能，按住 PTT 按钮说话时需要录制您的声音并发送给群组成员。"
                    )

                    permissionItem(
                        icon: "speaker.wave.3.fill",
                        color: .orange,
                        title: "扬声器/音频",
                        description: "用于播放其他成员的语音消息和通话回放。"
                    )

                    permissionItem(
                        icon: "wifi",
                        color: .blue,
                        title: "网络访问",
                        description: "用于连接 PTT 服务器，发送和接收语音数据、消息和群组信息。"
                    )

                    permissionItem(
                        icon: "bell.fill",
                        color: .purple,
                        title: "通知",
                        description: "用于接收新消息提醒和来电通知（可选）。"
                    )

                    permissionItem(
                        icon: "arrow.clockwise.circle.fill",
                        color: .green,
                        title: "后台运行",
                        description: "允许应用在后台保持连接，确保您不会错过任何语音呼叫。"
                    )

                    Spacer(minLength: 20)

                    Text("提示：您可以在 iPhone 设置 > PTTApp 中管理这些权限。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("权限说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func permissionItem(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 帮助视图

struct HelpInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 快速开始
                    helpSection(title: "快速开始") {
                        helpItem(number: "1", text: "登录您的账号或使用管理员分配的呼号")
                        helpItem(number: "2", text: "在群组页面选择要加入的对讲群组")
                        helpItem(number: "3", text: "点击底部 PTT 按钮进入对讲界面")
                        helpItem(number: "4", text: "按住大圆按钮说话，松开发送")
                    }

                    // 语音对讲
                    helpSection(title: "语音对讲") {
                        helpText("• **长按说话**：按住 PTT 按钮开始说话，松开自动发送")
                        helpText("• **点击说话**：在设置中开启后，点击开始/结束说话")
                        helpText("• **人声增强**：开启后自动降噪并优化人声")
                        helpText("• **通话记录**：自动保存所有通话，可回放或删除")
                    }

                    // 群组管理
                    helpSection(title: "群组管理") {
                        helpText("• **查看群组**：在群组页面查看所有群组")
                        helpText("• **切换群组**：点击群组卡片切换当前对讲群组")
                        helpText("• **群组详情**：点击群组查看成员列表和在线状态")
                    }

                    // 常见问题
                    helpSection(title: "常见问题") {
                        faqItem(
                            question: "为什么听不到声音？",
                            answer: "请检查：1) 设备音量是否开启；2) 是否连接到正确的群组；3) 网络是否正常。"
                        )
                        faqItem(
                            question: "为什么对方听不到我说话？",
                            answer: "请检查：1) 麦克风权限是否开启；2) PTT 按钮是否按住；3) 网络连接是否稳定。"
                        )
                        faqItem(
                            question: "如何节省流量？",
                            answer: "语音使用 G711 编码，每分钟约消耗 480KB 流量。建议在 WiFi 环境下使用。"
                        )
                    }

                    // 联系支持
                    helpSection(title: "联系我们") {
                        helpText("如有问题或建议，请联系技术支持：")
                        helpText("• 邮箱：support@pgarlic.com")
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func helpSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            content()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func helpItem(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }

    private func helpText(_ text: String) -> some View {
        Text(.init(text))
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(answer)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PTTMainView()
}
