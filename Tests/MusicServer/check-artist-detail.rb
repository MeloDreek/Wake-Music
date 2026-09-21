require 'pathname'
require 'json'
root = Pathname.new(__dir__).join('../..').realpath
base = root.join('Mobie/Mobie/Business/MusicServerModule')
artist = base.join('UI/MusicServerArtistDetailViewController.swift').read
browse = base.join('UI/MusicServerBrowseViewController.swift').read
actions = base.join('UI/MusicServerSongActions.swift').read
shelf = base.join('UI/NavidromeRecentViewCell.swift').read
checks = {
  'format-based shelf placeholder' => shelf.include?('artworkPlaceholder.image = model.placeImage()') && !shelf.include?('UIImage(systemName: "music.note")'),
  'shared music rows and menus for all songs' => browse.include?('as! MusicTableViewCell') && browse.include?('cellType: .navidromeTrack') && browse.include?('songActions.handle(model: model, action: action)'),
  'artist navigation from lists and song menus' => browse.scan('MusicServerArtistDetailViewController(session: session').count == 2,
  'native background retained' => artist.include?('style: .insetGrouped') && !artist.include?('backgroundColor ='),
  'scrollable centered profile' => artist.include?('tableView.tableHeaderView = header') && artist.include?('nameLabel.textAlignment = .center'),
  'top songs use the favorite shelf' => artist.include?('NavidromeFavoriteViewCell.self') && artist.include?('NavidromeRecentViewCell.preferredHeight'),
  'independent cancellable sections' => artist.include?('for section in Section.allCases { load(section) }') && artist.include?('generation == expected'),
  'artwork is downsampled' => artist.include?('DownsamplingImageProcessor') && artist.include?('prepareForReuse()'),
  'account-scoped mutations' => actions.include?('MusicServerSession.identity(for: user) == session.accountID'),
  'complete right-side actions' => %w[setSongFavorite addSongToPlaylist DownloadManager .artistDetial .albumDetial].all? { |word| actions.include?(word) }
}
checks.each { |message, ok| abort message unless ok }
catalog = JSON.parse(root.join('Mobie/Mobie/System/Localizable.xcstrings').read)['strings']
%w[TopSongs SimilarArtists NoTopSongs NoSimilarArtists].each do |key|
  translations = catalog.fetch("MusicServer.Artist.#{key}").fetch('localizations')
  abort "Missing translations: #{key}" unless translations.size == 42 && translations.values.all? { |v| v.dig('stringUnit', 'state') == 'translated' }
end
puts "Artist profile/song-cell source contracts passed (#{checks.size}); all 4 new strings have 42 locales."
