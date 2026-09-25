#!/bin/bash
set -euo pipefail
capture_root="$(cd "$(dirname "$0")/../.." && pwd)"
capture_build="$(mktemp -d /private/tmp/wake-batch-header.XXXXXX)"
capture_output="${1:-$capture_root/outputs/AppStore-3.6.0-zh-Hans-v1/raw/batch-header.png}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/kaka/Desktop/Xcode.app/Contents/Developer}"

# Only view sources and localization are read. No app build, install, launch,
# original audio access, accounts, or preferences are involved.
ruby - "$capture_root" "$capture_build" <<'RUBY'
require 'json'
require 'digest'
root, output = ARGV
paths = %w[
  Mobie/Mobie/Business/MusicModule/View/MusicTopBatchEditHeadView.swift
  Mobie/Mobie/Business/MusicModule/View/MatchingProgressView.swift
  LocalSDK/KakaUIKit/Classes/CustomUI/KakSliderControl/RTLProgressView.swift
  LocalSDK/KakaUIKit/Classes/CustomUI/CommonView/LoadingButton.swift
]
paths.each do |relative|
  source = File.read(File.join(root, relative))
  source = source.lines.reject { |line| line.start_with?('import ') }.join
  File.write(File.join(output, File.basename(relative)), "import UIKit\nimport SnapKit\n" + source)
end
%w[BatchHeaderSupport.swift BatchHeaderProbe.swift].each do |name|
  File.write(File.join(output, name), File.read(File.join(root, 'Tools/AppStoreScreenshots', name)))
end
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
keys = paths.flat_map { |p| File.read(File.join(root, p)).scan(/"([^"\n]+)"\.localStr\(\)/).flatten }.uniq
values = keys.to_h { |key| [key, catalog.dig(key, 'localizations', 'zh-Hans', 'stringUnit', 'value') || key] }
payload = JSON.generate(values)
File.write(File.join(output, 'BatchHeaderCatalog.swift'), "import Foundation\nenum BatchHeaderCatalog { static let values = try! JSONDecoder().decode([String:String].self, from: Data(###\"#{payload}\"###.utf8)) }\n")
manifest = {sources: paths.to_h { |p| [p, Digest::SHA256.file(File.join(root, p)).hexdigest] }, simulated: {current: 4, total: 9, song: 'Lady Gaga & Bruno Mars - Die With A Smile.flac'}, locale: 'zh-Hans'}
File.write(File.join(output, 'source-manifest.json'), JSON.pretty_generate(manifest))
RUBY

capture_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$capture_sdk" \
  -module-cache-path "$capture_build/modules" -emit-library -emit-module -module-name SnapKit \
  "$capture_root/Pods/SnapKit/Sources/"*.swift -o "$capture_build/libSnapKit.dylib" \
  -emit-module-path "$capture_build/SnapKit.swiftmodule"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$capture_sdk" \
  -module-cache-path "$capture_build/modules" -I "$capture_build" -L "$capture_build" -lSnapKit \
  -Xlinker -rpath -Xlinker "$capture_build" "$capture_build/"*.swift -o "$capture_build/batch-header-probe"

if [[ "${BATCH_HEADER_BUILD_ONLY:-0}" == "1" ]]; then
  printf '%s\n' "$capture_build/batch-header-probe"
  exit 0
fi
mkdir -p "$(dirname "$capture_output")"
xcrun simctl spawn "${BATCH_HEADER_SIMULATOR_UDID:-booted}" "$capture_build/batch-header-probe" \
  "$capture_output" "${BATCH_HEADER_WIDTH:-400}" "${BATCH_HEADER_SCALE:-3}" "${BATCH_HEADER_APPEARANCE:-light}"
printf 'Source manifest: %s\n' "$capture_build/source-manifest.json"
