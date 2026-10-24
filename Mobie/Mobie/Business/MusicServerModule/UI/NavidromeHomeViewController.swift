import UIKit
import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import SafariServices

/// Account-scoped data fills the six sections of the native grouped homepage.
final class NavidromeHomeViewController: SuperViewController {
    private typealias Section = NavidromeSection
    let session: MusicServerSession
    private let onExit: () -> Void
    private let loadingView = MusicServerLoadingView()
    private var overview: MusicServerOverview?
    private var previews: [Section: [MusicServerItem]] = [:]
    private var loadingSections = Set<Section>()
    private var failedSections = Set<Section>()
    private var sectionErrors: [Section: String] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var authenticated = false
    private var authenticationFailed = false
    private var authenticationError = "Unable to connect to this music server.".localStr()
    private var hasAppeared = false
    private var isCreatingPlaylist = false
    private weak var playlistNameAlert: UIAlertController?
    private var favoriteChanges = Set<String>()
    private var favoriteOverrides: [String: Bool] = [:]
    private var playbackSubscriptions = Set<AnyCancellable>()

    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { tasks.values.forEach { $0.cancel() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubViews()
        setupContains()
        handleBuness()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard self?.viewIfLoaded?.window != nil else { return }
            TrackingAuthorizationManager.shared.requestIDFAAuthorization()
        }
    }

    func setupSubViews() {
        navigationItem.title = session.user.customName.isEmpty ? "Navidrome" : session.user.customName
        navigationItem.largeTitleDisplayMode = .always
        let exit = UIBarButtonItem(image: AppModeCoordinator.exitImage, style: .plain, target: self, action: #selector(exitTapped))
        exit.accessibilityLabel = "Back to Classic Mode".localStr()
        navigationItem.leftBarButtonItem = exit
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
    }

    func setupContains() {
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        loadingView.snp.makeConstraints { $0.edges.equalTo(contentView.safeAreaLayoutGuide) }
    }

    func handleBuness() {
        configSearchBar()
        NotificationCenter.default.addObserver(self, selector: #selector(recentHistoryChanged(_:)), name: MusicServerHistory.didChange, object: nil)
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshVisiblePlaybackState()
        }.store(in: &playbackSubscriptions)
        KakaMusicPlayer.shared.$playbackStatus.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshVisiblePlaybackState()
        }.store(in: &playbackSubscriptions)
        refreshDataAction()
    }

    // MARK: GET && SET
    lazy var sectionArray: [NavidromeSection] = {
        return NavidromeSection.allCases
    }()

    // MARK: 懒加载
    private lazy var webFooter: UIView = {
        let footer = UIView()
        let button = UIButton(type: .system)
        button.setAttributedTitle(NSAttributedString(string: "MusicServer.Home.ViewOnWeb".localStr(), attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]), for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.isEnabled = session.webURL != nil
        button.addTarget(self, action: #selector(openServerWebsite), for: .touchUpInside)
        footer.addSubview(button)
        button.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(20)
            $0.trailing.lessThanOrEqualToSuperview().inset(20)
            $0.top.bottom.equalToSuperview().inset(16)
            $0.height.greaterThanOrEqualTo(44)
        }
        return footer
    }()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = webFooter.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let size = CGSize(width: width, height: ceil(height))
        if webFooter.frame.size != size || tableView.tableFooterView == nil {
            webFooter.frame.size = size
            tableView.tableFooterView = webFooter
        }
    }

    @objc private func openServerWebsite() {
        guard let url = session.webURL, presentedViewController == nil else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.rowHeight = UITableView.automaticDimension
        view.estimatedRowHeight = 80
        view.sectionHeaderHeight = UITableView.automaticDimension
        view.estimatedSectionHeaderHeight = 44
        view.keyboardDismissMode = .onDrag
        view.delegate = self
        view.dataSource = self
#if !targetEnvironment(macCatalyst)
        view.refreshControl = self.kaka_header
#endif
        view.allowsMultipleSelection = false
        view.allowsMultipleSelectionDuringEditing = false
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: 0, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(NavidromeSectionHeadView.self, forHeaderFooterViewReuseIdentifier: "NavidromeSectionHeadView")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        view.register(MusicServerRecentUploadCell.self, forCellReuseIdentifier: "RecentUploadCell")
        view.register(NavidromeOverviewCell.self, forCellReuseIdentifier: "NavidromeOverviewCell")
        view.register(NavidromeRecentViewCell.self, forCellReuseIdentifier: "NavidromeRecentViewCell")
        view.register(NavidromeRecentViewCell.self, forCellReuseIdentifier: "NavidromeRandomViewCell")
        view.register(NavidromeFavoriteViewCell.self, forCellReuseIdentifier: "NavidromeFavoriteViewCell")
        view.register(NavidromePlaylistViewCell.self, forCellReuseIdentifier: "NavidromePlaylistViewCell")
        view.register(NavidromeEmptyViewCell.self, forCellReuseIdentifier: "NavidromeEmptyViewCell")
        return view
    }()

    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()

    lazy var searchController: NavidromeSearchViewController = {
        let searchVC = NavidromeSearchViewController(session: session)
        return searchVC
    }()


    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared, authenticated {
            // Full-list screens can change favorites/history/playlists.
            for section in [Section.recent, .favorites, .playlists] where !loadingSections.contains(section) {
                loadSection(section, generation: generation)
            }
        }
        hasAppeared = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tableView.reloadData()
        }
    }

    @objc private func exitTapped() {
        // The coordinator asks for confirmation first. Cancelling the prompt
        // must not cancel loads or change the current playback state.
        onExit()
    }

    @objc private func recentHistoryChanged(_ notification: Notification) {
        guard authenticated, viewIfLoaded?.window != nil,
              let accountID = notification.object as? String, accountID == session.accountID else { return }
        loadSection(.recent, generation: generation)
    }

    func cancelPendingRequests() {
        searchController.cancelPendingRequests()
        generation = UUID()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    @objc private func refreshDataAction() {
        guard !isCreatingPlaylist, favoriteChanges.isEmpty else { kaka_header.endRefreshing(); return }
        cancelPendingRequests()
        favoriteOverrides.removeAll()
        authenticated = false
        authenticationFailed = false
        failedSections.removeAll()
        sectionErrors.removeAll()
        loadingSections.removeAll()
        previews.removeAll()
        overview = nil
        loadingView.isHidden = false
        loadingView.configure(.loading)
        tableView.reloadData()
        let requestGeneration = generation
        let session = session
        tasks["authenticate"] = Task { [weak self] in
            do {
                _ = try await session.authenticate()
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.authenticated = true
                self.loadingSections = Set(Section.allCases)
                self.tableView.reloadData()
                self.loadOverview(generation: requestGeneration)
                for section in Section.allCases where section != .overview {
                    self.loadSection(section, generation: requestGeneration)
                }
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.authenticationFailed = true
                self.authenticationError = (error as? MusicServerError)?.localizedDescription ?? "Unable to connect to this music server.".localStr()
                self.loadingView.configure(.failed(self.authenticationError)) { [weak self] in self?.refreshDataAction() }
                self.kaka_header.endRefreshing()
                self.tableView.reloadData()
            }
        }
    }

    private func loadOverview(generation requestGeneration: UUID) {
        loadingSections.insert(.overview)
        failedSections.remove(.overview)
        tasks["overview"]?.cancel()
        let session = session
        tasks["overview"] = Task { [weak self] in
            do {
                let value = try await session.overview()
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.overview = value
                self.finishLoading(.overview)
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.failedSections.insert(.overview)
                self.sectionErrors[.overview] = (error as? MusicServerError)?.localizedDescription
                self.finishLoading(.overview)
            }
        }
    }

    private func loadSection(_ section: Section, generation requestGeneration: UUID) {
        guard let route = section.route else { return }
        let key = "section-\(section.rawValue)"
        tasks[key]?.cancel()
        loadingSections.insert(section)
        failedSections.remove(section)
        let session = session
        tasks[key] = Task { [weak self] in
            do {
                let items: [MusicServerItem]
                if section == .playlists {
                    items = try await session.allPlaylists()
                } else {
                    items = try await session.page(route, offset: 0, limit: section.previewLimit).items
                }
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                var seen = Set<String>()
                let unique = items.filter { seen.insert($0.id).inserted }.map(self.applyingFavoriteOverride)
                    .filter { if section == .favorites, case .song(let song) = $0 { return song.value.starred }; return true }
                self.previews[section] = section == .playlists ? unique : Array(unique.prefix(section.previewLimit))
                self.finishLoading(section)
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.failedSections.insert(section)
                self.sectionErrors[section] = (error as? MusicServerError)?.localizedDescription
                self.finishLoading(section)
            }
        }
    }

    private func finishLoading(_ section: Section) {
        loadingSections.remove(section)
        if loadingSections.isEmpty { kaka_header.endRefreshing() }
        loadingView.isHidden = true
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    private func retry(_ section: Section) {
        if section == .overview { loadOverview(generation: generation) }
        else { loadSection(section, generation: generation) }
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    private func showAll(_ section: Section) {
        guard let route = section.route else { return }
        showList(route: route, title: section.title ?? "")
    }

    private func refreshDiscovery() {
        guard authenticated, !loadingSections.contains(.random) else { return }
        // Keep the current batch visible until a replacement succeeds.
        loadSection(.random, generation: generation)
        tableView.reloadSections(IndexSet(integer: Section.random.rawValue), with: .none)
    }

    private func createPlaylistTapped() {
        guard authenticated, !isCreatingPlaylist, presentedViewController == nil else { return }
        let alert = UIAlertController(title: "New Playlist".localStr(), message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.placeholder = "Name".localStr()
            field.autocapitalizationType = .sentences
            field.returnKeyType = .done
            field.addTarget(self, action: #selector(NavidromeHomeViewController.playlistNameChanged(_:)), for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel))
        let create = UIAlertAction(title: "Confirm".localStr(), style: .default) { [weak self, weak alert] _ in
            let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            self?.createPlaylist(name: name)
        }
        create.isEnabled = false
        alert.addAction(create)
        alert.preferredAction = create
        playlistNameAlert = alert
        present(alert, animated: true)
    }

    @objc private func playlistNameChanged(_ field: UITextField) {
        playlistNameAlert?.preferredAction?.isEnabled = !(field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createPlaylist(name: String) {
        guard !isCreatingPlaylist else { return }
        isCreatingPlaylist = true
        tableView.reloadSections(IndexSet(integer: Section.playlists.rawValue), with: .none)
        let requestGeneration = generation
        let session = session
        tasks["create-playlist"] = Task { [weak self] in
            do {
                try await session.createPlaylist(name: name)
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.isCreatingPlaylist = false
                self.loadSection(.playlists, generation: requestGeneration)
                self.tableView.reloadSections(IndexSet(integer: Section.playlists.rawValue), with: .none)
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.isCreatingPlaylist = false
                let message = (error as? MusicServerError)?.localizedDescription ?? "Unable to connect to the music server. Please try again.".localStr()
                // Keep a visible failure even if the name alert is still closing
                // or an exit confirmation currently owns the presentation slot.
                self.failedSections.insert(.playlists)
                self.sectionErrors[.playlists] = message
                self.tableView.reloadSections(IndexSet(integer: Section.playlists.rawValue), with: .none)
                let alert = UIAlertController(title: "New Playlist".localStr(), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK".localStr(), style: .default))
                if self.viewIfLoaded?.window != nil, self.presentedViewController == nil,
                   self.navigationController?.presentedViewController == nil,
                   self.tabBarController?.presentedViewController == nil {
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func showList(route: MusicServerRoute, title: String) {
        MusicServerSelection.browse(route, title: title, session: session, from: self)
    }

    private func showOverviewCategory(_ index: Int) {
        let routes: [MusicServerRoute] = [.songs, .artists, .albums, .radios]
        let titles = ["Songs", "Artists", "Albums", "Radio Stations"]
        guard routes.indices.contains(index) else { return }
        showList(route: routes[index], title: titles[index].localStr())
    }

    private func applyingFavoriteOverride(_ item: MusicServerItem) -> MusicServerItem {
        guard case .song(var song) = item, let favorite = favoriteOverrides[song.id] else { return item }
        song.value.starred = favorite
        return .song(song)
    }

    private func refreshVisiblePlaybackState() {
        for cell in tableView.visibleCells {
            if let shelf = cell as? NavidromeRecentViewCell { shelf.refreshPlaybackState() }
            if let songCell = cell as? MusicTableViewCell, let model = songCell.musicModel {
                songCell.update(musicModel: model, cellType: .navidromeTrack)
            }
        }
    }

    private func showActionError(_ error: Error) {
        guard viewIfLoaded?.window != nil else { return }
        view.makeToast((error as? MusicServerError)?.localizedDescription ?? "Unable to connect to the music server. Please try again.".localStr())
    }
}

extension NavidromeHomeViewController: MusicTableViewCellDelegate {
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        handleSongAction(model: model, action: action)
    }

    private func handleSongAction(model: MusicItemModel, action: MusicActionType) {
        guard let song = model.navidromeSong, let user = song.navUser,
              MusicServerSession.identity(for: user) == session.accountID else { return }
        switch action {
        case .addFavirote, .removeFavirote:
            guard favoriteChanges.insert(song.id).inserted else { return }
            let favorite = action == .addFavirote
            let requestGeneration = generation
            tasks["favorite-" + song.id] = Task { [weak self] in
                guard let self else { return }
                defer { self.favoriteChanges.remove(song.id) }
                do {
                    try await self.session.setSongFavorite(id: song.id, isFavorite: favorite)
                    guard !Task.isCancelled, self.generation == requestGeneration else { return }
                    self.favoriteOverrides[song.id] = favorite
                    for section in Section.allCases {
                        self.previews[section] = self.previews[section]?.map(self.applyingFavoriteOverride)
                    }
                    self.previews[.favorites] = self.previews[.favorites]?.filter {
                        if case .song(let song) = $0 { return song.value.starred }
                        return true
                    }
                    // Re-fetch only favorites; the random selection and horizontal positions stay intact.
                    self.loadSection(.favorites, generation: self.generation)
                    self.tableView.reloadData()
                    self.view.makeToast("Successful".localStr())
                } catch {
                    guard !Task.isCancelled, self.generation == requestGeneration else { return }
                    self.showActionError(error)
                }
            }
        case .addPlaylist:
            guard presentedViewController == nil else { return }
            let server = ServerConfigModel(serverType: .fromNavidrome, navUser: session.user)
            let picker = SelectPlaylistController(selectType: .navidromeList, serverModel: server)
            picker.onRemoteBlock = { [weak self] playlist in
                guard let self, self.viewIfLoaded?.window != nil else { return }
                let key = "add-playlist-" + playlist.id + "-" + song.id
                guard self.tasks[key] == nil else { return }
                let requestGeneration = self.generation
                self.tasks[key] = Task { [weak self] in
                    guard let self else { return }
                    defer { self.tasks[key] = nil }
                    do {
                        try await self.session.addSongToPlaylist(songID: song.id, playlistID: playlist.id)
                        guard !Task.isCancelled, self.generation == requestGeneration else { return }
                        self.loadSection(.playlists, generation: self.generation)
                        self.view.makeToast("Successful".localStr())
                    } catch {
                        guard !Task.isCancelled, self.generation == requestGeneration else { return }
                        self.showActionError(error)
                    }
                }
            }
            present(KakaNavigationController(rootViewController: picker), animated: true)
        case .download:
            guard presentedViewController == nil else { return }
            let picker = SelectPlaylistController(selectType: .downloadTask)
            picker.onLocalBlock = { [weak self] folder in
                guard let self, self.viewIfLoaded?.window != nil else { return }
                var download = model
                download.downloadFolderName = folder.lastPathComponent
                DownloadManager.shared.addMusicModel([download])
                self.view.makeToast("Added to Downloads".localStr())
            }
            present(KakaNavigationController(rootViewController: picker), animated: true)
        case .artistDetial:
            guard let id = song.artistId, !id.isEmpty else { return }
            showList(route: .artist(id: id), title: song.artist)
        case .albumDetial:
            guard let id = song.albumId, !id.isEmpty else { return }
            showList(route: .album(id: id), title: song.album)
        default: break
        }
    }
}

extension NavidromeHomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { authenticated ? sectionArray.count : 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard authenticated, let kind = Section(rawValue: section), kind != .overview else { return 1 }
        if kind.isShelf { return 1 }
        let count = previews[kind]?.count ?? 0
        return max(1, count + (count > 0 && failedSections.contains(kind) ? 1 : 0))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard authenticated, let section = Section(rawValue: indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NavidromeEmptyViewCell", for: indexPath) as! NavidromeEmptyViewCell
            cell.minimumHeight = 180
            cell.configure(authenticationFailed ? .failed(authenticationError) : .loading) { [weak self] in self?.refreshDataAction() }
            return cell
        }
        if section == .overview, let overview {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NavidromeOverviewCell", for: indexPath) as! NavidromeOverviewCell
            cell.configure(overview) { [weak self] in self?.showOverviewCategory($0) }
            return cell
        }
        if section.isShelf, let items = previews[section], !items.isEmpty {
            let identifier = section == .favorites ? "NavidromeFavoriteViewCell" :
                (section == .random ? "NavidromeRandomViewCell" : "NavidromeRecentViewCell")
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! NavidromeRecentViewCell
            cell.configure(items: items, session: session, onSongAction: { [weak self] item, action in
                guard let self, case .song(let song) = item else { return }
                self.handleSongAction(model: self.session.musicItem(for: song), action: action)
            }) { [weak self] item in
                guard let self else { return }
                MusicServerSelection.open(item, among: items, session: self.session, from: self)
            }
            return cell
        }
        if let items = previews[section], items.indices.contains(indexPath.row) {
            if case .song(let song) = items[indexPath.row] {
                if section == .recentlyAdded {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "RecentUploadCell", for: indexPath) as! MusicServerRecentUploadCell
                    cell.delegate = self
                    cell.configure(song: song, session: session)
                    return cell
                }
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                cell.delegate = self
                cell.update(musicModel: session.musicItem(for: song), cellType: .navidromeTrack)
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "NavidromePlaylistViewCell", for: indexPath) as! NavidromePlaylistViewCell
            cell.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            cell.configure(item: items[indexPath.row], session: session)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "NavidromeEmptyViewCell", for: indexPath) as! NavidromeEmptyViewCell
        cell.minimumHeight = 168
        let state: MusicServerLoadState
        if loadingSections.contains(section) { state = .loading }
        else if failedSections.contains(section) { state = .failed(sectionErrors[section] ?? "This section could not be loaded.".localStr()) }
        else { state = .empty(section.emptyMessage) }
        cell.configure(state) { [weak self] in self?.retry(section) }
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard authenticated, let kind = Section(rawValue: section) else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "NavidromeSectionHeadView") as! NavidromeSectionHeadView
        switch kind {
        case .overview:
            return nil
        case .recent, .favorites:
            header.configure(title: kind.title ?? "", navigation: { [weak self] in self?.showAll(kind) })
        case .playlists:
            header.configure(title: kind.title ?? "", actionTitle: "New Playlist".localStr(), actionSymbol: "plus",
                             actionEnabled: !isCreatingPlaylist, action: { [weak self] in self?.createPlaylistTapped() })
        case .random:
            header.configure(title: kind.title ?? "", navigation: { [weak self] in self?.showAll(kind) }, actionTitle: "MusicServer.Home.RefreshBatch".localStr(),
                             actionEnabled: !loadingSections.contains(.random), action: { [weak self] in self?.refreshDiscovery() })
        case .recentlyAdded:
            header.configure(title: kind.title ?? "")
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        authenticated && sectionArray[section] != .overview ? UITableView.automaticDimension : .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        authenticated ? 22 : .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard authenticated, let section = Section(rawValue: indexPath.section),
              !section.isShelf,
              let items = previews[section], items.indices.contains(indexPath.row) else { return }
        MusicServerSelection.open(items[indexPath.row], among: items, session: session, from: self)
    }
}
