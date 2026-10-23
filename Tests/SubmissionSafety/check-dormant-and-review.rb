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

removed_files = %w[
  DonateViewController.swift DonateViewController+Pay.swift
  GuideRatingViewCell.swift FreeStreamViewController.swift
]
project = File.read('Mobie/Mobie.xcodeproj/project.pbxproj')
sources = Dir.glob('Mobie/Mobie/**/*.swift')
removed_files.each do |name|
  check.call(sources.none? { |path| File.basename(path) == name }, "Remove discontinued file #{name}")
  check.call(!project.include?(name), "Remove all target references for #{name}")
end

profile = File.read('Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/ProfileViewController.swift')
model = File.read('Mobie/Mobie/Business/OtherModule/ProfileModule/Model/SettingGroupCellModel.swift')
%w[GuideRatingViewCell guideRanting rantingGroup DonateViewController].each do |symbol|
  check.call(!profile.include?(symbol) && !model.include?(symbol), "Remove dormant Profile path #{symbol}")
end
manager = File.read('Mobie/Mobie/Base/Core/Purcharge/AppStoreKitManager.swift')
check.call(!manager.include?('donationArray'), 'Remove unused donation-product state')
check.call(manager.include?('saleArray'), 'Preserve active Premium products')

batch = File.read('Mobie/Mobie/Business/MusicModule/Controller/BatchEditSuccessController.swift')
%w[isGuideScore successRate guideFiveStarRating isGuideFiveStar wakeTag].each do |symbol|
  check.call(!batch.include?(symbol), "Remove selective rating or incorrect app reference #{symbol}")
end
check.call(!batch.include?('requestReview'), 'Completion card does not automatically request a rating')
check.call(batch.include?('containerView.addSubview(rateButton)'), 'Keep a user-initiated review action')
check.call(batch.include?('containerView.addSubview(shareButton)'), 'Keep a separate share action for all results')
check.call(batch.include?('Application.wakeMusic.appstoreWriteURL()'), 'Review the current Wakemusic edition')
check.call(batch.include?('Application.wakeMusic.appstoreURL()'), 'Share the current Wakemusic edition')
check.call(batch.include?('Review.WriteReview'), 'Use a neutral review title')
check.call(!batch.include?('free trial is almost over'), 'Do not invent trial expiry')
check.call(batch.include?('min(count, max(0, missingTagCount))'), 'Clamp tag result counts to the batch size')
check.call(batch.include?('if missingCount > 0'), 'Display every partial result, including one or two missing tags')

application = File.read('LocalSDK/KakaFoundation/Classes/Base/Application.swift')
music_id = application.match(/case \.wakeMusic:\s*return isProTarget \? "([0-9]+)" : "([0-9]+)"/)
check.call(music_id && music_id.captures == %w[6740429002 6544783918], 'Keep correct Pro and ordinary App Store IDs')
check.call(File.read('Mobie/Mobie/Base/Music/KakaMusicPlayer+Delegate.swift').include?('SKStoreReviewController.requestReview'), 'Preserve existing system review behavior elsewhere')

catalog = JSON.parse(File.read('Mobie/Mobie/System/Localizable.xcstrings')).fetch('strings')
review = catalog.fetch('Review.WriteReview').fetch('localizations')
expected_locales = catalog.fetch('Share with Friends').fetch('localizations').keys | ['en']
check.call((expected_locales - review.keys).empty?, 'Localize the neutral review title in every supported locale')
review.each do |locale, entry|
  check.call(!entry.dig('stringUnit', 'value').to_s.strip.empty?, "Nonempty review title for #{locale}")
end
removed_keys = [
  'Donate', 'Support Us', 'Thank you for your support!', 'We need your help', 'Rate Us 5 Stars',
  'Awesome! %d tracks fully updated. Enjoying the app? Leave us a review on the App Store!',
  'Your free trial is almost over! Enjoying our auto-tagging algorithm? Upgrade to Lifetime Premium with a one-time purchase for permanent access.',
  'If you think we are not bad, please give us a 5 star rating or recommend it to your friends. Thank you for your support!',
  "This is a large project, and we're committed to providing you with the best possible music experience. Your donation not only supports our work, but also helps us continue improving the app and bringing you new features. Thank you for your support!"
]
removed_keys.each do |key|
  check.call(!catalog.key?(key), "Remove unused or misleading localization: #{key}")
  check.call(sources.none? { |path| File.read(path).include?("\"#{key}\".localStr()") }, "No dangling localization call: #{key}")
end

puts "#{checks} dormant-feature / review-integrity source and localization checks passed"
