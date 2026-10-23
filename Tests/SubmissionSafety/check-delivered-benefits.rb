#!/usr/bin/env ruby
require 'json'
require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

benefits = File.read('Mobie/Mobie/Business/PlayerModule/Model/VIPBenefitsModel.swift')
paywall = File.read('Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/PurchaseViewController.swift')
catalog = JSON.parse(File.read('Mobie/Mobie/System/Localizable.xcstrings')).fetch('strings')
shipped_cases = %w[allFormats audioFingerprint batchAutoEdit allPlayerStyle allCloudDrive lyricFeature advancedSetting allAppleOS]
actual_cases = benefits.scan(/^    case (\w+)$/).flatten
check.call(actual_cases == shipped_cases, 'Keep delivered benefits and their existing display order only')
check.call(benefits.include?('enum VIPBenefitsModel: CaseIterable'), 'Keep the CaseIterable benefit model')
check.call(paywall.include?('return VIPBenefitsModel.allCases'), 'Keep the paywall driven by the delivered benefit list')
check.call(paywall.include?('let benefits = benefitArray[indexPath.row]'), 'Keep visible paywall benefit rows connected to that list')
check.call(!benefits.match?(/newMore|Apple Watch|CarPlay|future premium features/), 'Do not advertise unreleased Watch, CarPlay or unspecified future benefits')
shipped_cases.each do |name|
  check.call(benefits.scan(/^        case \.#{Regexp.escape(name)}:/).size == 3,
             "Keep title, description and icon for delivered benefit #{name}")
end
removed_keys = [
  'More Advanced Features',
  'All future premium features! E.g., Apple Watch, native CarPlay, more cloud storage, and more'
]
sources = Dir.glob('Mobie/Mobie/**/*.swift') + Dir.glob('LocalSDK/AppGroupKit/Classes/**/*.swift')
removed_keys.each do |key|
  check.call(!catalog.key?(key), "Remove obsolete future-benefit localization: #{key}")
  check.call(sources.none? { |path| File.read(path).include?(key) }, "No source references to future-benefit localization: #{key}")
end

puts "#{checks} delivered-benefit / paywall description checks passed"
