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

EQ is off by default. The store uses the app-wide `isVIP()` policy: Pro always has access; the normal app requires an active subscription or lifetime purchase. Opening the page is free; attempting to edit first presents a localized explanation with cancel/upgrade actions, and only confirmation opens the paywall. Every mutation is gated both in the UI and store. Losing entitlement bypasses processing without deleting the saved curve.

Enabling EQ selects the all-format engine. An existing native EQ output updates live without flushing or reloading a song. The initial engine/output upgrade retires the previous player and restores its resolved URL, precise position, actual playback rate, volume and playback intent. Preparation does not automatically start playback. Only one app-owned seek restores position; live streams resume without a seek. Pending seeks and late completions use the existing generation/identity guards.

Each band ranges from −12 to +12 dB. The preamp offers up to 12 dB additional attenuation. Positive boosts subtract the largest boost from master gain as automatic headroom; this reduces clipping risk but is not a brick-wall peak guarantee. Bands above the source Nyquist limit are bypassed. Turning EQ off bypasses all bands and restores unity master gain.

The page uses a dark native rack design and a generated raster icon. Presets occupy exactly three horizontally scrolling rows, with Custom first and Bass Boost beside it in the first row (mirrored for RTL). Dynamic Type grows row height without adding rows. The fourteen factory curves combine practical listening adjustments with selected genres. They are starting points, not reference responses or definitive settings for a genre. Fresh settings select Bass Boost, but EQ remains off until enabled. The original Bass Boost curve is unchanged: +6/+5/+4/+2 dB at 32/64/125/250 Hz, zero for the remaining bands, with the existing automatic headroom policy. Previously saved choices and custom curves are not overwritten. Manual band or preamp adjustments update the custom snapshot, which can be recalled after trying another preset. Original persisted preset IDs remain decodable; a retired genre preset retains its saved sound as Custom rather than silently changing the user's curve. Reset restores flat bands and zero preamp, retaining the custom snapshot.

A localized note below the presets explains this starting-point approach and Custom saving. The footer above Reset explains frequency ranges, gentle adjustment and distortion reduction; processing never changes the original audio files. The top-right audio-engine button opens the existing PlayerEngineViewController. When opened from EQ, selecting an engine returns to the EQ page instead of dismissing its entire presentation.

Faders use vertical gestures; horizontal gestures browse the frequency strip or preset rows. Vertical swipes over presets remain available for scrolling the page. All controls have accessibility labels/values and entitlement-gated VoiceOver adjustments. EQ copy, including the six listening-adjustment names, Custom and preset guidance, is translated in all forty-two supported locales. Catalyst retains the native preamp slider without unsupported track tint or custom thumb images; iOS keeps the metallic styling.

## Verification

See `Tests/Equalizer/README.md` for reproducible production-code transition tests and actual Audio Unit render tests. Both iOS app schemes and arm64 Mac Catalyst are build-checked. The additional universal Catalyst build reaches the linker but fails for x86_64: the existing MEGASDK `libcurl.a` references unresolved `nghttp2_*` and `idn2_*` symbols. These dependencies are absent from the MEGASDK package; its arm64 slice has no corresponding unresolved references. No EQ source compile errors are reported; this separate dependency issue is not changed by the feature. Simulator UI checks cover preview access, paywall entry, presets, pause/position preservation and fader interaction. No real purchase is made.

Real headphone/AirPlay route changes, interruptions and every remote provider still need device listening regression testing. Existing route handling, download files and embedded audio metadata are unchanged; EQ changes playback only.
