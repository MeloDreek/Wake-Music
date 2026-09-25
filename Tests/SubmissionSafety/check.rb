#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
Dir.chdir(root)
checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

# Deliberately exclude vendor Pods/SDKs: their review is a separate, outstanding item.
source_files = Dir.glob('Mobie/Mobie/**/*.swift') +
  Dir.glob('LocalSDK/Kaka{Foundation,UIKit,ObjcKit}/**/*.{swift,m}')
forbidden = ['_displayCornerRadius', '_titleTextColor', 'CATransitionType(rawValue: "cube")',
             'performSelector:@selector(view)', 'dlsym(RTLD_DEFAULT, "fork")', '/private/test29108.txt']
source_files.each do |path|
  source = File.read(path)
  forbidden.each { |pattern| assert.call(!source.include?(pattern), "#{path}: #{pattern}") }
end

ads = File.read('Mobie/Mobie/Base/Core/Tools/AppleSearchAdsManager.swift')
assert.call(ads.include?('private static let thirdPartyAttributionEnabled = false'), 'Third-party attribution must stay paused')
%w[postbackAdAttribution getDetialAdAttribution].each do |method|
  body = ads.match(/func #{method}\([^\n]+\{(.*?)\n    \}/m)&.[](1)
  assert.call(body && body.lstrip.start_with?('guard Self.thirdPartyAttributionEnabled else { return }'), "Gate #{method} before requests/parameters")
end
assert.call(ads.include?('https://api-adservices.apple.com/api/v1/'), 'Keep official Apple attribution')

manifest, status = Open3.capture2('plutil', '-convert', 'json', '-o', '-', 'Mobie/Mobie/System/PrivacyInfo.xcprivacy')
assert.call(status.success?, 'Valid privacy plist')
apis = JSON.parse(manifest).fetch('NSPrivacyAccessedAPITypes')
disk = apis.find { |item| item['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryDiskSpace' }
assert.call(disk && disk['NSPrivacyAccessedAPITypeReasons'].include?('E174.1'), 'Declare disk space check before downloading')

all_app = Dir.glob('Mobie/Mobie/**/*.swift').map { |path| File.read(path) }.join("\n")
credential_logs = ['谷歌配置信息 =', 'DropBox授权成功 =', '刷新115网盘token =',
                   'loginModel.access_token =', '下载header =', '登录Nav =', '歌词Token =',
                   '跳转回来的URL =', '⏭️URL =', '开始播放新URL =', '获取115生活下载地址 =']
log_lines = all_app.lines.grep(/\b(?:debugPrint|print|NSLog)\(/).join
credential_logs.each { |text| assert.call(!log_lines.include?(text), "Remove credential log: #{text}") }

tip = File.read('LocalSDK/KakaObjcKit/Classes/CustomUI/CMPopTipView.m')
assert.call(tip.include?('UIView *targetView = barButtonItem.customView;'), 'Tooltip uses public customView')
background = File.read('Mobie/Mobie/Business/PlayerModule/Controller/PlayBackgroundListController.swift')
assert.call(background.include?('UIBarButtonItem(customView: button)'), 'Tooltip caller supplies an actual anchor')
assert.call(background.include?('#selector(uploadCustomBackground)'), 'Retain wallpaper action')

picker = File.read('Mobie/Mobie/Business/ImportModule/Controller/VideoConverterViewController+Action.swift')
assert.call(!picker.include?('PHPhotoLibrary.requestAuthorization'), 'Video PHPicker must not require full-library access')
assert.call(picker.include?('PHPickerViewController(configuration: config)'), 'Retain video selection')

# Explicitly retained at the user's request pending their authorization review.
assert.call(File.read('Mobie/Mobie/Business/ConnectModule/Controller/GuangyaDriveFileListController.swift').include?('https://www.guangyapan.com/#/vip-center'), 'Keep requested membership link')
assert.call(File.read('Mobie/Mobie/Base/Core/Tools/MusicTagEditor+Embed.swift').include?('TaglibMetadataParser.setCoverArt'), 'Keep artwork embedding')
puts "#{checks} submission safety source/config checks passed (not a final Archive certification)"
