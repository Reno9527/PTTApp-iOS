import Foundation
import Accelerate

/// 音频重采样器
///
/// 使用 vDSP 加速 + 低通滤波器实现高质量重采样
/// 支持 48kHz ↔ 8kHz / 16kHz 转换
public final class AudioResampler: @unchecked Sendable {

    // MARK: - 采样率常量

    /// 高采样率 (48000 Hz - RNNoise)
    public static let highSampleRate = 48000

    /// 低采样率 (8000 Hz - G711)
    public static let lowSampleRate = 8000

    /// 中采样率 (16000 Hz - Opus)
    public static let midSampleRate = 16000

    /// 重采样比率 48k→8k (48000 / 8000 = 6)
    public static let resampleRatio = 6

    /// 重采样比率 48k→16k (48000 / 16000 = 3)
    public static let resampleRatio16k = 3

    /// 重采样比率 8k→16k (16000 / 8000 = 2)
    public static let resampleRatio8kTo16k = 2

    // MARK: - 低通滤波器

    /// 低通滤波器阶数（越高截止越陡，但延迟越大）
    private static let filterOrder = 31

    /// 8k→16k 专用滤波器阶数（更高阶以获得更平坦的通带）
    private static let filterOrder8kTo16k = 63

    /// 48k→8k 低通滤波器系数（截止频率 ~3.5kHz，为 4kHz 留余量）
    /// 使用 Hamming 窗设计的 FIR 滤波器
    private let lowpassCoeffs8k: [Float]

    /// 48k→16k 低通滤波器系数（截止频率 ~7kHz）
    private let lowpassCoeffs16k: [Float]

    /// 上采样后的低通滤波器系数（去除镜像频率）
    private let upsampleLowpassCoeffs8k: [Float]
    private let upsampleLowpassCoeffs16k: [Float]

    /// 8kHz→16kHz 上采样滤波器系数（截止频率 ~3.8kHz，63阶）
    private let upsampleLowpassCoeffs8kTo16k: [Float]

    // MARK: - 滤波器状态（历史缓冲）

    /// 下采样滤波器历史缓冲
    private var downsampleHistory8k: [Float]
    private var downsampleHistory16k: [Float]

    /// 上采样滤波器历史缓冲
    private var upsampleHistory8k: [Float]
    private var upsampleHistory16k: [Float]
    private var upsampleHistory8kTo16k: [Float]

    // MARK: - 累积器（使用预分配数组 + 索引，避免 removeFirst）

    /// 下采样累积器
    private var downsampleBuffer8k: [Float]
    private var downsampleBuffer8kCount: Int = 0

    private var downsampleBuffer16k: [Float]
    private var downsampleBuffer16kCount: Int = 0

    /// 上采样历史值（用于插值）
    private var lastSample8k: Float = 0
    private var lastSample16k: Float = 0
    private var lastSample8kTo16k: Float = 0

    // MARK: - 初始化

    public init() {
        // 设计低通滤波器系数（使用 Hamming 窗的 FIR 滤波器）
        let order = Self.filterOrder

        // 48k→8k: 截止频率 3.5kHz / 24kHz = 0.146 (归一化频率)
        lowpassCoeffs8k = Self.designLowpassFilter(order: order, normalizedCutoff: 0.146)

        // 48k→16k: 截止频率 7kHz / 24kHz = 0.292
        lowpassCoeffs16k = Self.designLowpassFilter(order: order, normalizedCutoff: 0.292)

        // 上采样后滤波器（与下采样相同截止频率）
        upsampleLowpassCoeffs8k = lowpassCoeffs8k
        upsampleLowpassCoeffs16k = lowpassCoeffs16k

        // 8kHz→16kHz 上采样滤波器：截止频率 3.8kHz / 8kHz = 0.475 (归一化频率)
        // 使用 63 阶获得更平坦的通带响应
        upsampleLowpassCoeffs8kTo16k = Self.designLowpassFilter(order: Self.filterOrder8kTo16k, normalizedCutoff: 0.475)

        // 初始化历史缓冲
        downsampleHistory8k = [Float](repeating: 0, count: order)
        downsampleHistory16k = [Float](repeating: 0, count: order)
        upsampleHistory8k = [Float](repeating: 0, count: order)
        upsampleHistory16k = [Float](repeating: 0, count: order)
        upsampleHistory8kTo16k = [Float](repeating: 0, count: Self.filterOrder8kTo16k)

        // 预分配累积器（足够大以容纳多帧数据）
        let maxBufferSize = 4800  // 100ms @ 48kHz
        downsampleBuffer8k = [Float](repeating: 0, count: maxBufferSize)
        downsampleBuffer16k = [Float](repeating: 0, count: maxBufferSize)
    }

    // MARK: - 滤波器设计

    /// 使用 Hamming 窗设计 FIR 低通滤波器
    /// - Parameters:
    ///   - order: 滤波器阶数（系数个数）
    ///   - normalizedCutoff: 归一化截止频率 (0~1，1 = Nyquist)
    /// - Returns: 滤波器系数
    private static func designLowpassFilter(order: Int, normalizedCutoff: Float) -> [Float] {
        var coeffs = [Float](repeating: 0, count: order)
        let center = Float(order - 1) / 2.0
        let omega = Float.pi * normalizedCutoff

        for i in 0..<order {
            let n = Float(i) - center

            // sinc 函数
            let sinc: Float
            if abs(n) < 0.0001 {
                sinc = omega / Float.pi
            } else {
                sinc = sin(omega * n) / (Float.pi * n)
            }

            // Hamming 窗
            let hamming = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(order - 1))

            coeffs[i] = sinc * hamming
        }

        // 归一化（使直流增益为 1）
        let sum = coeffs.reduce(0, +)
        if sum > 0 {
            for i in 0..<order {
                coeffs[i] /= sum
            }
        }

        return coeffs
    }

    // MARK: - 下采样 (48kHz → 8kHz)

    /// 将 48kHz 音频下采样到 8kHz（带低通滤波抗混叠）
    ///
    /// - Parameter samples: 48kHz Float32 PCM 采样点 (范围 [-32768, 32768])
    /// - Returns: 8kHz Int16 PCM 采样点
    public func downsample48kTo8k(_ samples: [Float]) -> [Int16] {
        // 1. 低通滤波（抗混叠）
        let filtered = applyLowpassFilter(
            samples,
            coeffs: lowpassCoeffs8k,
            history: &downsampleHistory8k
        )

        // 2. 添加到累积器
        let newCount = downsampleBuffer8kCount + filtered.count
        if newCount > downsampleBuffer8k.count {
            // 扩容（罕见情况）
            downsampleBuffer8k.append(contentsOf: [Float](repeating: 0, count: newCount - downsampleBuffer8k.count))
        }
        for i in 0..<filtered.count {
            downsampleBuffer8k[downsampleBuffer8kCount + i] = filtered[i]
        }
        downsampleBuffer8kCount = newCount

        // 3. 抽取（每 6 个点取 1 个）
        let outputCount = downsampleBuffer8kCount / Self.resampleRatio
        guard outputCount > 0 else {
            return []
        }

        var output = [Int16](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let value = downsampleBuffer8k[i * Self.resampleRatio]
            output[i] = Int16(clamping: Int32(value))
        }

        // 4. 移动剩余数据到缓冲区开头（比 removeFirst 高效）
        let processedCount = outputCount * Self.resampleRatio
        let remainingCount = downsampleBuffer8kCount - processedCount
        if remainingCount > 0 {
            for i in 0..<remainingCount {
                downsampleBuffer8k[i] = downsampleBuffer8k[processedCount + i]
            }
        }
        downsampleBuffer8kCount = remainingCount

        return output
    }

    /// 将 48kHz Float 音频下采样到 8kHz Float
    public func downsample48kTo8kFloat(_ samples: [Float]) -> [Float] {
        let filtered = applyLowpassFilter(
            samples,
            coeffs: lowpassCoeffs8k,
            history: &downsampleHistory8k
        )

        let newCount = downsampleBuffer8kCount + filtered.count
        if newCount > downsampleBuffer8k.count {
            downsampleBuffer8k.append(contentsOf: [Float](repeating: 0, count: newCount - downsampleBuffer8k.count))
        }
        for i in 0..<filtered.count {
            downsampleBuffer8k[downsampleBuffer8kCount + i] = filtered[i]
        }
        downsampleBuffer8kCount = newCount

        let outputCount = downsampleBuffer8kCount / Self.resampleRatio
        guard outputCount > 0 else {
            return []
        }

        var output = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            output[i] = downsampleBuffer8k[i * Self.resampleRatio]
        }

        let processedCount = outputCount * Self.resampleRatio
        let remainingCount = downsampleBuffer8kCount - processedCount
        if remainingCount > 0 {
            for i in 0..<remainingCount {
                downsampleBuffer8k[i] = downsampleBuffer8k[processedCount + i]
            }
        }
        downsampleBuffer8kCount = remainingCount

        return output
    }

    // MARK: - 下采样 (48kHz → 16kHz) for Opus

    /// 将 48kHz 音频下采样到 16kHz（带低通滤波抗混叠）
    public func downsample48kTo16k(_ samples: [Float]) -> [Int16] {
        let filtered = applyLowpassFilter(
            samples,
            coeffs: lowpassCoeffs16k,
            history: &downsampleHistory16k
        )

        let newCount = downsampleBuffer16kCount + filtered.count
        if newCount > downsampleBuffer16k.count {
            downsampleBuffer16k.append(contentsOf: [Float](repeating: 0, count: newCount - downsampleBuffer16k.count))
        }
        for i in 0..<filtered.count {
            downsampleBuffer16k[downsampleBuffer16kCount + i] = filtered[i]
        }
        downsampleBuffer16kCount = newCount

        let outputCount = downsampleBuffer16kCount / Self.resampleRatio16k
        guard outputCount > 0 else {
            return []
        }

        var output = [Int16](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let value = downsampleBuffer16k[i * Self.resampleRatio16k]
            output[i] = Int16(clamping: Int32(value))
        }

        let processedCount = outputCount * Self.resampleRatio16k
        let remainingCount = downsampleBuffer16kCount - processedCount
        if remainingCount > 0 {
            for i in 0..<remainingCount {
                downsampleBuffer16k[i] = downsampleBuffer16k[processedCount + i]
            }
        }
        downsampleBuffer16kCount = remainingCount

        return output
    }

    /// 将 48kHz Float 音频下采样到 16kHz Float
    public func downsample48kTo16kFloat(_ samples: [Float]) -> [Float] {
        let filtered = applyLowpassFilter(
            samples,
            coeffs: lowpassCoeffs16k,
            history: &downsampleHistory16k
        )

        let newCount = downsampleBuffer16kCount + filtered.count
        if newCount > downsampleBuffer16k.count {
            downsampleBuffer16k.append(contentsOf: [Float](repeating: 0, count: newCount - downsampleBuffer16k.count))
        }
        for i in 0..<filtered.count {
            downsampleBuffer16k[downsampleBuffer16kCount + i] = filtered[i]
        }
        downsampleBuffer16kCount = newCount

        let outputCount = downsampleBuffer16kCount / Self.resampleRatio16k
        guard outputCount > 0 else {
            return []
        }

        var output = [Float](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            output[i] = downsampleBuffer16k[i * Self.resampleRatio16k]
        }

        let processedCount = outputCount * Self.resampleRatio16k
        let remainingCount = downsampleBuffer16kCount - processedCount
        if remainingCount > 0 {
            for i in 0..<remainingCount {
                downsampleBuffer16k[i] = downsampleBuffer16k[processedCount + i]
            }
        }
        downsampleBuffer16kCount = remainingCount

        return output
    }

    // MARK: - 上采样 (8kHz → 48kHz)

    /// 将 8kHz 音频上采样到 48kHz（带低通滤波去除镜像）
    ///
    /// - Parameter samples: 8kHz Int16 PCM 采样点
    /// - Returns: 48kHz Float32 PCM 采样点 (范围 [-32768, 32768])
    public func upsample8kTo48k(_ samples: [Int16]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio

        // 1. 插值（线性插值 + 插零）
        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = Float(samples[i])
            let prev = i > 0 ? Float(samples[i - 1]) : lastSample8k

            // 线性插值
            for j in 0..<Self.resampleRatio {
                let t = Float(j) / Float(Self.resampleRatio)
                interpolated[i * Self.resampleRatio + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample8k = Float(last)
        }

        // 2. 低通滤波（去除镜像频率）
        // 增益补偿：上采样后能量分散，需要乘以插值倍数
        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs8k,
            history: &upsampleHistory8k
        )

        // 增益补偿
        let gain = Float(Self.resampleRatio)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    /// 将 8kHz Float 音频上采样到 48kHz
    public func upsample8kTo48kFloat(_ samples: [Float]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio

        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = samples[i]
            let prev = i > 0 ? samples[i - 1] : lastSample8k

            for j in 0..<Self.resampleRatio {
                let t = Float(j) / Float(Self.resampleRatio)
                interpolated[i * Self.resampleRatio + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample8k = last
        }

        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs8k,
            history: &upsampleHistory8k
        )

        let gain = Float(Self.resampleRatio)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    // MARK: - 上采样 (16kHz → 48kHz) for Opus playback

    /// 将 16kHz 音频上采样到 48kHz
    public func upsample16kTo48k(_ samples: [Int16]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio16k

        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = Float(samples[i])
            let prev = i > 0 ? Float(samples[i - 1]) : lastSample16k

            for j in 0..<Self.resampleRatio16k {
                let t = Float(j) / Float(Self.resampleRatio16k)
                interpolated[i * Self.resampleRatio16k + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample16k = Float(last)
        }

        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs16k,
            history: &upsampleHistory16k
        )

        let gain = Float(Self.resampleRatio16k)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    /// 将 16kHz Float 音频上采样到 48kHz
    public func upsample16kTo48kFloat(_ samples: [Float]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio16k

        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = samples[i]
            let prev = i > 0 ? samples[i - 1] : lastSample16k

            for j in 0..<Self.resampleRatio16k {
                let t = Float(j) / Float(Self.resampleRatio16k)
                interpolated[i * Self.resampleRatio16k + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample16k = last
        }

        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs16k,
            history: &upsampleHistory16k
        )

        let gain = Float(Self.resampleRatio16k)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    // MARK: - 上采样 (8kHz → 16kHz) for G.711 playback at 16kHz

    /// 将 8kHz 音频上采样到 16kHz（带低通滤波去除镜像）
    /// 用于 G.711 接收端，统一输出 16kHz 给系统播放
    ///
    /// - Parameter samples: 8kHz Int16 PCM 采样点
    /// - Returns: 16kHz Float32 PCM 采样点
    public func upsample8kTo16k(_ samples: [Int16]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio8kTo16k

        // 1. 插值（线性插值）
        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = Float(samples[i])
            let prev = i > 0 ? Float(samples[i - 1]) : lastSample8kTo16k

            // 线性插值：每 1 个输入点生成 2 个输出点
            for j in 0..<Self.resampleRatio8kTo16k {
                let t = Float(j) / Float(Self.resampleRatio8kTo16k)
                interpolated[i * Self.resampleRatio8kTo16k + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample8kTo16k = Float(last)
        }

        // 2. 低通滤波（去除镜像频率）
        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs8kTo16k,
            history: &upsampleHistory8kTo16k
        )

        // 增益补偿
        let gain = Float(Self.resampleRatio8kTo16k)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    /// 将 8kHz Float 音频上采样到 16kHz
    public func upsample8kTo16kFloat(_ samples: [Float]) -> [Float] {
        let inputCount = samples.count
        let outputCount = inputCount * Self.resampleRatio8kTo16k

        var interpolated = [Float](repeating: 0, count: outputCount)

        for i in 0..<inputCount {
            let current = samples[i]
            let prev = i > 0 ? samples[i - 1] : lastSample8kTo16k

            for j in 0..<Self.resampleRatio8kTo16k {
                let t = Float(j) / Float(Self.resampleRatio8kTo16k)
                interpolated[i * Self.resampleRatio8kTo16k + j] = prev + (current - prev) * t
            }
        }

        if let last = samples.last {
            lastSample8kTo16k = last
        }

        var filtered = applyLowpassFilter(
            interpolated,
            coeffs: upsampleLowpassCoeffs8kTo16k,
            history: &upsampleHistory8kTo16k
        )

        let gain = Float(Self.resampleRatio8kTo16k)
        vDSP_vsmul(filtered, 1, [gain], &filtered, 1, vDSP_Length(filtered.count))

        return filtered
    }

    // MARK: - 低通滤波器（使用 vDSP 加速）

    /// 应用 FIR 低通滤波器
    /// - Parameters:
    ///   - samples: 输入采样点
    ///   - coeffs: 滤波器系数
    ///   - history: 历史缓冲（用于跨帧连续性）
    /// - Returns: 滤波后的采样点
    private func applyLowpassFilter(
        _ samples: [Float],
        coeffs: [Float],
        history: inout [Float]
    ) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let filterLen = coeffs.count
        let inputLen = samples.count

        // 构建扩展输入（历史 + 当前）
        var extendedInput = [Float](repeating: 0, count: filterLen - 1 + inputLen)

        // 复制历史数据
        for i in 0..<(filterLen - 1) {
            extendedInput[i] = history[i]
        }

        // 复制当前输入
        for i in 0..<inputLen {
            extendedInput[filterLen - 1 + i] = samples[i]
        }

        // 使用 vDSP 进行卷积
        var output = [Float](repeating: 0, count: inputLen)
        vDSP_conv(
            extendedInput, 1,
            coeffs.reversed(), 1,  // FIR 滤波器需要反转系数
            &output, 1,
            vDSP_Length(inputLen),
            vDSP_Length(filterLen)
        )

        // 更新历史缓冲（保存最后 filterLen-1 个采样点）
        let historyStart = inputLen - (filterLen - 1)
        if historyStart >= 0 {
            for i in 0..<(filterLen - 1) {
                history[i] = samples[historyStart + i]
            }
        } else {
            // 输入不够长，混合历史和输入
            let fromHistory = (filterLen - 1) - inputLen
            for i in 0..<fromHistory {
                history[i] = history[inputLen + i]
            }
            for i in 0..<inputLen {
                history[fromHistory + i] = samples[i]
            }
        }

        return output
    }

    // MARK: - 重置

    /// 重置重采样器状态
    public func reset() {
        // 重置历史缓冲
        for i in 0..<downsampleHistory8k.count {
            downsampleHistory8k[i] = 0
        }
        for i in 0..<downsampleHistory16k.count {
            downsampleHistory16k[i] = 0
        }
        for i in 0..<upsampleHistory8k.count {
            upsampleHistory8k[i] = 0
        }
        for i in 0..<upsampleHistory16k.count {
            upsampleHistory16k[i] = 0
        }
        for i in 0..<upsampleHistory8kTo16k.count {
            upsampleHistory8kTo16k[i] = 0
        }

        // 重置累积器
        downsampleBuffer8kCount = 0
        downsampleBuffer16kCount = 0

        // 重置上采样历史值
        lastSample8k = 0
        lastSample16k = 0
        lastSample8kTo16k = 0
    }
}

// MARK: - 便捷扩展

extension AudioResampler {

    /// 计算下采样后的采样点数
    ///
    /// - Parameter count48k: 48kHz 采样点数
    /// - Returns: 8kHz 采样点数
    public static func downsampledCount(from count48k: Int) -> Int {
        return count48k / resampleRatio
    }

    /// 计算上采样后的采样点数
    ///
    /// - Parameter count8k: 8kHz 采样点数
    /// - Returns: 48kHz 采样点数
    public static func upsampledCount(from count8k: Int) -> Int {
        return count8k * resampleRatio
    }

    /// RNNoise 帧对应的 8kHz 采样点数
    /// 480 samples @ 48kHz = 80 samples @ 8kHz
    public static let rnnoiseFrameSize8k = RNNoiseProcessor.frameSize / resampleRatio  // 80

    /// 计算下采样后的采样点数 (48k→16k)
    ///
    /// - Parameter count48k: 48kHz 采样点数
    /// - Returns: 16kHz 采样点数
    public static func downsampledCount16k(from count48k: Int) -> Int {
        return count48k / resampleRatio16k
    }

    /// 计算上采样后的采样点数 (16k→48k)
    ///
    /// - Parameter count16k: 16kHz 采样点数
    /// - Returns: 48kHz 采样点数
    public static func upsampledCount16k(from count16k: Int) -> Int {
        return count16k * resampleRatio16k
    }

    /// RNNoise 帧对应的 16kHz 采样点数
    /// 480 samples @ 48kHz = 160 samples @ 16kHz
    public static let rnnoiseFrameSize16k = RNNoiseProcessor.frameSize / resampleRatio16k  // 160
}
