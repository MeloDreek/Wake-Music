# 123 Drive integration

Uses the official third-party mounting API, not the personal developer token flow.

## Specification

- [Authorization requirements](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/kf05anzt1r0qnudd)
- [Browser authorization](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/gr7ggimkcysm18ap)
- [Token exchange and rotation](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/gammzlhe6k4qtwd9)
- [V2 folder listing](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/zrip9b0ye81zimv4)
- [Download URL](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/fnf60phsushn8ip2)
- [User info](https://123yunpan.yuque.com/org-wiki-123yunpan-muaork/cr6ced/zgf9gyh7gvmdl4a3)

The public chapters also expose `/markdown?attachment=true` for reading the specification without browser login.

## Configuration and boundaries

- Normal app: `wakemusic-123pan://oauth/callback`; Pro: `wakemusicpro-123pan://oauth/callback`. Each target registers only its own 123 URL scheme.
- AppGroupConstKey selects credentials using the running app bundle ID because AppGroupKit is shared by both targets. Do not log credential values or token-request URLs. Do not copy real credentials into tests.
- ASWebAuthenticationSession performs login. The app does not collect the user's password. Exact callback scheme/host/path and random state are checked; duplicate query values are rejected.
- The vendor currently documents a fixed scope including write access. Application behavior is read-only: user info, listing and download URL calls only. There are no upload/delete endpoints.
- The documented OAuth token endpoint uses POST query parameters, including client_secret. API redirects are disabled. A native-app embedded secret is extractable; obfuscation or Keychain storage does not make it a confidential client. Confirm this architecture with the vendor before release, or move exchanges to a backend if required.
- Access/refresh tokens are kept in per-app, per-account Keychain. Single-use refresh is coalesced, replacements are saved before use, 401 retries once, and unlink invalidates pending requests.
- Root ID is 0, V2 pagination follows lastFileId until -1, detects cursor cycles and filters trashed entries. File IDs retain Int64 precision.
- Resolve fresh signed URLs for playback, download and prefetch. Never send OAuth headers to CDN hosts. Multiple vendor CDN domains are supported over HTTPS, rejecting literal IP/local destinations. Explicit downloads preserve existing same-named local files.
- Covers the existing `.wakePlayer` remote metadata path and sandbox artwork cache without scanning tags while browsing. Cache identity includes provider/account/file ID.
- Code 5113 means provider transfer quota exhausted, not a Wake Music membership issue. UI distinguishes quota, rate limit, authentication, missing/restricted files and network failures.
- Account authorization from Import uses the existing `routeImportedServer` path to Connect before opening a folder.

## Verification

Run `bash Tests/Pan123/run-regressions.sh` for production API/model URLProtocol fixtures without accounts or network. Covers callback isolation, query encoding, token exchange, cursor pagination/trash filtering, large IDs, fresh links, quota errors, concurrent refresh, failed persistence, unlink races and cache identities.

Live sign-in, multi-page folders, audio playback/seeking, embedded metadata, download/offline playback and both app identities still require manual verification. Fixture tests and builds do not prove live provider compatibility.

2026-09-16: User reported completing live testing without finding issues (individual scenarios were not enumerated). Both normal and Pro arm64 simulator Debug builds passed under Xcode 27. Follow-up profile-field support passes 55 API/model checks. Breadcrumb titles retain the folder traversal path, and saved accounts missing contacts refresh them on the next root-folder visit.
