# Offline spectrum analysis

Run from the repository root:

```sh
bash Tests/Spectrum/run-tests.sh
bash Tests/Spectrum/run-cache-tests.sh
bash Tests/Spectrum/run-backend-tests.sh /path/to/local/audio.flac
SPECTRUM_REPORT_PATH=/private/tmp/wake-spectrum-report.json bash Tests/Spectrum/run-backend-tests.sh /path/to/local/audio.flac
bash Tests/Spectrum/run-poster-probe.sh /private/tmp/wake-spectrum-report.json
```

The DSP tests compile the production accumulator and verify FFT normalization with half-amplitude bin-centered tones at 44.1/48/96/192 kHz, opposite-phase stereo, silent/high-frequency bins, nonfinite input, last time column and RGBA output. The localization check covers all 42 supported locales.

The backend harness compiles the actual analyzer against Homebrew FFmpeg on macOS (the small C shim only exposes FFmpeg error constants). It checks real decoding, six-channel silence, pre-cancelled jobs, damaged/missing files, plus any supplied fixtures. DTS tests generate six-channel DTS-in-WAV, inject isolated middle/trailing corruption and sustained corruption into temporary copies, and check recovery, timeline preservation and rejection respectively. It does not substitute for testing the bundled iOS FFmpeg build. The app was separately built and tested on the simulator with the user's local FLAC/DTS files. APE and DSF fixtures were also tested using the macOS harness. No source files are modified.

## Persistent cache

- `SandboxFileManager.spectrumPathURL()` creates `.MusicSpectrum` in the public music directory, hidden from library scans and excluded from backups.
- Cache identity is the SHA-256 of the Documents-relative source path (absolute path for external files). It is independent of editable titles/artists and sandbox UUIDs; same filenames in different folders do not collide.
- Each versioned binary plist contains the source size/modification/creation dates, analysis metadata, partial-analysis flag and LZFSE-compressed RGBA pixels with a SHA-256 integrity check. No audio samples or original files are copied.
- Reads happen before FFmpeg probing/decoding, on the serial analysis queue. Changed, obsolete or corrupt entries are misses; a successful reanalysis replaces the report atomically. Source revisions are rechecked before publication. Cancelled/failed jobs are not saved; optional cache I/O failures do not fail analysis.
- The disk budget is 128 MiB, evicting the least recently accessed generated reports only. Missing entries are regenerated on demand; unrelated files are never removed.
- `run-cache-tests.sh` exercises production cache serialization, compression, corrupt/oversized data, path collisions, source changes, cancellation and size eviction. Its real-backend integration test verifies that cache hits bypass the decoder, corrupt entries are repaired and failed jobs do not create reports.

The poster probe extracts the actual report/plot views, loads output produced by the backend, renders 1280-pixel-wide PNGs in the simulator, and checks layout in Chinese, English and Arabic. It loads the real app logo explicitly because the standalone process has no app asset catalog. It does not send or publish anything.

## Interpretation and limits

- A private, serial background decoder reads the first audio stream, independently of the playing engine and EQ. Protocols are restricted to local files; remote models (including local HLS manifests) are rejected at the entry point.
- The FFT uses 4096-sample Hann windows. Each time/frequency pixel holds the maximum magnitude across its windows and channels, not a downmix that could cancel antiphase audio. No whole-track PCM buffer or temporary decoded file is created. Working buffers are fixed-size; currently up to eight channels are supported.
- Frequency is linear, with a −100…0 dBFS color scale. This is a compressed peak spectrum, not a loudness/DR measurement or certification of a lossless master. Container format and bitrate alone do not establish source quality.
- Analysis above 192 kHz is resampled to 192 kHz and explicitly labeled. DSD source-rate display restores the 1-bit rate (FFmpeg's DSF/DFF DSD parameters use packed-byte sampling); its spectrum is of decoded PCM, not the raw 1-bit modulation stream. Reference: [FFmpeg DSF demuxer](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/dsfdec.c).
- Bitrate is explicitly the average **file** bitrate, including container overhead and embedded metadata. Original metadata is not rewritten. Time-axis duration comes from the selected audio stream or container metadata.
- Closing the page cancels reads/decoding via the interrupt callback and loop checks. A midstream sample format/layout change is rejected rather than passing mismatched buffers to the resampler. Isolated FFmpeg `INVALIDDATA` packets can be skipped, preserving missing time regions; more than eight consecutive errors, 64 total errors or fewer than 100 decoded frames per error reject the analysis. Partial results carry a localized warning both on screen and in the shared poster, including after a cache hit. IO/allocation errors are not swallowed. The share action sends only a rendered image through the user's chosen system share destination.
