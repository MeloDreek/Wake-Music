#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-history.XXXXXX)
trap 'rm -f "$test_dir/History.swift" "$test_dir/history-tests"; rmdir "$test_dir"' EXIT
ruby - "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerHistory.swift" "$test_dir/History.swift" <<'RUBY'
source = File.read(ARGV[0])
helper = source.split('static func updateFavorite(accountID: String, songID: String, isFavorite: Bool)', 2).last&.split('private static func storageKey', 2)&.first
abort 'Favorite synchronization helper is missing' unless helper
abort 'Favorite changes must not emit playback notifications' if helper.include?('NotificationCenter') || helper.include?('recordPlayback(')
File.write(ARGV[1], source.gsub("import AppGroupKit\n", '').gsub('UserDefaults.standard', 'historyTestDefaults'))
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wakemusic-history-module-cache \
  "$test_dir/History.swift" \
  "$project_root/Tests/MusicServer/HistoryFavoriteRegression.swift" \
  -o "$test_dir/history-tests"
"$test_dir/history-tests"
