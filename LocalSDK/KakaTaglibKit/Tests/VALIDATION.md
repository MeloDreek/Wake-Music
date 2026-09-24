# 2.3.3 release validation

Date: 2026-09-24. Host: Apple Silicon macOS, Xcode 27.0 (27A266a).

## Regression results

The final standalone run completed **1,345 assertions with zero failures**:
1,064 generated-fixture checks and 281 verified upstream-corpus checks.
AddressSanitizer and UndefinedBehaviorSanitizer reported no failures.
LeakSanitizer was not enabled; this is not a leak-free guarantee.

| Scope | Result |
| --- | --- |
| Basic tags, artwork and lyrics | Read/write/reopen checks passed for MP3, FLAC, M4A, WAV, AIFF, Ogg Vorbis, Opus, WavPack, TTA, ASF, DSF, DFF, APE and Musepack |
| Matroska | Metadata read checks passed; artwork and lyrics writing intentionally disabled |
| Audio integrity | Decoded PCM SHA-256 unchanged for all 15 valid fixtures; no decoder skips |
| Malformed files | All six selected historical APE/Musepack crash or loop probes completed safely and retained original bytes |
| Legacy tags | Raw ID3v1.0 preservation, unsafe-write rejection and Unicode migration checks passed |
| Concurrent access | 64 concurrent read/write operations on the same disposable MP3 passed |
| Invalid inputs | Empty/corrupt/readonly files, directories, remote URLs, nil arguments, malformed lyrics and invalid artwork checks passed |
| Alternate metadata sources | FLAC ID3v2/Xiph artwork, described USLT, lyric aliases, MP4 freeform, RIFF ILYR and timed-comment fallbacks passed |
| Picture compatibility | TIFF APIC and raw GIF/BMP/TIFF APE reads passed; replacing an APE front picture preserved raw back-picture bytes |
| First artwork write | Native tags were created in legacy-only WV/TTA/APE/MPC and DIIN-only DFF files; reopened artwork matched |
| FLAC size limits | Oversized artwork and cumulative Vorbis-comment blocks were rejected without changing file bytes |

All edits were performed on temporary generated files or copies of verified
upstream fixtures. No user music files were modified. See [README.md](README.md)
for reproduction steps and [../UPSTREAM.md](../UPSTREAM.md) for provenance.

## Compilation and integration

- Complete SwiftPM product builds: macOS, iOS, Mac Catalyst, tvOS and watchOS.
- watchOS device builds include arm64 and arm64_32.
- Swift consumer import smoke check passed with warnings treated as errors.
- CocoaPods packaging baseline (2.3.2): macOS lint and iOS framework/import build
  passed. The 2.3.3 source was validated with the SwiftPM platform builds above.

CocoaPods multi-platform simulator lint could not complete because the host has
no tvOS simulator runtime. The separate full SwiftPM tvOS/watchOS device-target
compilations passed. No physical iPhone, Apple TV or Apple Watch runtime tests
were performed. These checks validate the metadata library, not playback support
for every audio codec on every device.

## Remaining boundaries

This is a targeted regression suite, not an exhaustive fuzzing campaign. TagLib
still writes files in place; callers must check failure returns and should keep
backups of important originals. Cross-process writes and interrupted filesystem
writes are not transactional. Unsupported tracker writes and potentially
destructive legacy-ID3v1 saves are rejected as documented in the main README.
