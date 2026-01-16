import Foundation
import os.lock

/// 音频环形缓冲区
///
/// 职责：存储 PCM 样本，供 AudioUnit 渲染回调拉取
/// 线程安全：使用 os_unfair_lock
public final class AudioRingBuffer: @unchecked Sendable {

    // MARK: - 配置

    /// 采样率
    public let sampleRate: Int

    /// 缓冲区容量（样本数）
    public let capacity: Int

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

    private var buffer: [Int16]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var availableCount: Int = 0
    private var lock = os_unfair_lock_s()

    /// 统计信息
    public private(set) var stats = Stats()

    // MARK: - 初始化

    /// 创建环形缓冲区
    /// - Parameters:
    ///   - capacityMs: 容量（毫秒）
    ///   - sampleRate: 采样率（默认 8000）
    public init(capacityMs: Int = 600, sampleRate: Int = 8000) {
        self.sampleRate = sampleRate
        self.capacity = capacityMs * sampleRate / 1000
        self.buffer = [Int16](repeating: 0, count: capacity)
    }

    // MARK: - 写入

    /// 写入 PCM 样本
    /// - Parameter samples: 16-bit PCM 样本数组
    /// - Returns: 实际写入的样本数
    @discardableResult
    public func write(_ samples: [Int16]) -> Int {
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

        // 更新电平统计
        updateLevels(samples)

        return written
    }

    /// 写入 PCM 数据（从指针）
    /// - Parameters:
    ///   - ptr: 样本指针
    ///   - count: 样本数量
    /// - Returns: 实际写入的样本数
    @discardableResult
    public func write(from ptr: UnsafePointer<Int16>, count: Int) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        let freeSpace = capacity - availableCount

        if count > freeSpace {
            let overflow = count - freeSpace
            readIndex = (readIndex + overflow) % capacity
            availableCount -= overflow
            stats.overrunCount += 1
        }

        // 写入数据
        for i in 0..<count {
            buffer[writeIndex] = ptr[i]
            writeIndex = (writeIndex + 1) % capacity
        }

        availableCount += count
        stats.samplesWritten += UInt64(count)

        return count
    }

    // MARK: - 读取

    /// 读取 PCM 样本
    /// - Parameters:
    ///   - into: 目标缓冲区
    ///   - count: 请求的样本数
    /// - Returns: 实际读取的样本数（不足则填充静音）
    @discardableResult
    public func read(into: UnsafeMutablePointer<Int16>, count: Int) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        var actualRead = 0

        for i in 0..<count {
            if availableCount > 0 {
                into[i] = buffer[readIndex]
                readIndex = (readIndex + 1) % capacity
                availableCount -= 1
                actualRead += 1
            } else {
                // 欠载：填充静音
                into[i] = 0
                if actualRead == 0 && i == 0 {
                    stats.underrunCount += 1
                }
            }
        }

        stats.samplesRead += UInt64(actualRead)
        return actualRead
    }

    /// 读取 PCM 样本数组
    /// - Parameter count: 请求的样本数
    /// - Returns: PCM 样本数组（不足则包含静音）
    public func read(count: Int) -> [Int16] {
        var result = [Int16](repeating: 0, count: count)
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

    /// 清空缓冲区
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        readIndex = 0
        writeIndex = 0
        availableCount = 0
    }

    /// 重置统计
    public func resetStats() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        stats = Stats()
    }

    // MARK: - 内部方法

    private func updateLevels(_ samples: [Int16]) {
        guard !samples.isEmpty else { return }

        var peak: Int16 = 0
        var sumSquares: Float = 0

        for sample in samples {
            let absSample = abs(sample)
            if absSample > peak {
                peak = absSample
            }
            sumSquares += Float(sample) * Float(sample)
        }

        stats.peakLevel = Float(peak) / 32768.0
        stats.rmsLevel = sqrt(sumSquares / Float(samples.count)) / 32768.0
    }
}
