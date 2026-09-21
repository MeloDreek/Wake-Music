#!/bin/bash
set -euo pipefail
download_root="$(cd "$(dirname "$0")/../.." && pwd)"
download_temp="$(mktemp -d /private/tmp/wake-download-ui.XXXXXX)"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
ruby - "$download_root" "$download_temp" <<'RUBY'
root, output = ARGV
ui = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI/NavidromeDownloadViewController.swift'))
roots = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/MusicServerRootControllers.swift'))
classic = File.read(File.join(root, 'Mobie/Mobie/Business/ImportModule/Controller/DownloadViewController.swift'))
abort 'Classic page still depends on Navidrome' if classic.include?('Navidrome') || classic.include?('MusicServer') || classic.include?('allowsMusicImport')
abort 'Must be independent, not a subclass of the classic sheet' unless ui.include?('NavidromeDownloadViewController: SuperViewController')
abort 'Badge must observe queue from the root' unless roots.include?('DownloadManager.shared.$taskArray') && roots.include?('.map { $0.count }.removeDuplicates()')
abort 'Return must share the exact home exit closure' unless roots.include?('NavidromeDownloadViewController(onExit: onExit)')
fixture = File.read(File.join(root, 'Tests/MusicServer/DownloadUIProbe.swift'))
method = roots.split('private func updateDownloadBadge', 2).last.split("\n    }", 2).first
fixture.sub!('// PRODUCTION_BADGE', "func updateDownloadBadge#{method}\n    }")
cell = ui[ui.index('final class NavidromeDownloadEmptyCell:')..]
asset = File.join(root, 'Mobie/Mobie/System/Assets.xcassets/Other/empty_music.imageset/empty_music@3x.png')
cell = cell.gsub('UIImage(named: "empty_music")', "UIImage(contentsOfFile: \"#{asset}\")")
fixture.sub!('// PRODUCTION_EMPTY_CELL', cell)
File.write(File.join(output, 'Probe.swift'), fixture)
RUBY
download_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$download_sdk" \
  -module-cache-path "$download_temp/modules" "$download_temp/Probe.swift" -o "$download_temp/test"
xcrun simctl spawn "${MUSIC_SERVER_SIMULATOR_UDID:-booted}" "$download_temp/test"
