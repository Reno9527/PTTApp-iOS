import AVFoundation
import WatchKit

/// Watch 端音频管理器
/// 负责录音和播放
class WatchAudioManager: NSObject {

    // MARK: - 录音相关

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false

    // MARK: - 播放相关

    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    // MARK: - 常量

    /// PCM 采样率 (8000 Hz for G.711 compatibility)
    private let sampleRate: Double = 8000

    /// 每次发送的缓冲区大小
    private let bufferSize: AVAudioFrameCount = 1024

    // MARK: - 录音

    /// 开始录音
    /// - Parameter onAudioData: 音频数据回调（PCM 16-bit）
    func startRecording(onAudioData: @escaping (Data) -> Void) {
        guard !isRecording else { return }

        do {
            // 配置音频会话
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try session.setActive(true)

            // 创建 AudioEngine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            inputNode = audioEngine.inputNode

            // 获取输入格式
            let inputFormat = inputNode?.outputFormat(forBus: 0)
            print("[WatchAudio] Input format: \(inputFormat?.description ?? "nil")")

            // 创建目标格式 (8000 Hz, mono, 16-bit)
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: true
            ) else {
                print("[WatchAudio] Failed to create target format")
                return
            }

            // 创建格式转换器（如果需要）
            var converter: AVAudioConverter?
            if let inputFormat = inputFormat, inputFormat.sampleRate != sampleRate {
                converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            }

            // 安装 tap
            inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
                guard let self = self else { return }

                var pcmData: Data

                if let converter = converter {
                    // 需要重采样
                    pcmData = self.convertBuffer(buffer, converter: converter, targetFormat: targetFormat)
                } else {
                    // 直接转换
                    pcmData = self.bufferToData(buffer)
                }

                if !pcmData.isEmpty {
                    onAudioData(pcmData)
                }
            }

            // 启动引擎
            try audioEngine.start()
            isRecording = true

            print("[WatchAudio] Recording started")

        } catch {
            print("[WatchAudio] Failed to start recording: \(error)")
        }
    }

    /// 停止录音
    func stopRecording() {
        guard isRecording else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false

        print("[WatchAudio] Recording stopped")
    }

    /// 将 AVAudioPCMBuffer 转换为 Data（16-bit PCM）
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else {
            return Data()
        }

        let frameLength = Int(buffer.frameLength)
        let floatData = channelData[0]

        // 转换为 16-bit PCM
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = floatData[i]
            // 钳位到 [-1, 1] 范围
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * Float(Int16.max))
        }

        return Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
    }

    /// 使用转换器重采样
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) -> Data {
        // 计算输出帧数
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else {
            return Data()
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("[WatchAudio] Conversion error: \(error)")
            return Data()
        }

        // 直接返回 int16 数据
        let frameLength = Int(outputBuffer.frameLength)
        guard let int16Data = outputBuffer.int16ChannelData else {
            return Data()
        }

        return Data(bytes: int16Data[0], count: frameLength * MemoryLayout<Int16>.size)
    }

    // MARK: - 播放

    /// 播放 PCM 音频数据
    /// - Parameter pcmData: 16-bit PCM 数据
    func playAudio(_ pcmData: Data) {
        guard !pcmData.isEmpty else { return }

        do {
            // 配置音频会话（如果录音未启动）
            if !isRecording {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            }

            // 创建音频格式
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: true
            ) else { return }

            // 创建 buffer
            let frameCount = UInt32(pcmData.count / MemoryLayout<Int16>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }
            buffer.frameLength = frameCount

            // 复制数据到 buffer
            pcmData.withUnsafeBytes { rawBuffer in
                guard let int16Ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                    return
                }
                if let channelData = buffer.int16ChannelData {
                    channelData[0].initialize(from: int16Ptr, count: Int(frameCount))
                }
            }

            // 简单播放：使用 AVAudioPlayer（更可靠）
            playWithAudioPlayer(pcmData)

        } catch {
            print("[WatchAudio] Failed to play audio: \(error)")
        }
    }

    /// 使用 AVAudioPlayer 播放（更简单可靠）
    private var audioPlayer: AVAudioPlayer?

    private func playWithAudioPlayer(_ pcmData: Data) {
        // 将 PCM 转换为 WAV 格式
        let wavData = createWavData(from: pcmData)

        do {
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[WatchAudio] AVAudioPlayer error: \(error)")
        }
    }

    /// 创建 WAV 格式数据
    private func createWavData(from pcmData: Data) -> Data {
        var wavData = Data()

        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        wavData.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wavData.append(pcmData)

        return wavData
    }
}
