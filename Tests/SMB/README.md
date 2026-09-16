# SMB integration checks

Run `bash Tests/SMB/run-regressions.sh` from the workspace. The suite compiles the production connection parser, stable identity models and loopback transport. It uses generated in-memory audio bytes, never real credentials or server mutations.

Verified on 2026-09-11: 40 SMB regression checks passed; ordinary and Pro simulator builds succeeded. The dynamically linked AMSMB2 framework is present in the application bundle. The Mac's TCP 445 endpoint is reachable. Real-account listing/playback/download verification remains pending user password entry.

2026-09-16: 53 deterministic checks passed, including legacy JSON decoding, endpoint edits preserving Keychain/file identities, and persistence of the new stable connection ID. Ordinary iOS Simulator, Pro iOS Simulator, and ordinary Mac Catalyst builds succeeded. IQKeyboardManager is now excluded from Mac Catalyst by the project's separate platform-configuration fix.

## Nearby-device discovery and changing IP addresses

- Opening the SMB login page starts an `NWBrowser` for `_smb._tcp` in `local.`. Both app plists declare that Bonjour service. The OS presents the local-network prompt on first access; it will not repeatedly prompt after a saved decision. Verify the actual allow/deny prompt on a physical device, not the simulator.
- The discovery list includes resolved Bonjour-advertised SMB devices, deduplicated across interfaces. It does not scan IP ranges, enumerate private shares, or authenticate. Some Windows PCs/NAS devices do not advertise Bonjour and must be entered manually.
- Selecting a device fills its hostname and advertised port. An untouched default display name is replaced by the device name; custom names, share, username, domain, and password are retained. Selection never connects automatically.
- Persist the hostname (for example `my-mac.local`), not its currently resolved DHCP address. The server must stay awake, keep that hostname, and remain reachable on a network supporting name resolution. Otherwise use a known hostname or a router DHCP reservation.
- Existing connections may edit host/port without changing share/account identity. After a successful password-verified connection, the original identity is retained for Keychain, favorites and artwork. Old playlist/file models resolve the latest saved endpoint by that identity. No automatic IP-to-device migration is attempted.
- Discovery stops on leaving/backgrounding the page and restarts on return. Empty results, policy denial and other browser errors have distinct states and a retry/settings action. New discovery UI strings cover all 42 project locales.

The production discovery code was tested against the local Mac's SMB advertisement (hostname/port, deduplication, stop/restart). The simulator UI was also verified to find the device and fill the form without submitting a login.

Optional real-LAN smoke test (uses no credentials, pass a server you control):

```sh
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  Mobie/Mobie/Base/Core/Extension/SMBDiscovery.swift Tests/SMB/DiscoverySmoke.swift \
  -o /private/tmp/wakemusic-smb-discovery-smoke
/private/tmp/wakemusic-smb-discovery-smoke my-mac.local
```

Additional physical-device acceptance: enter the page with permission undecided, allow/deny, return from Settings, try an empty network, leave/reopen while resolving, select a device while another field has focus, update an existing IP-based connection to its hostname, and verify favorites/playback after the server gets a new DHCP address. The actual DHCP change and permission denial have not been simulated on the user's network.

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
- Discovery strings are localized in all 42 supported locales.
- License text and pinned upstream source links are bundled in `Reasource.bundle/SMB-Open-Source-Notices.txt`. Review distribution obligations before release.

Existing unrelated regression mismatch: `Tests/Box/BoxRegression.swift` expects `root_readonly`, but the pre-existing Box implementation requests `root_readwrite`. This SMB change does not alter either Box file.
