#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-artist-catalog.XXXXXX)
trap 'rm -f "$test_dir/ArtistCatalogRegression.swift" "$test_dir/catalog-tests"; rmdir "$test_dir"' EXIT
ruby - "$project_root" "$test_dir/ArtistCatalogRegression.swift" <<'RUBY'
root, destination = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift'))
fixture = File.read(File.join(root, 'Tests/MusicServer/ArtistCatalogRegression.swift'))
def extract(source, signature)
  start = source.index(signature) or abort "Missing production signature: #{signature}"
  source[start..-1].split("\n    }", 2).first + "\n    }"
end
methods = ['func allArtists(', 'private func artistCatalogBatch(', 'nonisolated private static func decodeArtistCatalog(', 'func setArtistFavorite(', 'private func validate('].map { |s| extract(source, s) }.join("\n\n    ")
fixture.sub!('// PRODUCTION_ARTIST', source[/struct MusicServerArtist \{[^\n]+/])
fixture.sub!('// PRODUCTION_ERROR', source[/enum MusicServerError: LocalizedError \{.*?\n\}/m])
fixture.sub!('// PRODUCTION_METHODS', methods)
File.write(destination, fixture)
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wakemusic-catalog-module-cache \
  "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" \
  "$test_dir/ArtistCatalogRegression.swift" -o "$test_dir/catalog-tests"
"$test_dir/catalog-tests"
