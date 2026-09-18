#!/bin/bash
set -euo pipefail
eq_root="$(cd "$(dirname "$0")/../.." && pwd)"
eq_build="$(mktemp -d /private/tmp/wake-eq-layout.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$eq_root" "$eq_build" <<'RUBY'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerEqualizerViewController.swift'))
grid = source.split('private final class EQPresetGrid: UIView {', 2).fetch(1).split('// MARK: - Rack finish', 2).first
probe = File.read(File.join(root, 'Tests/Equalizer/PresetLayoutProbe.swift'))
File.write(File.join(output, 'LayoutProbe.swift'), "import UIKit\nprivate final class EQPresetGrid: UIView {" + grid + probe)
RUBY
eq_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$eq_sdk" \
  -module-cache-path "$eq_build/modules" "$eq_build/LayoutProbe.swift" -o "$eq_build/probe"
xcrun simctl spawn "${EQ_SIMULATOR_UDID:-booted}" "$eq_build/probe"
