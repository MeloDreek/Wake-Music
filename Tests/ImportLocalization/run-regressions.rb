#!/usr/bin/env ruby
# Run from any directory: ruby Tests/ImportLocalization/run-regressions.rb
require 'json'
require 'open3'

ROOT = File.expand_path('../..', __dir__)
LANGUAGES = %w[ar ca cs da de el en en-AU en-GB en-IN es es-419 es-US fi fr fr-CA he hi hr hu id it ja ko ms nb nl pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-HK zh-Hans zh-Hant].freeze
failures = []
catalogs = {}

%w[Localizable InfoPlist].each do |name|
  path = File.join(ROOT, 'Mobie/Mobie/System', "#{name}.xcstrings")
  catalog = JSON.parse(File.read(path))
  catalogs[name] = catalog
  catalog.fetch('strings').each do |key, entry|
    # URLs and other explicitly nontranslatable entries must remain untouched.
    next if entry['shouldTranslate'] == false
    translations = entry.fetch('localizations', {})
    # Xcode uses an English source key directly when no explicit en unit exists.
    missing = LANGUAGES - translations.keys - [catalog.fetch('sourceLanguage')]
    failures << "#{name}: #{key.inspect} missing #{missing.join(', ')}" unless missing.empty?
    walk = lambda do |value, locale|
      case value
      when Hash
        if value.key?('stringUnit')
          unit = value.fetch('stringUnit')
          failures << "#{name}: #{key.inspect}/#{locale} is unfinished" unless unit['state'] == 'translated'
          failures << "#{name}: #{key.inspect}/#{locale} is empty" if unit['value'].to_s.empty?
        end
        value.each_value { |child| walk.call(child, locale) }
      when Array
        value.each { |child| walk.call(child, locale) }
      end
    end
    translations.each { |locale, value| walk.call(value, locale) }
  end
end

strings = catalogs.fetch('Localizable').fetch('strings')
%w[Local Remote].each do |key|
  failures << "Missing import section: #{key}" unless strings.key?(key)
end
{'en'=>'Remote', 'zh-Hans'=>'远程', 'zh-Hant'=>'遠端', 'zh-HK'=>'遠端'}.each do |locale, value|
  actual = strings.dig('Remote', 'localizations', locale, 'stringUnit', 'value')
  failures << "Incorrect Remote heading for #{locale}" unless actual == value
end

# Model/entry-point/permission cleanup, without banning unrelated Shazam and ALAC text.
paths = [
  'LocalSDK/AppGroupKit/Classes/Const/ImportFileType.swift',
  'LocalSDK/AppGroupKit/Classes/CoreData/Music/MusicItemModel.swift',
  'LocalSDK/AppGroupKit/Classes/CoreManager/Manager/AppLocalManager.swift',
  'Mobie/Mobie.xcodeproj/project.pbxproj'
]
paths += Dir.glob(File.join(ROOT, 'Mobie/Mobie/Business/{ImportModule,MusicModule,PlayerModule}/**/*.swift')).map { |p| p.delete_prefix(ROOT + '/') }
paths.each do |path|
  source = File.read(File.join(ROOT, path))
  if source.match?(/\bfromApple(?:Music)?\b|AppleMusicListController|isGrantedAppleMusic|NSAppleMusicUsageDescription|MPMediaLibrary|MPMediaQuery/)
    failures << "Retired media-library feature referenced in #{path}"
  end
end
failures << 'Apple Music usage description remains' if catalogs.fetch('InfoPlist').fetch('strings').key?('NSAppleMusicUsageDescription')
[
  'Mobie/Mobie/Business/MusicModule/Controller/AppleMusicListController.swift',
  'Mobie/Mobie/System/Assets.xcassets/Other/Apple_Music.imageset'
].each { |p| failures << "Retired file still exists: #{p}" if File.exist?(File.join(ROOT,p)) }

import_source = File.read(File.join(ROOT, 'Mobie/Mobie/Business/ImportModule/Controller/ImportViewController.swift'))
groups = import_source.scan(/ImportGroupModel\(group: \.(\w+), headTitle: "(\w+)"\.localStr\(\)/)
failures << "Unexpected import groups: #{groups.inspect}" unless groups == [['localGroup','Local'], ['remoteGroup','Remote']]

# Optional: verify an actual built app, including every localized permission table.
if ARGV.first
  app = File.expand_path(ARGV.first)
  plist_paths = [File.join(app, 'Info.plist')] + Dir.glob(File.join(app, '*.lproj/InfoPlist.strings'))
  plist_paths.each do |path|
    json, status = Open3.capture2('/usr/bin/plutil', '-convert', 'json', '-o', '-', path)
    if !status.success?
      failures << "Cannot read built plist: #{path}"
    elsif JSON.parse(json).key?('NSAppleMusicUsageDescription')
      failures << "Built app retains Apple Music permission: #{path}"
    end
  end
  %w[en zh-Hans zh-Hant ja de].each do |locale|
    path = File.join(app, "#{locale}.lproj/Localizable.strings")
    json, status = Open3.capture2('/usr/bin/plutil', '-convert', 'json', '-o', '-', path)
    localized = status.success? ? JSON.parse(json) : {}
    %w[Local Remote].each do |key|
      expected = strings.dig(key,'localizations',locale,'stringUnit','value') || key
      failures << "Built #{key} heading mismatch for #{locale}" unless localized[key] == expected
    end
  end
end

abort failures.join("\n") unless failures.empty?
puts "PASS: #{LANGUAGES.size} locales; no missing or unfinished translatable units; two import sections; retired feature and permission removed."
puts 'PASS: built app permissions and localized headings.' if ARGV.first
