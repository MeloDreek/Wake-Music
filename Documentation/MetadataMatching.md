# Audio recognition and automatic metadata

## Matching order

1. Prepare bounded, mono 44.1 kHz signatures from local audio off the main thread. Try at most two distinct 12-second excerpts, skipping silent candidates.
2. Query ShazamKit with isolated per-request sessions. Cancellation does not count as recognition failure.
3. If acoustic recognition fails or the format is not decodable by AVAudioFile, search Apple's public **iTunes Search API** using the filename and actual embedded identity. This is catalog text matching, not a successful audio fingerprint, and does not access the user's Apple Music library. It sends no audio or local path.
4. Apply conservative title, full artist-credit, recording-version and duration checks. Similar-scoring conflicting performers are rejected. Uncertain release editions do not supply album/year/track/genre.
5. A unique exact-title / near-duration match with no artist evidence may offer artwork only. It does not provide identity tags or lyrics. The interactive matching screen labels catalog suggestions explicitly.
6. Lyrics must match normalized title and artist first. Timed lyrics tolerate at most three seconds of duration difference; plain lyrics tolerate eight. No match is preferable to embedding another recording's lyrics.

Apple catalog requests use URL query items, an ephemeral session, bounded timeouts/results, roughly 19 requests/minute, and a bounded ten-minute in-memory cache. No API credentials are required for this endpoint. This is not the authenticated Apple Music Catalog API.

Official reference: [iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html).

## Safe automatic embedding

- Interactive and batch operations share one writer. Reads, final checks, commits, renames and thumbnail regeneration run on a serial background queue.
- Decisions use freshly read file tags, not stale list-model metadata. A second read after artwork downloading protects edits made during the request.
- Catalog-derived results only fill missing fields, even if the user selected overwrite mode. They never rename the file or infer an instrumental lyric.
- Existing artwork bytes/decoded artwork and existing lyrics are preserved in fill-only mode. Blank proposals cannot erase data. Year and track conversion is checked for overflow.
- Automatic branding comments are no longer inserted. Existing comments are untouched.
- An explicit user-selected instrumental placeholder is allowed only when disk lyrics are absent and the result is not a catalog guess. Failure to identify a song itself is not proof that it is instrumental.
- Models and thumbnails are refreshed from persisted data. A failed cover download cannot embed the UI's placeholder image.
- Cancelling queued/in-flight batches produces exactly one internal completion per operation, drains the queue, and suppresses stale success screens and quota increments. An already-running synchronous filesystem write is allowed to return its actual persisted state.

## Tests

```sh
bash Tests/MetadataMatching/run-tests.sh
bash Tests/MetadataMatching/run-tests.sh --online
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ruby scripts/test-audio-fingerprint-core.rb
ruby Tests/MetadataEmbedding/run-regressions.rb
bash Tests/Equalizer/run-tests.sh --settings-only
```

- Catalog policy: filename orientations, numeric titles, formatting, non-Latin text, artist credits, ambiguous performers/releases, version/duration mismatches, hashed/generic names and image-host validation.
- `--online` explicitly sends the public test song name to Apple and checks a live catalog result. Availability/rate limiting are outside the app's control.
- Fingerprint core: real converter code exercised at 8–192 kHz, mono/stereo/5.1, short/silent inputs and cancellation. `--file /path/to/audio` can be repeated for read-only signature preparation; it does not submit Shazam queries.
- Embedding suite: production writer/operation source with in-memory tag I/O doubles plus a disposable rename fixture. This checks policy and lifecycle; it is not a substitute for the library's binary-format tests.
- Eight local Mac MP3/FLAC samples, including a 96 kHz FLAC, produced two 12-second signatures each. Their SHA-256 hashes remained unchanged. This verifies signature preparation, not that every song is in Shazam's catalog.
- A disposable FLAC copy was also exercised against the actual WaketagLibKit 2.3.3 / TagLib 2.3.2 binary writer: 32 assertions verified persisted basic tags, PNG artwork, LRC lyrics, comment preservation and catalog fill-only behavior. Decoded PCM and the original source file remained byte-for-byte unchanged.
- The normal app built successfully for ARM64 Mac Catalyst and ARM64 iOS Simulator. Catalyst UI verification covered the iOS-style EQ switch/presets/preamp slider, the selected queue-mode glyph and the full-height spectrum share button. A live `Victory` fingerprint returned artwork, title, artist and album in the matching screen without embedding into the original file.
- The generic, both-architectures Catalyst build separately exposed existing Intel `libcurl.a` / `_nghttp2_*` linker failures; the ARM64 validation does not certify that Intel build.

Catalog coverage and filenames are imperfect. No filename-based policy can guarantee identity for every same-title recording; ambiguous results intentionally require manual editing.
