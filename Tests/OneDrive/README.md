# OneDrive integration regression checks

OneDrive uses the system `ASWebAuthenticationSession` on both iOS and Mac
Catalyst, with Microsoft's OAuth 2.0 authorization-code flow and S256 PKCE.
No client secret or custom web view is used. The requested scopes are
`offline_access User.Read Files.Read`; access/refresh tokens are stored only in
the application's device-only Keychain, not shared account/file models.

MSAL is not a dependency. Its verified 2.12.0 SwiftPM artifact lacks a Catalyst
slice, and its unmodified source pod fails to compile against the Catalyst SDK.
The system-browser implementation avoids maintaining a private SDK patch.

Run the integration and production OAuth-client checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ruby Tests/OneDrive/check.rb
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ruby Tests/OneDrive/check-folder-paths.rb
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Tests/OneDrive/run-oauth-regressions.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash Tests/OneDrive/check-platform-compilation.sh
```

Checks cover target membership, redirect registration, callback suppression,
the RFC 7636 PKCE vector, hostile callbacks, form escaping, token rotation,
single-flight refresh, bounded 401 recovery, account-removal race protection,
pagination isolation/deduplication, and queue cleanup. Runtime tests compile
the production client and use an isolated URLProtocol; no Microsoft account or
real credential is used. They do not prove the remote app registration is valid.
The platform check links the production client/manager against real UIKit,
AuthenticationServices and Security in iOS/Catalyst SDKs, with isolated stubs for
app-specific models only. It supplements, not replaces, a full app build.

## Existing-account migration

Legacy MSAL entries keep their serialized account key and favorites. They have
no refresh token in the new Keychain namespace and must sign in again. Graph
`/me.id` identifies new connections. An existing OAuth account matches by that
ID; an old account is only migrated if the token endpoint's `client_info`
home identity (`uid.utid`) exactly matches its saved `homeAccountId`.

If identity cannot be established, the new authorization is added separately
and the old connection/favorites are retained with an explanatory message.
Email/name similarity is never used to merge accounts. A verified same-account
reauthorization preserves the current folder; a different account opens its root.

## Manual verification with a dedicated account

1. In Microsoft Entra, verify that the existing public-client registration
   accepts both `msauth.com.OfflineMusic.www://auth` and
   `msauth.com.OfflineMusic.www.pro://auth`. No client secret is embedded or needed
   for this public-client flow. Microsoft recommends the **Mobile and desktop
   applications** platform for direct OAuth implementations. Verify the existing
   registration accepts these exact URIs as public-client redirects; no backend
   configuration has been changed by this code update. Keep developer credentials
   out of test reports.
2. In each edition, use **Import / Connections → OneDrive**, authorize read access,
   and verify the root folder. Test both a personal Microsoft account and any
   supported work/school account; administrator consent policies may differ.
3. Open nested folders containing spaces, Unicode characters, `#`, and `%`.
   Refresh repeatedly and during pagination; rows must not duplicate or jump
   back to the root folder.
4. Play and download an authorized audio file. Reopen the app and verify silent
   token refresh. An expired/revoked session must offer reauthorization, not loop.
5. Remove the connection. The new application's OAuth token cache for that account
   is removed; this does not revoke Microsoft consent or sign out other apps.
   Disconnect while a refresh is in progress: the account must stay removed,
   its queued tracks must disappear, and its current track must stop at the
   paused demo. Reauthorizing the same account retains the folder; switching to
   another account opens its root and updates the navigation title.
6. Cancel login, close the system browser, retry, and attempt repeated taps.
   Check a real device and a signed Mac Catalyst build, because Keychain and
   authorization callbacks cannot be validated by unsigned compilation alone.

Official references:

- [Microsoft authorization-code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Microsoft redirect registration](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [RFC 7636: PKCE](https://www.rfc-editor.org/rfc/rfc7636)
