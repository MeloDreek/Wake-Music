# MEGA integration

## Dependency provenance

- Official MEGA SDK v10.19.0: https://github.com/meganz/sdk/releases/tag/v10.19.0
- Source archive root: `meganz-sdk-8775533`, downloaded from the official GitHub API release endpoint.
- Downloaded archive SHA-256: `ff31ee1e2c4d8a02155124ff73758bb6230f61a9fbf67fc2cc0a214a7c46ee0b`.
- Vendored at `LocalSDK/MEGASDK`; its BSD-2-Clause LICENSE is retained.
- Official binary dependency URLs and SHA-256 values are pinned in `bootstrap-sdk.sh`, copied from the upstream Package.swift. They include device, simulator, Mac Catalyst and macOS slices.
- Local changes: binary target paths point to ignored `.artifacts` (avoids unreliable automatic downloads); public MEGASdk.h exposes HAVE_LIBUV APIs consistently with upstream's unconditional libuv build. The unused `evt-tls` module is excluded, consistent with Apple's upstream `USE_OPENSSL=OFF` configuration (curl keeps its system TLS backend). Apple filename natural sorting uses public CoreFoundation APIs because Xcode does not ship ICU collation headers; numeric ordering has deterministic byte tie-breaking, though punctuation/locale ordering can differ from ICU. No cryptographic or network-verification code was modified.

Run `bash Tests/MEGA/bootstrap-sdk.sh` to download/verify dependencies on another checkout. Set HTTPS_PROXY for this command only if your environment requires its existing proxy. `download-cryptopp.py` is an optional parallel range downloader for the largest archive; it requires the complete official SHA-256 before accepting output. Do not commit `.artifacts` or `.downloads`.

## Behavior

- Native email/password + optional authenticator-code login. No borrowed API key. The official SDK no longer requires a developer key: https://github.com/meganz/sdk/issues/2706 .
- Session stored per app bundle/account in device-only Keychain; passwords, 2FA codes and file decryption keys are never added to AppGroupKit models. SDK persistent database caching is disabled for this first implementation.
- Browse own cloud-drive root and descendants, search the current folder, favorites, existing download queue and audio playback. No upload/delete/share-link creation API is exposed by the adapter.
- SDK's HTTP range/decryption server binds loopback only, allows explicitly requested files, disables folder and subtitle serving, and uses bounded buffers. Unlink stops that account's local server and removes its saved session.
- The Mac sandbox server entitlement is required for the loopback listener; the adapter still binds only to loopback, not the LAN. Both app targets share this entitlement file.
- Root/node handles, not filenames or temporary URLs, identify files and account-scoped artwork caches. Audio metadata extraction continues to use the existing premium wakePlayer gate; no list-time remote-tag scanning is added.
- MEGA transfer quotas are not bypassed. HTTP 509 gets the quota explanation; ordinary player range cancellation is not treated as an error.
- Provider badges show 20 GB free (MEGA's own App Store description, checked 2026-09-11: https://apps.apple.com/us/app/mega-encrypted-cloud-storage/id706857885) and a transfer-quota warning, not unlimited transfer.
- Login timeout is 90 seconds per SDK request. Very large libraries may need future paginated indexing or a longer fetchNodes flow. This first implementation does not browse incoming shares or public links.

## Verification

2026-09-11: both `Mobie` and `Mobie_Pro` built successfully for the iOS simulator. The ordinary app was installed without removing its data. UI inspection was interrupted when the Mac locked, before reaching the login form. The Mac Catalyst SDK targets compiled, but the application build remains blocked by existing IQKeyboardReturnManager usages of unavailable `UIInputSuggestion` / `UITextFormattingViewController` APIs; no unrelated dependency files were changed to hide that failure.

`bash Tests/MEGA/run-regressions.sh` checks identity isolation, supported formats, credential-free synthetic URLs and empty/search/error presentation (14 assertions), plus Apple's filename comparator (9 assertions). Actual login, 2FA, quota handling, seek, background playback, downloads and metadata require a test account and device checks. Do not treat model tests or a successful build as verification of those network behaviors.

Before release: finish real-account tests on iOS and Catalyst; review all bundled upstream and transitive dependency license notices for distribution. These notes are not legal advice or release approval.
