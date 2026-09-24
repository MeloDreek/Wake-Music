# Changelog

## 2.3.3 — 2026-09-24

- Recover FLAC artwork from legacy ID3v2 and Vorbis-comment pictures when appropriate.
- Read described USLT frames, common lyric aliases, MP4 freeform lyrics and explicit RIFF ILYR fields; only treat legacy comments as lyrics when they contain timed LRC.
- Skip empty lyric placeholders and incomplete artwork rather than hiding later usable entries.
- Preserve bracketed lyric section labels and handle UTF-8 BOM-prefixed LRC.
- Create native artwork tags in files containing only legacy tags, and retain other artwork containers.
- Read additional ImageIO-recognized picture formats and filename-less APE artwork; retain portable JPEG/PNG/GIF/BMP write support.
- Reject FLAC metadata blocks that exceed the container's 24-bit size limit before saving.
- Expand regression coverage and publish format/tag capability tables with explicit verification boundaries.

## 2.3.2 — 2026-09-24

Initial **WaketagLibKit** release.

- Upgrade upstream TagLib 2.0.2 to official 2.3.2 and its bundled UTF8-CPP headers; retain upstream licenses and archive provenance.
- Add Swift Package Manager and CocoaPods support for iOS, macOS, Mac Catalyst, tvOS and watchOS.
- Keep existing parser/model Objective-C APIs; consumers change their module import to `WaketagLibKit`.
- Read metadata, artwork and lyrics using one file handle instead of reopening the file for each field.
- Add original artwork Data read/write APIs, image-size-limited extraction, orientation-aware PNG image writing and front-cover preference.
- Preserve secondary artwork, native metadata containers and unrelated lyrics language variants during edits.
- Fix missing lyrics on untagged files; remove destructive ID3v1-comment fallback and ineffective WAV INFO lyric writes.
- Fix malformed LRC crashes, repeated timestamp handling and ID3 SYLT event/unit handling; bound lyric expansion.
- Validate local regular files, reject invalid numeric inputs, serialize same-path operations and check persistence failures.
- Explicitly reject unsupported or legacy data-loss-prone writes; see README for limitations.
- Add generated-fixture ASan/UBSan regression tests, decoded-audio preservation checks, optional verified upstream corpus, and a repeatable five-platform compilation script.
