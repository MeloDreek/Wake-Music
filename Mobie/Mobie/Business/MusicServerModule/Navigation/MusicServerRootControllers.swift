import UIKit
import KakaUIKit
import KakaFoundation
import AppGroupKit

/// Every destination shares the same account-scoped session and playback engine.
@MainActor
private enum MusicServerDestination: Int, CaseIterable {
    case home, library, search, profile

    var title: String {
        switch self {
        case .home: return "Home".localStr()
        case .library: return "Library".localStr()
        case .search: return "Search".localStr()
        case .profile: return KakaTabbarType.profile.formatStr()
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .library: return "square.stack"
        case .search: return "magnifyingglass"
        case .profile: return "person.crop.circle"
        }
    }

    func controller(session: MusicServerSession, onExit: @escaping () -> Void) -> UIViewController {
        switch self {
        case .home: return MusicServerHomeViewController(session: session, onExit: onExit)
        case .profile: return ProfileViewController()
        case .library: return MusicServerLibraryViewController(session: session)
        case .search: return MusicServerSearchViewController(session: session)
        }
    }
}

@MainActor
final class MusicServerTabBarController: UITabBarController {
    private let session: MusicServerSession
    private let onExit: () -> Void
    private lazy var playback = MusicServerPlaybackChrome(host: self)

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
        viewControllers = MusicServerDestination.allCases.map { destination in
            let controller = destination.controller(session: session, onExit: onExit)
            let navigation = KakaNavigationController(rootViewController: controller)
            navigation.tabBarItem = UITabBarItem(title: destination.title, image: UIImage(systemName: destination.symbol), tag: destination.rawValue)
            // Shared Profile screens already reserve playingHeight in their scroll insets.
            navigation.additionalSafeAreaInsets.bottom = destination == .profile ? 6 : playingHeight + 6
            return navigation
        }
        playback.install(in: view, bottom: tabBar.topAnchor)
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: Notification.Name(kAppearanceChangedKey), object: nil)
        AppStoreKitManager.shared.verifyPaymentRecords()
    }

    @objc private func updateAppearance() {
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        tabBar.tintColor = appMainColor
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
        playback.install(in: view, bottom: view.safeAreaLayoutGuide.bottomAnchor)
        overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        NotificationCenter.default.addObserver(self, selector: #selector(updateAppearance), name: Notification.Name(kAppearanceChangedKey), object: nil)
        AppStoreKitManager.shared.verifyPaymentRecords()
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.backward"), style: .plain, target: self, action: #selector(exitMode))
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Back to Classic Mode".localStr()
        tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
    }

    @objc private func exitMode() { onExit() }

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

    init(host: UIViewController) {
        self.host = host
        super.init()
        toolbar.toolDelegate = self
        KakaMusicPlayer.shared.restoreRemoteQueueIfNeeded()
        toolbar.musicModel = KakaMusicPlayer.shared.playingMusic
    }

    func install(in view: UIView, bottom: NSLayoutYAxisAnchor) {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: bottom, constant: -4),
            toolbar.heightAnchor.constraint(equalToConstant: playingHeight)
        ])
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
