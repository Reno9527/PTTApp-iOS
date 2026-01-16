import Foundation
import CRNNoise

/// RNNoise 降噪处理器（官方 xiph/rnnoise 黑盒封装）
///
/// ## 输入输出契约
/// - **格式**: Float32 单声道 PCM
/// - **数值范围**: [-32768, 32768]（16-bit scale，与原始 RNNoise 一致）
/// - **帧长**: 480 samples（固定，不可更改）
/// - **采样率**: 48kHz（10ms/帧）
///
/// ## Int16 ↔ Float 转换规则
/// - `float = Float(int16)`（直接转换，保持 16-bit scale）
/// - `int16 = Int16(clamping: Int32(float))`
///
/// ## 使用方式
/// ```swift
/// let processor = RNNoiseProcessor()
/// processor.isEnabled = false  // 默认禁用，passthrough 模式
/// processor.isEnabled = true   // 启用降噪
/// processor.debugPrint = true  // 可选：打印 min/max/rms 统计
/// ```
///
/// ## 重要说明
/// - `isEnabled = false` 时，所有处理方法直接返回原始数据，无任何 DSP 行为
/// - RNNoise 算法层为黑盒，不允许修改 denoise.c / rnn.c 等 C 源码
/// - state 在 init 时创建，deinit 时销毁，生命周期内不重建
public final class RNNoiseProcessor: @unchecked Sendable {

    // MARK: - 常量

    /// RNNoise 帧大小 (480 采样点 = 10ms @ 48kHz)
    public static let frameSize = 480

    /// RNNoise 采样率 (48000 Hz)
    public static let sampleRate = 48000

    // MARK: - 属性

    private var state: OpaquePointer?
    private var isInitialized = false

    /// 预分配的输出缓冲区（避免每帧分配）
    private var outputBuffer: [Float]

    /// 预分配的 Int16 转换缓冲区
    private var floatConvertBuffer: [Float]

    /// 是否启用降噪处理 (默认禁用，用于调试)
    public var isEnabled: Bool = false

    /// VAD (语音活动检测) 概率阈值
    public var vadThreshold: Float = 0.5

    /// 最近一帧的 VAD 概率 (0.0 ~ 1.0)
    public private(set) var lastVadProbability: Float = 0

    /// 是否打印调试信息（默认关闭）
    public var debugPrint: Bool = false

    /// 帧计数器（用于调试）
    private var frameCounter: UInt64 = 0

    // MARK: - 初始化

    public init() {
        // 预分配缓冲区
        self.outputBuffer = [Float](repeating: 0, count: Self.frameSize)
        self.floatConvertBuffer = [Float](repeating: 0, count: Self.frameSize)

        // 创建 RNNoise state（整个生命周期只创建一次）
        state = rnnoise_create(nil)
        isInitialized = state != nil

        if isInitialized {
            let size = rnnoise_get_size()
            print("[RNNoiseProcessor] Initialized, state size: \(size) bytes")
        } else {
            print("[RNNoiseProcessor] Failed to initialize")
        }
    }

    deinit {
        if let state = state {
            rnnoise_destroy(state)
        }
    }

    // MARK: - 处理方法

    /// 处理一帧 48kHz 音频数据（就地处理，零分配）
    ///
    /// - Parameter frame: 输入输出帧 (480 个 Float32 采样点)
    /// - Returns: VAD 概率 (0.0 ~ 1.0)，如果禁用则返回 0
    @discardableResult
    public func processFrameInPlace(_ frame: inout [Float]) -> Float {
        guard frame.count == Self.frameSize else {
            return 0
        }

        // 如果禁用降噪，直接返回（不修改 frame）
        guard isEnabled, isInitialized else {
            return 0
        }

        // 调试：检测输入 NaN/Inf
        if debugPrint {
            checkAndLogStats(frame, label: "input", frameIndex: frameCounter)
        }

        // 使用预分配的 outputBuffer
        lastVadProbability = rnnoise_process_frame(state, &outputBuffer, frame)

        // 调试：检测输出 NaN/Inf
        if debugPrint {
            checkAndLogStats(outputBuffer, label: "output", frameIndex: frameCounter)
        }

        // 复制结果到 frame
        for i in 0..<Self.frameSize {
            frame[i] = outputBuffer[i]
        }

        frameCounter += 1
        return lastVadProbability
    }

    /// 处理一帧 48kHz 音频数据 (返回新数组)
    ///
    /// - Parameter frame: 输入帧 (480 个 Float32 采样点，范围 [-32768, 32768])
    /// - Returns: 降噪后的帧 (如果 isEnabled=false，直接返回原始数据)
    public func processFrame(_ frame: [Float]) -> [Float] {
        guard frame.count == Self.frameSize else {
            return frame
        }

        // 如果禁用降噪，直接返回原始数据
        guard isEnabled, isInitialized else {
            return frame
        }

        var mutableFrame = frame
        _ = processFrameInPlace(&mutableFrame)
        return mutableFrame
    }

    /// 将 Int16 PCM 转换为 Float 并处理（使用预分配缓冲区）
    ///
    /// - Parameter samples: Int16 PCM 采样点 (480 个)
    /// - Returns: 处理后的 Int16 PCM (如果禁用降噪，返回原始数据)
    public func processInt16Frame(_ samples: [Int16]) -> [Int16] {
        guard samples.count == Self.frameSize else {
            return samples
        }

        // 如果禁用降噪，直接返回原始数据
        guard isEnabled, isInitialized else {
            return samples
        }

        // 使用预分配缓冲区转换
        for i in 0..<Self.frameSize {
            floatConvertBuffer[i] = Float(samples[i])
        }

        // 处理
        _ = processFrameInPlace(&floatConvertBuffer)

        // 转换回 Int16（使用预分配路径）
        var result = [Int16](repeating: 0, count: Self.frameSize)
        for i in 0..<Self.frameSize {
            result[i] = Int16(clamping: Int32(floatConvertBuffer[i]))
        }
        return result
    }

    /// 处理多帧数据
    ///
    /// - Parameter samples: 输入采样点 (必须是 480 的倍数)
    /// - Returns: 处理后的采样点 (如果禁用降噪，返回原始数据)
    public func process(_ samples: [Float]) -> [Float] {
        // 如果禁用降噪，直接返回原始数据
        guard isEnabled, isInitialized else { return samples }

        let frameCount = samples.count / Self.frameSize
        guard frameCount > 0 else { return samples }

        var output = [Float]()
        output.reserveCapacity(frameCount * Self.frameSize)

        for i in 0..<frameCount {
            let start = i * Self.frameSize
            let end = start + Self.frameSize
            let frame = Array(samples[start..<end])
            output.append(contentsOf: processFrame(frame))
        }

        // 处理剩余不足一帧的数据（直接返回）
        let remaining = samples.count % Self.frameSize
        if remaining > 0 {
            let start = frameCount * Self.frameSize
            output.append(contentsOf: samples[start...])
        }

        return output
    }

    /// 处理多帧 Int16 数据
    ///
    /// - Parameter samples: Int16 PCM 采样点 (必须是 480 的倍数)
    /// - Returns: 处理后的 Int16 PCM (如果禁用降噪，返回原始数据)
    public func processInt16(_ samples: [Int16]) -> [Int16] {
        // 如果禁用降噪，直接返回原始数据
        guard isEnabled, isInitialized else { return samples }

        let frameCount = samples.count / Self.frameSize
        guard frameCount > 0 else { return samples }

        var output = [Int16]()
        output.reserveCapacity(frameCount * Self.frameSize)

        for i in 0..<frameCount {
            let start = i * Self.frameSize
            let end = start + Self.frameSize
            let frame = Array(samples[start..<end])
            output.append(contentsOf: processInt16Frame(frame))
        }

        // 处理剩余不足一帧的数据
        let remaining = samples.count % Self.frameSize
        if remaining > 0 {
            let start = frameCount * Self.frameSize
            output.append(contentsOf: samples[start...])
        }

        return output
    }

    /// 软重置处理器（不销毁 state，只清零统计）
    ///
    /// 用于 TX 开始时，避免重新分配内存
    public func softReset() {
        frameCounter = 0
        lastVadProbability = 0
        // 注意：不重建 state，保持内存稳定
    }

    /// 硬重置处理器（重建 state，仅在必要时使用）
    ///
    /// 警告：会重新分配内存，不建议在 TX 期间调用
    public func reset() {
        if let state = state {
            rnnoise_destroy(state)
        }
        state = rnnoise_create(nil)
        isInitialized = state != nil
        frameCounter = 0
        lastVadProbability = 0
    }

    // MARK: - 调试辅助

    /// 检测并记录帧统计（仅在 debugPrint=true 时）
    private func checkAndLogStats(_ samples: [Float], label: String, frameIndex: UInt64) {
        var hasNaN = false
        var hasInf = false
        var min: Float = .greatestFiniteMagnitude
        var max: Float = -.greatestFiniteMagnitude
        var sumSquares: Float = 0

        for sample in samples {
            if sample.isNaN {
                hasNaN = true
            } else if sample.isInfinite {
                hasInf = true
            } else {
                min = Swift.min(min, sample)
                max = Swift.max(max, sample)
                sumSquares += sample * sample
            }
        }

        let rms = sqrt(sumSquares / Float(samples.count))

        // 检测异常值
        if hasNaN || hasInf {
            print("[RNNoiseProcessor] ⚠️ Frame \(frameIndex) \(label): NaN=\(hasNaN) Inf=\(hasInf)")
        }

        // 每 100 帧打印一次统计
        if frameIndex % 100 == 0 {
            print("[RNNoiseProcessor] Frame \(frameIndex) \(label): min=\(min), max=\(max), rms=\(rms), vad=\(lastVadProbability)")
        }
    }
}
