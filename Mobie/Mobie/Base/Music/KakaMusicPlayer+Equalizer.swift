import AppGroupKit
import KSPlayer
import AVFoundation
import AudioToolbox

extension KakaMusicPlayer {
    @MainActor
    func equalizerSettingsDidChange() {
        let store = PlayerEqualizerStore.shared
        if store.isActive, MusicConfigManager.shared.playerEngine != .wakePlayer {
            // Do not run the legacy engine-change observer, which starts this song from zero.
            isSwitchingEngineForEqualizer = true
            MusicConfigManager.shared.playerEngine = .wakePlayer
            isSwitchingEngineForEqualizer = false
        }
        guard let layer = playerView.playerLayer else { return }
        if let me = layer.player as? KSMEPlayer, me.audioOutput is AudioEngineDynamicsPlayer {
            configureCurrentEqualizer()
        } else if store.isActive {
            reloadCurrentEngineForEqualizer()
        }
    }

    /// Called before the SDK's ready -> play transition, including restored and paused tracks.
    /// Apple Audio Unit parameter updates are live; no decoded buffers or FFmpeg graphs are mutated.
    @MainActor
    func configureCurrentEqualizer() {
        guard let me = playerView.playerLayer?.player as? KSMEPlayer,
              let output = me.audioOutput as? AudioEngineDynamicsPlayer else { return }
        var bypass: UInt32 = 1
        let status = AudioUnitSetProperty(output.audioUnitForDynamicsProcessor,
            kAudioUnitProperty_BypassEffect, kAudioUnitScope_Global, 0,
            &bypass, UInt32(MemoryLayout<UInt32>.size))
        assert(status == noErr, "The EQ output must not enable the SDK's compressor")
        let store = PlayerEqualizerStore.shared
        let settings = store.settings.normalized()
        let equalizer = output.nbandEQ
        let enabled = store.isActive && equalizer.bands.count >= settings.gains.count
        // Ignore unavailable ultrasonic bands on low-sample-rate content instead of
        // moving their frequencies (and unexpectedly boosting another audible band).
        let sampleRate = equalizer.inputFormat(forBus: 0).sampleRate
        let upperFrequency = sampleRate > 0 ? min(20_000, Float(sampleRate * 0.49)) : 20_000
        equalizer.globalGain = enabled ? settings.outputGain : 0
        for (index, band) in equalizer.bands.enumerated() {
            guard PlayerEqualizerSettings.frequencies.indices.contains(index) else {
                band.bypass = true
                continue
            }
            let frequency = PlayerEqualizerSettings.frequencies[index]
            band.filterType = .parametric
            band.frequency = min(frequency, upperFrequency)
            band.bandwidth = 1
            band.gain = settings.gains[index]
            band.bypass = !enabled || frequency > upperFrequency
        }
        equalizer.bypass = !enabled
    }

    /// Only the initial AVPlayer -> KSMEPlayer/output upgrade reloads the source.
    /// Reuse the resolved URL and preserve time, rate, volume and pause intent.
    @MainActor
    private func reloadCurrentEngineForEqualizer() {
        guard let model = playingMusic, let oldLayer = playerView.playerLayer else { return }
        let shouldResume = wantsPlayback
        let engineTime = oldLayer.player.currentPlaybackTime
        let resumeTime = !isSeeking && oldLayer.player.isReadyToPlay && engineTime.isFinite
            ? engineTime : currentTime
        let position = oldLayer.player.isReadyToPlay && !oldLayer.player.seekable ? 0 :
            (pendingSeekTime ?? (resumeTime.isFinite ? max(0, resumeTime) : 0))
        let volume = oldLayer.player.playbackVolume
        let rate = oldLayer.player.playbackRate
        let url = oldLayer.url
        retirePlayback()
        wantsPlayback = shouldResume
        currentTime = position
        lastUpdateTime = 0
        MusicConfigManager.shared.lastPlayTime = position
        let options = audioOption(model)
        options.startPlayRate = rate
        options.isAutoPlay = false
        // Only pendingSeekTime owns restoration. startPlayTime would launch a second
        // SDK seek concurrently and could cancel our completion with finished=false.
        options.isAccurateSeek = true
        playerView.set(url: url, options: options)
        playerView.playerLayer?.player.playbackVolume = volume
        configureCurrentEqualizer()
        pendingSeekTime = position
        playbackStatus = shouldResume ? .buffering : .paused
        // Preparation is not playback. The ready callback seeks then honors wantsPlayback.
        playerView.playerLayer?.prepareToPlay()
        updatePlaybackState()
    }
}
