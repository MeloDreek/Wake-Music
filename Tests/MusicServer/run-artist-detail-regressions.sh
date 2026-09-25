#!/bin/bash
set -euo pipefail
artist_root="$(cd "$(dirname "$0")/../.." && pwd)"
artist_temp="$(mktemp -d /private/tmp/wake-artist-detail.XXXXXX)"
ruby - "$artist_root" "$artist_temp" <<'RUBY'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift'))
fixture = File.read(File.join(root, 'Tests/MusicServer/ArtistDetailRegression.swift'))
methods = ['func artistDetails(id:', 'func artistTopSongs(name:', 'func artistInfo(id:', 'func similarArtists(id:', 'private func records(_ response:'].map do |signature|
  start = source.index(signature) or abort "Missing #{signature}"
  source[start..].split("\n    }", 2).first + "\n    }"
end
File.write(File.join(output, 'Test.swift'), fixture.sub('// PRODUCTION_METHODS', methods.join("\n    ")))
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
  -module-cache-path /private/tmp/wake-artist-detail-modules \
  "$artist_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" "$artist_temp/Test.swift" -o "$artist_temp/test"
"$artist_temp/test"
