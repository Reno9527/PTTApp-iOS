import Foundation
import os.log

private let eqLog = OSLog(subsystem: "com.pgarlic.pttapp", category: "VoiceEQ")

/// TX 人声调音 EQ（2 段简洁 EQ + RMS 补偿）
///
/// ## 频段设计
/// 1. **High-pass** (110 Hz): 去低频轰鸣
/// 2. **Peaking** (1.5 kHz, +1.0 dB, Q=0.8): 人声存在感
///
/// ## RMS 补偿
/// - 不是 AGC，只是小幅补偿存在感
/// - 目标 RMS: 6000，补偿系数: 1.05
///
/// ## 约束
/// - 任意频段 boost 不超过 +2 dB
/// - 不推高频 (5kHz 以上)
/// - 实时低 CPU（逐 sample IIR）
public final class VoiceEQ: @unchecked Sendable {

    // MARK: - 常量

    /// 默认采样率 (48 kHz)
    public static let defaultSampleRate: Float = 48000.0

    /// RMS 补偿目标值
    private let targetRms: Float = 6000.0

    /// RMS 补偿系数（小幅补偿，不是 AGC）
    private let rmsBoostFactor: Float = 1.05

    // MARK: - Biquad 滤波器结构

    /// Biquad 滤波器系数和状态
    private struct BiquadFilter {
        // 系数 (normalized)
        var b0: Float = 1.0
        var b1: Float = 0.0
        var b2: Float = 0.0
        var a1: Float = 0.0
        var a2: Float = 0.0

        // 状态变量 (Direct Form II Transposed)
        var z1: Float = 0.0
        var z2: Float = 0.0

        /// 处理单个采样点
        @inline(__always)
        mutating func process(_ input: Float) -> Float {
            let output = b0 * input + z1
            z1 = b1 * input - a1 * output + z2
            z2 = b2 * input - a2 * output
            return output
        }

        /// 重置状态
        mutating func reset() {
            z1 = 0.0
            z2 = 0.0
        }
    }

    // MARK: - 属性

    private let sampleRate: Float

    /// High-pass 滤波器 (110 Hz, 2nd order)
    private var highpassFilter = BiquadFilter()

    /// Peaking 滤波器 (1.5 kHz, +1.0 dB, Q=0.8)
    private var peakingFilter = BiquadFilter()

    /// 是否启用 EQ（默认关闭）
    public var isEnabled: Bool = false

    /// 是否启用 RMS 补偿（默认开启）
    public var enableRmsBoost: Bool = true

    /// 是否打印调试信息
    public var debugPrint: Bool = false

    /// 处理帧计数
    private var frameCounter: UInt64 = 0

    // MARK: - 可调参数

    /// High-pass 截止频率 (Hz)
    public var highpassCutoff: Float = 110.0 {
        didSet { updateHighpassCoefficients() }
    }

    /// Peaking 中心频率 (Hz) - 1.5kHz 人声存在感
    public var peakingFrequency: Float = 1500.0 {
        didSet { updatePeakingCoefficients() }
    }

    /// Peaking 增益 (dB) - 只加一点
    public var peakingGain: Float = 1.0 {
        didSet { updatePeakingCoefficients() }
    }

    /// Peaking Q 值 - 宽一点
    public var peakingQ: Float = 0.8 {
        didSet { updatePeakingCoefficients() }
    }

    // MARK: - 初始化

    public init(sampleRate: Float = defaultSampleRate) {
        self.sampleRate = sampleRate

        // 计算滤波器系数
        updateHighpassCoefficients()
        updatePeakingCoefficients()

        print("[VoiceEQ] Initialized at \(sampleRate) Hz, peaking=\(peakingFrequency)Hz +\(peakingGain)dB Q=\(peakingQ)")
    }

    // MARK: - 系数计算

    /// 计算 High-pass 滤波器系数 (2nd order Butterworth)
    private func updateHighpassCoefficients() {
        let freq = min(highpassCutoff, sampleRate * 0.45)  // 防止超过奈奎斯特
        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let alpha = sinOmega / (2.0 * sqrt(2.0))  // Q = sqrt(2)/2 for Butterworth

        let a0 = 1.0 + alpha

        highpassFilter.b0 = ((1.0 + cosOmega) / 2.0) / a0
        highpassFilter.b1 = (-(1.0 + cosOmega)) / a0
        highpassFilter.b2 = ((1.0 + cosOmega) / 2.0) / a0
        highpassFilter.a1 = (-2.0 * cosOmega) / a0
        highpassFilter.a2 = (1.0 - alpha) / a0

        if debugPrint {
            print("[VoiceEQ] HPF updated: \(highpassCutoff) Hz")
        }
    }

    /// 计算 Peaking 滤波器系数
    private func updatePeakingCoefficients() {
        let freq = min(peakingFrequency, sampleRate * 0.45)
        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cos(omega)
        let sinOmega = sin(omega)
        let A = pow(10.0, peakingGain / 40.0)  // sqrt(10^(dB/20))
        let alpha = sinOmega / (2.0 * peakingQ)

        let a0 = 1.0 + alpha / A

        peakingFilter.b0 = (1.0 + alpha * A) / a0
        peakingFilter.b1 = (-2.0 * cosOmega) / a0
        peakingFilter.b2 = (1.0 - alpha * A) / a0
        peakingFilter.a1 = (-2.0 * cosOmega) / a0
        peakingFilter.a2 = (1.0 - alpha / A) / a0

        if debugPrint {
            print("[VoiceEQ] Peaking updated: \(peakingFrequency) Hz, +\(peakingGain) dB, Q=\(peakingQ)")
        }
    }

    // MARK: - 处理方法

    /// 就地处理一帧音频（零分配）
    ///
    /// - Parameter frame: 输入输出帧（Float32，范围 [-32768, 32768]）
    public func processInPlace(_ frame: inout [Float]) {
        guard isEnabled else { return }

        // 每 50 帧打印一次调试日志
        let shouldLog = frameCounter % 50 == 0

        // 计算输入统计
        var inSumSq: Float = 0
        for sample in frame {
            inSumSq += sample * sample
        }
        let inRms = sqrt(inSumSq / Float(frame.count))

        // 1. EQ 处理
        for i in 0..<frame.count {
            var sample = frame[i]

            // High-pass (去低频轰鸣)
            sample = highpassFilter.process(sample)

            // Peaking (1.5kHz 人声存在感)
            sample = peakingFilter.process(sample)

            frame[i] = sample
        }

        // 2. RMS 补偿（不是 AGC，只是小幅补偿存在感）
        if enableRmsBoost {
            // 计算处理后 RMS
            var postEqSumSq: Float = 0
            for sample in frame {
                postEqSumSq += sample * sample
            }
            let postEqRms = sqrt(postEqSumSq / Float(frame.count))

            // 如果 RMS 低于目标，小幅补偿
            if postEqRms > 100 && postEqRms < targetRms {
                for i in 0..<frame.count {
                    frame[i] *= rmsBoostFactor
                }
            }
        }

        // 3. 软限幅 (防止削波失真)
        for i in 0..<frame.count {
            frame[i] = softClip(frame[i], threshold: 28000.0)
        }

        // 计算输出统计
        var outSumSq: Float = 0
        for sample in frame {
            outSumSq += sample * sample
        }
        let outRms = sqrt(outSumSq / Float(frame.count))

        frameCounter += 1

        if shouldLog {
            os_log("[TX-EQ] frame=%llu inRms=%.1f outRms=%.1f boost=%d", log: eqLog, type: .default, frameCounter, inRms, outRms, enableRmsBoost && outRms < targetRms ? 1 : 0)
        }
    }

    /// 处理一帧并返回新数组
    ///
    /// - Parameter frame: 输入帧
    /// - Returns: 处理后的帧（如果禁用，返回原始数据）
    public func process(_ frame: [Float]) -> [Float] {
        guard isEnabled else { return frame }

        var result = frame
        processInPlace(&result)
        return result
    }

    /// 重置滤波器状态
    public func reset() {
        highpassFilter.reset()
        peakingFilter.reset()
        frameCounter = 0
    }

    /// 软重置（只清统计，不重置滤波器状态）
    public func softReset() {
        frameCounter = 0
    }

    // MARK: - 软限幅

    /// 软限幅函数（tanh-based soft clipper）
    ///
    /// 当信号超过阈值时，使用 tanh 曲线平滑压缩，避免硬削波失真
    /// - Parameters:
    ///   - sample: 输入采样值
    ///   - threshold: 开始压缩的阈值（默认 28000，留出余量）
    /// - Returns: 软限幅后的采样值
    @inline(__always)
    private func softClip(_ sample: Float, threshold: Float) -> Float {
        let absValue = abs(sample)
        if absValue <= threshold {
            return sample
        }

        // 超过阈值部分使用 tanh 压缩
        let sign: Float = sample >= 0 ? 1.0 : -1.0
        let excess = (absValue - threshold) / threshold  // 归一化超出量
        let compressed = threshold + threshold * tanh(excess) * 0.18  // 0.18 更安全
        return sign * min(compressed, 32000.0)  // 硬限幅在 32000
    }
}
