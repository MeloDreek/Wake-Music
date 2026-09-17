# Playback state / stale callback regressions

Run `ruby Tests/PlaybackState/run-regressions.rb` from the repository root.

With an iOS simulator booted, also run
`bash Tests/PlaybackState/run-button-highlight-regressions.sh [simulator-UDID]`.
This checks the production button configurations and performs 1,200 actual UIKit
image-state assertions. A custom UIButton with only normal/selected images falls
back to its normal image in the selected+highlighted state, creating a visible
pause → play → pause flash before the playback command even runs.

The runner extracts the actual app transition methods from `KakaMusicPlayer+Play.swift`
and compiles them against a deterministic fake engine. It checks pause/stop state,
retiring paused engines, rejecting obsolete provider requests (including the same
song after resume), delayed seek completion, overlapping seeks, paused seeking,
rapid toggles, and clearing pending seeks when switching songs. Static checks also
cover the legacy providers' request gates and state-driven transport buttons.
Paused scrubbing additionally checks that the requested timestamp is retained,
the same engine is used until seek completion, and a subsequent pause cancels
the requested resume. UI scrubbing/lyric jumps must use the atomic seek-and-resume
API instead of a separate `seek()` followed immediately by `play()`.

This does not simulate FFmpeg/AVPlayer audio output or real provider networking.
Device follow-up: pause/resume repeatedly, pause then next/previous during slow URL
resolution, seek then immediately pause/next, and return from queue/settings after
pausing through the mini player or system controls. Verify the default and cassette
buttons, mini player, and lock-screen controls agree and the old song does not resume.
