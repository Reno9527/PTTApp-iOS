import Foundation
import Accelerate

/// 高质量 AGC 动态增益控制
///
/// 特点：
/// - RMS 电平检测（符合人耳感知）
/// - 快攻慢放（避免削波和抽气效果）
/// - 噪声门限（避免放大底噪）
/// - 平滑增益过渡（无咔嗒声）
///
/// 参数设计依据：
/// - targetRMS: 25% 满量程，留足够动态余量
/// - attackTime: 10ms，快于语音音节，避免削波
/// - releaseTime: 300ms，广播标准，避免"抽气"
/// - maxGain: 3.0，平衡响度与噪声
public final class AudioAGC: @unchecked Sendable {

    // MARK: - 参数

    /// 目标 RMS 电平 (范围 0-32768)
    /// 对于 16-bit 音频，8000 约为 25% 电平
    private let targetRMS: Float

    /// 最大增益（避免放大背景噪声）
    private let maxGain: Float

    /// 最小增益（避免过度压缩大信号）
    private let minGain: Float

    /// 攻击时间（信号变大时，增益下降的速度）
    /// 越小越快，推荐 5-20ms
    private let attackTimeMs: Float

    /// 释放时间（信号变小时，增益上升的速度）
    /// 越大越慢，推荐 100-500ms，避免"抽气"效果
    private let releaseTimeMs: Float

    /// 噪声门限（低于此电平不放大）
    /// 避免放大背景噪声
    private let noiseGateThreshold: Float

    /// RMS 平滑系数（平滑电平检测）
    private let rmsSmoothing: Float

    // MARK: - 状态

    /// 当前增益值
    private var currentGain: Float = 1.0

    /// 平滑后的 RMS 值
    private var smoothedRMS: Float = 0.0

    /// 采样率
    private let sampleRate: Float

    // MARK: - 预计算系数

    /// 攻击系数（增益下降速度）
    private let attackCoeff: Float

    /// 释放系数（增益上升速度）
    private let releaseCoeff: Float

    // MARK: - 线程安全

    private let lock = NSLock()

    // MARK: - 初始化

    /// 创建 AGC 处理器
    /// - Parameters:
    ///   - sampleRate: 采样率（默认 16000 Hz）
    ///   - targetRMS: 目标 RMS 电平（默认 8000）
    ///   - maxGain: 最大增益（默认 3.0）
    ///   - minGain: 最小增益（默认 0.5）
    ///   - attackTimeMs: 攻击时间（默认 10ms）
    ///   - releaseTimeMs: 释放时间（默认 300ms）
    ///   - noiseGateThreshold: 噪声门限（默认 500）
    ///   - rmsSmoothing: RMS 平滑系数（默认 0.3）
    public init(
        sampleRate: Float = 16000.0,
        targetRMS: Float = 8000.0,
        maxGain: Float = 3.0,
        minGain: Float = 0.5,
        attackTimeMs: Float = 10.0,
        releaseTimeMs: Float = 300.0,
        noiseGateThreshold: Float = 500.0,
        rmsSmoothing: Float = 0.3
    ) {
        self.sampleRate = sampleRate
        self.targetRMS = targetRMS
        self.maxGain = maxGain
        self.minGain = minGain
        self.attackTimeMs = attackTimeMs
        self.releaseTimeMs = releaseTimeMs
        self.noiseGateThreshold = noiseGateThreshold
        self.rmsSmoothing = rmsSmoothing

        // 时间常数 → IIR 滤波器系数
        // coeff = 1 - exp(-1 / (time_seconds * sampleRate))
        self.attackCoeff = 1.0 - exp(-1.0 / (attackTimeMs * 0.001 * sampleRate))
        self.releaseCoeff = 1.0 - exp(-1.0 / (releaseTimeMs * 0.001 * sampleRate))

        #if DEBUG
        print("[AudioAGC] Initialized: targetRMS=\(targetRMS), maxGain=\(maxGain), attack=\(attackTimeMs)ms, release=\(releaseTimeMs)ms")
        #endif
    }

    // MARK: - 处理

    /// 处理音频样本（原地修改）
    /// - Parameter samples: Float32 PCM 样本数组
    public func process(_ samples: inout [Float]) {
        guard !samples.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        // 1. 计算当前帧的 RMS
        let frameRMS = calculateRMS(samples)

        // 2. 平滑 RMS（避免对瞬态过度反应）
        smoothedRMS = rmsSmoothing * frameRMS + (1.0 - rmsSmoothing) * smoothedRMS

        // 3. 计算目标增益
        var targetGain: Float
        if smoothedRMS < noiseGateThreshold {
            // 低于噪声门限，保持当前增益（不增加）
            targetGain = min(currentGain, 1.0)
        } else {
            targetGain = targetRMS / max(smoothedRMS, 1.0)
        }

        // 4. 限制增益范围
        targetGain = max(minGain, min(maxGain, targetGain))

        // 5. 逐样本应用增益（平滑过渡，快攻慢放）
        let count = samples.count
        for i in 0..<count {
            // 选择攻击或释放系数
            let coeff = targetGain < currentGain ? attackCoeff : releaseCoeff

            // 平滑增益变化
            currentGain += coeff * (targetGain - currentGain)

            // 应用增益
            samples[i] *= currentGain
        }
    }

    /// 处理音频样本（返回新数组）
    /// - Parameter samples: Float32 PCM 样本数组
    /// - Returns: 处理后的样本数组
    public func processed(_ samples: [Float]) -> [Float] {
        var result = samples
        process(&result)
        return result
    }

    // MARK: - RMS 计算

    /// 使用 vDSP 加速计算 RMS
    private func calculateRMS(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        vDSP_svesq(samples, 1, &sumSquares, vDSP_Length(samples.count))
        return sqrt(sumSquares / Float(samples.count))
    }

    // MARK: - 状态管理

    /// 重置 AGC 状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }

        currentGain = 1.0
        smoothedRMS = 0.0
    }

    /// 获取当前增益值（用于调试/显示）
    public var gain: Float {
        lock.lock()
        defer { lock.unlock() }
        return currentGain
    }

    /// 获取当前平滑 RMS 值（用于调试/显示）
    public var rms: Float {
        lock.lock()
        defer { lock.unlock() }
        return smoothedRMS
    }
}
