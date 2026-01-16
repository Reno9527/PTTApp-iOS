import Foundation
import Accelerate

// MARK: - 双二阶滤波器 (Biquad Filter)

/// 双二阶 IIR 滤波器
/// 用于实现各种滤波器类型（低通、高通、带通、搁架等）
final class BiquadFilter {

    // 滤波器系数
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    // 状态变量（Direct Form II Transposed）
    private var z1: Float = 0.0
    private var z2: Float = 0.0

    init() {}

    /// 配置为低通滤波器
    func configureLowpass(frequency: Float, q: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = ((1.0 - cosOmega) / 2.0) / a0
        b1 = (1.0 - cosOmega) / a0
        b2 = ((1.0 - cosOmega) / 2.0) / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    /// 配置为高通滤波器
    func configureHighpass(frequency: Float, q: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = ((1.0 + cosOmega) / 2.0) / a0
        b1 = (-(1.0 + cosOmega)) / a0
        b2 = ((1.0 + cosOmega) / 2.0) / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    /// 配置为带通滤波器
    func configureBandpass(frequency: Float, q: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = alpha / a0
        b1 = 0.0
        b2 = -alpha / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    /// 配置为低频搁架滤波器
    func configureLowShelf(frequency: Float, gainDb: Float, q: Float, sampleRate: Float) {
        let A = pow(10.0, gainDb / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrt(A) * alpha
        b0 = (A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrt(A) * alpha)) / a0
        b1 = (2 * A * ((A - 1) - (A + 1) * cosOmega)) / a0
        b2 = (A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrt(A) * alpha)) / a0
        a1 = (-2 * ((A - 1) + (A + 1) * cosOmega)) / a0
        a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrt(A) * alpha) / a0
    }

    /// 配置为高频搁架滤波器
    func configureHighShelf(frequency: Float, gainDb: Float, q: Float, sampleRate: Float) {
        let A = pow(10.0, gainDb / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrt(A) * alpha
        b0 = (A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrt(A) * alpha)) / a0
        b1 = (-2 * A * ((A - 1) + (A + 1) * cosOmega)) / a0
        b2 = (A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrt(A) * alpha)) / a0
        a1 = (2 * ((A - 1) - (A + 1) * cosOmega)) / a0
        a2 = ((A + 1) - (A - 1) * cosOmega - 2 * sqrt(A) * alpha) / a0
    }

    /// 配置为参数化 EQ (Peaking Filter)
    /// - Parameters:
    ///   - frequency: 中心频率
    ///   - gainDb: 增益 (正值提升，负值衰减)
    ///   - q: Q 值 (带宽控制，Q 越大带宽越窄)
    ///   - sampleRate: 采样率
    func configurePeaking(frequency: Float, gainDb: Float, q: Float, sampleRate: Float) {
        let A = pow(10.0, gainDb / 40.0)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha / A
        b0 = (1.0 + alpha * A) / a0
        b1 = (-2.0 * cosOmega) / a0
        b2 = (1.0 - alpha * A) / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha / A) / a0
    }

    /// 处理单个样本
    @inline(__always)
    func process(_ input: Float) -> Float {
        let output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }

    /// 处理样本数组（原地修改）
    func process(_ samples: inout [Float]) {
        for i in 0..<samples.count {
            samples[i] = process(samples[i])
        }
    }

    /// 重置状态
    func reset() {
        z1 = 0.0
        z2 = 0.0
    }
}

// MARK: - Linkwitz-Riley 分频器

/// Linkwitz-Riley 4阶分频器（24dB/oct）
/// 由两个级联的 Butterworth 滤波器组成
final class LinkwitzRileyCrossover {

    private let lowpass1: BiquadFilter
    private let lowpass2: BiquadFilter
    private let highpass1: BiquadFilter
    private let highpass2: BiquadFilter

    init(frequency: Float, sampleRate: Float) {
        let q: Float = 0.7071 // Butterworth Q

        lowpass1 = BiquadFilter()
        lowpass2 = BiquadFilter()
        highpass1 = BiquadFilter()
        highpass2 = BiquadFilter()

        lowpass1.configureLowpass(frequency: frequency, q: q, sampleRate: sampleRate)
        lowpass2.configureLowpass(frequency: frequency, q: q, sampleRate: sampleRate)
        highpass1.configureHighpass(frequency: frequency, q: q, sampleRate: sampleRate)
        highpass2.configureHighpass(frequency: frequency, q: q, sampleRate: sampleRate)
    }

    /// 分离低频和高频
    func process(_ input: [Float]) -> (low: [Float], high: [Float]) {
        var low = input
        var high = input

        // 低通：两级级联
        lowpass1.process(&low)
        lowpass2.process(&low)

        // 高通：两级级联
        highpass1.process(&high)
        highpass2.process(&high)

        return (low, high)
    }

    func reset() {
        lowpass1.reset()
        lowpass2.reset()
        highpass1.reset()
        highpass2.reset()
    }
}

// MARK: - 频段 AGC

/// 单频段 AGC 配置
struct BandAGCConfig {
    let targetRMS: Float
    let maxGain: Float
    let minGain: Float
    let attackMs: Float
    let releaseMs: Float
    let noiseGate: Float

    static let lowBand = BandAGCConfig(
        targetRMS: 5000,
        maxGain: 2.2,     // 提高以补偿低频损失 (was 1.8)
        minGain: 0.6,
        attackMs: 15,
        releaseMs: 600,   // 增加以避免跟踪颤音
        noiseGate: 300
    )

    static let midBand = BandAGCConfig(
        targetRMS: 8000,
        maxGain: 2.5,
        minGain: 0.5,
        attackMs: 10,
        releaseMs: 500,   // 增加以避免跟踪颤音
        noiseGate: 400
    )

    static let highBand = BandAGCConfig(
        targetRMS: 6000,
        maxGain: 2.0,
        minGain: 0.4,
        attackMs: 8,
        releaseMs: 400,   // 增加以避免跟踪颤音
        noiseGate: 200
    )
}

/// 单频段 AGC 处理器
final class BandAGC {

    private let config: BandAGCConfig
    private let sampleRate: Float

    private var currentGain: Float = 1.0
    private var smoothedRMS: Float = 0.0
    private let rmsSmoothing: Float = 0.1  // 降低以忽略颤音波动

    init(config: BandAGCConfig, sampleRate: Float) {
        self.config = config
        self.sampleRate = sampleRate
    }

    func process(_ samples: inout [Float]) {
        guard !samples.isEmpty else { return }

        let frameSize = Float(samples.count)

        // 帧级攻击/释放系数（基于帧大小动态计算）
        let framesPerMs = sampleRate / (frameSize * 1000.0)
        let attackCoeff = 1.0 - exp(-1.0 / (config.attackMs * framesPerMs))
        let releaseCoeff = 1.0 - exp(-1.0 / (config.releaseMs * framesPerMs))

        // 计算 RMS
        var sumSquares: Float = 0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        let frameRMS = sqrt(sumSquares / frameSize)

        // 平滑 RMS
        smoothedRMS = rmsSmoothing * frameRMS + (1.0 - rmsSmoothing) * smoothedRMS

        // 计算目标增益
        var targetGain: Float
        if smoothedRMS < config.noiseGate {
            targetGain = min(currentGain, 1.0)
        } else {
            targetGain = config.targetRMS / max(smoothedRMS, 1.0)
        }

        // 限制增益范围
        targetGain = max(config.minGain, min(config.maxGain, targetGain))

        // 帧级增益平滑
        let coeff = targetGain < currentGain ? attackCoeff : releaseCoeff
        let newGain = currentGain + coeff * (targetGain - currentGain)

        // 帧内增益线性插值（从上一帧增益平滑过渡到当前帧增益，消除帧边界跳变）
        let startGain = currentGain
        let endGain = newGain
        let gainStep = (endGain - startGain) / frameSize

        for i in 0..<samples.count {
            let interpolatedGain = startGain + gainStep * Float(i)
            samples[i] *= interpolatedGain
        }

        currentGain = newGain
    }

    func reset() {
        currentGain = 1.0
        smoothedRMS = 0.0
    }
}

// MARK: - 软限幅器

/// 软限幅器（Soft Limiter）- 帧级处理版本
/// 防止信号削波，使用软拐点压缩
/// 改为帧级处理以避免样本级增益调制产生的颗粒音
final class SoftLimiter {

    private let threshold: Float
    private let ratio: Float
    private let kneeWidth: Float
    private let sampleRate: Float

    private var currentGain: Float = 1.0

    /// 创建软限幅器
    /// - Parameters:
    ///   - threshold: 开始限幅的电平
    ///   - ratio: 压缩比（如 10.0 表示 10:1）
    ///   - kneeWidth: 软拐点宽度
    ///   - sampleRate: 采样率
    init(
        threshold: Float = 20000,
        ratio: Float = 10.0,
        kneeWidth: Float = 3000,
        sampleRate: Float = 16000
    ) {
        self.threshold = threshold
        self.ratio = ratio
        self.kneeWidth = kneeWidth
        self.sampleRate = sampleRate
    }

    func process(_ samples: inout [Float]) {
        guard !samples.isEmpty else { return }

        let frameSize = Float(samples.count)
        let kneeStart = threshold - kneeWidth / 2
        let kneeEnd = threshold + kneeWidth / 2

        // 帧级：计算帧内峰值
        var peakValue: Float = 0
        vDSP_maxmgv(samples, 1, &peakValue, vDSP_Length(samples.count))

        // 计算目标增益
        var targetGain: Float = 1.0

        if peakValue > kneeEnd {
            // 超过拐点，完全压缩
            let overDb = peakValue - threshold
            let compressedOver = overDb / ratio
            targetGain = (threshold + compressedOver) / peakValue
        } else if peakValue > kneeStart {
            // 在软拐点范围内，渐进压缩
            let kneePos = (peakValue - kneeStart) / kneeWidth
            targetGain = 1.0 - kneePos * (1.0 - 1.0 / ratio)
        }

        // 帧级攻击/释放（快攻慢放）
        let attackMs: Float = 2.0
        let releaseMs: Float = 100.0
        let framesPerMs = sampleRate / (frameSize * 1000.0)
        let attackCoeff = 1.0 - exp(-1.0 / (attackMs * framesPerMs))
        let releaseCoeff = 1.0 - exp(-1.0 / (releaseMs * framesPerMs))

        let coeff = targetGain < currentGain ? attackCoeff : releaseCoeff
        let newGain = currentGain + coeff * (targetGain - currentGain)

        // 帧内增益线性插值（消除帧边界跳变）
        let startGain = currentGain
        let endGain = newGain
        let gainStep = (endGain - startGain) / frameSize

        for i in 0..<samples.count {
            let interpolatedGain = startGain + gainStep * Float(i)
            samples[i] *= interpolatedGain
        }

        currentGain = newGain
    }

    func reset() {
        currentGain = 1.0
    }
}

// MARK: - 多频带音频处理器

/// G.711 多频带音频处理器
///
/// 处理链路：
/// 1. 高通预滤波（去除低频噪声）
/// 2. 三频段分离（Linkwitz-Riley）
/// 3. 各频段独立 AGC
/// 4. 频段合并
/// 5. 高频搁架补偿
/// 6. 软限幅（防削波）
public final class MultibandAudioProcessor: @unchecked Sendable {

    // MARK: - 配置

    private let sampleRate: Float

    // 分频点（避开语音敏感频率 800-2000Hz）
    private let crossover1Freq: Float = 600.0   // 低/中分频点
    private let crossover2Freq: Float = 2500.0  // 中/高分频点

    // MARK: - 处理组件

    // 高通预滤波（去除 200Hz 以下）
    private let highpassFilter1: BiquadFilter
    private let highpassFilter2: BiquadFilter

    // 分频器
    private let crossover1: LinkwitzRileyCrossover  // 分离低频和中+高频
    private let crossover2: LinkwitzRileyCrossover  // 分离中频和高频

    // 各频段 AGC
    private let lowBandAGC: BandAGC
    private let midBandAGC: BandAGC
    private let highBandAGC: BandAGC

    // 低频搁架（衰减浑浊感 250Hz）
    private let lowShelfFilter: BiquadFilter

    // 中频提升 1.6kHz（清晰度）
    private let midBoost1600Filter: BiquadFilter

    // 中频提升 2.4kHz（核心清晰度，最大提升）
    private let midBoost2400Filter: BiquadFilter

    // 高频提升 3.2kHz（咬字）
    private let highBoost3200Filter: BiquadFilter

    // 输出增益（+3.5dB = 1.5倍）
    private let outputGain: Float = 1.5

    // 软限幅器
    private let limiter: SoftLimiter

    // 线程安全
    private let lock = NSLock()

    // MARK: - 初始化

    public init(sampleRate: Float = 16000.0) {
        self.sampleRate = sampleRate

        // 高通预滤波 (150Hz, 2阶 Butterworth) - 去除低频噪声和隆隆声
        highpassFilter1 = BiquadFilter()
        highpassFilter2 = BiquadFilter()
        highpassFilter1.configureHighpass(frequency: 150, q: 0.7071, sampleRate: sampleRate)
        highpassFilter2.configureHighpass(frequency: 150, q: 0.7071, sampleRate: sampleRate)

        // 分频器
        crossover1 = LinkwitzRileyCrossover(frequency: crossover1Freq, sampleRate: sampleRate)
        crossover2 = LinkwitzRileyCrossover(frequency: crossover2Freq, sampleRate: sampleRate)

        // 各频段 AGC
        lowBandAGC = BandAGC(config: .lowBand, sampleRate: sampleRate)
        midBandAGC = BandAGC(config: .midBand, sampleRate: sampleRate)
        highBandAGC = BandAGC(config: .highBand, sampleRate: sampleRate)

        // 低频搁架（-2dB @ 250Hz）- 轻微去闷，保留厚度
        lowShelfFilter = BiquadFilter()
        lowShelfFilter.configureLowShelf(frequency: 250, gainDb: -2.0, q: 0.7071, sampleRate: sampleRate)

        // 中频提升（+2dB @ 1.6kHz, Q=1.5）- 清晰度
        midBoost1600Filter = BiquadFilter()
        midBoost1600Filter.configurePeaking(frequency: 1600, gainDb: 2.0, q: 1.5, sampleRate: sampleRate)

        // 中频提升（+3dB @ 2.4kHz, Q=1.5）- 核心清晰度，最大提升
        midBoost2400Filter = BiquadFilter()
        midBoost2400Filter.configurePeaking(frequency: 2400, gainDb: 3.0, q: 1.5, sampleRate: sampleRate)

        // 高频提升（+1dB @ 3.2kHz, Q=1.5）- 咬字
        highBoost3200Filter = BiquadFilter()
        highBoost3200Filter.configurePeaking(frequency: 3200, gainDb: 1.0, q: 1.5, sampleRate: sampleRate)

        // 软限幅器（阈值 25000，配合 basePlaybackGain=2.0 确保不削波）
        limiter = SoftLimiter(
            threshold: 25000,
            ratio: 8.0,
            kneeWidth: 5000,
            sampleRate: sampleRate
        )

        #if DEBUG
        print("[MultibandProcessor] Initialized: \(sampleRate)Hz, EQ: HP@150Hz, LS-2dB@250Hz, PK+2dB@1.6k, PK+3dB@2.4k, PK+1dB@3.2k, Gain+3.5dB")
        #endif
    }

    // MARK: - 处理

    /// 处理音频样本
    public func process(_ samples: inout [Float]) {
        guard !samples.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        // 1. 高通预滤波（去除低频噪声）
        highpassFilter1.process(&samples)
        highpassFilter2.process(&samples)

        // 2. 第一级分频：分离低频 和 中+高频
        let (lowBand, midHighBand) = crossover1.process(samples)

        // 3. 第二级分频：分离中频 和 高频
        let (midBand, highBand) = crossover2.process(midHighBand)

        // 4. 各频段独立 AGC
        var lowProcessed = lowBand
        var midProcessed = midBand
        var highProcessed = highBand

        lowBandAGC.process(&lowProcessed)
        midBandAGC.process(&midProcessed)
        highBandAGC.process(&highProcessed)

        // 5. 频段合并（直接相加，保留中频临场感）
        for i in 0..<samples.count {
            samples[i] = lowProcessed[i] + midProcessed[i] + highProcessed[i]
        }

        // 6. 低频搁架（-2dB @ 250Hz，轻微去闷）
        lowShelfFilter.process(&samples)

        // 7. 中频提升（清晰度 1.6k + 2.4k）
        midBoost1600Filter.process(&samples)
        midBoost2400Filter.process(&samples)

        // 8. 高频提升（咬字 3.2k）
        highBoost3200Filter.process(&samples)

        // 9. 输出增益（+3.5dB = 1.5倍）
        var gain = outputGain
        vDSP_vsmul(samples, 1, &gain, &samples, 1, vDSP_Length(samples.count))

        // 10. 软限幅（防削波）- 帧级处理，无颗粒音
        limiter.process(&samples)
    }

    /// 处理音频样本（返回新数组）
    public func processed(_ samples: [Float]) -> [Float] {
        var result = samples
        process(&result)
        return result
    }

    // MARK: - 重置

    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        highpassFilter1.reset()
        highpassFilter2.reset()
        crossover1.reset()
        crossover2.reset()
        lowBandAGC.reset()
        midBandAGC.reset()
        highBandAGC.reset()
        lowShelfFilter.reset()
        midBoost1600Filter.reset()
        midBoost2400Filter.reset()
        highBoost3200Filter.reset()
        limiter.reset()
    }
}
