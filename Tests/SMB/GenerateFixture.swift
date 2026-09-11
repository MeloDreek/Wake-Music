import Foundation

// A quiet, ten-second stereo sine wave. No user recordings or third-party music.
var wav = Data()
func ascii(_ value: String) { wav.append(contentsOf: value.utf8) }
func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
let frames = 44100 * 10
let bytes = UInt32(frames * 4)
ascii("RIFF"); u32(36 + bytes); ascii("WAVE")
ascii("fmt "); u32(16); u16(1); u16(2); u32(44100); u32(176400); u16(4); u16(16)
ascii("data"); u32(bytes)
for index in 0..<frames {
    let t = Double(index) / 44100
    let fade = min(1, min(t / 0.2, (10 - t) / 0.2))
    let sample = Int16(sin(t * 2 * .pi * 440) * 1800 * fade)
    u16(UInt16(bitPattern: sample)); u16(UInt16(bitPattern: sample))
}
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try wav.write(to: destination, options: .withoutOverwriting)
print("Created non-sensitive SMB audio fixture (10 seconds, PCM WAV).")
