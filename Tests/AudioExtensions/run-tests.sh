#!/bin/bash
set -euo pipefail

audio_root="$(cd "$(dirname "$0")/../.." && pwd)"
audio_build="$(mktemp -d /private/tmp/wake-audio-extension-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
audio_taglib="${TAGLIB_ROOT:-$audio_root/LocalSDK/KakaTaglibKit}"
audio_parser="$audio_taglib/Classes/TagLib/fileref.cpp"
if [[ ! -f "$audio_parser" ]]; then
  echo 'Set TAGLIB_ROOT to the resolved WaketagLibKit checkout.' >&2
  exit 1
fi
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$audio_build/modules" \
  "$audio_root/LocalSDK/AppGroupKit/Classes/Const/AudioExtension.swift" \
  "$audio_root/LocalSDK/AppGroupKit/Classes/CoreData/Music/URL+Support.swift" \
  "$audio_root/Tests/AudioExtensions/AudioExtensionRegression.swift" \
  -o "$audio_build/regressions"
"$audio_build/regressions" "$audio_parser"
