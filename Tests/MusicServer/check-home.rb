require 'pathname'
root = Pathname.new(__dir__).join('../..').realpath
home = root.join('Mobie/Mobie/Business/MusicServerModule/UI/NavidromeHomeViewController.swift').read + root.join('Mobie/Mobie/Business/MusicServerModule/UI/NavidromeSection.swift').read
cells = %w[NavidromeRecentViewCell NavidromeOverviewCell].map { |name| root.join("Mobie/Mobie/Business/MusicServerModule/UI/#{name}.swift").read }.join
checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
assert.call(home.include?('case .random: return 30') && home.include?('case .recentlyAdded: return 20'), 'Bound random shelves to 30 and recent uploads to 20')
assert.call(home.include?('self == .recent || self == .favorites || self == .random'), 'Random uses the same horizontal shelf interaction as favorites')
assert.call(home.include?('case overview, recent, favorites, playlists, random, recentlyAdded'), 'Recent uploads follows random discovery')
assert.call(home.include?('cellType: .navidromeTrack') && home.include?('MusicTableViewCellDelegate'), 'Home music rows use the shared music cell and functional menus')
assert.call(cells.include?('NavidromeSongListCollectionCell') && cells.include?('collectionView.isPagingEnabled = true'), 'Song previews use full-width paged song rows')
assert.call(home.include?('style: .insetGrouped') && home.include?('view.backgroundColor = .systemGroupedBackground'), 'Home uses native grouped table appearance')
assert.call(cells.include?('systemLayoutSizeFitting') && cells.include?('CGFloat(min(3, items.count))'), 'List height must have at most three rows')
assert.call(home.include?('onSongAction:') && home.include?('handleSongAction(model:'), 'Grid and uploaded-song row menus share one action handler')
assert.call(home.include?('items = try await session.allPlaylists()'), 'Show all accessible playlists')
assert.call(home.include?('section == .playlists ? unique'), 'Never truncate playlists to the preview limit')
assert.call(home.include?('if kind.isShelf { return 1 }'), 'Each horizontal song shelf occupies one outer table row')
assert.call(home.include?('NavidromeRecentViewCell'), 'Song shelves must scroll horizontally')
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
