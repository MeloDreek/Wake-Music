#!/usr/bin/env ruby
require 'json'
require 'open3'
root = File.expand_path('../..', __dir__)
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  abort("FAIL: #{message}") unless condition
  checks += 1
end
read = ->(path) { File.read(path) }
project_json, _, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', 'Mobie/Mobie.xcodeproj/project.pbxproj')
check.call(status.success?, 'Project parses')
objects = JSON.parse(project_json).fetch('objects')
check.call(!objects.values.any? { |o| o['productName'] == 'MSAL' || o['repositoryURL'].to_s.include?('microsoft-authentication-library-for-objc') }, 'No platform-incompatible MSAL dependency remains')
%w[Mobie Mobie_Pro].each do |name|
  target = objects.values.find { |o| o['isa'] == 'PBXNativeTarget' && o['name'] == name }
  sources = target.fetch('buildPhases').flat_map { |id| objects[id]['isa'] == 'PBXSourcesBuildPhase' ? objects[id]['files'] : [] }
  %w[OneDriveOAuthClient.swift OneDriveOAuthManager.swift].each do |file|
    check.call(sources.count { |id| objects[objects[id]['fileRef']]&.dig('path') == file } == 1, "#{name}: #{file} compiled exactly once")
  end
  plist_json, _, result = Open3.capture3('plutil', '-convert', 'json', '-o', '-', "Mobie/Mobie/System/#{name}.plist")
  check.call(result.success?, "#{name}: valid Info.plist")
  plist = JSON.parse(plist_json)
  bundle = name == 'Mobie' ? 'com.OfflineMusic.www' : 'com.OfflineMusic.www.pro'
  schemes = plist.fetch('CFBundleURLTypes').flat_map { |value| value.fetch('CFBundleURLSchemes', []) }
  check.call(schemes.include?("msauth.#{bundle}"), "#{name}: retain registered public-client redirect scheme")
  check.call((plist.fetch('LSApplicationQueriesSchemes') & %w[msauthv2 msauthv3]).empty?, "#{name}: no unused broker discovery")
end
pins = JSON.parse(read.call('Wake Music.xcworkspace/xcshareddata/swiftpm/Package.resolved')).fetch('pins')
check.call(!pins.any? { |p| p['identity'] == 'microsoft-authentication-library-for-objc' }, 'No stale MSAL lock pin')
constants = read.call('LocalSDK/AppGroupKit/Classes/Const/AppGroupConstKey.swift')
check.call(constants.include?('"msauth.\\(bundleID)://auth"'), 'Redirect tracks the running edition')
scene = read.call('Mobie/Mobie/System/SceneDelegate.swift')
check.call(scene.include?('if OneDriveOAuthManager.isCallback(firstURL) { return }'), 'Suppress OAuth callbacks before general URL logging')
types = read.call('Mobie/Mobie/Business/ImportModule/Model/ImportFileType+Extension.swift')
cloud = types[/static func cloudDriveArray\(\).*?let mainlandChinaArray/m]
check.call(cloud&.include?('.fromOneDrive') && !cloud.include?('#if'), 'OneDrive is available on both iOS and Catalyst')
availability = read.call('LocalSDK/AppGroupKit/Classes/Const/ImportFileType.swift')[/public func isAvailble\(\) -> Bool \{.*?\n    \}/m]
check.call(availability&.include?('self == .fromOneDrive'), 'OneDrive is available, not Coming Soon')
api = read.call('Mobie/Mobie/Base/Music/KakaMusicPlayer+API.swift')
check.call(api.scan('OneDriveOAuthManager.shared.request(user: user, url: url)').length == 2, 'Listing and download URL use Keychain OAuth requests')
check.call(api.include?('components.path = "/v1.0/me/" + path.trimmingCharacters'), 'Folder names are URL-encoded')
check.call(api.include?('components.path = "/v1.0/me/drive/items/" + onedriveFile.id'), 'Item URLs encode IDs')
check.call(api.include?('download.scheme == "https"') && api.include?('download.user == nil, download.password == nil'), 'Signed downloads are HTTPS without embedded credentials')
download = read.call('Mobie/Mobie/Business/ImportModule/Model/DownloadManager+Tasks.swift')
check.call(download.include?('fetchOneDriveFileDetail(onedriveFile: file, completion: callback)'), 'Queued downloads refresh expiring signed URLs')
manager = read.call('Mobie/Mobie/Base/Core/Extension/OneDriveOAuthManager.swift')
check.call(manager.include?('ASWebAuthenticationSession(url:') && !manager.include?('#if'), 'The same system OAuth session works on both platforms')
check.call(manager.include?('self.authorizationID == attempt, !self.handledCallback') && manager.include?('self.handledCallback = true'), 'Consume a login callback only once')
check.call(manager.include?('kSecClassGenericPassword') && manager.include?('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'), 'Save OAuth secrets in device-only Keychain')
check.call(manager.include?('graphID == profile.id') && manager.include?('homeID == received'), 'Migrate legacy identity only with a verified stable identity, not email')
check.call(manager.include?('previousIdentityMatches ? previous?.path : nil') && manager.include?('OneDrive.LegacyAccountKept'), 'Retain matching-account paths; preserve and explain unknown legacy accounts')
check.call(manager.include?('!ConnectConfigManager.shared.connectedModels.contains(where:'), 'Do not resurrect a deleted account during reauthorization')
model = read.call('LocalSDK/AppGroupKit/Classes/CoreData/CloudDrive/OneDriveUserModel.swift')
%w[accessToken authHeader authScheme].each do |field|
  check.call(model.include?("@SmartIgnored public var #{field}:"), "Do not serialize legacy secret field #{field}")
end
connections = read.call('Mobie/Mobie/Base/Core/Extension/ConnectConfigManager+Extension.swift')
disconnect = connections[/if let user = serverModel.onedriveUser \{\n            OneDriveOAuthManager.shared.unlink\(user\).*?\n        \}/m]
check.call(disconnect&.include?('self.lastPlaylist =') && disconnect.include?('player.musicArray =') && disconnect.include?('player.tempMusicArray =') && disconnect.include?('player.resetToPausedDemo(clearRemotePlaylist: false)'), 'Disconnect clears Keychain, queued songs and live playback')
list = read.call('Mobie/Mobie/Business/ConnectModule/Controller/OneDriveFileListController.swift')
check.call(list.include?('wSelf.requestGeneration == generation'), 'Ignore superseded list refresh callbacks')
check.call(list.include?('wSelf.allfileArray = refreshedFiles') && !list.include?('wSelf.allfileArray.append(contentsOf: tempArray)'), 'Refresh replaces rather than duplicates existing rows')
check.call(list.include?('loadedIDs.insert($0.id).inserted') && list.include?('visitedCursors.insert(cursor).inserted'), 'Deduplicate rows and repeated pagination cursors')
check.call(list.include?('replacing: loginModel') && list.include?('self?.title = user.pageTitle()'), 'Reauthorization updates folder title from the identity-aware result')
%w[Business/ImportModule/Controller/ImportViewController+Drive.swift Business/ConnectModule/Controller/ConnectListViewController+Connect.swift Business/ConnectModule/Controller/OneDriveFileListController.swift].each do |path|
  source = read.call('Mobie/Mobie/' + path)
  check.call(source.include?('OneDriveOAuthManager.shared.authorize(from: self') && !source.include?('MSAL'), "#{File.basename(path)}: formal system OAuth entrance")
end
puts "#{checks} OneDrive integration checks passed (live Microsoft authorization not exercised)"
