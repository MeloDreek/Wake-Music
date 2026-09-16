# Run: ruby Tests/RemoteAccess/check-policy.rb
require 'json'
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
read = ->(path) { File.read(File.join(root, path)) }
app = 'Mobie/Mobie/'
import = read.call(app + 'Business/ImportModule/Controller/ImportViewController+Drive.swift')
%w[Files Folder Videos USB WiFi].each do |kind|
  raise "Local #{kind} falls through to paywall" unless import.match?(/self\.importFrom#{kind}\(\)\s+return/)
end
[
  'Business/ImportModule/Controller/ImportViewController+Drive.swift',
  'Business/ConnectModule/Controller/ConnectListViewController+Connect.swift',
  'Business/ConnectModule/Controller/ConnectListViewController+Access.swift'
].each do |file|
  raise "Missing access gate: #{file}" unless read.call(app + file).include?('guard requireRemoteConnectionAccess() else { return }')
end
raise 'Free-account quota remains' if import.include?('connectedModels.count >= 1')

catalog = JSON.parse(read.call(app + 'System/Localizable.xcstrings'))['strings']
key = 'Connecting to cloud drives and servers requires Premium. Eligible users can start a free trial.'
raise 'Unwanted trial copy remains' if catalog.key?(key)
ui = read.call(app + 'Base/BaseUI/SuperViewController.swift')
paywall = ui[/static func showRemoteConnectionPaywall.*?^    \}/m]
raise 'Must confirm before opening paywall' unless paywall.include?('AppStoreKitManager.presentPurcharseVC(controller)') && paywall.include?('showTwoAlert')
upsell = 'Upgrade to Premium at the lowest price currently available to unlock all remote features, plus upcoming Apple Watch and native CarPlay support.'
translations = catalog.fetch(upsell).fetch('localizations')
raise 'Missing upsell locales' unless translations.keys.sort == catalog.fetch('Queue.Title').fetch('localizations').keys.sort
raise 'Incomplete upsell translations' unless translations.values.all? { |v| v.dig('stringUnit', 'state') == 'translated' && !v.dig('stringUnit', 'value').to_s.empty? }
raise 'Unwanted footer message remains' if ui.include?('remoteConnectionMessage')
raise 'Obsolete free-account copy remains' if catalog.keys.any? { |k| k.start_with?('Free tier limited to 1 account.', "You've successfully connected a cloud service!") }

# Compile the actual entitlement methods with lightweight model stubs, including
# both product flags. A free trial uses .subscribing, as set by AppStoreKitManager.
vip = read.call(app + 'Base/Core/Extension/PurchargeStatus+Extension.swift').split('extension UserInfoManager {', 2).fetch(1)
premium = read.call('LocalSDK/AppGroupKit/Classes/BaseModel/UserInfoManager+VIP.swift')[/public func isPremium\(\) -> Bool \{.*?^    \}/m]
raise 'Missing entitlement method' unless premium
source = <<~SWIFT
  enum PurchargeStatus: CaseIterable { case normal, subscribing, lifetime, expired, refunded }
  final class UserInfoManager {
      var payStatus: PurchargeStatus = .normal
      #{premium}
  }
  extension UserInfoManager {#{vip}
  let user = UserInfoManager()
  for status in PurchargeStatus.allCases {
      user.payStatus = status
  #if Target_Mobie_Pro
      precondition(user.isVIP(), "Pro must retain its entitlement")
  #else
      precondition(user.isVIP() == (status == .subscribing || status == .lifetime), "Incorrect entitlement")
  #endif
  }
SWIFT
Dir.mktmpdir('remote-access-tests-') do |dir|
  file = File.join(dir, 'policy.swift')
  File.write(file, source)
  [[], ['-D', 'Target_Mobie_Pro']].each do |flags|
    output, status = Open3.capture2e({'DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer'}, 'xcrun', 'swift', *flags, file)
    raise output unless status.success?
  end
end
puts 'Passed: local import routing, 3 remote entry gates, normal/Pro entitlement states, upsell confirmation and translations, and obsolete copy removal.'
