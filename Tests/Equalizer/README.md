# Equalizer verification

Run from the repository root on macOS with Xcode installed:

```sh
bash Tests/Equalizer/run-tests.sh --settings-only
bash Tests/Equalizer/run-tests.sh
bash Tests/Equalizer/run-tests.sh --simulator
ruby Tests/Equalizer/check-ui-copy.rb
ruby Tests/Equalizer/check-navigation.rb
bash Tests/Equalizer/run-layout-probe.sh
```

The simulator variant also runs the macOS tests and requires one booted arm64 iOS simulator. Set `EQ_SIMULATOR_UDID` when more than one simulator is booted. `DEVELOPER_DIR` can override the default `/Applications/Xcode.app/Contents/Developer`. Audio Unit creation requires access to system audio component services; a restrictive shell sandbox can block it even though the probe never plays sound.

The layout probe extracts the production three-row horizontal preset view and runs it inside the booted simulator without installing or interacting with the app. It checks Custom and Bass Boost leading the first row, exactly three rows, scroll reachability, four widths, normal/large fonts, RTL/LTR and resizing across 42 locales. The copy check validates localized preset names and guidance, audio-engine navigation and its return path, the Catalyst slider styling guard, and confirmation before the paywall. The settings suite verifies distinct factory curves, the unchanged original Bass Boost curve as the new-instance default (with EQ still off), legacy flat fallback for incomplete saved records, custom-curve recall, and compatibility with all legacy raw IDs. It no longer imposes an arbitrary minimum preset count. `Tests/RemoteAccess/check-policy.rb` additionally compiles the actual shared entitlement implementation for both normal and Pro builds.

`IntegrationTests.swift` compiles the actual app settings source. `extract-integration.rb` mechanically extracts the actual store and playback migration/retire/pause/seek methods for compilation against deterministic boundaries. It covers corrupt and short gain arrays, finite-value normalization, preset JSON round trips, master headroom, premium mutation gating, persistence, entitlement loss and foreground refresh, engine-observer suppression, paused migration, retained URL/volume/rate, pending seeks, request invalidation, and pause during a seek. A unique `UserDefaults` suite isolates test persistence and is removed after the run.

`NativeDSPProbe.swift` renders generated sine waves through Apple's real `AVAudioUnitEQ` and dynamics processor to memory. It verifies:

- The default EQ used by the installed KSPlayer exposes at least ten bands; observed default is sixteen.
- A +6 dB band at 1 kHz measures within 0.03 dB at its center and within 0.1 dB of unity at 100 Hz.
- Mono, stereo and 5.1 at 22.05, 44.1, 48 and 96 kHz work.
- Disabling EQ while bypassing dynamics remains neutral at high signal level, within 0.01 dB.
- The dynamics bypass property accepts the write and reads back correctly. The unbypassed control measurably compresses the signal.
- Changing gain on a running engine changes rendered output without rebuilding or restarting it.

The probe tests real DSP behavior; the integration harness tests app state transitions. Neither substitutes for an on-device listening check of speaker/headphone/AirPlay route changes, interruptions, or remote network playback. KSPlayer's PCM and routing code is unchanged by this feature.

The migration intentionally leaves `startPlayTime` at zero and uses the app's pending seek once readiness arrives. Setting both would start two competing seek operations. SDK `KSPlayerLayer.seek` skips targets within one second of the current time; this is why live EQ adjustments update Audio Unit parameters directly.

The current FFmpeg package also contains working `equalizer`, `volume`, `firequalizer` and `superequalizer` filters (verified against its arm64 iOS simulator binary). It is not used for slider updates: this SDK's `MEFilter` adds replacement filters to a graph without freeing the prior graph, and codec seeks do not recreate that graph. `KSAVPlayer` has no EQ/tap integration. Native `AudioEngineDynamicsPlayer.nbandEQ` is the app's EQ output.
