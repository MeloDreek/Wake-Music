#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wake-button-highlight.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
task_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
for task_file in \
  Business/PlayerModule/View/PlayControlDefaultView.swift \
  Business/OtherModule/TabbarModule/iOS/PlayerControlToolBarView.swift; do
  # Require the production configuration as well as checking UIKit's behavior.
  rg -q 'for: \[\.selected, \.highlighted\]' "$task_root/Mobie/Mobie/$task_file"
done
xcrun --sdk iphonesimulator swiftc -target "$(uname -m)-apple-ios16.0-simulator" \
  -sdk "$task_sdk" "$task_root/Tests/PlaybackState/ButtonHighlightRegression.swift" \
  -o "$task_build/check"
xcrun simctl spawn "${1:-booted}" "$task_build/check"
