import Foundation
import AVFoundation
import AudioToolbox
import os.log

private let veLog = OSLog(subsystem: "com.pgarlic.pttapp", category: "VoiceEnhancement")

/// 语音增强处理器
///
/// 使用 48kHz 采集 → RNNoise 降噪 → 8kHz 输出 的流程
/// 实现高质量的实时语音降噪
public final class VoiceEnhancementProcessor: @unchecked Sendable {

    // MARK: - 常量

    /// 期望采集采样率 (48000 Hz - RNNoise 原生)
    private let expectedSampleRate: Float64 = 48000.0

    /// 实际硬件采样率（运行时确定）
    private var actualSampleRate: Float64 = 48000.0

    private let bytesPerSample = 2
    private let channelCount: UInt32 = 1

    /// RNNoise 帧大小 (480 samples @ 48kHz = 10ms)
    private let rnnoiseFrameSize = 480

    // MARK: - 80Hz 高通滤波器（风噪抑制）
    // Biquad 系数：fc=80Hz, fs=48000Hz, Q=0.707 (Butterworth)
    private let hpfB0: Float = 0.99262047
    private let hpfB1: Float = -1.98524094
    private let hpfB2: Float = 0.99262047
    private let hpfA1: Float = -1.98518619
    private let hpfA2: Float = 0.98524094

    /// 高通滤波器状态（Direct Form II Transposed）
    private var hpfZ1: Float = 0
    private var hpfZ2: Float = 0

    // MARK: - 输出采样率配置

    /// 输出采样率模式
    public enum OutputSampleRateMode: Int {
        case rate8k = 8000   // G711
        case rate16k = 16000 // Opus
    }

    /// 当前输出采样率模式（默认 8kHz for G711）
    public private(set) var outputMode: OutputSampleRateMode = .rate8k

    /// 输出采样率
    private var outputSampleRate: Float64 { Float64(outputMode.rawValue) }

    /// 输出缓冲大小 (samples) - 直接对齐协议包大小
    /// G711: 500 samples @ 8kHz = 62.5ms（与 500B 包对齐）
    /// Opus: 320 samples @ 16kHz = 20ms（Opus 帧大小）
    private var outputBufferSize: Int {
        switch outputMode {
        case .rate8k:
            return 500  // G711: 直接对齐协议 500B
        case .rate16k:
            return 320  // Opus: 20ms @ 16kHz
        }
    }

    // MARK: - 属性

    fileprivate var audioUnit: AudioUnit?
    private let rnnoiseProcessor: RNNoiseProcessor
    private let voiceEQ: VoiceEQ
    private let resampler: AudioResampler

    public private(set) var isRunning = false
    private var isProcessing = false

    /// 48kHz 录音缓冲（用于凑够 RNNoise 帧）
    private var captureBuffer = [Float]()

    /// 8kHz 输出缓冲（用于凑够输出帧）
    private var outputBuffer = [Int16]()

    /// TX 会话帧计数（用于延迟启用 RNNoise）
    private var txFrameCount: UInt64 = 0

    /// RNNoise 延迟启用帧数（TX 开始后延迟几帧再启用，避免初始噪声）
    public var delayedEnableFrames: UInt64 = 2

    /// 是否已延迟启用 RNNoise（当前 TX 会话）
    private var isRNNoiseDelayedEnabled = false

    /// 输出缓冲锁（使用递归锁防止回调路径导致的死锁）
    private let bufferLock = NSRecursiveLock()

    // MARK: - 回调

    /// 处理后的 8kHz PCM 数据回调
    public var onProcessedPCM: (([Int16]) -> Void)?

    /// VAD 概率回调 (0.0 ~ 1.0)
    public var onVadProbability: ((Float) -> Void)?

    /// 音量电平回调 (0.0 ~ 1.0)，用于 UI 水波纹动画
    public var onVolumeLevel: ((Float) -> Void)?

    // MARK: - 配置

    /// 录音音量增益 (0.0 ~ 2.0)
    public var inputGain: Float = 1.0

    /// 是否启用 RNNoise 降噪（默认禁用，passthrough 模式）
    public var enableNoiseReduction: Bool = false {
        didSet {
            rnnoiseProcessor.isEnabled = enableNoiseReduction
            print("[VoiceEnhancement] RNNoise enabled: \(enableNoiseReduction)")
        }
    }

    /// 是否打印 RNNoise 调试信息（min/max/rms）
    public var debugNoiseReduction: Bool = false {
        didSet {
            rnnoiseProcessor.debugPrint = debugNoiseReduction
        }
    }

    /// 降噪强度 (0.0 ~ 1.0，1.0 为全强度，仅在 enableNoiseReduction=true 时有效)
    public var noiseReductionStrength: Float = 1.0

    /// 是否启用 TX 人声 EQ（默认禁用）
    public var enableVoiceEQ: Bool = false {
        didSet {
            voiceEQ.isEnabled = enableVoiceEQ
            print("[VoiceEnhancement] VoiceEQ enabled: \(enableVoiceEQ)")
        }
    }

    /// 是否打印 EQ 调试信息
    public var debugVoiceEQ: Bool = false {
        didSet {
            voiceEQ.debugPrint = debugVoiceEQ
        }
    }

    /// 是否启用风噪抑制（80Hz 高通滤波器）
    public var enableWindNoiseFilter: Bool = false {
        didSet {
            print("[VoiceEnhancement] Wind noise filter (80Hz HPF) enabled: \(enableWindNoiseFilter)")
        }
    }

    // MARK: - 统计

    /// 最近的 VAD 概率
    public private(set) var lastVadProbability: Float = 0

    /// 处理的帧数
    public private(set) var processedFrameCount: UInt64 = 0

    // MARK: - 初始化

    public init() {
        self.rnnoiseProcessor = RNNoiseProcessor()
        self.voiceEQ = VoiceEQ(sampleRate: Float(expectedSampleRate))
        self.resampler = AudioResampler()

        captureBuffer.reserveCapacity(rnnoiseFrameSize * 2)
        outputBuffer.reserveCapacity(outputBufferSize)
    }

    /// 设置输出采样率模式
    /// - Parameter mode: 输出采样率模式 (.rate8k for G711, .rate16k for Opus)
    /// - Note: 必须在 start() 之前调用
    public func setOutputMode(_ mode: OutputSampleRateMode) {
        guard !isRunning else {
            print("[VoiceEnhancement] Cannot change output mode while running")
            return
        }
        outputMode = mode
        outputBuffer.removeAll(keepingCapacity: true)
        outputBuffer.reserveCapacity(outputBufferSize)
        print("[VoiceEnhancement] Output mode set to \(mode.rawValue)Hz")
    }

    deinit {
        stop()
    }

    // MARK: - 公开方法

    /// 启动语音增强处理器
    public func start() throws {
        guard !isRunning else { return }

        // 1. 配置音频会话 (48kHz)
        try configureAudioSession()

        // 2. 创建 AudioUnit
        try setupAudioUnit()

        // 3. 启动
        let status = AudioOutputUnitStart(audioUnit!)
        guard status == noErr else {
            throw VoiceEnhancementError.startFailed(status)
        }

        isRunning = true
        print("[VoiceEnhancement] Started at 48kHz")
    }

    /// 停止处理器
    public func stop() {
        guard isRunning else { return }

        isRunning = false
        isProcessing = false

        // 清除回调
        onProcessedPCM = nil
        onVadProbability = nil
        onVolumeLevel = nil

        // 停止 AudioUnit
        if let unit = audioUnit {
            AudioOutputUnitStop(unit)
            AudioComponentInstanceDispose(unit)
        }
        audioUnit = nil

        // 清空缓冲
        bufferLock.lock()
        captureBuffer.removeAll()
        outputBuffer.removeAll()
        bufferLock.unlock()

        resampler.reset()
        rnnoiseProcessor.reset()

        print("[VoiceEnhancement] Stopped")
    }

    /// 开始处理（TX 开始时调用）
    public func startProcessing() {
        guard isRunning else { return }

        // 重置缓冲
        bufferLock.lock()
        captureBuffer.removeAll(keepingCapacity: true)
        outputBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        // 重置采样器
        resampler.reset()

        // 软重置 RNNoise（不销毁 state，只清零统计）
        rnnoiseProcessor.softReset()

        // 软重置 VoiceEQ
        voiceEQ.softReset()

        // 重置高通滤波器状态
        hpfZ1 = 0
        hpfZ2 = 0

        // 重置 TX 会话状态
        txFrameCount = 0
        isRNNoiseDelayedEnabled = false
        processedFrameCount = 0

        // 延迟启用：TX 开始时先禁用 RNNoise，等几帧后再启用
        if enableNoiseReduction {
            rnnoiseProcessor.isEnabled = false
            print("[VoiceEnhancement] RNNoise delayed enable: will activate after \(delayedEnableFrames) frames")
        }

        // 启用 VoiceEQ（如果配置了）
        if enableVoiceEQ {
            voiceEQ.isEnabled = true
            let eqPtrInt = Int(bitPattern: Unmanaged.passUnretained(voiceEQ).toOpaque())
            os_log("[VoiceEnhancement] VoiceEQ enabled, ptr=0x%llx, isEnabled=%d", log: veLog, type: .default, UInt64(eqPtrInt), voiceEQ.isEnabled ? 1 : 0)
        } else {
            os_log("[VoiceEnhancement] VoiceEQ disabled (enableVoiceEQ=%d)", log: veLog, type: .default, enableVoiceEQ ? 1 : 0)
        }

        isProcessing = true
        os_log("[VoiceEnhancement] TX started, noiseReduction=%d, voiceEQ=%d", log: veLog, type: .default, enableNoiseReduction ? 1 : 0, enableVoiceEQ ? 1 : 0)
    }

    /// 停止处理（TX 结束时调用）
    public func stopProcessing() {
        isProcessing = false

        // 立即禁用 RNNoise（松开 PTT 立即生效）
        rnnoiseProcessor.isEnabled = false
        isRNNoiseDelayedEnabled = false

        // 禁用 VoiceEQ
        voiceEQ.isEnabled = false

        // 输出剩余缓冲
        bufferLock.lock()
        if !outputBuffer.isEmpty {
            let remaining = outputBuffer
            outputBuffer.removeAll(keepingCapacity: true)
            bufferLock.unlock()
            onProcessedPCM?(remaining)
        } else {
            bufferLock.unlock()
        }

        // 打印 TX 会话统计
        print("[VoiceEnhancement] Processing stopped (TX session: \(processedFrameCount) frames, \(txFrameCount) total)")
    }

    // MARK: - 音频会话配置

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // 检查音频会话是否已经正确配置，避免重复配置导致声音中断
        // 允许 .spokenAudio（普通模式）或 .voiceChat（会议模式）
        let isAlreadyConfigured = session.category == .playAndRecord
            && (session.mode == .spokenAudio || session.mode == .voiceChat)
            && session.isOtherAudioPlaying == false

        if isAlreadyConfigured {
            // 音频会话已配置，只更新采样率信息
            actualSampleRate = session.sampleRate
            print("[VoiceEnhancement] Audio session already configured, skipping reconfiguration")
            return
        }

        // 使用 .allowBluetoothHFP 启用 HFP 协议，支持车载蓝牙麦克风
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )

        // 请求 48kHz 采样率
        try session.setPreferredSampleRate(expectedSampleRate)

        // 低延迟缓冲
        try session.setPreferredIOBufferDuration(0.010)  // 10ms（人耳无感知，更稳定）

        try session.setActive(true, options: [])

        // 保存实际采样率
        actualSampleRate = session.sampleRate
        print("[VoiceEnhancement] Audio session configured, actual rate: \(actualSampleRate) Hz (expected: \(expectedSampleRate) Hz)")

        // 如果实际采样率不是 48kHz，记录警告
        if abs(actualSampleRate - expectedSampleRate) > 100 {
            print("[VoiceEnhancement] WARNING: Sample rate mismatch! Will resample from \(actualSampleRate) to \(expectedSampleRate)")
        }
    }

    // MARK: - AudioUnit 配置

    private func setupAudioUnit() throws {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw VoiceEnhancementError.componentNotFound
        }

        var unit: AudioUnit?
        var status = AudioComponentInstanceNew(component, &unit)
        guard status == noErr, let audioUnit = unit else {
            throw VoiceEnhancementError.instanceCreationFailed(status)
        }
        self.audioUnit = audioUnit

        // 启用录音输入
        var enableInput: UInt32 = 1
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,
            &enableInput,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else {
            throw VoiceEnhancementError.propertySetFailed("EnableIO Input", status)
        }

        // 禁用播放输出（仅录音）
        var disableOutput: UInt32 = 0
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &disableOutput,
            UInt32(MemoryLayout<UInt32>.size)
        )
        // 忽略此错误，某些设备可能不支持禁用输出

        // 设置 48kHz 16-bit PCM 格式
        var format = AudioStreamBasicDescription(
            mSampleRate: expectedSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: UInt32(bytesPerSample),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSample),
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,  // 输入 bus 的输出端
            &format,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard status == noErr else {
            throw VoiceEnhancementError.propertySetFailed("StreamFormat Input", status)
        }

        // 设置录音回调
        var inputCallback = AURenderCallbackStruct(
            inputProc: voiceEnhancementRecordingCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            0,
            &inputCallback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        guard status == noErr else {
            throw VoiceEnhancementError.propertySetFailed("InputCallback", status)
        }

        // 初始化
        status = AudioUnitInitialize(audioUnit)
        guard status == noErr else {
            throw VoiceEnhancementError.initializeFailed(status)
        }

        print("[VoiceEnhancement] AudioUnit configured for 48kHz capture")
    }

    // MARK: - 音频处理

    /// 处理录音数据 (在音频回调线程调用)
    fileprivate func handleCapturedAudio(_ buffer: AudioBuffer, frameCount: UInt32) {
        guard isProcessing else { return }
        guard let data = buffer.mData else { return }

        let samples = data.assumingMemoryBound(to: Int16.self)
        let count = Int(frameCount)

        // 调试：检查 AudioUnit 回调的帧数（48kHz 应该是 ~480/10ms）
        if txFrameCount % 100 == 0 {
            print("[VE-TX] AudioUnit callback: frameCount=\(count), actualRate=\(actualSampleRate)Hz, expectedRate=\(expectedSampleRate)Hz")
        }

        // 转换为 Float 并应用增益
        var floatSamples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floatSamples[i] = Float(samples[i]) * inputGain
        }

        // 如果实际采样率不是 48kHz，需要重采样到 48kHz
        let processedSamples: [Float]
        if abs(actualSampleRate - expectedSampleRate) > 100 {
            processedSamples = resampleTo48k(floatSamples)
        } else {
            processedSamples = floatSamples
        }

        // 添加到采集缓冲
        bufferLock.lock()
        captureBuffer.append(contentsOf: processedSamples)
        bufferLock.unlock()

        // 处理完整的 RNNoise 帧
        processAvailableFrames()
    }

    /// 应用 80Hz 高通滤波器（就地处理）
    /// 使用 Direct Form II Transposed 实现，延迟约 0.04ms
    private func applyHighPassFilter(_ samples: inout [Float]) {
        for i in 0..<samples.count {
            let x = samples[i]
            // Direct Form II Transposed
            let y = hpfB0 * x + hpfZ1
            hpfZ1 = hpfB1 * x - hpfA1 * y + hpfZ2
            hpfZ2 = hpfB2 * x - hpfA2 * y
            samples[i] = y
        }
    }

    /// 将任意采样率重采样到 48kHz（线性插值）
    private func resampleTo48k(_ samples: [Float]) -> [Float] {
        guard samples.count > 0 else { return [] }

        let ratio = expectedSampleRate / actualSampleRate
        let outputCount = Int(Double(samples.count) * ratio)
        guard outputCount > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let srcPos = Double(i) / ratio
            let srcIndex = Int(srcPos)
            let frac = Float(srcPos - Double(srcIndex))

            let sample1 = srcIndex < samples.count - 1 ? samples[srcIndex + 1] : samples[srcIndex]

            // 线性插值
            if srcIndex < samples.count {
                output[i] = samples[srcIndex] * (1 - frac) + sample1 * frac
            } else {
                output[i] = samples[samples.count - 1]
            }
        }

        return output
    }

    /// 处理可用的帧
    private func processAvailableFrames() {
        bufferLock.lock()

        while captureBuffer.count >= rnnoiseFrameSize {
            // 取出一帧
            let frame = Array(captureBuffer.prefix(rnnoiseFrameSize))
            captureBuffer.removeFirst(rnnoiseFrameSize)
            bufferLock.unlock()

            // 增加 TX 帧计数
            txFrameCount += 1

            // 延迟启用 RNNoise：达到指定帧数后启用
            if enableNoiseReduction && !isRNNoiseDelayedEnabled && txFrameCount > delayedEnableFrames {
                rnnoiseProcessor.isEnabled = true
                isRNNoiseDelayedEnabled = true
                print("[VoiceEnhancement] RNNoise activated after \(txFrameCount) frames")
            }

            // 80Hz 高通滤波器（风噪抑制，在 RNNoise 之前）
            var processedFrame = frame
            if enableWindNoiseFilter {
                applyHighPassFilter(&processedFrame)
            }

            // RNNoise 处理
            let vadProb = rnnoiseProcessor.processFrameInPlace(&processedFrame)

            // 混合处理结果（根据降噪强度）
            if enableNoiseReduction && isRNNoiseDelayedEnabled && noiseReductionStrength < 1.0 {
                for i in 0..<rnnoiseFrameSize {
                    processedFrame[i] = frame[i] * (1 - noiseReductionStrength) +
                                        processedFrame[i] * noiseReductionStrength
                }
            }

            // TX 人声 EQ 处理（RNNoise 之后、编码之前）
            voiceEQ.processInPlace(&processedFrame)

            // 计算音量电平（用于 UI 水波纹）
            var sumSquares: Float = 0
            for sample in processedFrame {
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(processedFrame.count))
            // 归一化到 0.0 ~ 1.0（假设最大值为 32768）
            let normalizedLevel = min(rms / 8000.0, 1.0)
            onVolumeLevel?(normalizedLevel)

            // 更新 VAD
            lastVadProbability = vadProb
            onVadProbability?(vadProb)

            // 下采样到目标采样率 (8kHz for G711, 16kHz for Opus)
            let downsampled: [Int16]
            switch outputMode {
            case .rate8k:
                downsampled = resampler.downsample48kTo8k(processedFrame)
                // 调试：检查下采样比率 (480 @ 48k → 80 @ 8k)
                if processedFrameCount % 50 == 0 {
                    print("[VE-TX] downsample: \(processedFrame.count) @ 48k → \(downsampled.count) @ 8k")
                }
            case .rate16k:
                downsampled = resampler.downsample48kTo16k(processedFrame)
            }

            // 添加到输出缓冲（重新获取锁后检查状态）
            bufferLock.lock()
            guard isProcessing else {
                bufferLock.unlock()
                return
            }
            outputBuffer.append(contentsOf: downsampled)

            processedFrameCount += 1

            // 输出足够大的缓冲
            while outputBuffer.count >= outputBufferSize {
                let output = Array(outputBuffer.prefix(outputBufferSize))
                outputBuffer.removeFirst(outputBufferSize)
                bufferLock.unlock()

                // 调试：检查输出数据量
                print("[VE-TX] output: \(output.count) samples @ \(outputMode.rawValue)Hz (bufSize=\(outputBufferSize))")

                // 回调输出
                onProcessedPCM?(output)

                bufferLock.lock()
                guard isProcessing else {
                    bufferLock.unlock()
                    return
                }
            }
        }

        bufferLock.unlock()
    }
}

// MARK: - AudioUnit 回调

private let voiceEnhancementRecordingCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    let processor = Unmanaged<VoiceEnhancementProcessor>.fromOpaque(inRefCon).takeUnretainedValue()

    // 分配缓冲区
    var bufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: inNumberFrames * 2,
            mData: nil
        )
    )

    let bufferSize = Int(inNumberFrames * 2)
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 2)
    defer { buffer.deallocate() }
    bufferList.mBuffers.mData = buffer

    // 获取录音数据
    guard let audioUnit = processor.audioUnit else { return noErr }

    let status = AudioUnitRender(
        audioUnit,
        ioActionFlags,
        inTimeStamp,
        1,
        inNumberFrames,
        &bufferList
    )

    guard status == noErr else { return status }

    // 处理数据
    processor.handleCapturedAudio(bufferList.mBuffers, frameCount: inNumberFrames)

    return noErr
}

// MARK: - 错误类型

public enum VoiceEnhancementError: Error, CustomStringConvertible {
    case componentNotFound
    case instanceCreationFailed(OSStatus)
    case propertySetFailed(String, OSStatus)
    case initializeFailed(OSStatus)
    case startFailed(OSStatus)

    public var description: String {
        switch self {
        case .componentNotFound:
            return "AudioComponent not found"
        case .instanceCreationFailed(let status):
            return "AudioComponent instance creation failed: \(status)"
        case .propertySetFailed(let property, let status):
            return "AudioUnit property '\(property)' set failed: \(status)"
        case .initializeFailed(let status):
            return "AudioUnit initialize failed: \(status)"
        case .startFailed(let status):
            return "AudioUnit start failed: \(status)"
        }
    }
}

