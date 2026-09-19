#!/bin/bash
set -euo pipefail
spectrum_root="$(cd "$(dirname "$0")/../.." && pwd)"
spectrum_temp="$(mktemp -d /private/tmp/wake-spectrum-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$spectrum_root" "$spectrum_temp" <<'RUBY'
require 'json'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Base/Music/AudioSpectrumAnalyzer.swift'))
dsp = source.split('final class SpectrumAccumulator {', 2).fetch(1)
File.write(File.join(output, 'DSP.swift'), "import Foundation\nimport Accelerate\nenum AudioSpectrumAnalyzer { enum Failure: Error { case unreadable } }\nfinal class SpectrumAccumulator {" + dsp)
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
locales = catalog.fetch('EQ.Title').fetch('localizations').keys
data = JSON.parse(File.read(File.join(root, 'Tests/Spectrum/localizations.json')))
data.fetch('keys').each do |name|
  values = catalog.fetch('Spectrum.' + name).fetch('localizations')
  raise "Missing locales: #{name}" unless (locales - values.keys).empty?
  values.each do |locale, entry|
    text = entry.fetch('stringUnit').fetch('value')
    raise "Empty: #{name}/#{locale}" if text.empty?
    raise "Format mismatch: #{locale}" if name == 'AnalysisRate' && text.scan('%g').count != 1
  end
end
puts "PASS_SPECTRUM_LOCALIZATION #{data['keys'].count} keys, #{locales.count} locales"
RUBY
xcrun swiftc -module-cache-path "$spectrum_temp/modules" -parse-as-library "$spectrum_temp/DSP.swift" "$spectrum_root/Tests/Spectrum/DSPTests.swift" -o "$spectrum_temp/dsp"
"$spectrum_temp/dsp"
