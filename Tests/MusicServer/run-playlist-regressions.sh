#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-playlist.XXXXXX)
trap 'rm -f "$test_dir/PlaylistSupport.swift" "$test_dir/playlist-tests"; rmdir "$test_dir"' EXIT
ruby - "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift" "$test_dir/PlaylistSupport.swift" <<'RUBY'
source = File.read(ARGV[0])
helper = source.split("enum MusicServerPlaylistSupport {", 2).last
abort "Production playlist helper is missing" unless helper
File.write(ARGV[1], "import Foundation\nenum MusicServerPlaylistSupport {" + helper)
create_method = source.split("func createPlaylist(name: String) async throws {", 2).last&.split("\n    }", 2)&.first
abort "Creation must remain a single form POST with no automatic replay" unless create_method&.include?('useFormPost: true') && !create_method.match?(/\bretry\b|\bcatch\b/)
all_method = source.split("func allPlaylists() async throws -> [MusicServerItem] {", 2).last&.split("\n    }", 2)&.first
abort "Homepage must request the complete bounded metadata list" unless all_method&.include?('subsonic("getPlaylists")') && all_method.include?('Task.checkCancellation()')
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wakemusic-playlist-module-cache \
  "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" \
  "$test_dir/PlaylistSupport.swift" \
  "$project_root/Tests/MusicServer/PlaylistRegression.swift" \
  -o "$test_dir/playlist-tests"
"$test_dir/playlist-tests"
