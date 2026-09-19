#!/bin/bash
set -euo pipefail
eq_root="$(cd "$(dirname "$0")/../.." && pwd)"
eq_build="$(mktemp -d /private/tmp/wake-eq-layout.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$eq_root" "$eq_build" <<'RUBY'
require 'json'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerEqualizerViewController.swift'))
grid = source.split('private final class EQPresetGrid: UIView {', 2).fetch(1).split('// MARK: - Rack finish', 2).first
model = File.read(File.join(root, 'Mobie/Mobie/Base/Music/PlayerEqualizerSettings.swift'))
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
locales = catalog.fetch('EQ.Custom').fetch('localizations').keys.sort
enum_cases = model.split('enum PlayerEqualizerPreset:', 2).fetch(1).split('static let factoryPresets', 2).first.scan(/^\s+case ([\w, ]+)$/).flatten.join(',').split(',').map(&:strip)
catalog = catalog.select { |key, _| key.start_with?('EQ.') || enum_cases.include?(key) }
labels = locales.to_h do |locale|
  [locale, catalog.each_with_object({}) do |(key, entry), values|
    value = entry.dig('localizations', locale, 'stringUnit', 'value')
    values[key] = value if value
  end]
end
payload = JSON.generate(labels)
copy = "enum EQLayoutLocalizations { static let labels = try! JSONDecoder().decode([String: [String: String]].self, from: Data(##\"#{payload}\"##.utf8)) }\n"
probe = File.read(File.join(root, 'Tests/Equalizer/PresetLayoutProbe.swift'))
File.write(File.join(output, 'LayoutProbe.swift'), "import UIKit\n" + model + copy + "private final class EQPresetGrid: UIView {" + grid + probe)
RUBY
eq_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$eq_sdk" \
  -module-cache-path "$eq_build/modules" "$eq_build/LayoutProbe.swift" -o "$eq_build/probe"
xcrun simctl spawn "${EQ_SIMULATOR_UDID:-booted}" "$eq_build/probe" "$eq_build/eq-presets-zh-Hans.png"
