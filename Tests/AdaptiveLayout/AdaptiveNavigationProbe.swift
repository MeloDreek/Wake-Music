import UIKit

// No network, account, preferences, StoreKit or production playback dependencies.
final class MusicServerSession {}
enum MusicServerDestination: Int, CaseIterable {
    case home, library, download, profile
    var title: String { String(describing: self) }
    var symbol: String { "music.note" }
}
typealias KakaNavigationController = UINavigationController
extension String { func localStr() -> String { self } }
enum AppModeCoordinator { static var exitImage: UIImage? { UIImage(systemName: "arrow.left") } }
let kAppearanceChangedKey = "test.appearance"
final class AppLocalManager {
    static let shared = AppLocalManager()
    struct Style { func userInterfaceStyle() -> UIUserInterfaceStyle { .light } }
    let appearanceStyle = Style()
}

@MainActor
final class MusicServerTabBarController: UITabBarController {
    static var initializationCount = 0
    let session: MusicServerSession
    var onSelectedDestination: ((Int) -> Void)?
    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        Self.initializationCount += 1
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = MusicServerDestination.allCases.map { destination in
            let content = UIViewController()
            content.title = destination.title
            let navigation = UINavigationController(rootViewController: content)
            navigation.tabBarItem = UITabBarItem(title: destination.title,
                image: UIImage(systemName: destination.symbol), tag: destination.rawValue)
            return navigation
        }
    }
}

@main
enum AdaptiveNavigationProbe {
    @MainActor static func main() {
        setbuf(stdout, nil)
        UIView.setAnimationsEnabled(false)
        func descendants(_ controller: UIViewController) -> [UIViewController] {
            [controller] + controller.children.flatMap(descendants)
        }
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
        let session = MusicServerSession()
        let root = MusicServerAdaptiveRootController(session: session, onExit: {})
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 900, height: 800))
        window.rootViewController = host
        host.loadViewIfNeeded()
        host.view.frame = window.bounds
        host.addChild(root)
        host.view.addSubview(root.view)
        root.didMove(toParent: host)
        root.view.frame = host.view.bounds
        root.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        guard let content = root.viewController(for: .secondary) as? UINavigationController,
              let tabs = content.viewControllers.first as? MusicServerTabBarController else {
            fatalError("Production root did not retain the tabs controller")
        }
        tabs.loadViewIfNeeded()
        let navigations = tabs.viewControllers!.map { $0 as! UINavigationController }
        let details = navigations.map { navigation -> UIViewController in
            let detail = UIViewController()
            navigation.pushViewController(detail, animated: false)
            return detail
        }
        tabs.selectedIndex = 2
        func transition(_ sizeClass: UIUserInterfaceSizeClass, width: CGFloat) {
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: 800)
            root.view.frame = host.view.bounds
            root.traitOverrides.horizontalSizeClass = sizeClass
            for _ in 0..<5 {
                host.view.setNeedsLayout(); host.view.layoutIfNeeded()
                root.view.setNeedsLayout(); root.view.layoutIfNeeded()
                root.viewDidLayoutSubviews()
                drain()
            }
            print("trait=\(root.traitCollection.horizontalSizeClass.rawValue) collapsed=\(root.isCollapsed) display=\(root.displayMode.rawValue) hidden=\(tabs.isTabBarHidden)")
            precondition(root.isCollapsed == (sizeClass == .compact), "UIKit did not apply requested collapse")
            precondition(tabs.isTabBarHidden == (sizeClass == .regular), "Tab visibility does not match sidebar")
            precondition(tabs.selectedIndex == 2, "Selected destination was lost")
            precondition(tabs.session === session, "Session was recreated")
            precondition(MusicServerTabBarController.initializationCount == 1, "Tabs were rebuilt")
            for (index, original) in navigations.enumerated() {
                precondition(tabs.viewControllers![index] === original, "Navigation controller was rebuilt")
                precondition(original.topViewController === details[index], "Detail stack was reset")
            }
            precondition(descendants(root).contains(where: { $0 === tabs }), "Tabs left the root containment tree")
        }
        transition(.regular, width: 900)
        transition(.compact, width: 390)
        transition(.regular, width: 900)
        transition(.compact, width: 390)
        print("PASS 4 UIKit fold transitions: same session/tabs/4 nav stacks, selected tab and sidebar visibility")
        _ = window // Retain the isolated test window for the full probe.
    }
}
