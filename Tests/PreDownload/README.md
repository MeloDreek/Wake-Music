# Downloads and pre-download migration

- Run `bash Tests/PreDownload/run-regressions.sh`: 37 checks against the actual
  storage/migration helper (metadata names, source markers, collisions, migration
  idempotency, failed-move retry, hidden/HLS/empty/symlink exclusions).
- Run `bash Tests/PreDownload/run-cancellation-tests.sh`: checks the production
  cancellation/commit gate, including exception paths.

## Behavior

- App startup activates DownloadManager execution and moves legacy completed audio
  into the Music home directory. Failed moves remain in place for the next launch.
  Source markers survive moves; legacy lookup names survive collision renames.
- A serial manual queue is independent of DownloadViewController. Failures remain
  visible and are skipped until retry; new enqueue events start/resume work.
- One separate speculative pre-download is cancelled on track/queue change or
  disabling the option. Stale URL resolutions cannot start a transfer.
- Transfers write only to UUID temporary files. HTTP validation and nonempty-file
  checks precede atomic, collision-safe publication. Pre-download filenames use
  embedded title/artist when available, with the original filename as fallback.
- Manual folder selections are retained; pre-downloads always go to the home root.
- Manual completion requests local notification permission and sends notifications
  when authorized. Pre-download completion and failure are silent.
- Background execution is bounded by iOS. On expiration, unfinished manual work
  is cancelled and retried from the start when the app becomes active. This is not
  an unlimited background URLSession or byte-range resume implementation.

## Device checks still needed

Use slow/throttled real cloud connections to test rapid track changes, queue removal,
network disconnects, permission denial, and long background transfers. Synthetic
file and gate checks do not replace end-to-end tests against every cloud provider.

The existing remote-access regression currently fails because the normal product's
`isVIP()` returns `true` unconditionally in PurchargeStatus+Extension.swift. The
download refactor does not alter that existing entitlement policy.
