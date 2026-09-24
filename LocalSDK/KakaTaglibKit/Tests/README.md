# WaketagLibKit standalone regression tests

Run on macOS with Xcode and ffmpeg installed:

```sh
bash scripts/run-regression-tests.sh
```

The runner builds every vendored TagLib C++ source plus the Objective-C++ wrapper
with AddressSanitizer and UndefinedBehaviorSanitizer. It uses explicit recursive
header search paths and does not depend on CocoaPods, SwiftPM, or CMake.
`DEVELOPER_DIR`, `FFMPEG`, and `JOBS` may be overridden; `SANITIZE=0` disables
sanitizers for a normal build. LeakSanitizer is not enabled because macOS does not
support it.

The fixture generator synthesizes a short sine wave in MP3, FLAC, M4A, WAV, AIFF,
Ogg Vorbis, Opus, WavPack, TTA, and ASF. Missing ffmpeg encoders are explicitly
reported as skips. A native Vorbis encoder is used if libvorbis is unavailable.
All input audio, mutated copies, binaries, and object files are placed in a fresh
temporary directory, whose path the runner prints and retains for inspection.
The harness refuses to operate outside a directory named `fixtures.*` containing
only its `synthetic.*` audio inputs (or the explicit optional corpus manifest).
No existing music library is read or changed.

Coverage includes:

- Unicode basic metadata writes followed by independent file reopen/read checks.
- Initially absent title/artist tags and negative track/year rejection.
- Exact JPEG and PNG cover-byte round trips, image decoding, and the image API.
- Front-cover selection and preservation of back covers in formats with typed
  pictures (MP3, FLAC, WAV, AIFF, Ogg Vorbis, Opus, TTA, WavPack, ASF).
- Native FLAC lyrics/art when an unrelated legacy ID3v2 tag also exists.
- Existing FLAC pictures in legacy ID3v2, Xiph METADATA_BLOCK_PICTURE and COVERART
  fields remain readable; writing a native picture retains the alternate source.
- Described USLT, standard and aliased TXXX/APEv2/Xiph lyrics, MP4 freeform lyrics,
  RIFF ILYR and timed-LRC comments are readable; ordinary comments are not lyrics.
- Blank/malformed first lyric candidates and unreadable front pictures do not
  mask later usable entries. BOM-prefixed LRC and lyric section labels survive.
- TIFF APIC and filename-less GIF/BMP/TIFF APE pictures can be read; front-picture
  replacement preserves raw APE back-picture bytes.
- Native artwork tags are created in legacy-only WV/TTA/APE/MPC files and
  DIIN-only DFF files, followed by independent reopen/read checks.
- Oversized FLAC artwork and cumulative Xiph blocks are rejected without changing
  the original file, rather than letting upstream silently drop the block.
- Secondary-only ID3v1/RIFF INFO fields surviving lyric writes in mixed-tag files.
- ID3 SYLT extraction retaining its final timed event.
- Updating primary USLT lyrics preserves other languages and descriptions.
- Mixed MPEG APIC/APE artwork preserves the secondary APE back cover and comment.
- Raw ID3v1.0 30-byte comments remain byte-for-byte unchanged during MP3 writes;
  unsafe WavPack rewrites return failure with the entire file unchanged.
- ID3v1-only WavPack, TTA, APE, and Musepack files gain native Unicode tags while
  retaining short legacy comments (APE/Musepack use the optional corpus).
- Sixty-four concurrent title writes and reads on one disposable MP3 finish
  without exceptions or corruption.
- Lyrics in each generated format, the legacy `setLyris:` API, read-mode filtering,
  multiple LRC timestamp prefixes, ordering, duplicate timestamps, stored offsets,
  and malformed bracket input.
- Large LRC inputs cannot expand beyond 20,000 timed or untimed events.
- Missing, empty, corrupt, directory, remote, and nil URLs; invalid image data and
  nil setter arguments; read-only file bytes and permissions are preserved.
- AppKit images backed by drawing handlers, rather than bitmap representations.
- Identical SHA-256 hashes of decoded PCM audio before and after all tag writes.

MP4 has no picture-type designation, so its test verifies exact cover bytes and
basic metadata preservation without treating a second MP4 cover as a back cover.
Assertions are reported individually, and any failure returns a nonzero status.

## Optional upstream corpus

To additionally exercise DSF, DSDIFF, APE, Musepack, Matroska reads, and historic
malformed-file regressions, extract the official TagLib 2.3.2 archive and point
`TAGLIB_TEST_DATA` to its `tests/data` directory:

```sh
TAGLIB_TEST_DATA=/path/to/taglib-2.3.2/tests/data \
  bash scripts/run-regression-tests.sh
```

Official source: [taglib-2.3.2.tar.gz](https://taglib.org/releases/taglib-2.3.2.tar.gz).
Archive SHA-256:
`3ca2d8afaa7f1cf7f6ed10e511ebc368bfacd6dcaa3dbfa690b89e502e8963dc`.
The preparation script also checks the SHA-256 of each selected fixture before
copying it to a fresh temporary directory. These audio files are not bundled in
this repository, and their source copies are never modified.

`empty10ms.dsf`, `empty10ms.dff`, `click.mpc`, and `mac-399.ape` receive the full
metadata/artwork/lyrics round trip. `no-tags.mka` receives read-only checks.
Decoded PCM hashes are compared whenever ffmpeg can decode the original;
unavailable decoders are explicit skips. The six malformed files (`segfault.mpc`,
`segfault2.mpc`, `infloop.mpc`, `zerodiv.mpc`, `longloop.ape`, and `zerodiv.ape`)
receive read-only crash probes with a ten-second per-file watchdog. Their bytes
must remain unchanged.
