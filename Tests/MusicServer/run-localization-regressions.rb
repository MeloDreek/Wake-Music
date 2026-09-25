#!/usr/bin/env ruby
# Run from any working directory; validates the new music-server module's UI copy.
require 'json'

root = File.expand_path('../..', __dir__)
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings')))
strings = catalog.fetch('strings')
expected_locales = %w[
  ar ca cs da de el en en-AU en-GB en-IN es es-419 es-US fi fr fr-CA he hi hr hu id it ja ko
  ms nb nl pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-HK zh-Hans zh-Hant
].sort

new_keys = [
  'Search songs, artists, or albums.', 'No search results. Try another keyword.',
  'Classic Mode', 'Back to Classic Mode', 'Home', 'Search', 'This section is coming soon.', 'Music Server',
  'Server Overview', 'Recently Played', 'See All', 'Albums', 'Artists', 'Radio Stations', 'Discover Music',
  'Play something to start your listening history.', 'Your favorite songs will appear here.',
  'Your playlists will appear here.', 'No music is available yet.', 'This section could not be loaded.',
  'Unable to connect to this music server.', 'Load More', 'Shuffle Play',
  'This radio station has no playable stream.',
  'Recent plays on this device and from your server.',
  'The server address is invalid.', 'Unable to sign in. Check your username and password.',
  'Your music server session has expired. Please sign in again.', 'This server does not support this feature.',
  'The music server returned an invalid response.', 'The server returned too much data. Please try a smaller page.',
  'Unable to connect to the music server. Please try again.', 'The server request timed out. Please try again.'
]

assertions = 0
check = lambda do |condition, message|
  assertions += 1
  raise message unless condition
end

new_keys.each do |key|
  record = strings.fetch(key) { raise "Missing new key: #{key}" }
  check.call(record['extractionState'] == 'manual', "New key not marked manual: #{key}")
  translations = record.fetch('localizations')
  check.call(translations.keys.sort == expected_locales, "Incomplete locales: #{key}")
  translations.each do |locale, localized|
    unit = localized.fetch('stringUnit')
    check.call(unit['state'] == 'translated', "Untranslated: #{key} / #{locale}")
    check.call(!unit.fetch('value').strip.empty?, "Empty value: #{key} / #{locale}")
    check.call(unit['value'].scan(/%(?:\d+\$)?[@diuf]/) == key.scan(/%(?:\d+\$)?[@diuf]/), "Placeholder mismatch: #{key} / #{locale}")
  end
  check.call(translations.fetch('en').fetch('stringUnit').fetch('value') == key, "English source mismatch: #{key}")
end

home_copy = JSON.parse(File.read(File.join(__dir__, 'HomeLocalizations.json')))
home_copy.fetch('keys').each_with_index do |key, index|
  record = strings.fetch(key)
  translations = record.fetch('localizations')
  check.call(record['extractionState'] == 'manual', "Home key not marked manual: #{key}")
  check.call(translations.keys.sort == expected_locales, "Incomplete home locales: #{key}")
  expected_locales.each do |locale|
    base = home_copy.fetch('aliases').fetch(locale, locale)
    expected = home_copy.fetch('translations').fetch(base).fetch(index)
    unit = translations.fetch(locale).fetch('stringUnit')
    check.call(unit['state'] == 'translated' && unit['value'] == expected, "Home translation mismatch: #{key}/#{locale}")
  end
end

source_paths = Dir.glob(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/**/*.swift'))
uploads = JSON.parse(File.read(File.join(__dir__, 'RecentUploadsLocalizations.json')))
upload_strings = strings.fetch(uploads.fetch('key')).fetch('localizations')
check.call(upload_strings.keys.sort == expected_locales, 'Recent uploads must cover every app language')
expected_locales.each do |locale|
  base = uploads.fetch('aliases').fetch(locale, locale)
  unit = upload_strings.fetch(locale).fetch('stringUnit')
  check.call(unit['state'] == 'translated' && unit['value'] == uploads.fetch('translations').fetch(base), "Recent upload translation mismatch: #{locale}")
end
%w[All\ Songs Edit\ Configuration Random\ Songs Reload Similar\ Artists].each do |key|
  check.call(!strings.key?(key), "Obsolete Navidrome-only localization remains: #{key}")
end
check.call(!source_paths.empty?, 'No module source files found')
source_paths.each do |path|
  source = File.read(path)
  literal_keys = source.scan(/"([^"\n]*)"\.localStr\(\)/).flatten
  literal_keys += source.scan(/key = "([^"\n]*)"/).flatten if path.end_with?('MusicServerSession.swift')
  literal_keys.uniq.each do |key|
    check.call(strings.key?(key), "Uncatalogued source string in #{File.basename(path)}: #{key}")
  end
end

detail_copy = JSON.parse(File.read(File.join(__dir__, 'DetailLocalizations.json')))
detail_copy.fetch('keys').each_with_index do |key, index|
  translations = strings.fetch(key).fetch('localizations')
  check.call(translations.keys.sort == expected_locales, "Incomplete detail locales: #{key}")
  expected_locales.each do |locale|
    base = detail_copy.fetch('aliases').fetch(locale, locale)
    expected = detail_copy.fetch('translations').fetch(base).fetch(index)
    unit = translations.fetch(locale).fetch('stringUnit')
    check.call(unit['state'] == 'translated' && unit['value'] == expected, "Detail translation mismatch: #{key}/#{locale}")
    check.call(unit['value'].scan(/%(?:\d+\$)?[@diuf]/) == (index == 2 ? ['%@'] : []), "Detail placeholder mismatch: #{key}/#{locale}")
  end
end

puts "Music server localization regressions passed: #{new_keys.length} original keys + detail copy, #{expected_locales.length} locales, #{assertions} assertions."
