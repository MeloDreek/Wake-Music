#!/bin/bash
set -euo pipefail

eq_root="$(cd "$(dirname "$0")/../.." && pwd)"
eq_build="$(mktemp -d /private/tmp/wake-equalizer-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
eq_tests="$eq_root/Tests/Equalizer"

ruby "$eq_tests/extract-integration.rb" "$eq_root" "$eq_build/ProductionIntegration.swift"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$eq_build/modules" \
  "$eq_root/Mobie/Mobie/Base/Music/PlayerEqualizerSettings.swift" \
  "$eq_build/ProductionIntegration.swift" "$eq_tests/IntegrationTests.swift" -o "$eq_build/integration"
"$eq_build/integration"

if [[ "${1:-}" == "--settings-only" ]]; then
  exit 0
fi

xcrun --sdk macosx swiftc -swift-version 5 -module-cache-path "$eq_build/modules" \
  "$eq_tests/NativeDSPProbe.swift" -o "$eq_build/native-dsp"
"$eq_build/native-dsp"

if [[ "${1:-}" == "--simulator" ]]; then
  eq_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  xcrun swiftc -swift-version 5 -target arm64-apple-ios18.0-simulator -sdk "$eq_sdk" \
    -module-cache-path "$eq_build/simulator-modules" "$eq_tests/NativeDSPProbe.swift" -o "$eq_build/simulator-dsp"
  xcrun simctl spawn "${EQ_SIMULATOR_UDID:-booted}" "$eq_build/simulator-dsp"
fi

printf 'Equalizer test artifacts: %s\n' "$eq_build"
