# Inline player queue

Run `bash Tests/PlayerQueue/run-regressions.sh`. The executable uses production generic queue operations with no playback, credentials, or network access.

Run `ruby Tests/PlayerQueue/check-folder-entry.rb` for the production queue setters and start-selection path. It checks folder exclusion (including empty/all-folder inputs), deduplication, preservation of the selected identity after filtering, and rejection before interrupting current playback. An optional simulator Documents path verifies the existing MMM/nonempty and PPP/empty fixtures read-only. Model boundaries are doubled; the queue and selection implementations are extracted from the app.

Coverage: stable identity deduplication, appending a duplicate to an unchanged list (the old `didSet` bug), empty/single-track queues, distinct IDs with identical titles, current-track exclusion, wrapped order, all forward/backward moves, invalid moves, 10,000-track input, and rejecting stale drag snapshots after a song/order/membership change.

The player publishes `queueItems` only after normalization via the `musicArray` setter. Original-order restoration is normalized too. Metadata-only updates are still published; they must not be suppressed by identity-only equality. Both legacy playlist surfaces subscribe to the normalized publisher and resolve taps by song ID rather than a potentially stale row index. Their delayed reload/scroll tasks were removed.

The new `PlayerQueueCollectCell` replaces the visible artwork/lyric page while the queue is open. The existing player background and transport remain in place, including when entering from tape/vinyl styles. The queue button or tapping the current artwork returns to the previous page (also available when the phone's landscape transport hides the queue button). The header deliberately has no favorite, more, or close button. Landscape uses the queue alongside lyrics; Mac layout no longer reloads the entire collection on every layout pass.

PanModal short/long forms explicitly use maximum height: never infer player height from queue content. The queue is not registered as PanModal's scroll view, so it owns scrolling and reordering without content-offset pinning. Modal pans originating at or below the queue are rejected; header-originated pans can still dismiss. Test both directions at the list boundary, a short aborted header drag, full header dismissal, and switching between queue and lyrics. Empty/single-song queues must remain full-height too.

Reordering is deliberately limited to sequential mode. Only a single same-view, in-app drag is accepted. The current track is excluded and cannot be moved. A successful move updates the live queue and the original-order snapshot without restarting playback, and invalidates the pending next-track selection. A changed current song, order, or membership rejects the drop. Random and single-repeat modes do not expose drag handles or accept drops.

2026-09-16 verification:

- 92 algorithm assertions passed.
- Ordinary iOS Simulator, Pro iOS Simulator, and Mac Catalyst builds passed during development.
- Simulator verified: entering the embedded page from the tape player, covers/titles, localized modes, current song separated from the queue, and retained playback/progress controls.
- Queue polish: iOS Simulator build and all 92 algorithm assertions passed; visually verified the simplified header, larger top spacing, regular-weight mode symbols, and white transport icons. Native accessibility scrolling reaches both ends of the queue while header and transport stay fixed. Physical-device continuous touch/pan arbitration still needs acceptance; accessibility scrolling alone does not prove it.
- Interactive drag, rapid mode switching, iPad/RTL, orientation changes, and physical-device PanModal/drag gesture interaction still need manual acceptance. UI automation stopped when the user began interacting with the simulator; no successful drag gesture is claimed.

Manual checklist: queue on/off from cover and lyric pages; tap a queued song; reorder forward/backward then press Next; switch shuffle → sequential and verify manual order remains; change tracks during a drag and confirm the stale move is rejected; empty the queue; scroll rapidly through repeated titles with different IDs; verify remote cached artwork; test iPhone portrait/landscape, iPad and Catalyst. This change does not persist a separate user-authored queue across app relaunches.

## Unified shuffle

The old random-policy setting and both retired localization keys are removed. Entering shuffle or starting a new playlist pins the selected track first and shuffles the rest. Next walks this round once; when exhausted, it prepares a fresh full round whose first track differs from the previous last track (except a one-track queue). Manual selection/Previous remain explicit user overrides. Switching out of shuffle restores the original playlist order.

Pre-download, Next and the boundary queue preview use the same next-ID planner. A prepared round stores IDs, not stale cloud URL/model copies; repeated previews do not reshuffle or consume entries. Queue/order/current-ID changes invalidate it. Empty queues do nothing, and single-repeat end-of-song handling stays unchanged.

Shuffle regression coverage brings the total to 7,297 assertions: 0/1/2/5/100-song rounds, identity deduplication, first-current placement, no boundary repeat, eligibility of every song again in every round, missing current ID, 100 consecutive five-track rounds with repeated pre-download previews, and unchanged sequential wrap behavior.
