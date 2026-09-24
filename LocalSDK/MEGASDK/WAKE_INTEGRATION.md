# Shared MEGA SDK for Wake apps

This directory is a reusable local Swift package, not a published remote repository.
Its source is vendored at `LocalSDK/MEGASDK` in the application repository.

## Add to another app

In Xcode, add this directory as a local package and link the `MEGASdk` product to
the app target. Use a repository-relative path so other developers can open the
same project without reproducing a specific user's folder layout. The package contains no account
credentials and has no dependency on Wake Music or AppGroupKit. App-specific
login, Keychain, browsing and playback adapters remain in the app projects.

The `.artifacts` directory contains the already verified official XCFrameworks.
The binaries are intentionally excluded from Git. If these binaries are missing
on a new computer, run from the application repository root:

```sh
bash LocalSDK/MEGASDK/tools/wake-bootstrap-artifacts.sh
```

The script pins all six official URLs and SHA-256 values. `MEGA_DOWNLOAD_CACHE`
optionally selects an existing archive cache; proxy environment variables may be
set for that command only. The script resolves its SDK directory from its own
location, so it can also be invoked from another working directory. Do not commit
`.artifacts` or `.downloads`; some binary files exceed GitHub's per-file limit.

## Upstream and local compatibility patches

- Official SDK v10.19.0, archive root `meganz-sdk-8775533`:
  https://github.com/meganz/sdk/releases/tag/v10.19.0
- Source archive SHA-256:
  `ff31ee1e2c4d8a02155124ff73758bb6230f61a9fbf67fc2cc0a214a7c46ee0b`.
- The upstream BSD-2-Clause LICENSE and dependency notices are retained.
- Package.swift references the local `.artifacts` directory and excludes unused
  `evt-tls`, consistent with the Apple `USE_OPENSSL=OFF` configuration.
- MEGASdk.h exposes libuv APIs to Swift, matching the compiled SDK configuration.
- `wakeSetProxy(url:username:password:delegate:)` exposes the existing C++ proxy
  API to Swift. The upstream HTTP layer does not discover system proxies on iOS
  (including Simulator). Consumers must resolve their current system proxy and
  await this method's completion before login/fastLogin. A nil URL means direct;
  no proxy address or account credential is embedded in this shared package.
- Apple natural filename sorting uses public CoreFoundation APIs because current
  Xcode SDKs do not expose ICU collation headers. See `src/apple_natural_sort.h`.
  Numeric ties use deterministic byte ordering; ICU locale ordering can differ.
- No cryptography or certificate verification code has been changed.

Preserve/review these patches when upgrading. A change to this package affects
every app target that links it; regression-test each consumer. The app repository
versions the SDK source and bootstrap script, while the verified binary artifacts
can be restored using the script above.

For local HTTP streaming in a sandboxed Mac app, the app needs the network server
entitlement as well as network client access; bind the SDK server to loopback
only and restrict it to explicitly requested files. Real-account playback and
download tests are still required for each consuming app.
