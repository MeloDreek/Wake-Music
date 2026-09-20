#!/usr/bin/env ruby
# The MusicServer shell replaces the old Connect-tab Navidrome screens. Keep
# their files/references out of both app targets without deleting shared models.
require 'pathname'

root = Pathname.new(__dir__).join('../..').expand_path
removed = %w[
  NavidromeViewController NavidromeSearchViewController
  NavidromeArtistListController NavidromeArtistDetialController
  NavidromeSongListController ConnectNavidromeArtistCell
  ConnectArtistTableCell ConnectMyPlayListCell ConnectSectionHeadView
  ConnectCellSection NavSongListType SearchKeyTableCell SearchArtistTableCell
]
pattern = /\b(?:#{removed.join('|')})\b/
sources = Dir[root.join('{Mobie,LocalSDK}/**/*.{swift,pbxproj}').to_s]
violations = sources.map do |path|
  path if File.read(path).match?(pattern)
end.compact
abort "Obsolete Navidrome UI references: #{violations.join(', ')}" unless violations.empty?

%w[NavidromeUserModel NavidromeSong NavidromeArtist NavidromePlaylist NavidromeAlbum].each do |name|
  path = root.join("LocalSDK/AppGroupKit/Classes/CoreData/Navidrome/#{name}.swift")
  abort "Shared model removed: #{name}" unless path.file?
end
%w[AuthNavidromeController SelectPlaylistController].each do |name|
  abort "Required shared flow removed: #{name}" unless Dir[root.join("Mobie/Mobie/**/#{name}.swift").to_s].one?
end

project = File.read(root.join('Mobie/Mobie.xcodeproj/project.pbxproj'))
artist_source_entries = project.lines.grep(/\/\* MusicServerArtistsViewController\.swift in Sources \*\/,/)
abort 'Artist screen must be compiled into both app targets' unless artist_source_entries.count == 2

%w[iOS/HomeTabbarViewController+Play.swift Mac/MacTabbarViewController+Play.swift].each do |relative|
  text = File.read(root.join("Mobie/Mobie/Business/OtherModule/TabbarModule/#{relative}"))
  abort "Missing shared-player remote fallback: #{relative}" unless text.include?('startPlayMusic(musics: [model], itemIndex: 0)')
end

puts 'Legacy Navidrome UI cleanup: no references; shared auth/models/picker retained; both targets linked.'
