import Foundation
import os.lock

/// 浮点音频环形缓冲区 (16kHz)
///
/// 职责：存储 Float32 PCM 样本，供 AudioUnit 渲染回调拉取
/// 线程安全：使用 os_unfair_lock
/// 初始缓冲：首次写入后等待达到目标深度才开始输出，吸收网络抖动
public final class AudioFloatRingBuffer: @unchecked Sendable {

    // MARK: - 配置

    /// 采样率
    public let sampleRate: Int

    /// 缓冲区容量（样本数）
    public let capacity: Int

    /// 初始缓冲目标（样本数）- 可动态调整
    public private(set) var initialBufferSamples: Int

    // MARK: - 统计

    /// 统计信息
    public struct Stats: Sendable {
        public var samplesWritten: UInt64 = 0
        public var samplesRead: UInt64 = 0
        public var underrunCount: UInt64 = 0
        public var overrunCount: UInt64 = 0
        public var peakLevel: Float = 0
        public var rmsLevel: Float = 0
    }

    // MARK: - 属性

    private var buffer: [Float]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var availableCount: Int = 0
    private var lock = os_unfair_lock_s()

    /// 是否正在初始缓冲（等待达到目标深度）
    private var isBuffering: Bool = true

    /// 统计信息
    public private(set) var stats = Stats()

    // MARK: - 初始化

    /// 创建环形缓冲区（毫秒配置）
    /// - Parameters:
    ///   - capacityMs: 容量（毫秒），必须大于 0
    ///   - sampleRate: 采样率（默认 16000），必须大于 0
    ///   - initialBufferMs: 初始缓冲目标（毫秒），首次写入后等待达到此深度才开始输出
    public init(capacityMs: Int = 600, sampleRate: Int = 16000, initialBufferMs: Int = 100) {
        precondition(capacityMs > 0, "capacityMs must be > 0")
        precondition(sampleRate > 0, "sampleRate must be > 0")
        self.sampleRate = sampleRate
        self.capacity = max(1, capacityMs * sampleRate / 1000)
        self.initialBufferSamples = max(1, initialBufferMs * sampleRate / 1000)
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    /// 创建环形缓冲区（包数配置，自适应不同编码）
    /// - Parameters:
    ///   - capacityMs: 容量（毫秒），必须大于 0
    ///   - sampleRate: 采样率（默认 16000），必须大于 0
    ///   - initialPacketCount: 初始缓冲包数（如 2 个包）
    ///   - samplesPerPacket: 每包样本数（播放采样率下，G711=1000, Opus=320）
    public init(capacityMs: Int = 600, sampleRate: Int = 16000, initialPacketCount: Int, samplesPerPacket: Int) {
        precondition(capacityMs > 0, "capacityMs must be > 0")
        precondition(sampleRate > 0, "sampleRate must be > 0")
        precondition(initialPacketCount > 0, "initialPacketCount must be > 0")
        precondition(samplesPerPacket > 0, "samplesPerPacket must be > 0")
        self.sampleRate = sampleRate
        self.capacity = max(1, capacityMs * sampleRate / 1000)
        self.initialBufferSamples = initialPacketCount * samplesPerPacket
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    // MARK: - 写入

    /// 写入 Float32 PCM 样本
    /// - Parameter samples: Float32 PCM 样本数组
    /// - Returns: 实际写入的样本数
    @discardableResult
    public func write(_ samples: [Float]) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let count = samples.count
        let freeSpace = capacity - availableCount

        if count > freeSpace {
            // 溢出：丢弃最旧的数据
            let overflow = count - freeSpace
            readIndex = (readIndex + overflow) % capacity
            availableCount -= overflow
            stats.overrunCount += 1
        }

        // 写入数据
        var written = 0
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            written += 1
        }

        availableCount += written
        stats.samplesWritten += UInt64(written)

        // 检查是否达到初始缓冲目标
        if isBuffering && availableCount >= initialBufferSamples {
            isBuffering = false
        }

        // 更新电平统计
        updateLevels(samples)

        return written
    }

    // MARK: - 读取

    /// 读取 Float32 PCM 样本
    /// - Parameters:
    ///   - into: 目标缓冲区
    ///   - count: 请求的样本数
    /// - Returns: 实际读取的样本数（不足则填充静音）
    @discardableResult
    public func read(into: UnsafeMutablePointer<Float>, count: Int) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        // 初始缓冲期间：返回静音，等待达到目标深度
        if isBuffering {
            for i in 0..<count {
                into[i] = 0
            }
            return 0
        }

        var actualRead = 0

        for i in 0..<count {
            if availableCount > 0 {
                into[i] = buffer[readIndex]
                readIndex = (readIndex + 1) % capacity
                availableCount -= 1
                actualRead += 1
            } else {
                // 欠载：填充静音，重新进入缓冲状态
                into[i] = 0
                if actualRead == 0 && i == 0 {
                    stats.underrunCount += 1
                    isBuffering = true  // 重新缓冲
                }
            }
        }

        stats.samplesRead += UInt64(actualRead)
        return actualRead
    }

    /// 读取 Float32 PCM 样本数组
    /// - Parameter count: 请求的样本数
    /// - Returns: PCM 样本数组（不足则包含静音）
    public func read(count: Int) -> [Float] {
        var result = [Float](repeating: 0, count: count)
        result.withUnsafeMutableBufferPointer { ptr in
            _ = read(into: ptr.baseAddress!, count: count)
        }
        return result
    }

    // MARK: - 状态查询

    /// 可用样本数
    public var available: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return availableCount
    }

    /// 可用时长（毫秒）
    public var availableMs: Int {
        available * 1000 / sampleRate
    }

    /// 空闲空间
    public var freeSpace: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return capacity - availableCount
    }

    /// 是否为空
    public var isEmpty: Bool {
        available == 0
    }

    // MARK: - 控制

    /// 清空缓冲区（重新进入初始缓冲状态）
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        readIndex = 0
        writeIndex = 0
        availableCount = 0
        isBuffering = true
    }

    /// 动态更新初始缓冲配置（用于切换编码格式）
    /// - Parameters:
    ///   - packetCount: 初始缓冲包数
    ///   - samplesPerPacket: 每包样本数（播放采样率下）
    public func updateInitialBuffer(packetCount: Int, samplesPerPacket: Int) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        initialBufferSamples = packetCount * samplesPerPacket
    }

    /// 重置统计
    public func resetStats() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        stats = Stats()
    }

    // MARK: - 内部方法

    private func updateLevels(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        var peak: Float = 0
        var sumSquares: Float = 0

        for sample in samples {
            let absSample = abs(sample)
            if absSample > peak {
                peak = absSample
            }
            sumSquares += sample * sample
        }

        // 假设输入范围是 [-32768, 32768]，归一化到 [0, 1]
        stats.peakLevel = peak / 32768.0
        stats.rmsLevel = sqrt(sumSquares / Float(samples.count)) / 32768.0
    }
}
