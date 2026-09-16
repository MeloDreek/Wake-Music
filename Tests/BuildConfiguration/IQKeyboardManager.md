# iOS-only IQKeyboardManager

The Mac app is Mac Catalyst, which CocoaPods considers an iOS platform. The
`IQKeyboardReturnManager` dependency currently references `UIInputSuggestion`
and `UITextFormattingViewController`, which Xcode 27 declares unavailable on
Mac Catalyst. Guarding only the app import doesn't prevent compiling the pod.

`scripts/ios_only_keyboard_pods.rb`, called by the Podfile's `post_integrate`
hook, keeps all eight IQ dependencies on iPhone/iPad and excludes them from Mac:

- Explicit dependencies and framework build files use `platformFilters = (ios)`.
- IQ linker/header/framework flags live in variables scoped to `sdk=iphone*`.
  This avoids conditional `$(inherited)` reintroducing unfiltered IQ flags.
- Catalyst has separate embed input/output file lists, and the embedding script
  skips IQ when `PLATFORM_NAME=macosx`. No CPU-architecture checks are used:
  arm64 is shared by iPhones, iOS simulators and Apple Silicon Macs.
- AppDelegate excludes both imports and initialization on Mac Catalyst.

No IQ vendor source is patched, and no library version is changed. Running
`pod install --no-repo-update` reapplies the configuration automatically.

Check generated configuration using `ruby Tests/BuildConfiguration/check-iq-platforms.rb`.
Build both Mobie and Mobie_Pro for Mac Catalyst and iOS Simulator to verify the
actual dependency graph, link command and embedded products.

## Verified with Xcode 27 (2026-09-16)

- Reproduced the original Catalyst-only IQKeyboardReturnManager compiler errors.
- Mobie Mac Catalyst Debug arm64: build passed; no IQ build targets or embedded frameworks.
- Re-ran `pod install --no-repo-update`: no dependency version changes; hook reapplied.
- Mobie iOS Simulator Debug arm64: build passed; all eight IQ frameworks still embedded.
- Mobie_Pro Mac Catalyst Debug arm64 after regeneration: build passed; no IQ frameworks embedded.
- 630 platform/configuration checks passed. Debug/Release configuration checks are static;
  the recorded builds above are Debug, with command-line code signing disabled.
