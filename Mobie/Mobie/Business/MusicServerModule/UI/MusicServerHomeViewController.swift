import UIKit
import KakaFoundation
import AppGroupKit

/// A bounded dashboard: opening a large server never means fetching its full library.
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
    }

    private let session: MusicServerSession
    private let onExit: () -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
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
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 62
        tableView.register(MusicServerItemCell.self, forCellReuseIdentifier: "item")
        tableView.register(MusicServerStatusCell.self, forCellReuseIdentifier: "status")
        tableView.register(MusicServerOverviewCell.self, forCellReuseIdentifier: "overview")
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
        if hasAppeared, authenticated, !loadingSections.contains(.recent) {
            loadSection(.recent, generation: generation)
        }
        hasAppeared = true
    }

    @objc private func exitTapped() {
        cancelPendingRequests()
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
                let page = try await session.page(route, offset: 0, limit: 3)
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                var seen = Set<String>()
                self.previews[section] = Array(page.items.filter { seen.insert($0.id).inserted }.prefix(3))
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
        return max(1, previews[kind]?.count ?? 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard authenticated, let section = Section(rawValue: indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! MusicServerStatusCell
            cell.configure(authenticationFailed ? .failed(authenticationError) : .loading) { [weak self] in self?.refreshAll() }
            return cell
        }
        if section == .overview, let overview {
            let cell = tableView.dequeueReusableCell(withIdentifier: "overview", for: indexPath) as! MusicServerOverviewCell
            cell.configure(overview) { [weak self] in self?.showOverviewCategory($0) }
            return cell
        }
        if let items = previews[section], items.indices.contains(indexPath.row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath) as! MusicServerItemCell
            cell.configure(item: items[indexPath.row], session: session)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! MusicServerStatusCell
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
        let canShowAll = kind.route != nil && !(previews[kind]?.isEmpty ?? true)
        header.configure(title: kind.title, onSeeAll: canShowAll ? { [weak self] in self?.showAll(kind) } : nil)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        authenticated ? UITableView.automaticDimension : .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        authenticated && section == Section.recent.rawValue ? "Recent plays on this device and from your server.".localStr() : nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        authenticated && section == Section.recent.rawValue ? UITableView.automaticDimension : 8
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard authenticated, let section = Section(rawValue: indexPath.section),
              let items = previews[section], items.indices.contains(indexPath.row) else { return }
        MusicServerSelection.open(items[indexPath.row], among: items, session: session, from: self)
    }
}
