require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
user_path = 'LocalSDK/AppGroupKit/Classes/CoreData/Navidrome/NavidromeUserModel.swift'
user_source = File.read(File.join(root, user_path)).sub('import SmartCodable', 'import Foundation')
user_source = user_source.sub('SmartCodableX, ', '')
tests = <<~'SWIFT'
  import Foundation
  enum AppMeta { static let name = "Wake Music + Test" }

  func user(_ host: String, _ name: String = "listener") -> NavidromeUserModel {
      var model = NavidromeUserModel()
      model.hostUrl = host
      model.username = name
      model.subsonicToken = "token+&value"
      model.subsonicSalt = "salt=?+"
      return model
  }
  let one = user("https://MUSIC.example.com:443/nav/")
  let same = user("https://music.example.com/nav")
  precondition(one.accountIdentity == same.accountIdentity)
  precondition(one.accountIdentity != user("https://music.example.com/another").accountIdentity)
  precondition(one.accountIdentity != user("https://music.example.com/nav", "another").accountIdentity)
  precondition(one.accountIdentity != user("https://other.example.com/nav").accountIdentity)
  var refreshed = one
  refreshed.subsonicToken = "new-token"
  precondition(refreshed.accountIdentity == one.accountIdentity)
  precondition(one.accountIdentity.count == 64)

  let special = user("https://music.example.com/music%20library/", "王 + & user")
  let url = special.subsonicURL(endpoint: "/rest/stream", parameters: [URLQueryItem(name:"id", value:"a/b&?+= 中")])!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  precondition(components.path == "/music library/rest/stream")
  let values = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
  precondition(values["u"] == special.username)
  precondition(values["t"] == special.subsonicToken)
  precondition(values["id"] == "a/b&?+= 中")
  precondition(!components.percentEncodedQuery!.contains("+"))
  precondition(user("file:///private/tmp").subsonicURL(endpoint: "/rest/ping") == nil)
  precondition(user("https://music.example.com/").subsonicURL(endpoint: "/rest/ping")!.path == "/rest/ping")
  print("Account identity and URL encoding checks passed")
SWIFT

Dir.mktmpdir('music-server-identity-') do |dir|
  File.write(File.join(dir, 'NavidromeUserModel.swift'), user_source)
  File.write(File.join(dir, 'main.swift'), tests)
  executable = File.join(dir, 'checks')
  env = {'DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer'}
  output, status = Open3.capture2e(env, 'xcrun', 'swiftc', File.join(dir, 'NavidromeUserModel.swift'), File.join(dir, 'main.swift'), '-o', executable)
  abort output unless status.success?
  output, status = Open3.capture2e(executable)
  abort output unless status.success?
  puts output
end

config = File.read(File.join(root, 'LocalSDK/AppGroupKit/Classes/CoreManager/Manager/AppLocalManager.swift'))
raise 'Classic must remain the migration default' unless config.include?('public var homeMode: AppHomeMode = .classic')
%w[classic navidrome emby jellyfin plex].each_with_index do |name, index|
  raise 'Mode raw values changed' unless config.include?("case #{name} = #{index}")
end
puts 'Home-mode persistence default and raw values checked'
