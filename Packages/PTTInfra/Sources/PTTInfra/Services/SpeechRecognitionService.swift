import Foundation
import Speech
import AVFoundation

/// 语音识别服务
/// 用于 RX 接收时实时将语音转为文字
public final class SpeechRecognitionService: NSObject, @unchecked Sendable {

    // MARK: - 单例

    public static let shared = SpeechRecognitionService()

    // MARK: - 属性

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// 音频格式（用于转换 PCM 数据）
    private let audioFormat8k: AVAudioFormat?
    private let audioFormat16k: AVAudioFormat?

    /// 是否已授权
    public private(set) var isAuthorized: Bool = false

    /// 是否正在识别
    public private(set) var isRecognizing: Bool = false

    /// 当前说话者标识（呼号-SSID）
    private var currentSpeaker: String?

    /// 当前识别会话 ID
    private var currentSessionId: UUID?

    // MARK: - 回调

    /// 实时识别结果回调 (speaker, sessionId, text, isFinal)
    public var onTranscriptionUpdate: ((String, UUID, String, Bool) -> Void)?

    /// 识别错误回调
    public var onError: ((Error) -> Void)?

    // MARK: - 初始化

    private override init() {
        // 创建中文识别器
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))

        // 创建音频格式（单声道）
        audioFormat8k = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 8000,
            channels: 1,
            interleaved: true
        )

        audioFormat16k = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )

        super.init()

        speechRecognizer?.delegate = self
    }

    // MARK: - 权限

    /// 请求语音识别权限
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
                completion(status == .authorized)
            }
        }
    }

    /// 检查权限状态
    public var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - 识别控制

    /// 开始新的识别会话
    /// - Parameters:
    ///   - speaker: 说话者标识（呼号-SSID）
    ///   - sampleRate: 采样率（8000 或 16000）
    public func startRecognition(speaker: String, sampleRate: Int) {
        guard isAuthorized else {
            print("[SpeechRecognition] Not authorized")
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[SpeechRecognition] Recognizer not available")
            return
        }

        // 如果已有进行中的识别，先停止
        if isRecognizing {
            stopRecognition()
        }

        // 创建新会话
        currentSpeaker = speaker
        currentSessionId = UUID()

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            print("[SpeechRecognition] Failed to create request")
            return
        }

        // 配置请求
        request.shouldReportPartialResults = true  // 实时返回部分结果
        request.taskHint = .dictation  // 听写模式

        // 如果支持，启用设备端识别（更快、更私密）
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = false  // 允许云端识别以获得更好效果
        }

        // 开始识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        isRecognizing = true
        print("[SpeechRecognition] Started recognition for \(speaker), sampleRate: \(sampleRate)")
    }

    /// 追加音频数据
    /// - Parameters:
    ///   - samples: PCM Int16 采样数据
    ///   - sampleRate: 采样率（8000 或 16000）
    public func appendAudio(_ samples: [Int16], sampleRate: Int) {
        guard isRecognizing, let request = recognitionRequest else {
            return
        }

        // 选择正确的音频格式
        let format: AVAudioFormat?
        switch sampleRate {
        case 8000:
            format = audioFormat8k
        case 16000:
            format = audioFormat16k
        default:
            print("[SpeechRecognition] Unsupported sample rate: \(sampleRate)")
            return
        }

        guard let audioFormat = format else {
            return
        }

        // 创建 PCM Buffer
        let frameCount = AVAudioFrameCount(samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        // 复制数据到 buffer
        if let channelData = buffer.int16ChannelData {
            _ = samples.withUnsafeBufferPointer { srcPtr in
                memcpy(channelData[0], srcPtr.baseAddress!, samples.count * MemoryLayout<Int16>.size)
            }
        }

        // 追加到识别请求
        request.append(buffer)
    }

    /// 停止识别
    public func stopRecognition() {
        guard isRecognizing else { return }

        // 结束音频输入
        recognitionRequest?.endAudio()

        // 取消任务（如果还在进行）
        // 注意：不要立即取消，让它完成最后的识别

        isRecognizing = false

        print("[SpeechRecognition] Stopped recognition for \(currentSpeaker ?? "unknown")")
    }

    /// 取消识别（丢弃结果）
    public func cancelRecognition() {
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecognizing = false
        currentSpeaker = nil
        currentSessionId = nil
    }

    // MARK: - 内部方法

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // 识别错误
            print("[SpeechRecognition] Error: \(error.localizedDescription)")

            // 某些错误是正常的（如用户停止说话）
            let nsError = error as NSError
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                // "No speech detected" - 正常情况
            } else {
                onError?(error)
            }
        }

        if let result = result {
            let text = result.bestTranscription.formattedString
            let isFinal = result.isFinal

            if let speaker = currentSpeaker, let sessionId = currentSessionId {
                // 通知更新
                DispatchQueue.main.async { [weak self] in
                    self?.onTranscriptionUpdate?(speaker, sessionId, text, isFinal)
                }

                if isFinal {
                    print("[SpeechRecognition] Final result: \(text)")
                }
            }
        }

        // 如果是最终结果，清理资源
        if result?.isFinal == true {
            cleanupRecognition()
        }
    }

    private func cleanupRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
        currentSpeaker = nil
        currentSessionId = nil
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("[SpeechRecognition] Availability changed: \(available)")
    }
}
