# Playback artwork regressions

Build/run the Foundation-only reader tests on macOS:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --sdk macosx swiftc \
  -swift-version 5 -parse-as-library -module-cache-path /private/tmp/wake-artwork-modules \
  Mobie/Mobie/Base/Core/Extension/EmbeddedArtworkReader.swift \
  Tests/Artwork/ArtworkRegression.swift -o /private/tmp/wake-artwork-regression
/private/tmp/wake-artwork-regression
```

Optional arguments are paths to local test audio containing embedded JPEG/PNG artwork.
Fixtures are read only; account IDs, credentials and user media are not stored in this test directory.

Coverage:
- ID3 v2.3/v2.4, JPEG/PNG, empty MIME, UTF-16 descriptions, truncated headers/frames,
  encrypted/compressed frames, linked pictures, malformed synchsafe sizes.
- WAV chunk seeking skips a synthetic 1 GB audio payload with less than 200 bytes read.
- Real URLSession path via URLProtocol: valid ranges, ignored/wrong ranges, oversized
  fixed/chunked bodies, permission errors. No live network/account required.
- Optional real fixtures: JPEG/PNG extraction and ImageIO pixel decoding.

Verified on 2026-09-11: 51 synthetic/network assertions; with the two local WAV
fixtures, 57 assertions pass and both covers decode to 600×600.
Mobie and Mobie_Pro iOS Simulator builds passed. Both real WAV covers were displayed
in the simulator and persisted under Documents/.Music_Cover using their Box identities.
After reinstalling the normally signed build and reopening Box/POP, both file-list rows
displayed the persisted covers. Box authorization remained usable with normal signing.

Manual checks:
1. Select `.wakePlayer` with the existing premium entitlement, play an uncached cloud
   track with an embedded cover and confirm its `.Music_Cover` JPG appears.
2. Reopen/scroll the cloud file list: it must read the cached image without downloading
   music or parsing remote tags. Existing cached artwork remains visible in all engines.
3. Select `.avPlayer` or automatic selection and play a different, uncached track:
   no new playback metadata/artwork extraction should start, even after a decoder fallback.
4. Switch tracks while metadata is loading: a late result must not overwrite the new
   track's metadata, artwork, or Now Playing information.
5. Switch away from `.wakePlayer` during extraction: results must not be applied.

The MIME-tolerant range reader covers ID3 in MP3/WAV/AIFF/DSF. Standard artwork in other
formats continues through KSPlayer/FFmpeg; complete local caches also use TagLib.
Range-incompatible servers fail this bounded fallback safely. The source audio is never
rewritten. Cover writes from the tag editor now include `mimeType=image/jpeg` and
`pictureType=Front Cover` so newly edited files are compatible with FFmpeg.

## Local list/cache regressions (2026-09-19)

```sh
# Pure cache identity tests plus the real UIKit writer on a booted simulator:
ruby Tests/Artwork/run-cache-regression.rb
# Optional read-only reproduction with the user's FLAC (fixture is not committed):
ruby Tests/Artwork/run-cache-regression.rb --audio '/absolute/path/to/song.flac'

# Actual MusicTableViewCell loader with real Kingfisher/UIKit; uses the app's
# previously built Debug-iphonesimulator/Kingfisher.o, without rebuilding it:
ruby Tests/Artwork/run-list-image-regressions.rb

# Actual scan/parse operation with small filesystem/TagLib doubles, native macOS:
ruby Tests/Artwork/check-library-artwork-scan.rb
```

Latest verification: cache **37** assertions; UIKit writer with the actual embedded
cover **17**; list loader **54**; scan/import **35**, including 1,000 queued files
with a peak of two concurrent jobs. These are targeted probes, not an end-to-end
benchmark of 1,000 real audio files.

The reported FLAC contains a valid 800×800 PNG. Its artist metadata includes `/`;
using artist/title as a filesystem path caused the old thumbnail write to fail.
This differs from the simulator's Metal shared-linear-texture limitation.
The test reads PICTURE bytes only, writes its decoded copy in a unique temporary
directory, and verifies the original audio SHA-256 is unchanged. No user-media
fixture is stored in the repository.

Cache coverage includes metadata-independent source keys, same-name files in
different folders, sandbox UUID changes, Unicode/percent paths, source-file
existence changes, safe legacy migration, and live revision invalidation.
The writer checks a 1200 px cap, main-thread callback/notification, invalid inputs,
and no source mutation. See [cache-regression.md](cache-regression.md).

The list probe verifies real async disk decoding/downsampling to 132 px at 3×,
PNG data in a `.jpg` file, aspect ratio, late completions after reuse, placeholder
reset, revision refresh, memory-only derived images, and a 24 MB / 200-entry RAM
cache limit. The scan probe covers source changes, zero-byte cache recovery,
skipping artwork decoding on cache hits, copy/move writing only after final URL
selection, cancellation, missing-cover tolerance, and bounded concurrency.
