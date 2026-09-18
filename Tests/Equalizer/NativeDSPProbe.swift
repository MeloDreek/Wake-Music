import AVFoundation
import AudioToolbox
import Foundation

setbuf(stdout, nil)

struct ProbeFailure: Error { let detail: String }

func render(frequency: Double, gain: Float, channels: AVAudioChannelCount,
            sampleRate: Double = 48_000, enabled: Bool = true,
            amplitude: Float = 0.05, dynamicsBypassed: Bool = true,
            initialGain: Float? = nil) throws -> Double {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let eq = AVAudioUnitEQ()
    let dynamics = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_DynamicsProcessor,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0))
    var bypass = UInt32(dynamicsBypassed ? 1 : 0)
    let setStatus = AudioUnitSetProperty(dynamics.audioUnit, kAudioUnitProperty_BypassEffect,
                                        kAudioUnitScope_Global, 0, &bypass,
                                        UInt32(MemoryLayout<UInt32>.size))
    var observedBypass: UInt32 = 99
    var byteSize = UInt32(MemoryLayout<UInt32>.size)
    let getStatus = AudioUnitGetProperty(dynamics.audioUnit, kAudioUnitProperty_BypassEffect,
                                        kAudioUnitScope_Global, 0, &observedBypass, &byteSize)
    guard setStatus == 0 && getStatus == 0 && observedBypass == bypass else {
        throw ProbeFailure(detail: "dynamics bypass set=\(setStatus), get=\(getStatus), actual=\(observedBypass)")
    }
    for band in eq.bands { band.bypass = true }
    eq.bands[0].filterType = .parametric
    eq.bands[0].frequency = 1_000
    eq.bands[0].bandwidth = 1
    eq.bands[0].gain = initialGain ?? gain
    eq.bands[0].bypass = !enabled
    let layoutTag = channels == 6 ? kAudioChannelLayoutTag_MPEG_5_1_A : (channels == 1 ? kAudioChannelLayoutTag_Mono : kAudioChannelLayoutTag_Stereo)
    let layout = AVAudioChannelLayout(layoutTag: layoutTag)!
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, interleaved: false, channelLayout: layout)
    let sampleCount = AVAudioFrameCount(sampleRate * 2)
    let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sampleCount)!
    input.frameLength = sampleCount
    for channel in 0..<Int(channels) {
        for frame in 0..<Int(sampleCount) {
            input.floatChannelData![channel][frame] = amplitude * Float(sin(2 * .pi * frequency * Double(frame) / sampleRate))
        }
    }
    engine.attach(player)
    engine.attach(eq)
    engine.attach(dynamics)
    engine.connect(player, to: eq, format: format)
    engine.connect(eq, to: dynamics, format: format)
    engine.connect(dynamics, to: engine.mainMixerNode, format: format)
    engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    player.scheduleBuffer(input)
    try engine.start()
    player.play()
    let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
    var sumSquares = 0.0
    var measuredCount = 0
    var emptyPasses = 0
    var changedGain = false
    let measurementStart = Int64(sampleRate * (initialGain == nil ? 0.5 : 1))
    while engine.manualRenderingSampleTime < AVAudioFramePosition(sampleCount) {
        let remaining = sampleCount - AVAudioFrameCount(engine.manualRenderingSampleTime)
        let position = engine.manualRenderingSampleTime
        if initialGain != nil && !changedGain && position >= Int64(sampleRate / 2) {
            guard engine.isRunning else { throw ProbeFailure(detail: "live parameter test lost running engine") }
            eq.bands[0].gain = gain
            changedGain = true
        }
        let status = try engine.renderOffline(min(4096, remaining), to: output)
        if status == .success {
            emptyPasses = 0
            for channel in 0..<Int(channels) {
                for frame in 0..<Int(output.frameLength) where position + Int64(frame) > measurementStart {
                    let value = Double(output.floatChannelData![channel][frame])
                    sumSquares += value * value
                    measuredCount += 1
                }
            }
        } else {
            emptyPasses += 1
            if emptyPasses > 10 { throw ProbeFailure(detail: "render failed repeatedly: \(status.rawValue)") }
        }
    }
    player.stop()
    engine.stop()
    let rms = sqrt(sumSquares / Double(measuredCount))
    return 20 * log10(rms / (Double(amplitude) / sqrt(2)))
}

let availableBands = AVAudioUnitEQ().bands.count
print("DEFAULT_EQ_BANDS=\(availableBands)")
precondition(availableBands >= 10, "The SDK default EQ must expose at least ten bands")
for channels: AVAudioChannelCount in [1, 2, 6] {
    for sampleRate in [22_050.0, 44_100.0, 48_000.0, 96_000.0] {
        let center = try render(frequency: 1_000, gain: 6, channels: channels, sampleRate: sampleRate)
        let low = try render(frequency: 100, gain: 6, channels: channels, sampleRate: sampleRate)
        let disabled = try render(frequency: 1_000, gain: 6, channels: channels, sampleRate: sampleRate, enabled: false, amplitude: 0.6)
        print(String(format: "channels=%d sampleRate=%.0f EQ_1k_gain=%.4fdB EQ_100Hz_gain=%.4fdB DISABLED_HIGH_LEVEL=%.4fdB", channels, sampleRate, center, low, disabled))
        guard abs(center - 6) < 0.03 && abs(low) < 0.1 && abs(disabled) < 0.01 else {
            throw ProbeFailure(detail: "response failed acceptance")
        }
    }
}
let compressed = try render(frequency: 1_000, gain: 0, channels: 2, amplitude: 0.6, dynamicsBypassed: false)
print(String(format: "DEFAULT_DYNAMICS_HIGH_LEVEL_GAIN=%.4fdB", compressed))
precondition(compressed < -1, "The control must demonstrate that unbypassed dynamics change audio")
let liveChange = try render(frequency: 1_000, gain: 6, channels: 2, initialGain: 0)
print(String(format: "RUNNING_ENGINE_PARAMETER_CHANGE_GAIN=%.4fdB", liveChange))
precondition(abs(liveChange - 6) < 0.03, "Gain changes must reach output without engine restart")
print("PASS_NATIVE_EQ_RESPONSE_AND_BYPASS")
