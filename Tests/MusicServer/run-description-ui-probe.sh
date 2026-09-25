#!/bin/bash
set -euo pipefail
description_root="$(cd "$(dirname "$0")/../.." && pwd)"
description_temp="$(mktemp -d /private/tmp/wake-description-layout.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
description_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$description_sdk" \
  -module-cache-path "$description_temp/modules" \
  "$description_root/Mobie/Mobie/Business/MusicServerModule/UI/MusicServerExpandableTextView.swift" \
  "$description_root/Tests/MusicServer/ExpandableDescriptionProbe.swift" -o "$description_temp/test"
xcrun simctl spawn "${MUSIC_SERVER_SIMULATOR_UDID:-booted}" "$description_temp/test"
