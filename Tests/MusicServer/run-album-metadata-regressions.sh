#!/bin/bash
set -euo pipefail
album_root="$(cd "$(dirname "$0")/../.." && pwd)"
album_temp="$(mktemp -d /private/tmp/wake-album-metadata.XXXXXX)"
ruby - "$album_root" "$album_temp" <<'RUBY'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift'))
fixture = File.read(File.join(root, 'Tests/MusicServer/AlbumMetadataRegression.swift'))
methods = ['func albumDetails(id:', 'func albumDescription(id:', 'func invalidateAlbumDetails(id:',
           'private func albumSnapshot(id:', 'private func fetchAlbumSnapshot(id:',
           'private func compatiblePage(', 'private func records(_ response:'].map do |signature|
  start = source.index(signature) or abort "Missing #{signature}"
  source[start..].split("\n    }", 2).first + "\n    }"
end
cache_start = source.index('    private struct AlbumSnapshot {') or abort 'Missing album cache'
cache_end = source.index("\n\n    var hasCachedArtistCatalog:", cache_start) or abort 'Missing cache boundary'
fixture.sub!('// PRODUCTION_CACHE', source[cache_start...cache_end])
fixture.sub!('// PRODUCTION_METHODS', methods.join("\n    "))
File.write(File.join(output, 'Test.swift'), fixture)
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
  -module-cache-path /private/tmp/wake-album-metadata-modules \
  "$album_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" "$album_temp/Test.swift" -o "$album_temp/test"
"$album_temp/test"
