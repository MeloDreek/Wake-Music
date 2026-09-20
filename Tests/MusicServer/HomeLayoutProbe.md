# Offline home layout probe

Run `bash Tests/MusicServer/run-home-layout-probe.sh` with an iOS simulator already booted.
Optionally set `MUSIC_SERVER_SIMULATOR_UDID` to select it. The probe does not launch,
reinstall, navigate, or make network requests from Wakemusic.

It compiles the actual `MusicServerCells.swift` and `UIFontNumber` into a standalone
UIKit renderer. The server model, localization lookup, image-loading dependencies,
playback state and action names are stubbed. The custom artwork grid and menu UIKit
components are the real production implementation.
PNG snapshots are written to a newly created directory
under `/private/tmp/wake-server-home-layout.*`.

Assertions cover:

- Numeric overview values, and absence of overview image views.
- Inline section navigation arrow; image-only playlist action with its accessible
  label and at least a 44 × 44 pt hit target.
- Empty-state height of at least 168 pt.
- Exactly one full-width page at rest: no next-page preview on phone or iPad.
- Two artwork-card rows, with two phone columns and width-adaptive iPad columns.
- The first song remaining visible in the initial Arabic RTL page.
- Whole-page snapping, page dots, and preserving the relevant song page on resize.
- Horizontal scrolling being allowed to cancel a song row's touch tracking.
- A real custom artwork grid (no nested UITableViews), pan-dependent song taps,
  explicit accessible/keyboard activation, and all five server song menu actions.
  Native collection selection callbacks cannot start playback after a cancelled drag.
- Playback refresh updating visible song cells without reloading/moving the shelf.
- A grid tall enough for both artwork/text rows at all tested text sizes.

The offscreen content-size override validates geometry but does not reproduce every
application-level Dynamic Type font notification. Test the actual menu action
handlers, artwork loading, VoiceOver, horizontal dragging, and vertical
scrolling in the running app as well.
The renderer uses English fixture strings and placeholder artwork, not live accounts.
