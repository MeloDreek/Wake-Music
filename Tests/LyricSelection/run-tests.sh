#!/bin/bash
set -euo pipefail
lyric_root="$(cd "$(dirname "$0")/../.." && pwd)"
lyric_build="$(mktemp -d /private/tmp/wake-lyric-selection.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby "$lyric_root/Tests/LyricSelection/extract-controller.rb" \
  "$lyric_root/Mobie/Mobie/Business/MusicModule/Controller/SelectLyricViewController.swift" \
  "$lyric_build/ProductionController.swift"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$lyric_build/modules" \
  "$lyric_build/ProductionController.swift" \
  "$lyric_root/Tests/LyricSelection/LyricSelectionTests.swift" -o "$lyric_build/check"
"$lyric_build/check"
