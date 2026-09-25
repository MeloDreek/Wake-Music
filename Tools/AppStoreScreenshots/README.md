# Screenshot-only batch header renderer

`render-batch-header.sh` compiles the complete production `MusicTopBatchEditHeadView`, `MatchingProgressView`, `RTLProgressView`, and `LoadingButton`, along with the repository's SnapKit source. Only umbrella imports change in temporary copies. The support file provides the default label-color accent, identical font/geometry helpers, catalog translations, and a URL-only model fixture.

The renderer outputs a transparent 400 × 180 point header at 3× scale (1200 × 540 pixels). It uses the actual matching state with **simulated 4/9 progress** and the filename `Lady Gaga & Bruno Mars - Die With A Smile.flac`. It does not read audio, run tag processing, launch the app, interact with UI, access accounts, or change saved app preferences.

Run against an already booted simulator:

```sh
BATCH_HEADER_SIMULATOR_UDID=29D9612A-A7C3-47F8-9FC6-B74A3C50EBEF \
  bash Tools/AppStoreScreenshots/render-batch-header.sh
```

Optional environment settings: `DEVELOPER_DIR`, `BATCH_HEADER_WIDTH` (points), `BATCH_HEADER_SCALE`, `BATCH_HEADER_APPEARANCE` (`light` or `dark`), and `BATCH_HEADER_BUILD_ONLY=1`. The first script argument overrides the PNG output path. The script prints its temporary build directory's source checksum manifest for provenance.

The PNG is a render of real production UIKit views, not a complete app screenshot. For the batch promotion screenshot, compose this authorized simulated header with a real capture of the app's existing music list. The table cells are best retained from that capture because the production cell class pulls in player, artwork cache, download, and cloud services; a standalone mock of those services would add unrelated behavior and could alter the resulting list.

# Native local HTML export

`bash Tools/AppStoreScreenshots/render-design.sh [design.html] [output-directory] [preview.png]` compiles the AppKit/WebKit renderer and exports `shot-01` through `shot-06` as 1242 × 2688 opaque RGB PNGs. Defaults are the project artifact's `design.html`, `final/`, and `preview.png`. `DESIGN_RENDER_BUILD_ONLY=1` prints the compiled renderer's path without running it.

The renderer reads local resources only within the HTML's directory, blocks remote requests, waits for fonts and images, and uses a fully transparent off-screen window. It controls no existing browser or app window. Export-only CSS isolates one design section at a time and disables animations. A native bitmap context normalizes output dimensions and RGB opacity; a 1370 × 1888 contact sheet shows all six exports.
