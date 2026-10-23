#!/usr/bin/env ruby
require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

# Audit application code and first-party libraries, not bundled third-party code.
# StoreKit's requestReview and an explicit write-review URL are outbound review
# actions: neither returns the user's review nor the app's rating to the app.
first_party_roots = %w[
  Mobie/Mobie LocalSDK/AppGroupKit LocalSDK/KakaFoundation LocalSDK/KakaUIKit
  LocalSDK/KakaObjcKit LocalSDK/KakaPhotoBrowser LocalSDK/WakeMusicPlayer
  LocalSDK/KakaTaglibKit/Classes
]
sources = first_party_roots.flat_map do |directory|
  Dir.glob("#{directory}/**/*.{swift,m,mm,h}")
end.reject { |path| path.include?('/TagLib/') }.sort
check.call(!sources.empty?, 'Locate application and first-party sources')

forbidden = {
  /averageUserRating(?:ForCurrentVersion)?/i => 'App Store average-rating payload',
  /userRatingCount(?:ForCurrentVersion)?/i => 'App Store rating-count payload',
  %r{(?:rss/)?customerreviews(?:/|\?)}i => 'App Store customer-review retrieval endpoint',
  /(?:fetch|get|load|request)(?:Current)?App(?:Store)?(?:Rating|Score)/i => 'Application-rating retrieval method',
  /\b(?:requestApplication|AppStoreInfoModel|SingleImageCollectionCell|StarRatingView)\b/ => 'Removed application-info lookup or unused rating UI',
  %r{itunes\.apple\.com/[^"\n]*lookup\?id=} => 'Whole-app lookup that also returns rating fields'
}
sources.each do |path|
  text = File.read(path)
  forbidden.each do |pattern, description|
    check.call(!text.match?(pattern), "#{description} must not be present in #{path}")
  end
end

# The QR-code page needs a localized brand name, not a network app record that
# includes ratings. The previous screenshot collection was not even displayed.
removed_files = [
  'Mobie/Mobie/Business/OtherModule/TabbarModule/Mac/AppStoreInfoModel.swift',
  'LocalSDK/KakaUIKit/Classes/Utils/StarRatingView.swift'
]
projects = %w[Mobie/Mobie.xcodeproj/project.pbxproj Pods/Pods.xcodeproj/project.pbxproj]
removed_files.each do |path|
  check.call(!File.exist?(path), "Remove unused #{path}")
  projects.each do |project|
    check.call(!File.read(project).include?(File.basename(path)), "Remove dangling build reference in #{project}: #{path}")
  end
end
download_page = File.read('Mobie/Mobie/Business/OtherModule/TabbarModule/Mac/LargeImageViewController.swift')
check.call(download_page.include?('Application.wakeMusic.appTitle()'), 'Use the localized Wakemusic brand name offline')
check.call(download_page.include?('Application.wakeTag.appTitle()'), 'Use the localized Waketag brand name offline')
check.call(download_page.include?('view.text = appType.applicationTitle()'), 'Populate the caption without a request')
check.call(download_page.include?('self.view.addSubview(qrcodeView)'), 'Preserve the QR-code view')
check.call(download_page.include?('"Download for iOS".localStr()'), 'Preserve the localized iOS-download title')
check.call(!download_page.include?('UICollectionView'), 'Remove the never-displayed screenshot collection')
%w[APIManager URLSession Alamofire].each do |network_type|
  check.call(!download_page.include?(network_type), "QR-code page has no #{network_type} request")
end

application = File.read('LocalSDK/KakaFoundation/Classes/Base/Application.swift')
check.call(application.include?('?action=write-review'), 'Preserve user-initiated App Store reviews')
check.call(File.read('Mobie/Mobie/Base/Core/Tools/MusicTagEditor.swift').include?('requestITunesAlbumImages'),
           'Do not confuse music-catalog artwork search with application ratings')

puts "#{checks} application-rating retrieval checks passed across #{sources.length} first-party source files"
