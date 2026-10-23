# IQKeyboardManager integration

## Current configuration — 2026-10-23

Both app targets use the official CocoaPods `IQKeyboardManagerSwift ~> 8.0.3`
dependency. The custom post-integration Ruby script, SDK-scoped linker variables,
platform filters, conditional embedding guard and Catalyst-specific embedding
file lists have been removed. Run `pod install --no-repo-update` to regenerate
normal CocoaPods integration; do not restore the removed platform-rewriting hook.

AppDelegate still uses Swift's ordinary compile-time `targetEnvironment(macCatalyst)`
and `canImport` conditions for importing and initializing the keyboard library.
These guards do not prevent CocoaPods from compiling the library itself.

The removed script operated only during local CocoaPods project generation and
framework embedding. It did not contact a server, identify App Review, change
features after release, or execute as Ruby code inside the app. Its removal is a
build-configuration simplification, not a finding that it caused an App Review
rejection.

## Mac Catalyst limitation

The original workaround existed because `IQKeyboardReturnManager` references
`UIInputSuggestion` and `UITextFormattingViewController`, which the tested Xcode
27 SDK declared unavailable on Mac Catalyst. A targeted Release build of the
`IQKeyboardReturnManager` scheme for Mac Catalyst on 2026-10-23 reproduced these
errors with Xcode 27.1 (27A9275). The first source error was
`IQKeyboardReturnManager+UITextFieldDelegate.swift:234:85`:
`'UIInputSuggestion' is unavailable in Mac Catalyst`. The build failed with exit
code 65; subsequent errors also identified `UITextFormattingViewController` and
the corresponding text-view delegate methods. No replacement workaround or
vendor source patch is introduced here, and a passing configuration test must
not be reported as a successful Catalyst build.

Keep the dependency when building the iOS app. If the current dependency still
does not compile for Catalyst, its removal for a Mac-only build must be deliberate
and followed by CocoaPods regeneration; restore the normal iOS dependency before
the next iOS build. Do not carry temporary local packaging edits into a release
without verifying the resulting target and embedded frameworks.

## Checks

```sh
ruby Tests/BuildConfiguration/check-iq-platforms.rb
```

This checks both targets' generated Debug/Release dependencies, linker flags and
embedding lists, confirms that the custom platform-rewriting configuration is
gone, and preserves the app's Swift import/initialization guards. It does not
replace compiling, archiving and testing the intended platform.

On 2026-10-23, all 62 standard IQ integration checks and all 19 Xcode build
configuration checks passed. No pod versions changed during regeneration.

## Historical context

The previous platform-isolation setup passed Debug simulator and Catalyst builds
on 2026-09-16. Those results applied to the now-removed workaround, not to the
current unmodified CocoaPods integration.
