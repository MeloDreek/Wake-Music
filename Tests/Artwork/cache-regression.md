# Artwork disk-cache regressions

From the repository root:

```sh
ruby Tests/Artwork/run-cache-regression.rb
```

This extracts the actual `MusicArtworkCache`, the three artwork cache methods on
`MusicItemModel`, and `writeMusicthumbnailImage` from production source. It does not
require building Wakemusic. A small model stub supplies only the dependencies;
the cache identity, migration, revision, rendering, and writing code are not copied
or reimplemented in the tests.

- The Foundation probe runs natively on macOS. `--no-simulator` runs only this part.
- The UIKit writer probe runs on an already booted arm64 iOS Simulator, without
  installing or opening an app. `ARTWORK_SIMULATOR_UDID` can select a simulator.
- Compiled probes and generated fixture files remain in a uniquely created
  `/private/tmp/wake-artwork-cache-*` directory for inspection.
- Tests never write to the app's container, modify audio, or access a network.

Optional real-media validation:

```sh
ruby Tests/Artwork/run-cache-regression.rb --audio '/absolute/path/to/song.flac'
# Or use artwork previously extracted with TagLib:
ruby Tests/Artwork/run-cache-regression.rb --artwork '/private/tmp/extracted-cover.png'
```

`--audio` reads the embedded FLAC PICTURE bytes into the temporary test directory.
It checks the original audio's SHA-256 before and after the whole test. This is a
writer/cache test, not an independent test of TagLib extraction or media playback.
`--artwork` is intended for a real cover below 1200 px; the optional fixture check
confirms its dimensions remain unchanged.

Coverage:

- Editable Chinese, slash-containing, empty, multilingual, and extremely long
  tags never enter the cache filename.
- Fixed-length digest names, directory confinement, same-name files in different
  folders, sandbox UUID relocation, canonical Unicode, literal `%` characters,
  and paths containing `..`.
- Stable identity before and after creating the source file, including the macOS
  `/private/tmp` alias case that exposed existence-dependent normalization.
- Local/remote namespaces and use of the upstream remote account identity.
  The stub does not retest how `preDownloadIdentity()` constructs that identity.
- New cache lookup, rejection of ambiguous old local/cloud names, provider-scoped
  legacy lookup, and unsafe slash/NUL/overlong legacy names.
- Revision changes after atomic replacement or same-size timestamp changes,
  including reuse of the same URL value (no stale resource-value cache).
- Actual UIKit render-to-JPEG: 2400×1600 → 1200×800, no upscaling of a 128×128 image,
  safe overwrite, slash/long tags, rejection of nil images and folders, and source
  audio left untouched.
- Success callbacks and cache-change notifications on the main thread; notifications
  identify the same source key used by the reader.
- Optional real 800×800 PNG → JPEG through the actual production writer.

Verified on 2026-09-19 with the reported FLAC: 37 Foundation assertions and
17 simulator/UIKit assertions passed; the source audio SHA-256 was unchanged.
