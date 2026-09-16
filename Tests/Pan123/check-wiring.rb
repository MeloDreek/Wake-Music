require 'json'
require 'open3'
root = File.expand_path('../..', __dir__)
checks = 0
check = ->(ok, message) { abort(message) unless ok; checks += 1 }
read = ->(path) { File.read(File.join(root, path)) }
{
  'LocalSDK/AppGroupKit/Classes/CoreData/Music/MusicItemModel.swift' => ['public var pan123File:', 'self.fileSourceType = .from123Drive'],
  'LocalSDK/AppGroupKit/Classes/CoreManager/Manager/ServerConfigModel.swift' => ['public var pan123User:', 'lhs.pan123User == rhs.pan123User'],
  'Mobie/Mobie/Base/Core/Extension/Pan123DriveService.swift' => ['routeImportedServer(server)', 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly', 'file.status <= 100'],
  'Mobie/Mobie/Base/Music/KakaMusicPlayer+Play.swift' => ['handlePan123Streaming(model, resumeTime: pcloudResumeTime)'],
  'Mobie/Mobie/Business/ImportModule/Controller/DownloadViewController+Action.swift' => ['Pan123DriveService.shared.fileURL(file)', 'Pan123DriveAPI.validDownloadURL(url)'],
  'Mobie/Mobie/Base/Music/KakaMusicPlayer.swift' => ['Pan123DriveService.shared.fileURL(file)', 'Pan123DriveAPI.validDownloadURL(url)'],
  'Mobie/Mobie/Base/Core/Extension/ConnectConfigManager+Extension.swift' => ['Pan123DriveService.shared.unlink(user)', '$0.pan123File?.pan123User != user'],
  'Mobie/Mobie/System/SceneDelegate.swift' => ['Pan123DriveService.isCallback(firstURL)']
}.each { |path, snippets| snippets.each { |s| check.call(read.call(path).include?(s), "Missing integration: #{path}: #{s}") } }

%w[Mobie Mobie_Pro].each do |target|
  output, status = Open3.capture2('plutil','-convert','json','-o','-',File.join(root,"Mobie/Mobie/System/#{target}.plist"))
  check.call(status.success?, "Invalid plist: #{target}")
  schemes=JSON.parse(output).fetch('CFBundleURLTypes').flat_map { |x| x['CFBundleURLSchemes'] || [] }
  expected=target == 'Mobie' ? 'wakemusic-123pan' : 'wakemusicpro-123pan'
  other=target == 'Mobie' ? 'wakemusicpro-123pan' : 'wakemusic-123pan'
  check.call(schemes.include?(expected) && !schemes.include?(other), "Cross-app callback collision: #{target}")
end
catalog=JSON.parse(read.call('Mobie/Mobie/System/Localizable.xcstrings')).fetch('strings')
keys=Dir.glob(File.join(root,'Mobie/Mobie/**/*.swift')).flat_map { |p| File.read(p).scan(/"(Pan123\.[A-Za-z]+)"/).flatten }.uniq
locales=catalog.fetch('Guangya.Name').fetch('localizations').keys
keys.each do |key|
  locales.each do |locale|
    unit=catalog.fetch(key).fetch('localizations').fetch(locale).fetch('stringUnit')
    check.call(unit['state']=='translated' && !unit['value'].empty?, "Missing localization: #{key} #{locale}")
  end
end
api=read.call('Mobie/Mobie/Base/Core/Extension/Pan123DriveAPI.swift')
tag=catalog.fetch('ConnectionTag.UpTo5PB').fetch('localizations')
locales.each { |locale| check.call(tag.fetch(locale).fetch('stringUnit')['state']=='translated', "Missing 115 capacity localization: #{locale}") }
list=read.call('Mobie/Mobie/Business/ConnectModule/Controller/Pan123DriveFileListController.swift')
check.call(list.include?('parentPath: folderPath') && list.include?('(["Pan123.Name".localStr()] + folderPath).joined(separator: "/")'), '123 folder traversal must retain the full breadcrumb')
check.call(!api.match?(/print\(|debugPrint\(/), 'Never log token URLs or response bodies')
puts "#{checks} 123 Drive wiring/localization checks passed"
