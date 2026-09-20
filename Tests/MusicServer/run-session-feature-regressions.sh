#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-session-features.XXXXXX)
trap 'rm -f "$test_dir/SessionFeatureRegression.swift" "$test_dir/session-tests"; rmdir "$test_dir"' EXIT
ruby - "$project_root" "$test_dir/SessionFeatureRegression.swift" <<'RUBY'
root, destination = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift'))
fixture = File.read(File.join(root, 'Tests/MusicServer/SessionFeatureRegression.swift'))
abort 'Production session must remain MainActor-isolated' unless source.include?("@MainActor\nfinal class MusicServerSession")
home = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI/MusicServerHomeViewController.swift'))
abort 'Incoming favorite pages must apply the local override before filtering unstarred songs' unless home.match?(/items\.filter.*?map\(self\.applyingFavoriteOverride\).*?\.filter \{ if section == \.favorites, case \.song\(let song\) = \$0 \{ return song\.value\.starred \}/m)
abort 'An accepted unlike must disappear immediately before the server shelf reload' unless home.match?(/try await self\.session\.setSongFavorite.*?self\.favoriteOverrides\[song\.id\] = favorite.*?self\.previews\[\.favorites\] = self\.previews\[\.favorites\]\?\.filter \{\s*if case \.song\(let song\) = \$0 \{ return song\.value\.starred \}.*?self\.loadSection\(\.favorites/m)
def extract(source, signature)
  start = source.index(signature) or abort "Missing production signature: #{signature}"
  tail = source[start..-1]
  # These declarations end at four-space indentation; inner blocks are deeper.
  tail.split("\n    }", 2).first + "\n    }"
end
methods = [
  'func page(_ route: MusicServerRoute,',
  'func artistPage(offset:',
  'func setArtistFavorite(id:',
  'func setSongFavorite(id:',
  'private func setFavorite(id:',
  'func addSongToPlaylist(songID:',
  'private func subsonicURL(_ endpoint:',
  'private func subsonic(_ endpoint:',
  'private func records(_ response:',
  'private func validate(_ response:'
].map { |signature| extract(source, signature) }.join("\n\n    ")
route = source[/enum MusicServerRoute: Hashable \{.*?\n\}/m] or abort 'Missing route enum'
helper = source.split('enum MusicServerPlaylistSupport {', 2).last or abort 'Missing production form helper'
fixture.sub!('// PRODUCTION_ROUTE', route)
fixture.sub!('// PRODUCTION_METHODS', methods)
fixture.sub!('// PRODUCTION_PLAYLIST_SUPPORT', 'enum MusicServerPlaylistSupport {' + helper)
File.write(destination, fixture)
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wakemusic-session-features-module-cache \
  "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" \
  "$test_dir/SessionFeatureRegression.swift" \
  -o "$test_dir/session-tests"
"$test_dir/session-tests"
