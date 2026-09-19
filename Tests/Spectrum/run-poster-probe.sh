#!/bin/bash
set -euo pipefail
spectrum_root="$(cd "$(dirname "$0")/../.." && pwd)"
spectrum_temp="$(mktemp -d /private/tmp/wake-spectrum-poster.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$spectrum_root" "$spectrum_temp" <<'RUBY'
require 'json'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerSpectrumViewController.swift'))
view = source.split('final class SpectrumReportView: UIView {', 2).fetch(1)
# The probe runs outside the app bundle; use the same real brand asset explicitly.
logo = File.join(root, 'Mobie/Mobie/System/Assets.xcassets/Other/app_logo.imageset/app_logo@3x.png')
view = view.gsub('UIImage(named: "app_logo")', "UIImage(contentsOfFile: #{logo.to_json})")
model = File.read(File.join(root, 'Mobie/Mobie/Base/Music/AudioSpectrumAnalyzer.swift')).split('    struct Report {', 2).fetch(1).split('    enum Failure:', 2).first
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
catalog = catalog.select { |k, _| k.start_with?('Spectrum.') || ['File Size', 'Sample Rate'].include?(k) }
copy = %w[zh-Hans en ar].to_h { |locale| [locale, catalog.to_h { |k, v| [k, v.dig('localizations', locale, 'stringUnit', 'value') || k] }] }
header = "import UIKit\nenum AudioSpectrumAnalyzer { struct Report {#{model}}\n"
header += "enum SpectrumCopy { static var locale = \"zh-Hans\"; static let values = try! JSONDecoder().decode([String:[String:String]].self, from: Data(###\"#{JSON.generate(copy)}\"###.utf8)) }\n"
header += "extension String { func localStr() -> String { SpectrumCopy.values[SpectrumCopy.locale]?[self] ?? self } }\n"
File.write(File.join(output, 'Views.swift'), header + "final class SpectrumReportView: UIView {" + view)
RUBY
spectrum_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$spectrum_sdk" \
  -module-cache-path "$spectrum_temp/modules" "$spectrum_temp/Views.swift" "$spectrum_root/Tests/Spectrum/PosterProbe.swift" -o "$spectrum_temp/test"
xcrun simctl spawn "${SPECTRUM_SIMULATOR_UDID:-booted}" "$spectrum_temp/test" "$1" "$spectrum_temp"
