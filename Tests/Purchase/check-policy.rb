# Run: ruby Tests/Purchase/check-policy.rb
# Compiles the production purchase policy with Foundation-only test doubles.
# No App Store, RevenueCat, app launch, credentials, or network are used.
require 'tmpdir'
require 'open3'

ROOT = File.expand_path('../..', __dir__)
def read(path)
  File.read(File.join(ROOT, path))
end

def check(condition, message)
  raise message unless condition
end

def method_source(source, signature)
  source[/^    #{Regexp.escape(signature)}.*?^    \}/m] || raise("Missing production method: #{signature}")
end

app = 'Mobie/Mobie/'
ids = read('LocalSDK/AppGroupKit/Classes/BaseModel/PurchaseStoreID.swift')
ids = ids.split('extension Product {', 2).first.gsub(/^import .*\n/, '')
entitlement_source = read(app + 'Base/Core/Extension/SKProduct+Extension.swift')
entitlements = 'extension EntitlementInfo {' + entitlement_source.split('extension EntitlementInfo {', 2).fetch(1)
manager = read(app + 'Base/Core/Purcharge/AppStoreKitManager.swift')
product_helpers = manager[/extension StoreProduct \{.*?^\}/m] || raise('Missing StoreProduct billing helpers')
title_method = method_source(read(app + 'Business/OtherModule/ProfileModule/View/PurchageListViewcell.swift'), 'public func formatStr() -> String {')
paywall = read(app + 'Business/OtherModule/ProfileModule/Controller/PurchaseViewController.swift')
selection_method = method_source(paywall, 'func handlePriceGoods(_ models: [StoreProduct]) {')
button_method = method_source(paywall, 'private func updatePurchaseButton() {')
expiration_property = method_source(read('LocalSDK/AppGroupKit/Classes/BaseModel/UserInfoManager.swift'), 'public var membershipExpirationDate: Date? {')

source = <<~SWIFT
  import Foundation
  public protocol SmartCaseDefaultable {}
  #{ids}
  struct EntitlementInfo {
      let productIdentifier: String
      let isActive: Bool
      let expirationDate: Date?
      let willRenew: Bool
  }
  #{entitlements}
  extension String {
      func localStr() -> String {
          switch self {
          case "Purchase.Billing.Monthly": return "%@ / month"
          case "Purchase.Billing.Annual": return "%@ / year"
          case "Purchase.Billing.Once": return "%@ one-time"
          default: return self
          }
      }
  }
  extension PurchaseStoreID {
      #{title_method}
  }
  enum ProductType { case autoRenewableSubscription, nonConsumable }
  struct StoreProduct {
      let productIdentifier: String
      let localizedPriceString: String
      var localizedTitle = "Store title"
      var localizedDescription = "Store description"
      var productType: ProductType {
          PurchaseStoreID(rawValue: productIdentifier)?.isSubscription == true ? .autoRenewableSubscription : .nonConsumable
      }
  }
  #{product_helpers}
  final class UserInfoManager {
      static let shared = UserInfoManager()
      var ownedID: PurchaseStoreID?
      var premium = false
      var expireDate: TimeInterval?
      #{expiration_property}
      func payedStoreModel() -> PurchaseStoreID? { ownedID }
      func isVIP() -> Bool { premium }
  }
  final class TestTableView {
      var reloadCount = 0
      func reloadData() { reloadCount += 1 }
  }
  final class TestButton {
      enum State { case normal }
      var isEnabled = false
      var title: String?
      func setTitle(_ title: String?, for state: State) { self.title = title }
  }
  final class TestLabel { var text: String? }
  final class PaywallHarness {
      var priceArray: [StoreProduct] = []
      var selectModel: StoreProduct? { didSet { updatePurchaseButton() } }
      var isPurchasing = false { didSet { updatePurchaseButton() } }
      let tableView = TestTableView()
      let buyoutButton = TestButton()
      let tipsLabel = TestLabel()
      private func refreshTrialEligibility() {}
      #{selection_method}
      #{button_method}
  }

  var assertions = 0
  func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
      assertions += 1
      precondition(condition(), message)
  }
  let orderedIDs: [PurchaseStoreID] = [.monthly, .yearly, .lifetime198, .lifetime298]
  expect(PurchaseStoreID.paywallProducts == orderedIDs, "Four plans must keep a stable display order")
  expect(!PurchaseStoreID.paywallProducts.contains(.weekly), "Weekly must not be promoted")
  let allIDs: [PurchaseStoreID] = [.weekly] + orderedIDs
  let rawIDs = ["com.OfflineMusic.www.Weekly", "com.OfflineMusic.www.Monthly", "com.OfflineMusic.www.Annual", "com.OfflineMusic.www.lifetime198", "com.OfflineMusic.www.lifetime298"]
  for (id, raw) in zip(allIDs, rawIDs) {
      expect(id.rawValue == raw && PurchaseStoreID(rawValue: raw) == id, "Legacy product identity changed")
      let subscription = [PurchaseStoreID.weekly, .monthly, .yearly].contains(id)
      expect(id.isSubscription == subscription, "Incorrect subscription classification")
      for active in [false, true] {
          for expirationDate in [nil, Date(timeIntervalSince1970: 1), Date.distantFuture] as [Date?] {
              for willRenew in [false, true] {
                  let entitlement = EntitlementInfo(productIdentifier: raw, isActive: active, expirationDate: expirationDate, willRenew: willRenew)
                  let expected: PurchargeStatus = subscription ? (active ? .subscribing : .expired) : (active ? .lifetime : .refunded)
                  expect(entitlement.payStatus() == expected, "Active/grace-period/cancelled-renewal entitlement was misclassified: \\(id)")
              }
          }
      }
  }
  for active in [false, true] {
      let unknown = EntitlementInfo(productIdentifier: "unknown.product", isActive: active, expirationDate: nil, willRenew: true)
      expect(unknown.payStatus() == .normal, "Unknown products must not grant Premium")
  }

  let monthly = StoreProduct(productIdentifier: PurchaseStoreID.monthly.rawValue, localizedPriceString: "¥18.00")
  let annual = StoreProduct(productIdentifier: PurchaseStoreID.yearly.rawValue, localizedPriceString: "¥128.00")
  let lifetime = StoreProduct(productIdentifier: PurchaseStoreID.lifetime198.rawValue, localizedPriceString: "¥198.00")
  let family = StoreProduct(productIdentifier: PurchaseStoreID.lifetime298.rawValue, localizedPriceString: "¥298.00")
  let weekly = StoreProduct(productIdentifier: PurchaseStoreID.weekly.rawValue, localizedPriceString: "¥6.00")
  let unknown = StoreProduct(productIdentifier: "unknown.product", localizedPriceString: "€7,00")
  let products = [monthly, annual, lifetime, family]
  let expectedTitles = ["Purchase.Monthly.Title", "Purchase.Annual.Title", "Purchase.Lifetime.Title", "Purchase.FamilyLifetime.Title"]
  let expectedDescriptions = ["Purchase.Monthly.Description", "Purchase.Annual.Description", "Purchase.Lifetime.Description", "Purchase.FamilyLifetime.Description"]
  let expectedBilling = ["¥18.00 / month", "¥128.00 / year", "¥198.00 one-time", "¥298.00 one-time"]
  for index in products.indices {
      expect(products[index].paywallTitle == expectedTitles[index], "Each plan must retain its own title")
      expect(products[index].paywallDetail == expectedDescriptions[index], "Each plan must retain its own description")
      expect(products[index].paywallBillingSummary == expectedBilling[index], "The full Store price and billing period must be shown")
  }
  expect(unknown.paywallTitle == unknown.localizedTitle, "Unknown title fallback")
  expect(unknown.paywallDetail == unknown.localizedDescription, "Unknown description fallback")
  expect(unknown.paywallBillingSummary == unknown.localizedPriceString, "Unknown price fallback")
  expect(weekly.paywallTitle == "Weekly", "Legacy weekly purchase title must remain available")

  let wall = PaywallHarness()
  wall.handlePriceGoods([family, weekly, annual, unknown, lifetime, monthly])
  expect(wall.priceArray.map { $0.productIdentifier } == orderedIDs.map { $0.rawValue }, "Price order and unsupported product filtering")
  expect(wall.selectModel?.productIdentifier == annual.productIdentifier, "Recommend Annual initially")
  expect(wall.buyoutButton.isEnabled, "Available unowned product can be purchased")
  wall.selectModel = monthly
  let refreshedMonthly = StoreProduct(productIdentifier: monthly.productIdentifier, localizedPriceString: "¥20.00")
  wall.handlePriceGoods([annual, family, refreshedMonthly, lifetime])
  expect(wall.selectModel?.localizedPriceString == "¥20.00", "Preserve selection by ID but replace stale Store data")
  wall.handlePriceGoods([family, annual])
  expect(wall.selectModel?.productIdentifier == annual.productIdentifier, "Missing selection falls back to Annual")
  wall.handlePriceGoods([family, monthly])
  expect(wall.selectModel?.productIdentifier == monthly.productIdentifier, "Missing Annual falls back to first available approved plan")
  wall.isPurchasing = true
  expect(!wall.buyoutButton.isEnabled, "Prevent duplicate purchase requests")
  wall.isPurchasing = false
  wall.handlePriceGoods([weekly, unknown])
  expect(wall.priceArray.isEmpty && wall.selectModel == nil, "Do not fabricate products when Store returns no approved plan")
  expect(!wall.buyoutButton.isEnabled && wall.tipsLabel.text == nil, "No-product state disables purchase and clears stale billing copy")
  expect(wall.tableView.reloadCount == 5, "Each refresh must render its current product snapshot")
  let user = UserInfoManager.shared
  user.premium = true
  user.ownedID = .lifetime198
  wall.handlePriceGoods(products)
  expect(!wall.buyoutButton.isEnabled, "Individual lifetime users must not buy a redundant subscription")
  wall.selectModel = family
  expect(wall.buyoutButton.isEnabled, "Individual lifetime can voluntarily choose family lifetime")
  user.ownedID = .lifetime298
  for product in products {
      wall.selectModel = product
      expect(!wall.buyoutButton.isEnabled, "Family lifetime already covers each offered plan")
  }
  user.premium = false
  wall.selectModel = family
  expect(wall.buyoutButton.isEnabled, "Expired/refunded users may repurchase")

  let expirationUser = UserInfoManager()
  let dateFormatter = ISO8601DateFormatter()
  let exampleDate = dateFormatter.date(from: "2026-09-18T12:34:56Z")!
  for seconds in [exampleDate.timeIntervalSince1970, exampleDate.timeIntervalSince1970 + 0.125, Date(timeIntervalSince1970: 1_893_456_000).timeIntervalSince1970] {
      expirationUser.expireDate = seconds
      let secondsDate = expirationUser.membershipExpirationDate
      expect(secondsDate == Date(timeIntervalSince1970: seconds), "RevenueCat Unix seconds must not be divided by 1000")
      expirationUser.expireDate = seconds * 1000
      let millisecondsDate = expirationUser.membershipExpirationDate
      expect(millisecondsDate == secondsDate, "Legacy Unix milliseconds must resolve to the same instant")
      expect(dateFormatter.string(from: millisecondsDate!) == dateFormatter.string(from: secondsDate!), "Seconds and legacy milliseconds must show the same calendar date")
  }
  for invalid in [nil, 0, -1, Double.infinity, -Double.infinity, Double.nan] as [TimeInterval?] {
      expirationUser.expireDate = invalid
      expect(expirationUser.membershipExpirationDate == nil, "Missing, nonpositive, and nonfinite membership expiration dates must be rejected")
  }
  print("PASS_PURCHASE_RUNTIME \\(assertions) assertions")
SWIFT

Dir.mktmpdir('wake-purchase-policy-') do |dir|
  file = File.join(dir, 'Policy.swift')
  binary = File.join(dir, 'policy')
  File.write(file, source)
  environment = {
    'DEVELOPER_DIR' => ENV.fetch('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'),
    'CLANG_MODULE_CACHE_PATH' => File.join(dir, 'modules'),
    'SWIFT_MODULECACHE_PATH' => File.join(dir, 'modules')
  }
  output, status = Open3.capture2e(environment, 'xcrun', 'swiftc', file, '-o', binary)
  raise output unless status.success?
  output, status = Open3.capture2e(binary)
  raise output unless status.success?
  puts output
end

# UI and project wiring checks supplement the executable policy tests above.
forbidden = /DiscountIAPManager|PremiumTimerView|kLifetimeDiscountKey|kDiscountLeftTimeKey|kStartDiscountPriceKey|calculateDiscountPercentage/
Dir.glob(File.join(ROOT, '{Mobie/Mobie,LocalSDK/AppGroupKit}/**/*.swift')).each do |path|
  check(!File.read(path).match?(forbidden), "Removed discount reference remains: #{path}")
end
project = read('Mobie/Mobie.xcodeproj/project.pbxproj')
%w[AppStoreKitManager+Discount.swift PurchaseViewController+Discount.swift PremiumTimerView.swift].each do |file|
  check(!project.include?(file), "Deleted source still referenced by Xcode: #{file}")
end
prices = read(app + 'Base/Core/Purcharge/AppStoreKitManager+Price.swift')
check(prices.include?('productIds: [PurchaseStoreID] = PurchaseStoreID.paywallProducts'), 'Default price lookup must fetch only the four offered plans')
check(prices.include?('PurchaseStoreID.paywallProducts.compactMap'), 'Store results must use the approved stable product order')
history = read(app + 'Business/OtherModule/ProfileModule/Controller/UserInfoViewController.swift')
%w[weekly monthly yearly].each do |id|
  check(history.include?("subscriptionsByProductIdentifier[PurchaseStoreID.#{id}.rawValue]"), "Missing #{id} purchase history")
end
expiration_display = method_source(read(app + 'Base/Core/Extension/UserInfoManager+Extension.swift'), 'public func vipExpirationDate() -> String {')
check(expiration_display.include?('self.membershipExpirationDate') && !expiration_display.match?(/\/\s*1000/), 'Membership date UI must use normalized seconds/legacy-milliseconds conversion')
welcome = read(app + 'Business/OtherModule/LoginModule/WelcomeViewController.swift')
welcome_cell = read(app + 'Business/OtherModule/LoginModule/WelcomePaywallViewCell.swift')
check(welcome.match?(/self\.selectModel = self\.productArray\.first\s*\{\s*\$0\.productIdentifier == PurchaseStoreID\.yearly\.rawValue/m), 'Onboarding must recommend Annual')
check(welcome_cell.include?('Purchase.AllPlans') && welcome_cell.include?('welcomePurchaseDidAllBenefit'), 'Onboarding must offer access to all plans')
all_plans = method_source(welcome, 'func welcomePurchaseDidAllBenefit(cell: WelcomePaywallViewCell) {')
check(all_plans.include?('AppStoreKitManager.presentPurcharseVC') && !all_plans.include?('cancel:'), 'All-plans navigation must not silently dismiss onboarding on cancellation')
check(welcome_cell.include?('Not Now') && welcome_cell.include?('Restore Purchase'), 'Onboarding must retain skip and restore paths')
check(welcome.include?('nextButton.isEnabled = !isProcessingPurchase && (!isPurchasePage || selectModel != nil || UserInfoManager.shared.isVIP())'), 'Disable the onboarding purchase action while busy or without a Store product')
%w[welcomePurchaseDidLimited welcomePurchaseDidRestore welcomePurchaseDidAllBenefit].each do |action|
  body = method_source(welcome, "func #{action}(cell: WelcomePaywallViewCell) {")
  check(body.include?('guard !isProcessingPurchase else { return }'), "Onboarding must guard #{action} during purchase/restore")
end
onboarding_purchase = read(app + 'Business/OtherModule/LoginModule/WelcomeViewController+Page.swift')
check(onboarding_purchase.include?('guard !isProcessingPurchase, let vModel = self.selectModel else { return }'), 'Onboarding purchase must reject duplicate or missing-product requests')
check(onboarding_purchase.include?('isProcessingPurchase = true') && onboarding_purchase.include?('wSelf.isProcessingPurchase = false'), 'Onboarding purchase must acquire the busy lock and release it on failure/cancellation')
restore_action = method_source(welcome, 'func welcomePurchaseDidRestore(cell: WelcomePaywallViewCell) {')
check(restore_action.include?('isProcessingPurchase = true') && restore_action.include?('self?.isProcessingPurchase = false'), 'Onboarding restore must acquire and release the busy lock on failure')
verification = method_source(welcome, 'func verfityPurchageRecord() {')
check(verification.include?('self?.isProcessingPurchase = false'), 'Onboarding verification must release the busy lock after completion')
%w[paywallTitle paywallDetail paywallBillingSummary].each do |helper|
  check(welcome_cell.include?(helper), "Onboarding must use the truthful #{helper} helper")
end
check(!product_helpers.match?(/freeTrialDays|localMonthlyPriceStr|strikethroughStyle|discount/i), 'Billing display must not invent a discount, trial, or substitute a monthly equivalent for the annual bill')
check(paywall.include?('tableView.reloadSections(IndexSet(integer: 1), with: .none)'), 'Product selection must refresh the product section')
check(!paywall.include?('visibleCells') && !paywall.include?('indexPathsForVisibleRows'), 'Do not index product rows through visible-cell order')
check(paywall.include?('guard !priceArray.isEmpty else') && paywall.include?('Purchase.ProductsUnavailable'), 'Paywall must expose a safe retryable empty state')
pay_action = read(app + 'Business/OtherModule/ProfileModule/Controller/PurchaseViewController+Pay.swift')
check(pay_action.include?('guard !isPurchasing, buyoutButton.isEnabled else { return }'), 'Purchase action must respect disabled/in-flight states')
puts 'PASS_PURCHASE_WIRING discount removal, project references, legacy history, truthful billing, Annual onboarding, all-plans/skip/restore, empty-state and selection guards.'
