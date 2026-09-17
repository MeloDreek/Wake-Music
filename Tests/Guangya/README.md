# Guangya Drive integration

Implementation follows the vendor's privately supplied API V1.3. The original document and its sample credentials are not copied here. Credentials come from the existing AppGroupConstKey constants; do not include their values in logs, fixtures, or screenshots.

## Authorization and deployment

- Ordinary app: `wakemusic-guangya://oauth/callback`; Pro app: `wakemusic-pro-guangya://oauth/callback`. Each target registers only its own scheme. AppGroupConstKey selects the corresponding production client ID, signing key and callback using the host app bundle identifier. Authorization verifies that the configured scheme is registered before opening the browser.
- The owner supplied the vendor's confirmation on 2026-09-17: both production clients keep the existing project ID and use the separately submitted signing keys. Neither credentials nor the original private application documents are copied into these tests.
- Uses the official web authorization page in ASWebAuthenticationSession, with PKCE S256 and `user offline` scope. The verifier stays on-device; a separate random state is checked against the callback. Unlike the document's sample, the verifier is not exposed as state. Verify compatibility in the real authorization flow.
- The app does not collect or save the Guangya password. Tokens and rotated refresh tokens stay in per-app Keychain storage. Shared library models contain account/file identity only.
- Only account info, folder listing and raw-resource download endpoints are called. No upload, deletion, sharing or video-VOD endpoints are implemented. The documented `user offline` OAuth scopes are not a granular read-only scope; the app's behavior is read-only, which is distinct from the scope's server-side capabilities.
- Production credentials are now configured by the owner. Any shared signing secret embedded in a native client can be extracted; confirm the vendor approves native-client distribution or arrange a signing backend if required.

## Data and media behavior

- Uses the `/openapi/v1/` business routes from the document's endpoint definitions, not the inconsistent prefix in its Python examples.
- Root omits parentId; listing starts at page zero, preserves directories and fetches every page. Numeric file IDs remain strings to avoid 64-bit precision loss.
- Business errors are checked even when HTTP status is 200. Expired authorization triggers one coalesced refresh and retry. Explicit errors distinguish configuration/signature, device clock, permission, rate limit, removed files, content restrictions and vendor membership.
- Business calls are paced per endpoint below the documented per-IP limit (list: five per second; other calls: two). Other devices sharing the same IP may still cause server-side throttling.
- Streaming, queued downloads and next-track prefetch resolve a fresh signed raw-file URL. Initial links must be HTTPS on Guangya's documented CDN/domain family; download redirects are validated too. OAuth/signing headers are not sent to the CDN. New vendor CDN domains require review before expanding the allowlist.
- Cache identity incorporates account, file kind and file ID, not display name. Explicit downloads preserve existing same-named local files.
- Uses the existing remote-playback metadata gate: selected `.wakePlayer` plus the existing entitlement check. Parsed artwork is written to the sandbox and reused by the list; browsing a folder does not scan remote tags.
- New labels/errors include English, Simplified Chinese, Traditional Chinese and Hong Kong Traditional Chinese. Other app languages use the catalog's English fallback. Promotional badges use the product information supplied by the owner: 2 TB on registration, Xunlei affiliation, and a no-speed-cap badge in Chinese interfaces only.

## Automated verification

Run from the repository root:

```sh
bash Tests/Guangya/run-regressions.sh
ruby Tests/Guangya/check-production-config.rb
```

The test runner compiles the production API, model and empty-state code with the installed SmartCodable dependency. Requests use URLProtocol fixtures, never live credentials. Covers PKCE vectors, dual-app callback validation and isolation, independent MD5 fixture, JSON OAuth, headers, zero-based pagination, repeated-page rejection, business errors, HTTPS/CDN rules, stable cache keys, fresh links, persisted-token restoration in a new API instance, concurrent token rotation, failed persistence and unlink races. The configuration audit checks both actual target plists and constant selection without printing credential values.

## Production account check — 2026-09-17

- Both ordinary and Pro Debug simulator builds passed with normal Xcode signing for production configuration. The API/model suite now passes 86 checks, including membership-only UI state; the dual-app production configuration audit passes 25 checks, including callback registration and app-specific credentials without printing their values.
- The owner completed authorization successfully using the ordinary app's production configuration.
- After a CLI build installed with `CODE_SIGNING_ALLOWED=NO`, the saved account showed an authorization-expired message. That build omitted simulated Keychain entitlements. Do **not** use unsigned installs to validate OAuth persistence: Xcode's ordinary simulator build embeds `application-identifier` and `keychain-access-groups` in simulated entitlements.
- Rebuilding with normal Xcode signing, reinstalling without deleting the app or Keychain, and cold-launching restored the owner's existing token without another login. A second cold launch also restored it (`Keychain read decoded=true`, token unexpired). No token migration, deletion, insecure storage, or forced reauthorization was added.
- Actual root listing request: `GET /openapi/v1/file/get_file_list`, HTTP 200, business **code 430**. V1.3 defines this as “用户不是会员”. This is not the video-resolution VIP code 164 and is not an app-side paywall. The request did not fail with the documented signature/client-ID errors.
- This establishes a membership restriction for this account/client on file listing, not a universal claim about every Guangya integration. Ask the vendor whether ordinary users require a Guangya membership for third-party file listing/raw download, or whether the app/test account needs an entitlement/allowlist.
- Follow-up: the owner confirmed with Guangya that membership is required for third-party file access. The membership-error state now displays “View Guangya Membership Plans” below Retry, opening `https://www.guangyapan.com/#/vip-center` in SFSafariViewController. Empty folders, search misses and unrelated errors never show this button. The title is localized in all 42 app locales. This only opens the official page; it does not purchase membership or change the app's entitlements.
- Real nested-folder browsing, playback and download remain blocked by that service-side restriction. No attempt was made to bypass it or purchase membership.
- Debug diagnostics emit only Keychain status/decoding outcome, refresh-needed booleans, endpoint names, HTTP statuses and sanitized protocol codes. They never print OAuth URLs, response bodies, authorization codes, tokens, signing keys, user IDs or arbitrary error descriptions.

## Manual verification still required

- Verify Pro authorization with its production client and independent callback. Ordinary authorization was reported successful by the owner; cold-start credential restoration was verified above.
- Verify an empty account, nested directories, more than 100 entries and non-ASCII filenames.
- Stream a supported MP3 and a full-format track; seek, switch tracks quickly and resume after pause.
- With `.wakePlayer`, verify embedded artwork/lyrics and cached artwork after scrolling/reopening. With the system engine, confirm remote metadata extraction does not run.
- Download to the local library, play offline and test a same-named file from another folder/account.
- Reconnect/refresh expired credentials and unlink an account during a pending request.
- Exercise Mac Catalyst authorization, Keychain persistence and media UI using a normally signed build.

Do not treat fixture tests or a successful build as successful live authorization or media playback.
