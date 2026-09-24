#!/bin/bash
set -euo pipefail
adaptive_root="$(cd "$(dirname "$0")/../.." && pwd)"
adaptive_temp="$(mktemp -d /private/tmp/wake-adaptive-navigation.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$adaptive_root" "$adaptive_temp" <<'RUBY'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/MusicServerRootControllers.swift'))
adaptive = source[/@available\(iOS 18\.0, \*\)\n@MainActor\nfinal class MusicServerAdaptiveRootController:.*?(?=\n@MainActor\nfinal class MusicServerSplitViewController)/m] or abort 'Adaptive root not found'
sidebar = source[/@MainActor\nprivate final class MusicServerSidebarController:.*?(?=\n\/\/\/ Reuses the existing mini player)/m] or abort 'Sidebar not found'
probe = File.read(File.join(root, 'Tests/AdaptiveLayout/AdaptiveNavigationProbe.swift'))
File.write(File.join(output, 'Probe.swift'), probe + "\n" + adaptive + "\n" + sidebar)
RUBY
adaptive_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios18.0-simulator \
  -sdk "$adaptive_sdk" -module-cache-path "$adaptive_temp/modules" \
  "$adaptive_temp/Probe.swift" -o "$adaptive_temp/probe"
xcrun simctl spawn "${ADAPTIVE_SIMULATOR_UDID:-booted}" "$adaptive_temp/probe"
echo "Adaptive navigation probe: $adaptive_temp"
