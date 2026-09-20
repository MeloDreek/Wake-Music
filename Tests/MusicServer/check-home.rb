require 'pathname'
root = Pathname.new(__dir__).join('../..').realpath
home = root.join('Mobie/Mobie/Business/MusicServerModule/UI/MusicServerHomeViewController.swift').read
cells = root.join('Mobie/Mobie/Business/MusicServerModule/UI/MusicServerCells.swift').read
checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
assert.call(home.include?('self == .random ? 50 : 12'), 'Bound song shelves and discovery separately')
assert.call(home.include?('items = try await session.allPlaylists()'), 'Show all accessible playlists')
assert.call(home.include?('section == .playlists ? unique'), 'Never truncate playlists to the preview limit')
assert.call(home.include?('if kind.isShelf { return 1 }'), 'Each horizontal song shelf occupies one outer table row')
assert.call(home.include?('MusicServerCarouselCell'), 'Song shelves must scroll horizontally')
assert.call(!home.include?('onSeeAll:'), 'Home must not show the old See All buttons')
assert.call(home.include?('actionSymbol: "plus"'), 'Playlists need a create action')
assert.call(home.include?('MusicServer.Home.RefreshBatch'), 'Discovery needs its own refresh action')
assert.call(home.include?('try await session.createPlaylist(name: name)'), 'Create action must call the account-scoped API')
assert.call(home.include?('create.isEnabled = false') && home.include?('trimmingCharacters(in: .whitespacesAndNewlines).isEmpty'), 'Reject blank playlist names')
assert.call(home.include?('cell.minimumHeight = 168'), 'Keep empty sections comfortably tall')
exit_body = home.split('@objc private func exitTapped()', 2).last.split('@objc private func recentHistoryChanged', 2).first
assert.call(!exit_body.include?('cancelPendingRequests()'), 'Exit cancellation must not stop homepage work before confirmation')
assert.call(cells.include?('UIFontNumber('), 'Overview uses the app number font')
puts "Home structural regression checks passed (#{checks}); use Simulator for layout, scrolling and exit checks."
