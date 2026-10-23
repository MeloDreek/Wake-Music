# Isolated OneDrive OAuth validation

## Offline behavior regression

```sh
bash Tests/OneDrive/run-oauth-regressions.sh
```

This compiles the production `OneDriveOAuthClient.swift` and executes its real
methods with an injected `URLSessionConfiguration`. A catch-all `URLProtocol`
returns fictional responses; no Microsoft account, live endpoint, filesystem
music library, or Keychain item is accessed. The tests include PKCE, callback
validation, form encoding, token rotation, account identity changes, concurrent
refreshes, account-removal races, bounded 401 recovery, and access-only legacy
accounts requiring sign-in.

## Actual Apple platform compilation

```sh
bash Tests/OneDrive/check-platform-compilation.sh
```

This compiles **and links** the production OAuth client and manager for both:

- `arm64-apple-ios16.0-macabi` (Mac Catalyst)
- `arm64-apple-ios16.0` (iOS)

UIKit, AuthenticationServices, Security, CryptoKit, and Foundation come from the
selected Xcode's real Apple SDKs. This checks use and availability of the system
authentication-session, presentation, cryptography, URLSession, and Keychain
APIs without requiring unrelated app dependencies to compile.

Only `AppGroupKit`, `KakaFoundation`, and `KakaUIKit` business signatures are
substituted by the explicit files in `PlatformCompileStubs/`. These stand-ins do
not implement production persistence, localization, errors, or alerts. They are
test inputs only, are not added to application targets, and must never be linked
into the shipped app. The script keeps all modules and unsigned dylibs in a new
temporary directory and does not execute the platform dylibs.

## Limits

Passing these checks does **not** prove a complete app archive, Microsoft app
registration, interactive authorization, signed-device Keychain entitlements,
browser presentation, or runtime account migration works. Those need full-app
builds and a dedicated authorized account on iOS and Mac Catalyst. The compile
check deliberately cannot certify other SDKs such as the keyboard dependency.
