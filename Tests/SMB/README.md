# SMB integration checks

Run `bash Tests/SMB/run-regressions.sh` from the workspace. The suite compiles the production connection parser, stable identity models and loopback transport. It uses generated in-memory audio bytes, never real credentials or server mutations.

Verified on 2026-09-11: 40 SMB regression checks passed; ordinary and Pro simulator builds succeeded. The dynamically linked AMSMB2 framework is present in the application bundle. The Mac's TCP 445 endpoint is reachable. Real-account listing/playback/download verification remains pending user password entry.

Mac Catalyst build is currently blocked in the existing IQKeyboardReturnManager dependency by unavailable UITextFormattingViewController/UIInputSuggestion APIs. That dependency was not modified for SMB.

Coverage: host/URL/UNC parsing, Chinese share names, port validation, path traversal rejection, identity isolation, full HTTP download, HEAD, byte ranges/suffix/seek, bounded 256 KiB reads, invalid ranges, rejecting write methods, and revoking local URLs on unlink.

Manual acceptance still required with an actual SMB2/3 server:

1. Connect using a dedicated read-only user. Credentials should persist across app restart, but never appear in App Group JSON or URLs.
2. Browse nested folders and Chinese filenames; empty folders and network/permission errors must be distinguished.
3. Play MP3/M4A with the system engine; use the premium full-format engine for supported lossless/other files. Seek near the end, pause/resume and switch tracks quickly.
4. With the full-format engine selected, embedded cover/lyrics should populate playback and cached covers should remain visible after scrolling. The system engine must not trigger remote tag extraction.
5. Download via the cloud button and batch selection. Check exact size/content and cancellation; files on the server must remain untouched.
6. Disconnect Wi-Fi or sleep the server, retry, relaunch the app, and remove the account.
7. Test a physical iPhone and Mac Catalyst separately, including background playback and local-network permission denial.

Implementation notes:

- Both app targets use the local Swift package at `/Users/kaka/Documents/本地公开库/AMSMB2`, checked out at tag 4.0.3 (1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0). Initialize its libsmb2 submodule when cloning. Its dynamic framework is explicitly embedded and signed in both app targets. Local package revisions are managed by that repository, not pinned by Package.resolved.
- Passwords use a bundle-scoped, device-only Keychain item. Library models contain connection identity only.
- Loopback URLs are opaque, in-memory capabilities on 127.0.0.1, not shareable SMB URLs. They are freshly resolved for playback/download. No listener is exposed on Wi-Fi.
- The adapter provides no upload/delete/rename/write methods. Server-side account permissions are configured separately.
- New SMB strings have English and Simplified/Traditional Chinese variants; other locales use English fallback.
- License text and pinned upstream source links are bundled in `Reasource.bundle/SMB-Open-Source-Notices.txt`. Review distribution obligations before release.

Existing unrelated regression mismatch: `Tests/Box/BoxRegression.swift` expects `root_readonly`, but the pre-existing Box implementation requests `root_readwrite`. This SMB change does not alter either Box file.
