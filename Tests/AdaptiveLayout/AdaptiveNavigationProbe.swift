import UIKit
import Combine

// Only external business services/destination bodies are replaced. The
// destination enum and MusicServerTabBarController below are production code.
// This executable has no network, account, preferences or StoreKit access.
final class MusicServerSession {
    static var initializationCount = 0
    init() { Self.initializationCount += 1 }
}
typealias KakaNavigationController = UINavigationController
extension String { func localStr() -> String { self } }
enum KakaTabbarType {
    case profile
    func formatStr() -> String { "Profile" }
}
let appMainColor = UIColor.systemBlue
let playingHeight: CGFloat = 60
let kAppearanceChangedKey = "test.appearance"
final class AppLocalManager {
    static let shared = AppLocalManager()
    struct Style { func userInterfaceStyle() -> UIUserInterfaceStyle { .light } }
    let appearanceStyle = Style()
}
final class DownloadManager {
    static let shared = DownloadManager()
    @Published var taskArray: [Int] = []
}
final class AppStoreKitManager {
    static let shared = AppStoreKitManager()
    var verificationCount = 0
    func verifyPaymentRecords() { verificationCount += 1 }
}
@MainActor
final class MusicServerPlaybackChrome {
    static var initializationCount = 0
    static var installationCount = 0
    init(host: UIViewController) { Self.initializationCount += 1 }
    func install(in view: UIView) { Self.installationCount += 1 }
    func updateLayout(avoiding tabBar: UITabBar? = nil) {}
}
final class NavidromeHomeViewController: UIViewController {
    let session: MusicServerSession
    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
}
final class MusicServerLibraryViewController: UIViewController {
    let session: MusicServerSession
    init(session: MusicServerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
}
final class NavidromeDownloadViewController: UIViewController {
    init(onExit: @escaping () -> Void) { super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
}
final class ProfileViewController: UIViewController {}

@main
enum AdaptiveNavigationProbe {
    @MainActor static func main() {
        setbuf(stdout, nil)
        UIView.setAnimationsEnabled(false)
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.08)) }
        let session = MusicServerSession()
        let tabs = MusicServerTabBarController(session: session, onExit: {})
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = tabs
        tabs.loadViewIfNeeded()
        tabs.view.frame = window.bounds
        let navigations = tabs.viewControllers!.map { $0 as! UINavigationController }
        precondition(navigations.count == 4)
        let destinationRoots = navigations.map { $0.viewControllers.first! }
        precondition((destinationRoots[0] as! NavidromeHomeViewController).session === session)
        precondition((destinationRoots[1] as! MusicServerLibraryViewController).session === session)
        precondition(navigations.allSatisfy { $0.viewControllers.count == 1 },
            "A tab root must not inherit a sidebar navigation predecessor")
        let details = navigations.map { navigation -> UIViewController in
            let detail = UIViewController()
            navigation.pushViewController(detail, animated: false)
            return detail
        }
        tabs.selectedIndex = 2
        DownloadManager.shared.taskArray = [1, 2, 3]
        drain()

        func transition(_ sizeClass: UIUserInterfaceSizeClass, width: CGFloat) {
            window.frame = CGRect(x: 0, y: 0, width: width, height: 844)
            tabs.view.frame = window.bounds
            tabs.traitOverrides.horizontalSizeClass = sizeClass
            for _ in 0..<3 {
                tabs.view.setNeedsLayout(); tabs.view.layoutIfNeeded()
                tabs.viewDidLayoutSubviews()
                drain()
            }
            precondition(tabs.traitCollection.horizontalSizeClass == sizeClass)
            precondition(window.rootViewController === tabs, "Window root was replaced")
            precondition(tabs.navigationController == nil, "Tabs must not be wrapped in a navigation controller")
            precondition(tabs.splitViewController == nil, "Phone tabs must not be wrapped in a split controller")
            precondition(!tabs.isTabBarHidden, "Phone tab navigation became hidden")
            precondition(tabs.selectedIndex == 2, "Selected destination was lost")
            precondition(MusicServerSession.initializationCount == 1, "Session was recreated")
            precondition(MusicServerPlaybackChrome.initializationCount == 1, "Playback chrome was recreated")
            precondition(MusicServerPlaybackChrome.installationCount == 1, "Playback chrome was reinstalled")
            precondition(AppStoreKitManager.shared.verificationCount == 1, "Business initialization repeated")
            for (index, original) in navigations.enumerated() {
                precondition(tabs.viewControllers![index] === original, "Navigation controller was rebuilt")
                precondition(original.viewControllers.first === destinationRoots[index], "Destination root changed")
                precondition(original.topViewController === details[index], "Detail stack was reset")
                precondition(original.viewControllers.count == 2, "Unexpected split/sidebar navigation entry")
            }
            precondition(navigations[2].tabBarItem.badgeValue == "3", "Download badge was lost")
            print("PASS trait=\(sizeClass.rawValue) width=\(Int(width)): direct tabs root, 4 stacks and selection retained")
        }
        transition(.compact, width: 390)
        transition(.regular, width: 900)
        transition(.compact, width: 390)
        transition(.regular, width: 900)

        // Normal in-tab detail navigation must still work; do not fix the
        // unwanted shell back button by globally hiding legitimate back items.
        for (index, navigation) in navigations.enumerated() {
            navigation.popViewController(animated: false)
            precondition(navigation.topViewController === destinationRoots[index])
            precondition(navigation.viewControllers.count == 1)
        }
        print("PASS ordinary detail pop returns to each original destination root")
        _ = window // Retain the hidden test window for the full probe.
    }
}
