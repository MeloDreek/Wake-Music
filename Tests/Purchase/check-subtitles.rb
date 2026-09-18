# Run: ruby Tests/Purchase/check-subtitles.rb
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
manager = File.read(File.join(root, 'Mobie/Mobie/Base/Core/Purcharge/AppStoreKitManager.swift'))
production = manager.split('// MARK: - Compact paywall copy', 2).fetch(1).split('/// 内购管理者', 2).first
source = <<~SWIFT
  import Foundation
  enum PurchaseStoreID: String { case monthly, yearly, weekly, lifetime198, lifetime298 }
  struct Period {
      enum Unit { case day, week, month, year }
      let value: Int
      let unit: Unit
  }
  struct Offer {
      enum PaymentMode { case freeTrial, payAsYouGo, payUpFront }
      let subscriptionPeriod: Period
      let numberOfPeriods: Int
      var paymentMode: PaymentMode = .freeTrial
  }
  struct StoreProduct {
      var productIdentifier: String
      var introductoryDiscount: Offer?
      var localizedPricePerMonth: String? = "$0.67"
  }
  extension String {
      func localStr() -> String {
          self == "Purchase.FreeTrialDuration" ? "Free trial: %@" : self
      }
  }
  #{production}
  var count = 0
  func expect(_ success: @autoclosure () -> Bool) { count += 1; precondition(success()) }
  let threeDays = Offer(subscriptionPeriod: Period(value: 3, unit: .day), numberOfPeriods: 1)
  var monthly = StoreProduct(productIdentifier: "monthly")
  var annual = StoreProduct(productIdentifier: "yearly")
  expect(monthly.compactPaywallSubtitle(isEligibleForTrial: true) == nil)
  expect(annual.compactPaywallSubtitle(isEligibleForTrial: false) == "$0.67/mo")
  monthly.introductoryDiscount = threeDays
  annual.introductoryDiscount = threeDays
  for product in [monthly, annual] {
      let text = product.compactPaywallSubtitle(isEligibleForTrial: true)!
      expect(text.hasPrefix("Free trial: ") && text.contains("3"))
  }
  expect(monthly.compactPaywallSubtitle(isEligibleForTrial: false) == nil)
  expect(annual.compactPaywallSubtitle(isEligibleForTrial: false) == "$0.67/mo")
  for id in ["weekly", "lifetime198", "lifetime298", "unknown"] {
      let product = StoreProduct(productIdentifier: id, introductoryDiscount: threeDays)
      expect(product.compactPaywallSubtitle(isEligibleForTrial: true) == nil)
      expect(product.compactPaywallSubtitle(isEligibleForTrial: false) == nil)
  }
  for mode in [Offer.PaymentMode.payAsYouGo, .payUpFront] {
      monthly.introductoryDiscount = Offer(subscriptionPeriod: Period(value: 3, unit: .day), numberOfPeriods: 1, paymentMode: mode)
      expect(monthly.compactPaywallSubtitle(isEligibleForTrial: true) == nil)
  }
  for (unit, value, periods) in [(Period.Unit.day, 3, 2), (.week, 2, 1), (.month, 1, 1), (.year, 1, 1)] {
      monthly.introductoryDiscount = Offer(subscriptionPeriod: Period(value: value, unit: unit), numberOfPeriods: periods)
      let subtitle = monthly.compactPaywallSubtitle(isEligibleForTrial: true)!
      expect(subtitle.contains(String(value * periods)))
      expect(!subtitle.contains("30") && !subtitle.contains("365"))
  }
  for (value, periods) in [(0, 1), (-1, 1), (1, 0), (Int.max, 2)] {
      monthly.introductoryDiscount = Offer(subscriptionPeriod: Period(value: value, unit: .day), numberOfPeriods: periods)
      expect(monthly.compactPaywallSubtitle(isEligibleForTrial: true) == nil)
  }
  annual.introductoryDiscount = nil
  annual.localizedPricePerMonth = nil
  expect(annual.compactPaywallSubtitle(isEligibleForTrial: false) == nil)
  print("PASS_COMPACT_SUBTITLES \\(count) assertions")
SWIFT
Dir.mktmpdir('wake-purchase-subtitles-') do |dir|
  file = File.join(dir, 'Subtitles.swift')
  File.write(file, source)
  output, status = Open3.capture2e({'DEVELOPER_DIR'=>'/Applications/Xcode.app/Contents/Developer'}, 'xcrun', 'swiftc', '-module-cache-path', File.join(dir, 'modules'), file, '-o', File.join(dir, 'probe'))
  raise output unless status.success?
  output, status = Open3.capture2e(File.join(dir, 'probe'))
  raise output unless status.success?
  puts output
end
controller = File.read(File.join(root, 'Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/PurchaseViewController.swift'))
raise 'Trial eligibility must be verified' unless controller.include?('checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)') && controller.include?('result[$0]?.status == .eligible')
raise 'Stale eligibility response can overwrite refreshed products' unless controller.include?('self.eligibilityRequestID == generation')
raise 'Family explanation must be in the product section footer' unless controller.include?('"Purchase.FamilySharingFooter".localStr()')
puts 'PASS_COMPACT_WIRING eligibility, generation guard, family footer'
