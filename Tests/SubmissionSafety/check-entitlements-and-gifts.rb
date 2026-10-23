#!/usr/bin/env ruby
# Offline checks of production entitlement code; no credentials or Store calls.
require 'open3'
require 'tmpdir'

ROOT = File.expand_path('../..', __dir__)
def read(path)
  File.read(File.join(ROOT, path))
end
def check(condition, message)
  raise message unless condition
end

profile = read('Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/ProfileViewController.swift')
%w[isJumpRedeem checkFreecodeStatus verfityPurchageRecord].each do |symbol|
  check(!profile.include?(symbol), "Unused redemption path remains: #{symbol}")
end
user_model = read('LocalSDK/AppGroupKit/Classes/BaseModel/UserInfoManager.swift')
check(!user_model.include?('isDonater'), 'Unused donation flag remains')
user_ui = read('Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/UserInfoViewController.swift')
check(!user_ui.include?('"Beta"'), 'Release must not mislabel paid membership as Beta')

sources = Dir.glob(File.join(ROOT, 'Mobie/Mobie/**/*.swift'))
writers = sources.select { |path| File.read(path).match?(/UserInfoManager\.shared\.(?:payStatus|payGoodsId|expireDate)\s*=(?!=)/) }
check(writers == [File.join(ROOT, 'Mobie/Mobie/Base/Core/Purcharge/AppStoreKitManager+Pay.swift')], 'Unexpected membership writer; audit before permitting it')
payment = read('Mobie/Mobie/Base/Core/Purcharge/AppStoreKitManager+Pay.swift')
check(payment.include?('UserInfoManager.shared.payStatus = activePremium.payStatus()'), 'Membership must derive from the purchase entitlement')
check(payment.include?('UserInfoManager.shared.isFreeTrail = activePremium.periodType == .trial'), 'Preserve genuine Store trial state')
check(read('Mobie/Mobie/Base/Core/Purcharge/AppStoreKitManager.swift').include?('Purchases.shared.restorePurchases'), 'Preserve purchase restoration')

ids = read('LocalSDK/AppGroupKit/Classes/BaseModel/PurchaseStoreID.swift').split('extension Product {', 2).first.gsub(/^import .*\n/, '')
premium = read('LocalSDK/AppGroupKit/Classes/BaseModel/UserInfoManager+VIP.swift')[/public func isPremium\(\) -> Bool \{.*?^    \}/m]
vip = read('Mobie/Mobie/Base/Core/Extension/PurchargeStatus+Extension.swift').split('extension UserInfoManager {', 2).fetch(1)
entitlement = read('Mobie/Mobie/Base/Core/Extension/SKProduct+Extension.swift').split('extension EntitlementInfo {', 2).fetch(1)
source = <<~SWIFT
  import Foundation
  public protocol SmartCaseDefaultable {}
  #{ids}
  struct EntitlementInfo {
      let productIdentifier: String
      let isActive: Bool
  }
  extension EntitlementInfo {#{entitlement}
  final class UserInfoManager {
      var payStatus: PurchargeStatus = .normal
      #{premium}
  }
  extension UserInfoManager {#{vip}
  let user = UserInfoManager()
  for status: PurchargeStatus in [.normal, .subscribing, .lifetime, .expired, .refunded] {
      user.payStatus = status
  #if Target_Mobie_Pro
      precondition(user.isVIP(), "Paid Pro must retain its included Premium features")
  #else
      precondition(user.isVIP() == (status == .subscribing || status == .lifetime), "No Debug or local VIP override")
  #endif
  }
  let products: [PurchaseStoreID] = [.weekly, .monthly, .yearly, .lifetime198, .lifetime298]
  for product in products {
      for active in [false, true] {
          let entitlement = EntitlementInfo(productIdentifier: product.rawValue, isActive: active)
          let expected: PurchargeStatus = product.isSubscription ? (active ? .subscribing : .expired) : (active ? .lifetime : .refunded)
          precondition(entitlement.payStatus() == expected, "Purchase, family sharing, or expired membership changed")
      }
  }
  for unknown in ["unknown", "gift", "free_vip", "rc_promo_premium_lifetime"] {
      for active in [false, true] {
          precondition(EntitlementInfo(productIdentifier: unknown, isActive: active).payStatus() == .normal, "Unknown/gift product must not grant Premium")
      }
  }
  print("23 production entitlement checks passed")
SWIFT
Dir.mktmpdir('wakemusic-entitlements-') do |dir|
  path = File.join(dir, 'Entitlements.swift')
  File.write(path, source)
  [[], %w[-D DEBUG], %w[-D Target_Mobie_Pro], %w[-D DEBUG -D Target_Mobie_Pro]].each do |flags|
    output, status = Open3.capture2e({'DEVELOPER_DIR' => '/Applications/Xcode.app/Contents/Developer'}, 'xcrun', 'swift', '-module-cache-path', File.join(dir, 'ModuleCache'), *flags, path)
    raise output unless status.success?
    puts "#{flags.empty? ? 'Standard Release' : flags.join(' ')}: #{output.strip}"
  end
end
puts 'Membership writer, redemption cleanup, real trial and restoration checks passed (no server-side dashboard audit).'
