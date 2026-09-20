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
    private weak var exitConfirmation: UIAlertController?

    init(window: UIWindow) { self.window = window }

    /// Navigation bars reconfigure SF Symbols and can discard UIImage orientation.
    /// Bake a left-pointing glyph into a template, then let UIKit mirror it for RTL.
    static let exitImage: UIImage? = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        guard let symbol = UIImage(systemName: "rectangle.portrait.and.arrow.right", withConfiguration: configuration) else { return nil }
        let image = UIGraphicsImageRenderer(size: symbol.size).image { context in
            context.cgContext.translateBy(x: symbol.size.width, y: 0)
            context.cgContext.scaleBy(x: -1, y: 1)
            symbol.draw(in: CGRect(origin: .zero, size: symbol.size))
        }
        return image.withRenderingMode(.alwaysTemplate).imageFlippedForRightToLeftLayoutDirection()
    }()

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
        // Retire server work before constructing Classic's first screen. A late
        // playback/metadata callback must not restore the song we just left.
        if let root = window?.rootViewController { cancelServerRequests(in: root) }
        KakaMusicPlayer.shared.resetToPausedDemo()
        AppLocalManager.shared.homeMode = .classic
        // Keep the saved account itself; Exit is not Logout.
        replaceRoot(makeClassicRoot(), returning: true)
    }

    private func requestExitToClassic() {
        guard !isSwitching, activeServer != nil, exitConfirmation == nil,
              let root = window?.rootViewController else { return }
        var presenter = root
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        guard !(presenter is UIAlertController), !presenter.isBeingDismissed else { return }
        let alert = UIAlertController(title: "Back to Classic Mode".localStr(),
            message: "MusicServer.ExitConfirmation".localStr(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel) { [weak self] _ in
            self?.exitConfirmation = nil
        })
        alert.addAction(UIAlertAction(title: "Continue".localStr(), style: .default) { [weak self, weak root] _ in
            guard let self else { return }
            self.exitConfirmation = nil
            // A stale confirmation cannot replace a newer shell/account.
            guard let root, self.window?.rootViewController === root, self.activeServer != nil else { return }
            self.showClassic()
        })
        exitConfirmation = alert
        presenter.present(alert, animated: true)
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
        let exit: () -> Void = { [weak self] in self?.requestExitToClassic() }
        if UIDevice.current.userInterfaceIdiom == .pad || kaka_IsMacOS() {
            return MusicServerSplitViewController(session: session, onExit: exit)
        }
        return MusicServerTabBarController(session: session, onExit: exit)
    }

    private func replaceRoot(_ root: UIViewController, returning: Bool = false) {
        guard let window else { return }
        isSwitching = true
        let oldRoot = window.rootViewController
        let replace = { [weak self, weak window] in
            guard let self else { return }
            // Root construction can start indefinitely repeating layer animations.
            // A CATransaction completion enclosing it may therefore never fire.
            // Gate only the root replacement, never the lifetime of those animations.
            defer { self.isSwitching = false }
            guard let window else { return }
            window.layer.removeAnimation(forKey: "musicServerModeTransition")
            let animated = !kaka_IsMacOS() && !UIAccessibility.isReduceMotionEnabled
            if animated {
                let rtl = window.effectiveUserInterfaceLayoutDirection == .rightToLeft
                let transition = CATransition()
                transition.type = CATransitionType(rawValue: "cube")
                transition.subtype = returning != rtl ? .fromLeft : .fromRight
                transition.duration = 0.35
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.layer.add(transition, forKey: "musicServerModeTransition")
            }
            self.retireClassicRoot(oldRoot)
            window.rootViewController = root
            window.makeKeyAndVisible()
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
            classic.cancellables.removeAll()
        } else if let classic = root as? MacTabbarViewController {
            classic.fileWatcher.stopWatching()
            classic.cancellables.removeAll()
        }
        // Cancel delayed root setup/review actions before their view disappears.
        NSObject.cancelPreviousPerformRequests(withTarget: root)
        NotificationCenter.default.removeObserver(root)
        cancelServerRequests(in: root)
    }

    private func cancelServerRequests(in controller: UIViewController) {
        (controller as? MusicServerHomeViewController)?.cancelPendingRequests()
        (controller as? MusicServerSearchViewController)?.cancelPendingRequests()
        (controller as? MusicServerBrowseViewController)?.cancelPendingRequests()
        for child in controller.children { cancelServerRequests(in: child) }
    }
}
