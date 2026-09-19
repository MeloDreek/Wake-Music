# KSPlayer Metal regression

Run `ruby Tests/KSPlayerCompatibility/check-metal-upload.rb [KSPlayer-repository-path]` on a Mac with a booted arm64 iOS simulator. The default SDK path is `/Users/kaka/Documents/本地公开库/KSPlayer`; set `DEVELOPER_DIR` or `EQ_SIMULATOR_UDID` when needed.

The probe extracts the two actual texture-upload methods from the SDK, compiles them for macOS and iOS Simulator, and exercises real Metal. It does not launch or modify the music app. Coverage includes six RGB/YUV pixel formats, padded rows and odd widths, two planes, empty/nil input, and 2,601 pixel-byte comparisons on each platform. Simulator textures must own their uploaded pixels; the native path must still use buffer-backed textures.

The crash fix lives in the local KSPlayer repository's `Sources/KSPlayer/Metal/MetalRender.swift`, on branch `wake`. The app's dependency reference is unchanged. Preserve this SDK change when updating the dependency.

Reason: Simulator aborts on `MTLBuffer.makeTexture` for a `.shared` buffer, whereas the physical-device path supports it. The simulator-only branch uploads via the existing standalone-texture helper. See [Apple's Simulator Metal limitations](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator).
