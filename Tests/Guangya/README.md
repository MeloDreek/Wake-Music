# Guangya Drive integration

Implementation follows the vendor's privately supplied API V1.3. The original document and its sample credentials are not copied here. Credentials come from the existing AppGroupConstKey constants; do not include their values in logs, fixtures, or screenshots.

## Authorization and deployment

- Both iOS app targets register `wakemusic-guangya://oauth/callback`. Confirm this exact callback with Guangya if the test client requires a redirect allowlist.
- Uses the official web authorization page in ASWebAuthenticationSession, with PKCE S256 and `user offline` scope. The verifier stays on-device; a separate random state is checked against the callback. Unlike the document's sample, the verifier is not exposed as state. Verify compatibility in the real authorization flow.
- The app does not collect or save the Guangya password. Tokens and rotated refresh tokens stay in per-app Keychain storage. Shared library models contain account/file identity only.
- Only account info, folder listing and raw-resource download endpoints are called. No upload, deletion, sharing or video-VOD endpoints are implemented. The documented `user offline` OAuth scopes are not a granular read-only scope; the app's behavior is read-only, which is distinct from the scope's server-side capabilities.
- Replace test credentials with vendor-approved production configuration before distributing a release. Any shared signing secret embedded in a native client can be extracted; confirm the vendor approves native-client distribution or arrange a signing backend if required.

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
```

The test runner compiles the production API, model and empty-state code with the installed SmartCodable dependency. Requests use URLProtocol fixtures, never live credentials. Covers PKCE vectors, callback validation, independent MD5 fixture, JSON OAuth, headers, zero-based pagination, repeated-page rejection, business errors, HTTPS/CDN rules, stable cache keys, fresh links, concurrent token rotation, failed persistence and unlink races.

## Manual verification still required

- Complete official authorization with the configured test client; confirm callback and independent state round-trip.
- Verify an empty account, nested directories, more than 100 entries and non-ASCII filenames.
- Stream a supported MP3 and a full-format track; seek, switch tracks quickly and resume after pause.
- With `.wakePlayer`, verify embedded artwork/lyrics and cached artwork after scrolling/reopening. With the system engine, confirm remote metadata extraction does not run.
- Download to the local library, play offline and test a same-named file from another folder/account.
- Reconnect/refresh expired credentials and unlink an account during a pending request.
- Exercise Mac Catalyst UI when the existing unrelated keyboard dependency build issue is resolved.

Do not treat fixture tests or a successful build as successful live authorization or media playback.
