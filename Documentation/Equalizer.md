# Player equalizer

## Engine audit and implementation

The installed KSPlayer source is in `/Users/kaka/Documents/本地公开库/KSPlayer`.
No shared SDK or FFmpeg binaries were changed.

- `AVPlayer/KSAVPlayer.swift` does not connect an EQ, audio mixing tap, or the `audioFilters` option.
- `MEPlayer/KSMEPlayer.swift` constructs `KSOptions.audioPlayerType` and retains the output across playback, seeks and pause/resume.
- `MEPlayer/AudioEnginePlayer.swift` already contains `AudioEngineDynamicsPlayer`: source PCM → `nbandEQ` → dynamics → time pitch → mixer/output. Its public EQ exposes sixteen bands on the tested macOS and iOS runtimes. The app uses ten octave-spaced bands, bypassing the remainder.
- The SDK dynamics processor MUST be bypassed. Its default compressed the high-level test signal by about 11.07 dB; bypass restored neutral output. The app is not adding a compressor or limiter.
- The shipped FFmpeg filters `equalizer`, `volume`, `firequalizer` and `superequalizer` were verified in the arm64 simulator binary. However, `MEPlayer/Filter.swift` reuses its filter graph when the filter string changes; codec flushes do not destroy that graph. Continuous slider updates therefore use Audio Unit parameters, not FFmpeg filter-string replacement.

## Runtime behavior

EQ is off by default. The normal app checks `isPremium()`; the paid Pro target is entitled. This intentionally does not rely on the existing development `isVIP()` implementation that currently returns true. Opening the page is free; every mutation is gated both in the UI and store. Losing entitlement bypasses processing without deleting the saved curve.

Enabling EQ selects the all-format engine. An existing native EQ output updates live without flushing or reloading a song. The initial engine/output upgrade retires the previous player and restores its resolved URL, precise position, actual playback rate, volume and playback intent. Preparation does not automatically start playback. Only one app-owned seek restores position; live streams resume without a seek. Pending seeks and late completions use the existing generation/identity guards.

Each band ranges from −12 to +12 dB. The preamp offers up to 12 dB additional attenuation. Positive boosts subtract the largest boost from master gain as automatic headroom; this reduces clipping risk but is not a brick-wall peak guarantee. Bands above the source Nyquist limit are bypassed. Turning EQ off bypasses all bands and restores unity master gain.

The page uses a dark native rack design and a generated raster icon. Faders use vertical gestures; horizontal gestures browse the frequency strip. All controls have accessibility labels/values and entitlement-gated VoiceOver adjustments. The feature's sixteen copy keys are translated in all forty-two supported locales.

## Verification

See `Tests/Equalizer/README.md` for reproducible production-code transition tests and actual Audio Unit render tests. Both iOS app schemes and arm64 Mac Catalyst are build-checked. The additional universal Catalyst build reaches the linker but fails for x86_64: the existing MEGASDK `libcurl.a` references unresolved `nghttp2_*` and `idn2_*` symbols. These dependencies are absent from the MEGASDK package; its arm64 slice has no corresponding unresolved references. No EQ source compile errors are reported; this separate dependency issue is not changed by the feature. Simulator UI checks cover preview access, paywall entry, presets, pause/position preservation and fader interaction. No real purchase is made.

Real headphone/AirPlay route changes, interruptions and every remote provider still need device listening regression testing. Existing route handling, download files and embedded audio metadata are unchanged; EQ changes playback only.
