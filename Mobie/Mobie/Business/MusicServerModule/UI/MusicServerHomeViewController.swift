import UIKit
import KakaFoundation
import AppGroupKit

/// A listening-first dashboard. Song shelves stay bounded even on very large
/// servers; playlists and the 50-song discovery selection are real table rows.
final class MusicServerHomeViewController: SuperViewController {
    private enum Section: Int, CaseIterable {
        case overview, recent, favorites, playlists, random

        var title: String {
            switch self {
            case .overview: return "Server Overview".localStr()
            case .recent: return "Recently Played".localStr()
            case .favorites: return "Favourite Songs".localStr()
            case .playlists: return "My Playlists".localStr()
            case .random: return "Discover Music".localStr()
            }
        }

        var route: MusicServerRoute? {
            switch self {
            case .overview: return nil
            case .recent: return .recent
            case .favorites: return .favorites
            case .playlists: return .playlists
            case .random: return .random
            }
        }

        var emptyMessage: String {
            switch self {
            case .recent: return "Play something to start your listening history.".localStr()
            case .favorites: return "Your favorite songs will appear here.".localStr()
            case .playlists: return "Your playlists will appear here.".localStr()
            case .overview, .random: return "No music is available yet.".localStr()
            }
        }

        var isShelf: Bool { self == .recent || self == .favorites }
        var previewLimit: Int { self == .random ? 50 : 12 }
    }

    private let session: MusicServerSession
    private let onExit: () -> Void
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
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

    init(session: MusicServerSession, onExit: @escaping () -> Void) {
        self.session = session
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { tasks.values.forEach { $0.cancel() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = session.user.customName.isEmpty ? "Navidrome" : session.user.customName
        navigationItem.largeTitleDisplayMode = .always
        let exit = UIBarButtonItem(image: AppModeCoordinator.exitImage, style: .plain, target: self, action: #selector(exitTapped))
        exit.accessibilityLabel = "Back to Classic Mode".localStr()
        navigationItem.leftBarButtonItem = exit
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        tableView.contentInset.bottom = 20
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 62
        tableView.register(MusicServerItemCell.self, forCellReuseIdentifier: "item")
        tableView.register(MusicServerStatusCell.self, forCellReuseIdentifier: "status")
        tableView.register(MusicServerOverviewCell.self, forCellReuseIdentifier: "overview")
        tableView.register(MusicServerCarouselCell.self, forCellReuseIdentifier: "shelf")
        tableView.register(MusicServerSectionHeader.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        refreshControl.addTarget(self, action: #selector(refreshAll), for: .valueChanged)
        tableView.refreshControl = refreshControl
        NotificationCenter.default.addObserver(self, selector: #selector(recentHistoryChanged(_:)), name: MusicServerHistory.didChange, object: nil)
        refreshAll()
    }

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
        generation = UUID()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    @objc private func refreshAll() {
        guard !isCreatingPlaylist else { refreshControl.endRefreshing(); return }
        cancelPendingRequests()
        authenticated = false
        authenticationFailed = false
        failedSections.removeAll()
        sectionErrors.removeAll()
        loadingSections.removeAll()
        previews.removeAll()
        overview = nil
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
                self.refreshControl.endRefreshing()
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
                let unique = items.filter { seen.insert($0.id).inserted }
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
        if loadingSections.isEmpty { refreshControl.endRefreshing() }
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    private func retry(_ section: Section) {
        if section == .overview { loadOverview(generation: generation) }
        else { loadSection(section, generation: generation) }
        tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
    }

    private func showAll(_ section: Section) {
        guard let route = section.route else { return }
        showList(route: route, title: section.title)
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
            field.addTarget(self, action: #selector(MusicServerHomeViewController.playlistNameChanged(_:)), for: .editingChanged)
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
        navigationController?.pushViewController(MusicServerBrowseViewController(session: session, route: route, title: title), animated: true)
    }

    private func showOverviewCategory(_ index: Int) {
        let routes: [MusicServerRoute] = [.songs, .artists, .albums, .radios]
        let titles = ["Songs", "Artists", "Albums", "Radio Stations"]
        guard routes.indices.contains(index) else { return }
        showList(route: routes[index], title: titles[index].localStr())
    }
}

extension MusicServerHomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { authenticated ? Section.allCases.count : 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard authenticated, let kind = Section(rawValue: section), kind != .overview else { return 1 }
        if kind.isShelf { return 1 }
        let count = previews[kind]?.count ?? 0
        return max(1, count + (count > 0 && failedSections.contains(kind) ? 1 : 0))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard authenticated, let section = Section(rawValue: indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! MusicServerStatusCell
            cell.minimumHeight = 180
            cell.configure(authenticationFailed ? .failed(authenticationError) : .loading) { [weak self] in self?.refreshAll() }
            return cell
        }
        if section == .overview, let overview {
            let cell = tableView.dequeueReusableCell(withIdentifier: "overview", for: indexPath) as! MusicServerOverviewCell
            cell.configure(overview) { [weak self] in self?.showOverviewCategory($0) }
            return cell
        }
        if section.isShelf, let items = previews[section], !items.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "shelf", for: indexPath) as! MusicServerCarouselCell
            cell.configure(items: items, session: session) { [weak self] item in
                guard let self else { return }
                MusicServerSelection.open(item, among: items, session: self.session, from: self)
            }
            return cell
        }
        if let items = previews[section], items.indices.contains(indexPath.row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath) as! MusicServerItemCell
            cell.backgroundColor = .systemBackground
            cell.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            cell.configure(item: items[indexPath.row], session: session)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! MusicServerStatusCell
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
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as! MusicServerSectionHeader
        switch kind {
        case .overview:
            header.configure(title: kind.title)
        case .recent, .favorites:
            header.configure(title: kind.title, navigation: { [weak self] in self?.showAll(kind) })
        case .playlists:
            header.configure(title: kind.title, actionTitle: "New Playlist".localStr(), actionSymbol: "plus",
                             actionEnabled: !isCreatingPlaylist, action: { [weak self] in self?.createPlaylistTapped() })
        case .random:
            header.configure(title: kind.title, actionTitle: "MusicServer.Home.RefreshBatch".localStr(),
                             actionEnabled: !loadingSections.contains(.random), action: { [weak self] in self?.refreshDiscovery() })
        }
        return header
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if authenticated, let section = Section(rawValue: indexPath.section), section.isShelf,
           !(previews[section]?.isEmpty ?? true) {
            return MusicServerCarouselCell.preferredHeight(for: traitCollection)
        }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        authenticated ? UITableView.automaticDimension : .leastNormalMagnitude
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
