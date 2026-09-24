import UIKit
import KakaUIKit
import KakaFoundation
import AppGroupKit
import Combine

/// Every destination shares the same account-scoped session and playback engine.
@MainActor
private enum MusicServerDestination: Int, CaseIterable {
    case home, library, download, profile

    var title: String {
        switch self {
        case .home: return "Home".localStr()
        case .library: return "Library".localStr()
        case .download: return "Download".localStr()
        case .profile: return KakaTabbarType.profile.formatStr()
        }
    }

    var symbol: String {
        switch self {
        case .home: return "music.note.house"
        case .library: return "rectangle.stack"
        case .download: return "arrow.down.circle"
        case .profile: return "person.crop.circle"
        }
    }

    var symbol_sel: String {
        switch self {
        case .home: return "music.note.house.fill"
        case .library: return "rectangle.stack.fill"
        case .download: return "arrow.down.circle.fill"
        case .profile: return "person.crop.circle.fill"
        }
    }

    func controller(session: MusicServerSession, onExit: @escaping () -> Void) -> UIViewController {
        switch self {
        case .home: return NavidromeHomeViewController(session: session, onExit: onExit)
        case .profile: return ProfileViewController()
        case .library: return MusicServerLibraryViewController(session: session)
        case .download: return NavidromeDownloadViewController(onExit: onExit)
        }
    }
}

@MainActor
final class MusicServerTabBarController: UITabBarController, UITabBarControllerDelegate {
    private let session: MusicServerSession
    private let onExit: () -> Void
    private lazy var playback = MusicServerPlaybackChrome(host: self)
    private var downloadBadgeSubscription: AnyCancellable?
    var onSelectedDestination: ((Int) -> Void)?

    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tabBar.tintColor = appMainColor
        delegate = self
        viewControllers = MusicServerDestination.allCases.map { destination in
            let controller = destination.controller(session: session, onExit: onExit)
            let navigation = KakaNavigationController(rootViewController: controller)
            navigation.tabBarItem = UITabBarItem(title: destination.title, image: UIImage(systemName: destination.symbol), selectedImage: UIImage(systemName: destination.symbol_sel))
            // Shared Profile screens already reserve playingHeight in their scroll insets.
            navigation.additionalSafeAreaInsets.bottom = destination == .profile ? 6 : playingHeight + 6
            return navigation
        }
        playback.install(in: view)
        // Observe at the root so the badge works before the Downloads tab is ever opened.
        updateDownloadBadge(DownloadManager.shared.taskArray.count)
        downloadBadgeSubscription = DownloadManager.shared.$taskArray
            .map { $0.count }.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] count in self?.updateDownloadBadge(count) }
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: Notification.Name(kAppearanceChangedKey), object: nil)
        AppStoreKitManager.shared.verifyPaymentRecords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playback.updateLayout(avoiding: tabBar)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        playback.updateLayout(avoiding: tabBar)
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        onSelectedDestination?(selectedIndex)
    }

    @objc private func updateAppearance() {
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        tabBar.tintColor = appMainColor
    }

    private func updateDownloadBadge(_ count: Int) {
        let index = MusicServerDestination.download.rawValue
        guard let controllers = viewControllers, controllers.indices.contains(index) else { return }
        // UIKit's built-in badge keeps the system styling; nil hides it when the queue empties.
        controllers[index].tabBarItem.badgeValue = count > 0 ? String(count) : nil
    }
}

/// A single tab controller owns the account's navigation stacks in both sizes.
/// The split view adds a sidebar when there is room; folding never creates a
/// new session, restores a queue, or replaces the window's root controller.
@available(iOS 18.0, *)
@MainActor
final class MusicServerAdaptiveRootController: UISplitViewController, UISplitViewControllerDelegate {
    private let tabs: MusicServerTabBarController
    private let onExit: () -> Void
    private var sidebar: MusicServerSidebarController?

    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        tabs = MusicServerTabBarController(session: session, onExit: onExit)
        self.onExit = onExit
        super.init(style: .doubleColumn)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        view.backgroundColor = .systemBackground
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        minimumPrimaryColumnWidth = 200
        maximumPrimaryColumnWidth = 280
        preferredPrimaryColumnWidthFraction = 0.25
        // Compact navigation belongs to the tabs, not a hidden sidebar stack.
        presentsWithGesture = false
        let sidebar = MusicServerSidebarController(onSelect: { [weak self] destination in
            self?.tabs.selectedIndex = destination.rawValue
        }, onExit: onExit)
        self.sidebar = sidebar
        tabs.onSelectedDestination = { [weak sidebar] index in sidebar?.selectDestination(at: index) }
        setViewController(KakaNavigationController(rootViewController: sidebar), for: .primary)

        // Split view otherwise inserts its own navigation bar around a tab
        // controller. The destination navigation bars are already inside tabs.
        let content = UINavigationController(rootViewController: tabs)
        content.setNavigationBarHidden(true, animated: false)
        setViewController(content, for: .secondary)
        updatePresentation()
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance),
            name: Notification.Name(kAppearanceChangedKey), object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePresentation()
    }

    func splitViewController(_ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        tabs.setTabBarHidden(false, animated: false)
        return .secondary
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) { updatePresentation() }
    func splitViewControllerDidExpand(_ svc: UISplitViewController) { updatePresentation() }

    private func updatePresentation() {
        // Leave a tab strip available if UIKit temporarily shows only content.
        let hasSidebar = !isCollapsed && displayMode != .secondaryOnly
        if tabs.isTabBarHidden != hasSidebar {
            tabs.setTabBarHidden(hasSidebar, animated: false)
        }
        sidebar?.selectDestination(at: tabs.selectedIndex)
    }

    @objc private func updateAppearance() {
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
    }
}

@MainActor
final class MusicServerSplitViewController: UISplitViewController {
    private let session: MusicServerSession
    private let onExit: () -> Void
    private var destinations: [MusicServerDestination: UINavigationController] = [:]
    private lazy var playback = MusicServerPlaybackChrome(host: self)

    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        self.onExit = onExit
        super.init(style: .doubleColumn)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        minimumPrimaryColumnWidth = 220
        maximumPrimaryColumnWidth = 300
        preferredPrimaryColumnWidthFraction = 0.25
        let sidebar = MusicServerSidebarController(onSelect: { [weak self] destination in
            self?.show(destination)
        }, onExit: onExit)
        let navigation = KakaNavigationController(rootViewController: sidebar)
        navigation.additionalSafeAreaInsets.bottom = playingHeight + 6
        setViewController(navigation, for: .primary)
        show(.home)
        playback.install(in: view)
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: Notification.Name(kAppearanceChangedKey), object: nil)
        AppStoreKitManager.shared.verifyPaymentRecords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playback.updateLayout()
    }

    private func show(_ destination: MusicServerDestination) {
        let navigation: UINavigationController
        if let existing = destinations[destination] {
            navigation = existing
        } else {
            navigation = KakaNavigationController(rootViewController: destination.controller(session: session, onExit: onExit))
            navigation.additionalSafeAreaInsets.bottom = destination == .profile ? 6 : playingHeight + 6
            destinations[destination] = navigation
        }
        setViewController(navigation, for: .secondary)
        if isCollapsed { show(.secondary) }
    }

    @objc private func updateAppearance() {
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
    }
}

@MainActor
private final class MusicServerSidebarController: UITableViewController {
    private let onSelect: (MusicServerDestination) -> Void
    private let onExit: () -> Void

    init(onSelect: @escaping (MusicServerDestination) -> Void, onExit: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onExit = onExit
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Music Server".localStr()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: AppModeCoordinator.exitImage, style: .plain, target: self, action: #selector(exitMode))
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Back to Classic Mode".localStr()
        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
    }

    @objc private func exitMode() { onExit() }

    func selectDestination(at index: Int) {
        guard isViewLoaded, MusicServerDestination.allCases.indices.contains(index) else { return }
        let indexPath = IndexPath(row: index, section: 0)
        if tableView.indexPathForSelectedRow != indexPath {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { MusicServerDestination.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let destination = MusicServerDestination.allCases[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "destination") ?? UITableViewCell(style: .default, reuseIdentifier: "destination")
        var content = cell.defaultContentConfiguration()
        content.text = destination.title
        content.image = UIImage(systemName: destination.symbol)
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(MusicServerDestination.allCases[indexPath.row])
    }
}

/// Reuses the existing mini player and engine, without creating another queue,
/// restoring an old playlist, or changing the currently playing song on entry.
@MainActor
private final class MusicServerPlaybackChrome: NSObject, @preconcurrency PlayingControlViewDelegate {
    private weak var host: UIViewController?
    private let toolbar = PlayerControlToolBarView(frame: CGRect(x: 0, y: 0, width: 390, height: playingHeight))
    private var layout: PlayerMinibarLayout?

    init(host: UIViewController) {
        self.host = host
        super.init()
        toolbar.toolDelegate = self
        KakaMusicPlayer.shared.restoreRemoteQueueIfNeeded()
        toolbar.musicModel = KakaMusicPlayer.shared.playingMusic
    }

    func install(in view: UIView) {
        guard layout == nil else { return }
        layout = PlayerMinibarLayout(toolbar: toolbar, in: view)
        layout?.update()
    }

    func updateLayout(avoiding tabBar: UITabBar? = nil) {
        layout?.update(avoiding: tabBar)
    }

    func musicControlViewDidFirstPlay(view: UIView, model: MusicItemModel?) {
        guard let model else { return }
        KakaMusicPlayer.shared.startPlayMusic(musics: [model], itemIndex: 0)
    }
    func musicControlViewDidClick(view: UIView) {
        guard let host, KakaMusicPlayer.shared.playingMusic != nil else { return }
        KakaMusicPlayer.presentPlayController(fromVC: host)
    }
    func musicControlViewDidPlaylistButton(view: UIView, playlistButton: UIButton) {
        musicControlViewDidClick(view: view)
    }
    func musicControlViewDidLongDoubleClick(view: UIView) {
        musicControlViewDidClick(view: view)
    }
}
