// UIKit integration harness. The runner appends routing code extracted verbatim
// from ImportViewController.swift; providers/storage are replaced by inert doubles.
import UIKit

struct ServerConfigModel { let id: String }
let testServer = ServerConfigModel(id: "new-account")
var failures = [String]()
var checks = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures.append(message) }
}

class HomeTabbarViewController: UITabBarController {}
class ConnectListViewController: UIViewController {
    var refreshCount = 0
    var opened = [String]()
    func refreshDataAction() {
        check(isViewLoaded, "Connections must load before refreshing")
        refreshCount += 1
    }
    func accessLoginedServer(_ server: ServerConfigModel) {
        NSLog("Opening fixture list; navigation transition: %@", navigationController?.transitionCoordinator == nil ? "none" : "active")
        check(refreshCount > 0, "Account data must refresh before opening")
        check(navigationController?.viewControllers.count == 1, "Reset old folder stack before opening")
        check(view.window?.rootViewController?.presentedViewController == nil, "Dismiss Import before opening")
        opened.append(server.id)
        navigationController?.pushViewController(UIViewController(), animated: false)
    }
}

enum PrimaryCellItemType: String { case connect }
class PrimaryToolViewController: UIViewController {
    weak var owner: MacTabbarViewController?
    func jumpConnectPage() {
        let key = PrimaryCellItemType.connect.rawValue
        let navigation = owner!.contentDict[key] ?? UINavigationController(rootViewController: ConnectListViewController())
        owner!.contentDict[key] = navigation
        owner!.setViewController(navigation, for: .secondary)
    }
}
class MacTabbarViewController: UISplitViewController {
    var contentDict = [String: UINavigationController]()
    lazy var primaryVC: PrimaryToolViewController = {
        let controller = PrimaryToolViewController()
        controller.owner = self
        return controller
    }()
}

@main
class NavigationHarness: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        Task { @MainActor in
            await run()
            let report = "\(checks) UIKit navigation checks, \(failures.count) failures\n" + failures.joined(separator: "\n")
            print(report)
            let path = URL.documentsDirectory.appendingPathComponent("navigation-results.txt")
            try? report.write(to: path, atomically: true, encoding: .utf8)
            exit(failures.isEmpty ? 0 : 1)
        }
        return true
    }

    @MainActor func present(_ child: UIViewController, from parent: UIViewController) async {
        await withCheckedContinuation { done in
            parent.present(child, animated: false) { done.resume() }
        }
    }

    @MainActor func settle() async {
        // Harness-only allowance for UIKit's animated dismissal. Production uses
        // dismissal completion, never this delay.
        try? await Task.sleep(nanoseconds: 900_000_000)
    }

    @MainActor func run() async {
        await settle() // Complete the launch window's initial appearance first.
        // Fresh music tab -> Import -> connection, plus duplicate callback.
        do {
            NSLog("Scenario: fresh Connections")
            let music = UINavigationController(rootViewController: UIViewController())
            let connections = ConnectListViewController()
            let connectionNavigation = UINavigationController(rootViewController: connections)
            let tabs = HomeTabbarViewController()
            // Match HomeTabbarViewController.configChildController's addChild API.
            tabs.addChild(music)
            tabs.addChild(connectionNavigation)
            window?.rootViewController = tabs
            await settle()
            check(!connections.isViewLoaded, "Fixture: Connections starts unloaded")
            let importer = ImportViewController()
            let importNavigation = UINavigationController(rootViewController: importer)
            importNavigation.modalPresentationStyle = .fullScreen
            await present(importNavigation, from: tabs)
            check(tabs.isPresentingImportFlow, "Legacy Dropbox tab switching is suppressed while Import is presented")
            check(importer.routeImportedServer(testServer), "Import owns new account routing")
            importer.finishRemoteAuthorization(testServer)
            await settle()
            check(tabs.selectedViewController === connectionNavigation, "Select Connections tab")
            check(tabs.presentedViewController == nil, "Close full-screen Import")
            check(!tabs.isPresentingImportFlow, "Legacy navigation resumes after Import closes")
            check(connections.opened == [testServer.id], "Duplicate callbacks open only once")
            check(connectionNavigation.viewControllers.count == 2, "List is a child of Connections")
            connectionNavigation.popViewController(animated: false)
            check(connectionNavigation.topViewController === connections, "Back returns to Connections")
            await settle()
        }

        // Previously visited Connections has an old nested folder. A Baidu/115
        // style full-screen authorization hides Import's view entirely.
        do {
            NSLog("Scenario: nested full-screen authorization")
            let connections = ConnectListViewController()
            let navigation = UINavigationController(rootViewController: connections)
            navigation.pushViewController(UIViewController(), animated: false)
            let tabs = HomeTabbarViewController()
            tabs.viewControllers = [navigation]
            window?.rootViewController = tabs
            await settle()
            let importer = ImportViewController()
            let importNavigation = UINavigationController(rootViewController: importer)
            importNavigation.modalPresentationStyle = .fullScreen
            await present(importNavigation, from: tabs)
            let authorization = UIViewController()
            let authorizationNavigation = UINavigationController(rootViewController: authorization)
            authorizationNavigation.modalPresentationStyle = .fullScreen
            await present(authorizationNavigation, from: importer)
            check(tabs.isPresentingImportFlow, "Detect Import underneath nested authorization")
            check(importer.viewIfLoaded?.window == nil, "Fixture: fullscreen auth hides Import")
            check(authorization.routeImportedServer(testServer), "Nested auth finds owning Import")
            await settle()
            check(connections.opened == [testServer.id], "Nested auth opens account")
            check(tabs.presentedViewController == nil, "Dismiss both nested modals")
            check(navigation.viewControllers.count == 2, "Remove stale folders from destination")
            await settle()
        }

        // Pushed SMB / WebDAV / Navidrome login controllers.
        do {
            NSLog("Scenario: pushed server login and unrelated reauthorization")
            let connections = ConnectListViewController()
            let tabs = HomeTabbarViewController()
            tabs.viewControllers = [UINavigationController(rootViewController: connections)]
            window?.rootViewController = tabs
            await settle()
            let importer = ImportViewController()
            let navigation = UINavigationController(rootViewController: importer)
            await present(navigation, from: tabs)
            let login = UIViewController()
            navigation.pushViewController(login, animated: false)
            check(login.routeImportedServer(testServer), "Pushed login finds owning Import")
            await settle()
            check(connections.opened == [testServer.id], "Server login opens from Connections")
            let reauthorization = UIViewController()
            await present(UINavigationController(rootViewController: reauthorization), from: tabs)
            check(!reauthorization.routeImportedServer(testServer), "Existing account reauthorization is untouched")
            tabs.dismiss(animated: false)
            await settle()
        }

        // Mac-style split: there is no Connections controller until selected.
        do {
            NSLog("Scenario: lazy split-view Connections")
            let split = MacTabbarViewController(style: .doubleColumn)
            split.setViewController(split.primaryVC, for: .primary)
            split.setViewController(UIViewController(), for: .secondary)
            split.setViewController(UIViewController(), for: .compact)
            window?.rootViewController = split
            await settle()
            check(split.contentDict.isEmpty, "Fixture: split Connections not created")
            let importer = ImportViewController()
            await present(UINavigationController(rootViewController: importer), from: split)
            importer.finishRemoteAuthorization(testServer)
            await settle()
            let navigation = split.contentDict[PrimaryCellItemType.connect.rawValue]
            let connections = navigation?.viewControllers.first as? ConnectListViewController
            check(connections?.opened == [testServer.id], "Create split Connections lazily and open account")
            check(navigation?.viewControllers.count == 2, "Split Back destination is Connections")
            await settle()
        }

        // Authorization callback arriving after the user closed Import is ignored.
        do {
            let importer = ImportViewController()
            importer.finishRemoteAuthorization(testServer)
            check(importer.presentingViewController == nil, "Detached callback cannot present a file list")
        }
    }
}
