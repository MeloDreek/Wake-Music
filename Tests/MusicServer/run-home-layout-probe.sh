#!/bin/bash
set -euo pipefail
home_root="$(cd "$(dirname "$0")/../.." && pwd)"
home_temp="$(mktemp -d /private/tmp/wake-server-home-layout.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$home_root" "$home_temp" <<'RUBY'
require 'json'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI/MusicServerCells.swift'))
source = source.gsub(/^import (KakaFoundation|Kingfisher)\n/, '')
font = File.read(File.join(root, 'Mobie/Mobie/Base/Core/ConstKey/ConfigInfoKey.swift'))[/func UIFontNumber\(_ value: CGFloat\) -> UIFont \{.*?\n\}/m]
File.write(File.join(output, 'Cells.swift'), source + "\n" + font)
RUBY
home_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$home_sdk" \
  -module-cache-path "$home_temp/modules" "$home_temp/Cells.swift" "$home_root/Tests/MusicServer/HomeLayoutProbe.swift" -o "$home_temp/test"
xcrun simctl spawn "${MUSIC_SERVER_SIMULATOR_UDID:-booted}" "$home_temp/test" "$home_temp"
