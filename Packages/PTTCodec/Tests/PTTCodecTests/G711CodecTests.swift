import Testing
import Foundation
@testable import PTTCodec

@Suite("G711Codec Tests")
struct G711CodecTests {

    let codec = G711Codec()

    @Test("Encode and decode single sample")
    func testEncodeDecodeSingle() {
        // Test various PCM values
        let testValues: [Int16] = [0, 100, 1000, 10000, -100, -1000, -10000, 32767, -32768]

        for original in testValues {
            let encoded = codec.encode(original)
            let decoded = codec.decode(encoded)

            // A-law is lossy, so we just check the value is close
            let diff = abs(Int(original) - Int(decoded))
            #expect(diff < 1000, "Original: \(original), Decoded: \(decoded), Diff: \(diff)")
        }
    }

    @Test("Encode and decode buffer")
    func testEncodeDecodeBuffer() {
        // Generate test PCM data (sine wave)
        var samples = [Int16]()
        for i in 0..<500 {
            let t = Double(i) / 8000.0
            let value = sin(2.0 * .pi * 400.0 * t) * 16000.0
            samples.append(Int16(value))
        }

        // Encode
        let encoded = codec.encode(samples)
        #expect(encoded.count == 500)

        // Decode
        let decoded = codec.decode(encoded)
        #expect(decoded.count == 500)
    }

    @Test("Silence encoding")
    func testSilenceEncoding() {
        // PCM silence (0) should encode to A-law silence
        let silence = codec.encode(Int16(0))
        let decoded = codec.decode(silence)

        // Decoded silence should be close to 0
        #expect(abs(decoded) < 10)
    }

    @Test("Data conversion")
    func testDataConversion() {
        // Create PCM data
        let samples: [Int16] = [100, 200, 300, -100, -200, -300]
        var pcmData = Data(capacity: samples.count * 2)
        for sample in samples {
            var s = sample.littleEndian
            withUnsafeBytes(of: &s) { pcmData.append(contentsOf: $0) }
        }

        // Encode from Data
        let encoded = codec.encodeFromData(pcmData)
        #expect(encoded.count == samples.count)

        // Decode to Data
        let decoded = codec.decodeToData(encoded)
        #expect(decoded.count == samples.count * 2)
    }
}
