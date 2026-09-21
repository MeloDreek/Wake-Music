require 'pathname'
require 'json'
root = Pathname.new(__dir__).join('../..').realpath
base = root.join('Mobie/Mobie/Business/MusicServerModule')
%w[MusicServerArtistsViewController MusicServerBrowseViewController NavidromeHomeViewController MusicServerLibraryViewController].each do |name|
  source = base.join("UI/#{name}.swift").read
  raise "Non-native table: #{name}" unless source.include?('style: .insetGrouped') && !source.include?('tableView.backgroundColor =')
end
artists = base.join('UI/MusicServerArtistsViewController.swift').read
raise 'Missing uncached loading explanation' unless artists.include?('!session.hasCachedArtistCatalog') && artists.include?('MusicServer.Artists.InitialLoadHint')
home = base.join('UI/NavidromeHomeViewController.swift').read
raise 'Missing native web footer' unless home.include?('.underlineStyle:') && home.include?('tableView.tableFooterView = webFooter') && home.include?('SFSafariViewController(url: url)')
session = base.join('Data/MusicServerSession.swift').read
%w[user password query fragment].each { |field| raise "Website URL leaks #{field}" unless session.include?("components.#{field} = nil") }
catalog = JSON.parse(root.join('Mobie/Mobie/System/Localizable.xcstrings').read)['strings']
%w[MusicServer.Artists.InitialLoadHint MusicServer.Home.ViewOnWeb].each do |key|
  translations = catalog.fetch(key).fetch('localizations')
  raise "Incomplete translations: #{key}" unless translations.size == 42 && translations.values.all? { |v| v.dig('stringUnit', 'state') == 'translated' && !v.dig('stringUnit', 'value').empty? }
end
puts 'Native list, loading hint, browser footer and 42-locale contracts passed.'
