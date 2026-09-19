import Foundation
import Accelerate

@main enum DSPTests {
    static func main() throws {
        var checks = 0
        for rate in [44_100.0, 48_000, 96_000, 192_000] {
            let bin = 100
            let frequency = Double(bin) * rate / 4096
            let left = UnsafeMutablePointer<Float>.allocate(capacity: 4096)
            let right = UnsafeMutablePointer<Float>.allocate(capacity: 4096)
            defer { left.deallocate(); right.deallocate() }
            for i in 0..<4096 {
                left[i] = Float(0.5 * sin(2 * Double.pi * frequency * Double(i) / rate))
                right[i] = -left[i]
            }
            let spectrum = try SpectrumAccumulator(duration: 1, sampleRate: rate)
            spectrum.append(channels: [left, right], channelCount: 2, count: 4096, time: 0)
            let row = 255 - bin * 256 / 2048
            precondition(abs(spectrum.level(column: 0, row: row) + 6.0206) < 0.05, "Half-amplitude sine must measure -6.02 dBFS, even with opposite channels")
            precondition(spectrum.level(column: 0, row: 0) < -95, "No invented high-frequency content")
            let pixels = spectrum.pixels()
            precondition(pixels.count == 768 * 256 * 4)
            precondition(stride(from: 3, to: pixels.count, by: 4).allSatisfy { pixels[$0] == 255 })
            checks += 4
        }
        let silence = UnsafeMutablePointer<Float>.allocate(capacity: 4096)
        silence.initialize(repeating: 0, count: 4096)
        defer { silence.deallocate() }
        let spectrum = try SpectrumAccumulator(duration: 1, sampleRate: 48_000)
        spectrum.append(channels: [silence], channelCount: 1, count: 4096, time: 0.99)
        precondition(spectrum.level(column: 767, row: 128) == -100)
        silence[0] = .nan; silence[1] = .infinity
        spectrum.append(channels: [silence], channelCount: 1, count: 2, time: 0)
        precondition(spectrum.level(column: 0, row: 128).isFinite)
        print("PASS_SPECTRUM_DSP checks=\(checks + 2)")
    }
}
