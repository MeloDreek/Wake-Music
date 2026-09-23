import UIKit

// Isolated UI/offer fixture. No StoreKit, analytics, player, preferences, or real purchases.
let fixtureRoot = ProcessInfo.processInfo.environment["ONBOARDING_ROOT"]!
let fixtureOutput = ProcessInfo.processInfo.environment["ONBOARDING_OUTPUT"]!
var fixtureLocale = "zh-Hans"
let catalog = (try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixtureRoot + "/Mobie/Mobie/System/Localizable.xcstrings"))) as! [String: Any])["strings"] as! [String: [String: Any]]
extension String {
    func localStr() -> String {
        let locales = catalog[self]?["localizations"] as? [String: [String: Any]]
        let unit = locales?[fixtureLocale]?["stringUnit"] as? [String: String]
        return unit?["value"] ?? self
    }
}
extension UIColor {
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UIColor { UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1) }
}
enum Reasource {
    static func named(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: fixtureRoot + "/Mobie/Mobie/Base/Bundle/Reasource.bundle/Images/" + name + "@3x.png")
    }
}
enum AudioExtension {
    static let audioSuffixs = ["dsd","dsf","dff","dts","flac","m4a","wav","ape","asf","aifc","aiff","alac","aif","au","caf","tta","wma","wave","wv","wvc","mp3","aac","ogg","opus","mod","xm","mqa","3gp","s3m","m4r","ogv","amr"]
}
class SuperViewController: UIViewController {
    let contentView = UIView()
    override func viewDidLoad() { super.viewDidLoad(); preSetupSubViews(); preSetupHandleBuness() }
    func preSetupSubViews() { view.addSubview(contentView) }
    func preSetupHandleBuness() {}
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); contentView.frame = view.bounds }
    func showOneAlert(message: String) {}
}
class UserInfoManager {
    static let shared = UserInfoManager()
    var premium = false
    func isVIP() -> Bool { premium }
}
class AppLocalManager { static let shared = AppLocalManager(); var isFirstLaunch = true }
class SceneDelegate: UIResponder, UIWindowSceneDelegate { var window: UIWindow?; var modeCoordinator: ModeCoordinator? }
class ModeCoordinator { func restoredRootController() -> UIViewController { UIViewController() } }
class ReachabilitySwift {
    enum Connection { case unavailable, wifi }
    var connection: Connection = .wifi
    init() throws {}
    func startNotifier() throws {}
    func stopNotifier() {}
}
extension Notification.Name { static let reachabilitySwiftChanged = Notification.Name("fixture.network") }
class AnalyticsManager { static let shared = AnalyticsManager(); func logEvent(_ event: String) {} }
class AppleSearchAdsManager { static let shared = AppleSearchAdsManager(); func handleASAAttribution() {} }
func kaka_IsMacOS() -> Bool { false }
let kPrivacyUrl = "https://example.com/privacy"
let kUseItemUrl = "https://example.com/terms"
enum ProgressHUD { static func dismiss() {}; static func animate(_ text: String) {} }
enum KakaError { case youhaveCanceled; var errorDescription: String { "cancelled" } }
enum PurchaseStoreID: String { case monthly = "fixture.monthly" }
struct Period { enum Unit { case day, week, month, year }; let value: Int; let unit: Unit }
struct Discount { enum Mode { case freeTrial, payAsYouGo }; var paymentMode = Mode.freeTrial; var subscriptionPeriod = Period(value: 3, unit: .day); var numberOfPeriods = 1 }
class StoreProduct {
    var productIdentifier = PurchaseStoreID.monthly.rawValue
    var introductoryDiscount: Discount?
    var localizedPriceString = "¥8.00"
    var paywallBillingSummary: String { localizedPriceString + " / 月" }
}
struct Eligibility { enum Status { case eligible, ineligible, unknown }; let status: Status }
class Purchases {
    static let shared = Purchases()
    var status: Eligibility.Status = .eligible
    func checkTrialOrIntroDiscountEligibility(productIdentifiers: [String], completion: @escaping ([String: Eligibility]) -> Void) {
        completion(Dictionary(uniqueKeysWithValues: productIdentifiers.map { ($0, Eligibility(status: status)) }))
    }
}
class AppStoreKitManager {
    static var products: [StoreProduct] = []
    static var purchases = 0
    static var requests = 0
    static var deferResponse = false
    static var pending: (([StoreProduct]) -> Void)?
    func refresRemoteProductsPrice(completion: @escaping ([StoreProduct]) -> Void) {
        Self.requests += 1
        if Self.deferResponse { Self.pending = completion } else { completion(Self.products) }
    }
    func startPurcharge(product: StoreProduct, successBlock: @escaping (Int) -> Void, failBlock: @escaping (String) -> Void) {
        Self.purchases += 1
        failBlock(KakaError.youhaveCanceled.errorDescription)
    }
    func restorePurcharge(success: @escaping () -> Void, fail: @escaping (String) -> Void) { fail("No purchases") }
    static func presentPurcharseVC(_ vc: UIViewController, animated: Bool, success: @escaping () -> Void) {}
}
