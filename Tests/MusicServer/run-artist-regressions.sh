#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-artists.XXXXXX)
trap 'rm -f "$test_dir/ArtistLocalIndex.swift" "$test_dir/artist-tests"; rmdir "$test_dir"' EXIT
ruby - "$project_root/Mobie/Mobie/Business/MusicServerModule/UI/MusicServerArtistsViewController.swift" "$test_dir/ArtistLocalIndex.swift" <<'RUBY'
source = File.read(ARGV[0])
helper = source.split("struct MusicServerArtistIndexRecord: Sendable {", 2).last&.split("\nprivate final class MusicServerArtistCell", 2)&.first
abort "Production artist local index missing" unless helper
File.write(ARGV[1], "import Foundation\nstruct MusicServerArtistIndexRecord: Sendable {" + helper)
abort "UI must load the complete artist directory" unless source.include?('try await session.allArtists(forceReload: forceReload, onProgress:')
abort "Explicit refresh must bypass the complete directory snapshot" unless source.include?('loadAllArtists(forceReload: true)')
abort "UI must not expose paging" if source.include?('loadNextPage(') || source.include?('MusicServerStatusCell') || source.include?('artistPage(')
abort "Artists must use grouped style" unless source.include?('UITableView(frame: .zero, style: .grouped)')
abort "Loading/empty/error must use the full-screen state view" unless source.include?('MusicServerLoadingView()') && source.include?('contentView.safeAreaLayoutGuide')
abort "Search is disabled until the complete directory is indexed" unless source.include?('searchTextField.isEnabled = false') && source.include?('searchTextField.isEnabled = true')
abort "Stale search completions require both identities" unless source.include?('self.generation == requestGeneration') && source.include?('self.searchGeneration == filterGeneration')
abort "Search must remain local" unless source.include?('MusicServerArtistLocalIndex.filter(records, query: nextQuery')
abort "Main-actor grouping must yield for large libraries" unless source.include?('offset.isMultiple(of: 64)') && source.include?('await Task.yield()')
abort "Sorting/filtering must run off the main actor" unless source.include?('Task.detached(priority: .userInitiated)')
abort "Root exit must invalidate mutations" unless source.include?('self.mutationGeneration == mutationGeneration')
abort "Explicit refresh should accept server-side favorite changes" unless source.include?('if mutations.isEmpty { favoriteOverrides.removeAll() }')
abort "Locale-aware alphabetical sections are required" unless source.include?('UILocalizedIndexedCollation.current()') && source.include?('sectionIndexTitles(for tableView: UITableView)')
RUBY
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wakemusic-artist-module-cache \
  "$test_dir/ArtistLocalIndex.swift" \
  "$project_root/Tests/MusicServer/ArtistLocalIndexRegression.swift" \
  -o "$test_dir/artist-tests"
"$test_dir/artist-tests"
