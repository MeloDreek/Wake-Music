# Offline home layout probe

Run `bash Tests/MusicServer/run-home-layout-probe.sh` with an iOS simulator already booted.
Optionally set `MUSIC_SERVER_SIMULATOR_UDID` to select it. The probe does not launch,
reinstall, navigate, or make network requests from Wakemusic.

It compiles the actual `MusicServerCells.swift` and `UIFontNumber` into a standalone
UIKit renderer. Only the server model, localization lookup, and image-loading
dependencies are stubbed. PNG snapshots are written to a newly created directory
under `/private/tmp/wake-server-home-layout.*`.

Assertions cover:

- Numeric overview values, and absence of overview image views.
- Inline section navigation arrow; image-only playlist action with its accessible
  label and at least a 44 × 44 pt hit target.
- Empty-state height of at least 168 pt.
- The next song column peeking into the viewport on phone and iPad widths.
- The first song remaining visible in the initial Arabic RTL column.
- Horizontal scrolling being allowed to cancel a song row's touch tracking.
- A song touch-up event not starting playback, with a dedicated tap recognizer and
  explicit VoiceOver activation still available.
- Increased carousel height for the largest accessibility content-size category.

The offscreen content-size override validates geometry but does not reproduce every
application-level Dynamic Type font notification. Test actual enlarged text,
VoiceOver, horizontal dragging, and vertical scrolling in the running app as well.
The renderer uses English fixture strings and placeholder artwork, not live accounts.
