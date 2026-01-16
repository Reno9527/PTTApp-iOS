import Foundation
import AVFoundation
import AudioToolbox
import Accelerate
import PTTCodec
import os.lock

// MARK: - 音频统计

/// 播放统计信息
public struct AudioPlaybackStats: Sendable {
    /// RingBuffer 当前深度（毫秒）
    public let bufferLevelMs: Int

    /// 欠载次数
    public let underrunCount: UInt64

    /// 峰值电平 (0.0 ~ 1.0)
    public let peakLevel: Float

    /// RMS 电平 (0.0 ~ 1.0)
    public let rmsLevel: Float

    public init(
        bufferLevelMs: Int = 0,
        underrunCount: UInt64 = 0,
        peakLevel: Float = 0,
        rmsLevel: Float = 0
    ) {
        self.bufferLevelMs = bufferLevelMs
        self.underrunCount = underrunCount
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
    }
}

/// 录音统计信息
public struct AudioRecordingStats: Sendable {
    /// 峰值电平 (0.0 ~ 1.0)
    public let peakLevel: Float

    /// RMS 电平 (0.0 ~ 1.0)
    public let rmsLevel: Float

    /// 削波次数
    public let clipCount: UInt64

    public init(
        peakLevel: Float = 0,
        rmsLevel: Float = 0,
        clipCount: UInt64 = 0
    ) {
        self.peakLevel = peakLevel
        self.rmsLevel = rmsLevel
        self.clipCount = clipCount
    }
}

/// AudioUnit 音频引擎
///
/// 使用 RemoteIO AudioUnit 实现最低延迟的录音和播放
/// - 录音采样率: 8000 Hz (Int16)
/// - 播放采样率: 16000 Hz (Float32) - G711 8k→16k, Opus 16k 直接播放，系统自动 16k→48k
/// - 通道: 单声道
public final class AudioUnitEngine: @unchecked Sendable {

    // MARK: - 常量

    /// 录音采样率 (8kHz for G711 TX compatibility)
    private let recordingSampleRate: Float64 = 8000.0
    /// 播放采样率 (16kHz - 系统自动处理 16k→48k 转换)
    private let playbackSampleRate: Float64 = 16000.0
    private let channelCount: UInt32 = 1

    // 缓冲配置
    private let preferredIOBufferDuration: TimeInterval = 0.010  // 10ms（人耳无感知，更稳定）
    private let recordingBufferSizeMs = 62  // 约 500 samples，与 G711 包大小匹配

    // MARK: - 属性

    fileprivate var audioUnit: AudioUnit?
    /// 播放缓冲区 (16kHz Float32)
    private let playbackBuffer: AudioFloatRingBuffer
    private let codec = G711Codec()
    /// 用于 playPCM -> 16k 上采样
    private let playbackResampler = AudioResampler()
    /// G.711 专用多频带音频处理器（极致音质）
    private let g711Processor = MultibandAudioProcessor(sampleRate: 16000.0)

    private var isRunning = false
    private var isRecording = false

    /// 音频引擎是否正在运行（公开只读）
    public var isEngineRunning: Bool { isRunning }

    // MARK: - 回调活动检测（用于检测音频是否真正在工作）

    /// 播放回调最后被调用的时间（使用 CFAbsoluteTimeGetCurrent 避免 Date 分配）
    fileprivate var lastPlaybackCallbackTime: CFAbsoluteTime = 0

    /// 检查播放回调是否在指定时间内被调用过
    /// - Parameter withinMs: 检查的时间窗口（毫秒）
    /// - Returns: true 表示回调活跃，音频正在播放
    public func isPlaybackCallbackActive(withinMs: Int = 500) -> Bool {
        guard isRunning else { return false }
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = (now - lastPlaybackCallbackTime) * 1000  // 转换为毫秒
        return elapsed < Double(withinMs)
    }

    // 录音缓冲
    private var recordingBuffer: [Int16] = []
    private let recordingBufferSize: Int  // samples
    private var recordingBufferLock = os_unfair_lock_s()  // 线程安全锁

    // 预分配的录音回调缓冲区（避免 RT 线程内存分配）
    fileprivate let maxRecordingFrames: Int = 1024  // 足够大的缓冲区
    fileprivate var recordingCallbackBuffer: UnsafeMutableRawPointer?

    // MARK: - 回调

    /// 录音数据回调（PCM 16-bit @ 8kHz）
    public var onPCMRecorded: (([Int16]) -> Void)?

    /// 统计信息
    public private(set) var playbackStats = AudioPlaybackStats()
    public private(set) var recordingStats = AudioRecordingStats()

    // 统计更新
    private var clipCount: UInt64 = 0
    private var recordingPeak: Float = 0
    private var recordingRms: Float = 0

    // MARK: - 初始化

    public init() {
        // 16kHz Float 播放缓冲区
        // 播放缓冲：2000ms 容量（录音播放需要更大缓冲），2包初始缓冲
        // 包数配置自适应不同编码：G711=1000样本/包, Opus=320样本/包
        self.playbackBuffer = AudioFloatRingBuffer(capacityMs: 2000, sampleRate: 16000, initialPacketCount: 2, samplesPerPacket: 1000)
        self.recordingBufferSize = recordingBufferSizeMs * 8  // 8 samples/ms @ 8kHz
        self.recordingBuffer.reserveCapacity(recordingBufferSize)
        // 预分配录音回调缓冲区（避免 RT 线程内存分配）
        self.recordingCallbackBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: maxRecordingFrames * 2,  // Int16 = 2 bytes
            alignment: 2
        )
    }

    deinit {
        stop()
        // 释放预分配的录音回调缓冲区
        recordingCallbackBuffer?.deallocate()
        recordingCallbackBuffer = nil
    }

    // MARK: - 公开方法

    /// 配置并启动音频引擎
    public func start() throws {
        guard !isRunning else { return }

        // 1. 配置音频会话
        try configureAudioSession()

        // 2. 创建 AudioUnit
        try setupAudioUnit()

        // 3. 启动
        guard let unit = audioUnit else {
            throw AudioEngineError.unitNotCreated
        }
        let status = AudioOutputUnitStart(unit)
        guard status == noErr else {
            throw AudioEngineError.startFailed(status)
        }

        isRunning = true
        print("[AudioUnitEngine] Started")
    }

    /// 停止音频引擎
    public func stop() {
        guard isRunning else { return }

        // 1. 先标记为停止，阻止回调继续处理
        isRunning = false
        isRecording = false

        // 2. 清除回调，防止在停止过程中触发
        onPCMRecorded = nil

        // 3. 停止并释放 AudioUnit
        if let unit = audioUnit {
            AudioOutputUnitStop(unit)
            AudioComponentInstanceDispose(unit)
        }
        audioUnit = nil

        // 4. 清空缓冲区
        os_unfair_lock_lock(&recordingBufferLock)
        recordingBuffer.removeAll()
        os_unfair_lock_unlock(&recordingBufferLock)

        print("[AudioUnitEngine] Stopped")
    }

    /// 开始录音
    public func startRecording() {
        guard isRunning else { return }
        os_unfair_lock_lock(&recordingBufferLock)
        recordingBuffer.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&recordingBufferLock)
        isRecording = true
        print("[AudioUnitEngine] Recording started")
    }

    /// 停止录音
    public func stopRecording() {
        isRecording = false
        // 输出剩余缓冲
        os_unfair_lock_lock(&recordingBufferLock)
        let remaining = recordingBuffer
        recordingBuffer.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&recordingBufferLock)
        if !remaining.isEmpty {
            onPCMRecorded?(remaining)
        }
        print("[AudioUnitEngine] Recording stopped")
    }

    /// 强制重启音频引擎
    /// 用于电话中断等场景，不依赖 isRunning 状态
    public func forceRestart() throws {
        print("[AudioUnitEngine] Force restart requested")

        // 1. 强制停止（不检查 isRunning）
        isRunning = false
        isRecording = false
        onPCMRecorded = nil

        if let unit = audioUnit {
            AudioOutputUnitStop(unit)
            AudioComponentInstanceDispose(unit)
        }
        audioUnit = nil

        os_unfair_lock_lock(&recordingBufferLock)
        recordingBuffer.removeAll()
        os_unfair_lock_unlock(&recordingBufferLock)

        print("[AudioUnitEngine] Force stopped")

        // 2. 重新启动
        try configureAudioSession()
        try setupAudioUnit()

        guard let unit = audioUnit else {
            throw AudioEngineError.unitNotCreated
        }
        let status = AudioOutputUnitStart(unit)
        guard status == noErr else {
            throw AudioEngineError.startFailed(status)
        }

        isRunning = true
        print("[AudioUnitEngine] Force restarted successfully")
    }

    // MARK: - 统一播放接口

    /// 统一播放入口 (自动处理采样率转换和格式转换)
    ///
    /// AudioUnitEngine 内部只接受：16kHz / Float / mono
    /// - 8kHz → 16kHz (我们手动重采样)
    /// - 16kHz 直接使用
    /// - 系统自动处理 16kHz → 48kHz (硬件采样率)
    ///
    /// - Parameters:
    ///   - samples: PCM 样本指针 (Float32，范围 [-32768, 32768])
    ///   - frameCount: 样本数量
    ///   - sampleRate: 采样率 (8000, 16000)
    ///   - channels: 声道数 (目前只支持 1)
    public func play(
        samples: UnsafePointer<Float>,
        frameCount: Int,
        sampleRate: Int,
        channels: Int = 1
    ) {
        // 复制到数组
        let input = Array(UnsafeBufferPointer(start: samples, count: frameCount))
        playFloat(input, sampleRate: sampleRate)
    }

    /// 播放 Float32 PCM 数据 (自动处理采样率转换)
    ///
    /// - Parameters:
    ///   - samples: Float32 PCM 样本 (范围 [-32768, 32768])
    ///   - sampleRate: 采样率 (8000, 16000)
    public func playFloat(_ samples: [Float], sampleRate: Int) {
        let pcm16k: [Float]

        switch sampleRate {
        case 8000:
            // 8kHz → 16kHz (ratio 2, 含 ×2 增益补偿)
            pcm16k = playbackResampler.upsample8kTo16kFloat(samples)
        case 16000:
            // 16kHz 直接使用（Opus 无需额外增益）
            pcm16k = samples
        default:
            // 不支持的采样率，按 16kHz 处理
            print("[AudioUnitEngine] Warning: unsupported sample rate \(sampleRate), treating as 16kHz")
            pcm16k = samples
        }

        playbackBuffer.write(pcm16k)
    }

    /// 播放 Int16 PCM 数据 (自动转换为 Float 并处理采样率)
    ///
    /// - Parameters:
    ///   - samples: Int16 PCM 样本
    ///   - sampleRate: 采样率 (8000, 16000)
    public func playInt16(_ samples: [Int16], sampleRate: Int) {
        var pcm16k: [Float]

        switch sampleRate {
        case 8000:
            // G711: 8kHz → 16kHz 上采样 + 1.5倍增益（简化处理，去掉EQ）
            // upsample8kTo16k 已含 ×2 增益，乘 0.75 得到 ×1.5
            pcm16k = playbackResampler.upsample8kTo16k(samples)
            var gain: Float = 0.75
            vDSP_vsmul(pcm16k, 1, &gain, &pcm16k, 1, vDSP_Length(pcm16k.count))
        case 16000:
            // Opus: 16kHz 直接播放
            pcm16k = samples.map { Float($0) }
        default:
            print("[AudioUnitEngine] Warning: unsupported sample rate \(sampleRate), treating as 16kHz")
            pcm16k = samples.map { Float($0) }
        }

        playbackBuffer.write(pcm16k)
    }

    /// 清空播放缓冲
    public func clearPlayBuffer() {
        playbackBuffer.clear()
        playbackResampler.reset()
        g711Processor.reset()
    }

    // MARK: - RX 编码配置

    /// G711 每包样本数 @ 16kHz（500字节 @ 8kHz → 上采样 → 1000样本 @ 16kHz）
    private static let g711SamplesPerPacket = 1000

    /// Opus 每包样本数 @ 16kHz（20ms 帧 = 320样本）
    private static let opusSamplesPerPacket = 320

    /// 初始缓冲包数
    private static let initialPacketCount = 2

    /// 配置 RX 编码格式（自动调整初始缓冲大小）
    /// - Parameter codec: 接收的编码格式
    public func configureForRxCodec(_ codec: AudioCodec) {
        let samplesPerPacket: Int
        switch codec {
        case .g711:
            samplesPerPacket = Self.g711SamplesPerPacket  // 2包 = 125ms
        case .opus:
            samplesPerPacket = Self.opusSamplesPerPacket  // 2包 = 40ms
        }
        playbackBuffer.updateInitialBuffer(packetCount: Self.initialPacketCount, samplesPerPacket: samplesPerPacket)
        print("[AudioUnitEngine] RX codec configured: \(codec.rawValue), initial buffer: \(Self.initialPacketCount) packets × \(samplesPerPacket) samples")
    }

    // MARK: - 音频会话配置

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        // 配置音频会话
        // 默认使用 .spokenAudio 模式（半双工 PTT）
        // 会议模式时切换到 .voiceChat（启用硬件回声消除）
        // 使用 .allowBluetoothHFP 启用 HFP 协议，支持车载蓝牙麦克风
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )

        // 设置首选 IO 缓冲时长（低延迟）
        try session.setPreferredIOBufferDuration(preferredIOBufferDuration)

        // 设置采样率为 48kHz (播放采样率，系统会自动处理录音转换)
        try session.setPreferredSampleRate(playbackSampleRate)

        // 激活会话
        try session.setActive(true, options: [])

        print("[AudioUnitEngine] Audio session configured: spokenAudio mode, \(preferredIOBufferDuration * 1000)ms buffer, \(playbackSampleRate)Hz")
    }

    /// 切换音频模式（用于会议模式切换）
    /// - Parameter conferenceMode: true = 会议模式（voiceChat + AEC），false = 普通模式（spokenAudio）
    /// - Note: 异步执行，避免阻塞主线程（AEC 初始化较慢）
    public func setConferenceMode(_ conferenceMode: Bool) {
        // 在后台线程执行，避免 AEC 初始化阻塞 UI
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            let mode: AVAudioSession.Mode = conferenceMode ? .voiceChat : .spokenAudio

            do {
                try session.setCategory(
                    .playAndRecord,
                    mode: mode,
                    options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
                )
                print("[AudioUnitEngine] Audio mode switched to: \(conferenceMode ? "voiceChat (AEC enabled)" : "spokenAudio")")
            } catch {
                print("[AudioUnitEngine] Failed to switch audio mode: \(error)")
            }
        }
    }

    // MARK: - AudioUnit 配置

    private func setupAudioUnit() throws {
        // 1. 获取 RemoteIO AudioUnit
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &desc) else {
            throw AudioEngineError.componentNotFound
        }

        var unit: AudioUnit?
        var status = AudioComponentInstanceNew(component, &unit)
        guard status == noErr, let audioUnit = unit else {
            throw AudioEngineError.instanceCreationFailed(status)
        }
        self.audioUnit = audioUnit

        // 2. 启用录音（输入）
        var enableInput: UInt32 = 1
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Input,
            1,  // 输入 bus
            &enableInput,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.propertySetFailed("EnableIO Input", status)
        }

        // 3. 启用播放（输出）
        var enableOutput: UInt32 = 1
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,  // 输出 bus
            &enableOutput,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.propertySetFailed("EnableIO Output", status)
        }

        // 4. 设置录音格式 (8kHz Int16 - 适配 G711 TX)
        var recordingFormat = AudioStreamBasicDescription(
            mSampleRate: recordingSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        // 设置输入格式 (录音 - 8kHz Int16)
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,  // 输入 bus 的输出端
            &recordingFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.propertySetFailed("StreamFormat Input", status)
        }

        // 5. 设置播放格式 (16kHz Float32 - 系统自动处理 16k→48k)
        var playbackFormat = AudioStreamBasicDescription(
            mSampleRate: playbackSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 4,  // Float32 = 4 bytes
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        // 设置输出格式 (播放 - 16kHz Float32)
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,  // 输出 bus 的输入端
            &playbackFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.propertySetFailed("StreamFormat Output", status)
        }

        // 6. 设置录音回调
        var inputCallback = AURenderCallbackStruct(
            inputProc: recordingCallback,
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
            throw AudioEngineError.propertySetFailed("InputCallback", status)
        }

        // 7. 设置播放回调
        var outputCallback = AURenderCallbackStruct(
            inputProc: playbackCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &outputCallback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        guard status == noErr else {
            throw AudioEngineError.propertySetFailed("RenderCallback", status)
        }

        // 8. 初始化
        status = AudioUnitInitialize(audioUnit)
        guard status == noErr else {
            throw AudioEngineError.initializeFailed(status)
        }

        print("[AudioUnitEngine] AudioUnit configured: recording@\(recordingSampleRate)Hz Int16, playback@\(playbackSampleRate)Hz Float32")
    }

    // MARK: - 回调处理

    /// 处理录音数据
    fileprivate func handleRecordedData(_ buffer: AudioBuffer, frameCount: UInt32) {
        guard isRecording else { return }
        guard let data = buffer.mData else { return }

        // 安全检查：确保缓冲区大小足够
        let maxFrames = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
        let count = min(Int(frameCount), maxFrames)
        guard count > 0 else { return }

        let samples = data.assumingMemoryBound(to: Int16.self)

        // 更新录音电平
        var peak: Int32 = 0
        var sumSquares: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            // 使用 Int32 避免 Int16.min (-32768) 时 abs() 溢出崩溃
            let absSample = abs(Int32(sample))
            if absSample > peak { peak = absSample }
            sumSquares += Float(sample) * Float(sample)
            if absSample >= 32767 { clipCount += 1 }
        }
        recordingPeak = max(recordingPeak, Float(peak) / 32768.0)
        recordingRms = sqrt(sumSquares / Float(count)) / 32768.0

        // 累积到缓冲区（加锁保护）
        os_unfair_lock_lock(&recordingBufferLock)
        for i in 0..<count {
            recordingBuffer.append(samples[i])
        }

        // 达到目标大小时提取输出
        var output: [Int16]? = nil
        if recordingBuffer.count >= recordingBufferSize {
            output = Array(recordingBuffer.prefix(recordingBufferSize))
            recordingBuffer.removeFirst(recordingBufferSize)
        }
        os_unfair_lock_unlock(&recordingBufferLock)

        // 在锁外处理输出（避免死锁）
        if var outputData = output {
            // 应用麦克风音量
            if recordingVolume != 1.0 {
                for i in 0..<outputData.count {
                    let amplified = Float(outputData[i]) * recordingVolume
                    outputData[i] = Int16(clamping: Int32(amplified))
                }
            }
            onPCMRecorded?(outputData)
        }

        // 更新统计
        recordingStats = AudioRecordingStats(
            peakLevel: recordingPeak,
            rmsLevel: recordingRms,
            clipCount: clipCount
        )
    }

    /// 基础播放增益 (适配多频带处理器和 Opus 输出范围)
    private let basePlaybackGain: Float = 2.0

    /// 用户设置的播放音量 (0.0 ~ 1.0)
    public var playbackVolume: Float = 1.0

    /// 用户设置的录音音量 (0.0 ~ 1.0)
    public var recordingVolume: Float = 1.0

    /// 提供播放数据 (16kHz Float32)
    fileprivate func providePlaybackData(_ buffer: AudioBuffer, frameCount: UInt32) {
        guard let data = buffer.mData else { return }

        // 安全检查：确保缓冲区大小足够
        let maxFrames = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
        let count = min(Int(frameCount), maxFrames)
        guard count > 0 else { return }

        let samples = data.assumingMemoryBound(to: Float.self)

        // 从 16kHz Float 缓冲区读取
        _ = playbackBuffer.read(into: samples, count: count)

        // 应用音量增益 (基础增益 * 用户音量)
        // G.711 输入范围 [-25000, 25000]（软限幅后），Opus 输入范围 [-32768, 32768]
        // 输出范围 [-1.0, 1.0] for AudioUnit
        let totalGain = (basePlaybackGain * playbackVolume) / 65536.0
        for i in 0..<count {
            let normalized = samples[i] * totalGain
            // 限幅到 [-1.0, 1.0]
            samples[i] = max(-1.0, min(1.0, normalized))
        }

        // 更新统计
        let stats = playbackBuffer.stats
        playbackStats = AudioPlaybackStats(
            bufferLevelMs: playbackBuffer.availableMs,
            underrunCount: stats.underrunCount,
            peakLevel: stats.peakLevel,
            rmsLevel: stats.rmsLevel
        )
    }
}

// MARK: - AudioUnit 回调函数

/// 录音回调
private let recordingCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    let engine = Unmanaged<AudioUnitEngine>.fromOpaque(inRefCon).takeUnretainedValue()

    // 使用预分配缓冲区（避免 RT 线程内存分配）
    guard let buffer = engine.recordingCallbackBuffer,
          Int(inNumberFrames) <= engine.maxRecordingFrames else {
        return noErr
    }

    var bufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: inNumberFrames * 2,
            mData: buffer
        )
    )

    // 获取录音数据
    guard let audioUnit = engine.audioUnit else { return noErr }

    let status = AudioUnitRender(
        audioUnit,
        ioActionFlags,
        inTimeStamp,
        1,  // 输入 bus
        inNumberFrames,
        &bufferList
    )

    guard status == noErr else { return status }

    // 处理录音数据
    engine.handleRecordedData(bufferList.mBuffers, frameCount: inNumberFrames)

    return noErr
}

/// 播放回调
private let playbackCallback: AURenderCallback = { (
    inRefCon,
    ioActionFlags,
    inTimeStamp,
    inBusNumber,
    inNumberFrames,
    ioData
) -> OSStatus in

    let engine = Unmanaged<AudioUnitEngine>.fromOpaque(inRefCon).takeUnretainedValue()

    // 记录回调时间（用于检测音频是否真正在工作）
    engine.lastPlaybackCallbackTime = CFAbsoluteTimeGetCurrent()

    guard let ioData = ioData else { return noErr }

    // 提供播放数据
    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    if let buffer = bufferList.first {
        var mutableBuffer = buffer
        engine.providePlaybackData(mutableBuffer, frameCount: inNumberFrames)
    }

    return noErr
}

// MARK: - 错误类型

public enum AudioEngineError: Error, CustomStringConvertible {
    case componentNotFound
    case instanceCreationFailed(OSStatus)
    case propertySetFailed(String, OSStatus)
    case initializeFailed(OSStatus)
    case startFailed(OSStatus)
    case unitNotCreated

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
        case .unitNotCreated:
            return "AudioUnit not created after setup"
        }
    }
}
