#!/usr/bin/env ruby
# ruby Tests/Localization/check-legacy-catalog.rb [--catalog PATH] [--before PATH]
# Validates legacy English-phrase keys without requiring English display copy
# to equal the lookup key. A --before snapshot additionally guards review scope.
require 'json'
require 'optparse'
require 'open3'

root = File.expand_path('../..', __dir__)
options = { catalog: File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings') }
OptionParser.new do |parser|
  parser.on('--catalog PATH') { |path| options[:catalog] = path }
  parser.on('--before PATH') { |path| options[:before] = path }
  parser.on('--compiled-directory PATH') { |path| options[:compiled] = path }
end.parse!

LOCALES = %w[ar ca cs da de el en en-AU en-GB en-IN es es-419 es-US fi fr fr-CA he hi hr hu id it ja ko ms nb nl pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-HK zh-Hans zh-Hant].sort.freeze

def legacy_key?(key)
  !key.match?(/\A[A-Za-z][A-Za-z0-9]*\.[A-Za-z]/) && !key.start_with?('http://', 'https://')
end

# Compare argument position and type; permit an explicitly positioned argument
# when natural grammar requires reordering. %% is a literal, not an argument.
def format_arguments(string)
  sequential = 0
  string.scan(/%%|%(?:(\d+)\$)?([-+ #0']*)(\d+|\*)?(?:\.(\d+|\*))?(hh|ll|[hljztL])?([@diuoxXfFeEgGaAcCsSp])/).map do |position, flags, width, precision, length, type|
    next unless type
    sequential += 1 unless position
    [position ? position.to_i : sequential, "#{length}#{type}", width == '*', precision == '*']
  end.compact.sort
end

raw = File.read(options[:catalog])
raise 'Catalog is not valid UTF-8' unless raw.valid_encoding?
catalog = JSON.parse(raw)
raise 'Unexpected source language' unless catalog['sourceLanguage'] == 'en'
strings = catalog.fetch('strings')
scoped = strings.select { |key, _| legacy_key?(key) }
checks = 0
units = 0
scoped.each do |key, record|
  translations = record.fetch('localizations')
  missing = LOCALES - translations.keys - ['en']
  raise "Missing locales #{missing.inspect}: #{key}" unless missing.empty?
  unexpected = translations.keys - LOCALES
  raise "Unexpected locales #{unexpected.inspect}: #{key}" unless unexpected.empty?
  translations.each do |locale, node|
    unit = node.fetch('stringUnit')
    value = unit.fetch('value')
    raise "Empty string: #{key}/#{locale}" if value.strip.empty?
    raise "Untranslated string: #{key}/#{locale}" unless unit['state'] == 'translated'
    raise "Invalid control character: #{key}/#{locale}" if value.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFD]/)
    raise "Format argument mismatch: #{key}/#{locale}" unless format_arguments(value) == format_arguments(key)
    # Legacy format strings use only %@ and %d. Catch accidental trailing %,
    # which can turn the following translated word into a format instruction.
    if key.include?('%')
      remainder = value.gsub(/%%|%(?:\d+\$)?[@d]/, '')
      raise "Unexpected percent sign: #{key}/#{locale}" if remainder.include?('%')
    end
    units += 1
    checks += 5
  end
end

{
  'Rate' => 'Playback Speed',
  'Dislike' => 'Remove from Favorites',
  'Year' => 'Year',
  'Super Lossless' => 'DSD Audio',
  'Restore Purchase' => 'Restore Purchases',
  'Clear All Cache' => 'Clear All Saved File References',
  'Clear Cache for This Folder' => 'Clear File References for This Folder',
  'Subscribing' => 'Active Subscription'
}.each do |key, expected|
  raise "Missing reviewed key: #{key}" unless strings.key?(key)
  actual = strings[key].dig('localizations', 'en', 'stringUnit', 'value') || key
  raise "Context regression: #{key} => #{actual.inspect}" unless actual == expected
  checks += 1
end

if options[:compiled]
  table = File.basename(options[:catalog], '.xcstrings')
  LOCALES.each do |locale|
    path = File.join(options[:compiled], "#{locale}.lproj", "#{table}.strings")
    json, status = Open3.capture2('/usr/bin/plutil', '-convert', 'json', '-o', '-', path)
    raise "Cannot read compiled catalog: #{path}" unless status.success?
    compiled = JSON.parse(json)
    scoped.each do |key, record|
      expected = record.dig('localizations', locale, 'stringUnit', 'value') || key
      raise "Compiled translation mismatch: #{key}/#{locale}" unless compiled[key] == expected
      checks += 1
    end
  end
end

if options[:before]
  before = JSON.parse(File.read(options[:before]))
  raise 'Keys added or removed' unless before.fetch('strings').keys.sort == strings.keys.sort
  raise 'Catalog metadata changed' unless before.reject { |key, _| key == 'strings' } == catalog.reject { |key, _| key == 'strings' }
  before.fetch('strings').each do |key, old|
    current = strings.fetch(key)
    unless legacy_key?(key)
      raise "Excluded key changed: #{key}" unless old == current
      next
    end
    raise "Key metadata changed: #{key}" unless old.reject { |field, _| field == 'localizations' } == current.reject { |field, _| field == 'localizations' }
    old.fetch('localizations').each do |locale, node|
      raise "Locale removed: #{key}/#{locale}" unless current.fetch('localizations').key?(locale)
    end
  end
  checks += before['strings'].size
end

puts "Legacy localization checks passed: #{scoped.size} keys, #{LOCALES.size} locales, #{units} translated values, #{checks} checks."
