# Dependency setup

Open **Wake Music.xcworkspace**, not the app's `.xcodeproj`.

## Remote packages

The app and Pro targets use the same remote SwiftPM packages. The fourteen
upstream migrations are pinned to their previously tested local revisions;
SwiftyUploader uses the separately tested public fork release described below.
Commit the shared `Package.resolved` together with the project.

| Package | Upstream | Pinned revision |
| --- | --- | --- |
| Alamofire | [Alamofire/Alamofire](https://github.com/Alamofire/Alamofire) | `bda9ed57d72988a3a2ada33d824583541f86eac6` |
| AliyunpanSDK | [alibaba/aliyunpan-ios-sdk](https://github.com/alibaba/aliyunpan-ios-sdk) | `66cdb2679e9cbacd7f682e43e784cf481f200a5a` |
| AMSMB2 | [amosavian/AMSMB2](https://github.com/amosavian/AMSMB2) | `1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0` |
| DominantColors | [DenDmitriev/DominantColors](https://github.com/DenDmitriev/DominantColors) | `a05327d36092c47e9ddc77ce565eb35a5b4a4a6e` |
| FilesProvider | [amosavian/FileProvider](https://github.com/amosavian/FileProvider) | `5d31778376af168ac917e0b1e8d2c4ee64cb246c` |
| Kingfisher | [onevcat/Kingfisher](https://github.com/onevcat/Kingfisher) | `8648fe649c5d62be38721110f835821906e9242a` |
| MorphingLabel | [lexrus/LTMorphingLabel](https://github.com/lexrus/LTMorphingLabel) | `bf629bd1ea03d92a1a2673bb2689a4ed2981e7b7` |
| MarqueeLabel | [cbpowell/MarqueeLabel](https://github.com/cbpowell/MarqueeLabel) | `c6b4da400c00dfd5db7a4f6e4915ca531d95fc49` |
| PanModal | [ppamorim/PanModal](https://github.com/ppamorim/PanModal) | `ac6d7427ef985515e1fe98f7c20242dcdaa3f7ba` |
| PCloudSDKSwift | [pCloud/pcloud-sdk-swift](https://github.com/pCloud/pcloud-sdk-swift) | `cc81e0250a9f378019470c78ce9a8bb501dcaeda` |
| Reachability | [ashleymills/Reachability.swift](https://github.com/ashleymills/Reachability.swift) | `21d1dc412cfecbe6e34f1f4c4eb88d3f912654a6` |
| RevenueCat, RevenueCatUI, ReceiptParser | [RevenueCat/purchases-ios](https://github.com/RevenueCat/purchases-ios) | `474a29a694ba9f09b8e8e9d9592ed546f51c9301` |
| Toast | [scalessec/Toast-Swift](https://github.com/scalessec/Toast-Swift) | `d780ff8fe55659b4fddf1fbfaf930d967f35d9ea` |
| ZLImageEditor | [longitachi/ZLImageEditor](https://github.com/longitachi/ZLImageEditor) | `d0bd245e02c68f2a7da21d8683a9caf11e28cc14` |
| SwiftyUploader | [MeloDreek/GCDWebServer_Swift](https://github.com/MeloDreek/GCDWebServer_Swift) | Exact version `1.0.0` |

The uploader uses the public customized fork, not the original upstream package.
Its Swift product/module remains `SwiftyUploader`. The release retains the custom
upload root and web-page configuration APIs and adds file-transfer regression
tests and path/lifecycle hardening.

WaketagLibKit already uses the private remote Swift package, version **2.3.3**.
New developers need access to `MeloDreek/WaketagLibKit` and working GitHub SSH
authentication. Never commit access tokens or private SSH keys.

Existing remotely managed CocoaPods and their locked versions remain in place.
The scope here is migrating **local third-party dependencies**, not changing
already working remote Pods. Run `pod install`, not `pod update`, to preserve the
lockfile. The post-install integration keeps IQKeyboardManager iOS-only.

## Local dependencies retained

- The app-owned `LocalSDK` pods remain versioned with the app.
- Firebase, KSPlayer and its FFmpegKit dependency remain local by design. Their
  source trees must be supplied separately, including the existing compatibility
  patches and binary artifacts. The app project's references resolve to
  `../../../本地公开库/` relative to `Mobie/`; KSPlayer's own manifest resolves
  FFmpegKit. These are still prerequisites for an iOS/Catalyst build on a new Mac.
- **MEGASDK is versioned at `LocalSDK/MEGASDK`**, pending a patched remote distribution. The installed
  SDK is upstream v10.19.0 with necessary proxy, public streaming declarations,
  CoreFoundation natural-sort and build-exclusion changes. Directly selecting
  the official package loses those changes and does not build with the current
  Apple SDK. It is deliberately still local rather than replacing working
  behavior with an incompatible package. Commit its source and patch files with
  the app; `.artifacts` and `.downloads` are deliberately ignored. On a new Mac,
  run `bash Tests/MEGA/bootstrap-sdk.sh` to restore six official binary artifacts
  with SHA-256 verification. See [MEGA setup](../Tests/MEGA/README.md). The original
  external checkout was left intact as a backup and is no longer referenced.

No shared source directories or binary artifacts were deleted by this migration.

## Reproducible setup and checks

From the repository root, after supplying the retained local SDKs:

```sh
bash Tests/MEGA/bootstrap-sdk.sh
pod install
xcodebuild -resolvePackageDependencies -scmProvider system \
  -workspace 'Wake Music.xcworkspace' -scheme Mobie
ruby Tests/BuildConfiguration/check-dependencies.rb
```

`-scmProvider system` uses the developer's normal Git/SSH configuration and avoids
the connectivity problem encountered with Xcode's internal SCM provider on the
test machine. The app project contains one explicit package product linkage per
target, with no leftover local/remote duplicates.

Format coverage and its separate playback compatibility list are documented in
[AudioFormatCoverage.md](AudioFormatCoverage.md).

## Migration verification (2026-09-24)

- All fourteen migrated revisions were independently verified against the
  corresponding upstream GitHub commit APIs; no unpublished patch was dropped.
- Xcode resolved the remote package graph and produced the shared lockfile.
  The existing seventeen resolved pins did not change versions or revisions.
- First-time RevenueCat history downloading stalled on the test network. Its
  clean local Git checkout was used to warm the Git object cache; the package
  itself is still resolved by its official remote URL and pinned revision.
  A completely cold network installation has not been timed or verified.
- GCDWebServer_Swift `1.0.0` resolves to
  `032c945867ac0f036fd1e30215edd02d7f349db1`. Its 22 package regression tests
  (including real loopback upload/download and restart) and standalone iOS
  Simulator demo build passed. GitHub HTTPS timed out on this network, so the
  app's resolution used a command-scoped Git HTTPS-to-SSH mapping for this one
  repository; no global Git configuration or project URL was changed.
  The public [GitHub Actions run](https://github.com/MeloDreek/GCDWebServer_Swift/actions/runs/36003304155)
  also passed. A separate working clone for SourceTree is available at
  `/Users/kaka/Documents/本地公开库/GCDWebServer_Swift`; the app does not depend on
  that local path.
- MEGASDK's 40 regression tests passed after moving the SDK into `LocalSDK`.
- With uploader `1.0.0` fetched from GitHub and MEGA resolved from `LocalSDK`,
  ordinary and Pro targets again passed both iOS 27 Simulator and arm64 Mac
  Catalyst Debug builds.
- Both ordinary and Pro targets passed iOS Simulator and Mac Catalyst (arm64)
  builds, as did
  package-linkage, IQKeyboardManager isolation, format, 115 and EQ regression
  checks. The Mac EQ layout was also inspected in the running app.
- The pre-existing Intel Catalyst MEGASDK `nghttp2`/`idn2` linker issue is outside
  this migration; the retained binary SDK still needs its separate Intel fix.
