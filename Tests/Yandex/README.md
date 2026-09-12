# Yandex Disk integration

Run `bash Tests/Yandex/run-regressions.sh` from the workspace. The Foundation API and production file/user models are compiled against the installed SmartCodable. URLProtocol intercepts every network request; no real credentials or cloud files are used.

Coverage: identity/serialization, account isolation, bounded artwork filenames, Unicode paths, full offset pagination and repeated-page protection, empty versus failed folders, 401/403/404/429/5xx, fresh download links, transient download headers, unexpected destinations/methods, Keychain save failures and in-flight invalidation on unlink.

## Configuration

- Uses existing `YandexLoginSDK` 3.0.2, in web-only mode, with PKCE/state. `Yandex_ClientID` is already in AppGroupConstKey; no client-secret exchange is added to the native application.
- Both application targets already register the `yx<clientID>` scheme and associated domain. The SDK callback path is `:///auth/finish?platform=ios`, not the Box callback.
- Enable `cloud_api:disk.read` and `cloud_api:disk.info` in the Yandex OAuth application's API permissions. No write, upload, delete or publish operation is implemented.
- Identity comes from `/v1/disk?fields=user`; credentials are stored per account in this app's Keychain service. SDK-global login data is cleared after each authorization. Token expiry/revocation requires signing in again; LoginSDK does not expose a refresh token.
- `/resources` lists a folder; folders are navigated using `disk:/...` paths. `resource_id` is used for stable identity when available. Cached listings do not trigger remote music-tag reads.
- `/resources/download` resolves a new temporary URL for each playback/download. The same OAuth header is applied as in the official SDK, after validating the HTTPS Yandex destination. Download redirects outside Yandex are rejected. Headers are never serialized into library/queue models.
- Metadata follows the existing `.wakePlayer` + entitlement gate. Playback and separate metadata probes obtain authorization from Keychain. Existing artwork storage and identity-based cache lookup are reused.
- New text is localized in English, Simplified Chinese, Traditional Chinese, Hong Kong Chinese and Russian; other languages use the English source fallback.

## Manual acceptance

1. Import / Connect → Yandex Disk; cancel once, then reopen and authorize. Confirm only intended permissions in consent.
2. Browse a root folder with files, an empty folder, nested folders, >200 entries, Cyrillic/Chinese and `% + #` in names. Search, sort, refresh and toggle grouping.
3. Play MP3 and FLAC, seek, pause/resume, change tracks quickly, and relaunch. Download single/multiple tracks into a selected local folder; preserve an existing same-name file.
4. With the full-format engine and entitlement, play a known embedded-artwork/lyrics fixture. Scroll away/back and reopen the list to verify cached artwork. With the system engine, no remote tag extraction should run.
5. Revoke consent externally; list/download must show authorization/permission feedback. Reconnect the same account; reject a different account when reconnecting. Unlink removes account credentials and clears its active playback references.
6. Verify on a physical iPhone and Mac Catalyst, including background playback and real-world network/transfer quotas, before release.

## Primary references (checked 2026-09-12)

- [Disk API quick start and scopes](https://yandex.com/dev/disk-api/doc/en/concepts/quickstart)
- [Official Java REST SDK, including authorized download requests](https://github.com/yandex-disk/yandex-disk-restapi-java/blob/master/disk-restapi-sdk/src/main/java/com/yandex/disk/rest/RestClient.java)
- [Yandex Login SDK for iOS](https://yandex.com/dev/id/doc/ru/mobileauthsdk/ios/sdk-ios-main)
- [Current free space: 5 GB](https://yandex.com/support/yandex-360/customers/disk/web/en/enlarge/disk-space)

The selection tag states free capacity only. It does not promise unlimited bandwidth or speed.

## Validation status (2026-09-12)

- Mobie and Mobie_Pro Debug iOS Simulator builds passed; 48 mocked API/model assertions passed.
- The simulator opens the real Yandex ID login page, and OAuth successfully returns to the app. The subsequent Disk information request returned HTTP 403. Waiting for confirmation of the OAuth application's Disk read/info permissions and account Disk activation; real file listing/playback/download are not yet verified.
- Mac Catalyst compilation was attempted and is blocked by existing `IQKeyboardReturnManager` source referring to `UIInputSuggestion` and `UITextFormattingViewController`, which are unavailable on Catalyst. That unrelated dependency has not been changed.
