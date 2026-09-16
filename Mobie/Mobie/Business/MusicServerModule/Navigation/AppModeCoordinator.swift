import UIKit
import KakaUIKit
import KakaFoundation
import AppGroupKit

/// A coordinator belongs to one main window. Switching its shell never replaces
/// the process-wide playback engine or chooses an unrelated scene's key window.
@MainActor
final class AppModeCoordinator {
    private weak var window: UIWindow?
    private var isSwitching = false
    private var activeServer: NavidromeUserModel?

    init(window: UIWindow) { self.window = window }

    func restoredRootController() -> UIViewController {
        let settings = AppLocalManager.shared
        if settings.homeMode == .navidrome,
           let accountID = settings.musicServerAccountID,
           let user = ConnectConfigManager.shared.connectedModels.compactMap(\.navUser)
            .first(where: { MusicServerSession.identity(for: $0) == accountID }) {
            // Expired users can still reach Profile/the paywall in Classic mode.
            if UserInfoManager.shared.isVIP() { return makeServerRoot(user) }
        } else if settings.homeMode != .classic {
            // Deleted accounts and not-yet-implemented providers cannot strand
            // the user on an empty window after relaunch.
            settings.homeMode = .classic
            settings.musicServerAccountID = nil
        }
        return makeClassicRoot()
    }

    static func enterNavidrome(_ user: NavidromeUserModel, from controller: UIViewController) {
        guard let scene = controller.viewIfLoaded?.window?.windowScene,
              let delegate = scene.delegate as? SceneDelegate else { return }
        guard UserInfoManager.shared.isVIP() else {
            SuperViewController.showRemoteConnectionPaywall(on: controller)
            return
        }
        delegate.modeCoordinator?.enterNavidrome(user)
    }

    func enterNavidrome(_ user: NavidromeUserModel) {
        guard !isSwitching else { return }
        AppLocalManager.shared.musicServerAccountID = MusicServerSession.identity(for: user)
        AppLocalManager.shared.homeMode = .navidrome
        replaceRoot(makeServerRoot(user))
    }

    func showClassic() {
        guard !isSwitching else { return }
        AppLocalManager.shared.homeMode = .classic
        // Keep the saved account itself; Exit is not Logout.
        replaceRoot(makeClassicRoot())
    }

    func reloadCurrentMode() {
        guard !isSwitching else { return }
        replaceRoot(activeServer.map(makeServerRoot) ?? makeClassicRoot())
    }

    private func makeClassicRoot() -> UIViewController {
        activeServer = nil
        return kaka_IsMacOS() ? MacTabbarViewController(style: .doubleColumn) : HomeTabbarViewController()
    }

    private func makeServerRoot(_ user: NavidromeUserModel) -> UIViewController {
        activeServer = user
        let session = MusicServerSession(user: user)
        let exit: () -> Void = { [weak self] in self?.showClassic() }
        if UIDevice.current.userInterfaceIdiom == .pad || kaka_IsMacOS() {
            return MusicServerSplitViewController(session: session, onExit: exit)
        }
        return MusicServerTabBarController(session: session, onExit: exit)
    }

    private func replaceRoot(_ root: UIViewController) {
        guard let window else { return }
        isSwitching = true
        let oldRoot = window.rootViewController
        let replace = { [weak self, weak window] in
            guard let self, let window else { return }
            self.retireClassicRoot(oldRoot)
            window.rootViewController = root
            window.makeKeyAndVisible()
            self.isSwitching = false
        }
        if oldRoot?.presentedViewController != nil {
            oldRoot?.dismiss(animated: false, completion: replace)
        } else {
            replace()
        }
    }

    private func retireClassicRoot(_ root: UIViewController?) {
        guard let root else { return }
        if let classic = root as? HomeTabbarViewController {
            classic.fileWatcher.stopWatching()
            classic.timer.stopTimer()
            classic.cancellables.removeAll()
        } else if let classic = root as? MacTabbarViewController {
            classic.fileWatcher.stopWatching()
            classic.cancellables.removeAll()
            if classic.isViewLoaded { classic.primaryVC.timer.stopTimer() }
        }
        // Cancel delayed root setup/review actions before their view disappears.
        NSObject.cancelPreviousPerformRequests(withTarget: root)
        NotificationCenter.default.removeObserver(root)
        cancelServerRequests(in: root)
    }

    private func cancelServerRequests(in controller: UIViewController) {
        (controller as? MusicServerHomeViewController)?.cancelPendingRequests()
        for child in controller.children { cancelServerRequests(in: child) }
    }
}
