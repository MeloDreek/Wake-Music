# MEGA integration

## Dependency provenance

- Official MEGA SDK v10.19.0: https://github.com/meganz/sdk/releases/tag/v10.19.0
- Source archive root: `meganz-sdk-8775533`, downloaded from the official GitHub API release endpoint.
- Downloaded archive SHA-256: `ff31ee1e2c4d8a02155124ff73758bb6230f61a9fbf67fc2cc0a214a7c46ee0b`.
- Local package source is vendored at `LocalSDK/MEGASDK`; its BSD-2-Clause LICENSE is retained. Both app targets reference it using `../LocalSDK/MEGASDK` relative to `Mobie/`.
- Official binary dependency URLs and SHA-256 values are pinned in the shared SDK's `tools/wake-bootstrap-artifacts.sh`, copied from the upstream Package.swift. They include device, simulator, Mac Catalyst and macOS slices.
- Local changes: binary target paths point to ignored `.artifacts` (avoids unreliable automatic downloads); public MEGASdk.h exposes HAVE_LIBUV APIs consistently with upstream's unconditional libuv build. The unused `evt-tls` module is excluded, consistent with Apple's upstream `USE_OPENSSL=OFF` configuration (curl keeps its system TLS backend). Apple filename natural sorting uses public CoreFoundation APIs because Xcode does not ship ICU collation headers; numeric ordering has deterministic byte tie-breaking, though punctuation/locale ordering can differ from ICU. No cryptographic or network-verification code was modified.

Run `bash Tests/MEGA/bootstrap-sdk.sh` from the app repository root to download/verify dependencies in `LocalSDK/MEGASDK/.artifacts`. The wrapper and regression script accept `MEGASDK_ROOT` if it is stored elsewhere; also update Xcode's local package reference for a different layout. Set HTTPS_PROXY for this command only if your environment requires its existing proxy. `download-cryptopp.py` is an optional parallel range downloader for the largest archive; it requires the complete official SHA-256 before accepting output. Do not commit `.artifacts` or `.downloads`; two `libcryptopp.a` slices exceed GitHub's 100 MiB per-file limit.

For Waketag or another app, add this SDK directory as a local Swift package and link `MEGASdk`. The SDK's `WAKE_INTEGRATION.md` describes setup and the preserved compatibility patches. App-specific login, models and playback integration stay in Wake Music; this migration does not modify Waketag. The source and bootstrap script are versioned with this app; ignored binaries are restored by the bootstrap command.

## Behavior

- Native email/password + optional authenticator-code login. No borrowed API key. The official SDK no longer requires a developer key: https://github.com/meganz/sdk/issues/2706 .
- Session stored per app bundle/account in device-only Keychain; passwords, 2FA codes and file decryption keys are never added to AppGroupKit models. Each SDK instance gets its own disposable database directory under the app's private temporary directory. This avoids v10.19.0's `Updating status without status table` assertion with `basePath: nil` and avoids simultaneous clients sharing a live database. Cross-launch database reuse is not enabled.
- Login and session restoration first apply the current CFNetwork proxy for the MEGA API endpoint. The shared SDK's `wakeSetProxy(url:username:password:delegate:)` bridge exposes the upstream C++ proxy API; it does not embed a proxy address. Static HTTP CONNECT/SOCKS proxies and direct routes are supported. PAC/unsupported configurations fail explicitly instead of silently bypassing the proxy. No system settings or TLS/pinning code are changed.
- Playback's FFmpeg options explicitly bypass the proxy for loopback HTTP URLs only. KSPlayer's DEBUG helper otherwise exports a global `http_proxy`, which sends the local MEGA/SMB bridge to the proxy. Cloud traffic continues through the SDK's configured route.
- Browse own cloud-drive root and descendants, search the current folder, favorites, existing download queue and audio playback. No upload/delete/share-link creation API is exposed by the adapter.
- SDK's HTTP range/decryption server binds loopback only, allows explicitly requested files, disables folder and subtitle serving, and uses bounded buffers. Unlink stops that account's local server and removes its saved session.
- The Mac sandbox server entitlement is required for the loopback listener; the adapter still binds only to loopback, not the LAN. Both app targets share this entitlement file.
- Root/node handles, not filenames or temporary URLs, identify files and account-scoped artwork caches. Audio metadata extraction continues to use the existing premium wakePlayer gate; no list-time remote-tag scanning is added.
- MEGA transfer quotas are not bypassed. HTTP 509 gets the quota explanation; ordinary player range cancellation is not treated as an error.
- Provider badges show 20 GB free (MEGA's own App Store description, checked 2026-09-11: https://apps.apple.com/us/app/mega-encrypted-cloud-storage/id706857885) and a transfer-quota warning, not unlimited transfer.
- Login timeout is 90 seconds per SDK request. Very large libraries may need future paginated indexing or a longer fetchNodes flow. This first implementation does not browse incoming shares or public links.

## Verification

2026-09-12: diagnosed a direct-connection timeout while the Mac browser used its
existing proxy. After the proxy bridge and per-instance database initialization,
the authorized test account logged in and listed its real folders/audio files on
iPhone 17 Pro Max Simulator (iOS 26.5). Restarting the app restored the Keychain
session and loaded the same library without entering a password. The loopback
proxy override then allowed a remote FLAC to play for more than 90 seconds, with
its embedded title parsed; playback was paused and the account left connected.
Both simulator app targets built with the final changes; all 40 regression
assertions passed. This does not verify physical devices, 2FA, quotas, complete
downloads, seeking or background playback. No account credential is in these tests.

Shared-directory migration: all 2,035 previously tracked SDK files were verified
byte-for-byte against their Git blobs after moving. Both simulator app targets
(`Mobie` and `Mobie_Pro`) built successfully using the shared package path, and
all 23 model / sorting assertions passed. The six binary frameworks were retained.

2026-09-11: both `Mobie` and `Mobie_Pro` built successfully for the iOS simulator. The ordinary app was installed without removing its data. UI inspection was interrupted when the Mac locked, before reaching the login form. The Mac Catalyst SDK targets compiled, but the application build remains blocked by existing IQKeyboardReturnManager usages of unavailable `UIInputSuggestion` / `UITextFormattingViewController` APIs; no unrelated dependency files were changed to hide that failure.

`bash Tests/MEGA/run-regressions.sh` checks identity isolation, supported formats, credential-free synthetic URLs and empty/search/error presentation (14 assertions), Apple's filename comparator (9 assertions), and proxy selection/validation/credentials separation (17 assertions). Actual login, 2FA, quota handling, seek, background playback, downloads and metadata require a test account and device checks. Do not treat model tests or a successful build as verification of those network behaviors.

Before release: finish real-account tests on iOS and Catalyst; review all bundled upstream and transitive dependency license notices for distribution. These notes are not legal advice or release approval.
