import UIKit
import KakaFoundation
import AppGroupKit

/// Songs/albums search the entire server, not only the rows already on screen.
/// Further pages load automatically as the listener reaches the end of the list.
final class MusicServerBrowseViewController: SuperViewController, UISearchResultsUpdating, UISearchBarDelegate {
    private let session: MusicServerSession
    /// Embedded homepage search supplies navigation without a second navigation stack.
    var onSelection: ((MusicServerItem, [MusicServerItem]) -> Void)?
    private let route: MusicServerRoute
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    private let loadingView = MusicServerLoadingView()
    private let pageFooter = UIView()
    private let pageSpinner = UIActivityIndicatorView(style: .medium)
    private let pageRetryButton = UIButton(type: .system)
    private var items: [MusicServerItem] = []
    private var nextOffset = 0
    private var hasMore = true
    private var isLoading = false
    private var didFail = false
    private var errorMessage = "This section could not be loaded.".localStr()
    private var request: Task<Void, Never>?
    private var pendingSearch: Task<Void, Never>?
    private var query = ""
    private var searchPending = false
    private var didCompleteInitialLoad = false
    private var generation = UUID()

    init(session: MusicServerSession, route: MusicServerRoute, title: String) {
        self.session = session
        self.route = route
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { request?.cancel(); pendingSearch?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MusicServerItemCell.self, forCellReuseIdentifier: "item")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor)
        ])
        pageFooter.addSubview(pageSpinner)
        pageFooter.addSubview(pageRetryButton)
        pageRetryButton.setTitle("Retry".localStr(), for: .normal)
        pageRetryButton.addTarget(self, action: #selector(retryPage), for: .touchUpInside)
        if searchKind != nil {
            definesPresentationContext = true
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchResultsUpdater = self
            searchController.searchBar.delegate = self
            searchController.searchBar.placeholder = "Search".localStr()
            searchController.searchBar.autocapitalizationType = .none
            searchController.searchBar.autocorrectionType = .no
            searchController.searchBar.isUserInteractionEnabled = false
            searchController.searchBar.searchTextField.isEnabled = false
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        if case .random = route {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(playRandomSelection))
            navigationItem.rightBarButtonItem?.accessibilityLabel = "Shuffle Play".localStr()
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        loadNextPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageFooter.frame.size = CGSize(width: tableView.bounds.width, height: 56)
        pageSpinner.center = CGPoint(x: pageFooter.bounds.midX, y: 28)
        pageRetryButton.frame = CGRect(x: 20, y: 6, width: max(0, pageFooter.bounds.width - 40), height: 44)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            cancelPendingRequests()
        }
    }

    func cancelPendingRequests() {
        generation = UUID()
        request?.cancel()
        request = nil
        pendingSearch?.cancel()
        pendingSearch = nil
    }

    @objc private func refresh() {
        cancelPendingRequests()
        searchPending = false
        items.removeAll()
        nextOffset = 0
        hasMore = true
        isLoading = false
        didFail = false
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading, !searchPending, hasMore else { return }
        isLoading = true
        didFail = false
        updatePresentation()
        let requestGeneration = generation
        let offset = nextOffset
        let session = session
        let route = requestRoute
        request = Task { [weak self] in
            do {
                _ = try await session.authenticate()
                try Task.checkCancellation()
                let page = try await session.page(route, offset: offset, limit: route == .random ? 30 : 40)
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                var known = Set(self.items.map(Self.stableKey))
                let additions = page.items.filter { known.insert(Self.stableKey($0)).inserted }
                self.items.append(contentsOf: additions)
                // Offset follows the server page, not the deduplicated UI count.
                // A repeated/empty page stops pagination rather than looping forever.
                self.nextOffset = page.nextOffset ?? (self.nextOffset + page.items.count)
                self.hasMore = page.hasMore && !page.items.isEmpty && !additions.isEmpty
                    && self.nextOffset > offset
                self.isLoading = false
                self.didCompleteInitialLoad = true
                self.searchController.searchBar.isUserInteractionEnabled = true
                self.searchController.searchBar.searchTextField.isEnabled = true
                self.refreshControl.endRefreshing()
                self.navigationItem.rightBarButtonItem?.isEnabled = !self.items.isEmpty
                self.updatePresentation()
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.isLoading = false
                self.didFail = true
                self.errorMessage = (error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()
                self.refreshControl.endRefreshing()
                self.updatePresentation()
            }
        }
    }

    private static func stableKey(_ item: MusicServerItem) -> String {
        switch item {
        case .song: return "song:\(item.id)"
        case .artist: return "artist:\(item.id)"
        case .album: return "album:\(item.id)"
        case .playlist: return "playlist:\(item.id)"
        case .radio: return "radio:\(item.id)"
        }
    }

    private var searchKind: MusicServerSearchKind? {
        switch route {
        case .songs: return .songs
        case .albums: return .albums
        default: return nil
        }
    }

    private var requestRoute: MusicServerRoute {
        guard !query.isEmpty, let kind = searchKind else { return route }
        return .search(query: query, kind: kind)
    }

    private func updatePresentation() {
        loadingView.isHidden = !items.isEmpty
        if items.isEmpty {
            if isLoading || searchPending { loadingView.configure(.loading) }
            else if didFail { loadingView.configure(.failed(errorMessage)) { [weak self] in self?.loadNextPage() } }
            else { loadingView.configure(.empty(emptyMessage)) }
        }
        pageSpinner.stopAnimating()
        pageSpinner.isHidden = !isLoading
        pageRetryButton.isHidden = !didFail
        if isLoading, !items.isEmpty { pageSpinner.startAnimating() }
        tableView.tableFooterView = !items.isEmpty && (isLoading || didFail) ? pageFooter : nil
        navigationItem.rightBarButtonItem?.isEnabled = !items.isEmpty
        tableView.reloadData()
    }

    @objc private func retryPage() { loadNextPage() }

    func updateSearchResults(for searchController: UISearchController) { scheduleSearch() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        scheduleSearch(immediately: true)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        scheduleSearch(immediately: true)
    }

    private func scheduleSearch(immediately: Bool = false) {
        guard didCompleteInitialLoad, searchKind != nil else { return }
        let nextQuery = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard nextQuery != query || searchPending else { return }
        cancelPendingRequests()
        query = nextQuery
        items.removeAll()
        nextOffset = 0
        hasMore = true
        isLoading = false
        didFail = false
        searchPending = true
        refreshControl.endRefreshing()
        updatePresentation()
        let requestGeneration = generation
        pendingSearch = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(nanoseconds: 300_000_000) }
                try Task.checkCancellation()
                guard let self, self.generation == requestGeneration else { return }
                self.pendingSearch = nil
                self.searchPending = false
                self.loadNextPage()
            } catch { /* A newer query or navigation cancelled this search. */ }
        }
    }

    private var emptyMessage: String {
        switch requestRoute {
        case .search: return "No search results. Try another keyword.".localStr()
        case .recent: return "Play something to start your listening history.".localStr()
        case .favorites: return "Your favorite songs will appear here.".localStr()
        case .playlists: return "Your playlists will appear here.".localStr()
        default: return "No data available".localStr()
        }
    }

    @objc private func playRandomSelection() {
        guard let first = items.first(where: { if case .song = $0 { return true }; return false }) else { return }
        MusicServerSelection.open(first, among: items, session: session, from: self)
    }
}

extension MusicServerBrowseViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath) as! MusicServerItemCell
        cell.configure(item: items[indexPath.row], session: session)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if !items.isEmpty, indexPath.row >= items.count - 6, !isLoading, !searchPending, hasMore, !didFail {
            // Do not reload the table inside its own cell-display callback.
            let requestGeneration = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == requestGeneration else { return }
                self.loadNextPage()
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        if let onSelection { onSelection(items[indexPath.row], items) }
        else { MusicServerSelection.open(items[indexPath.row], among: items, session: session, from: self) }
    }
}

/// Navigation and playback are shared, so home previews and detail lists cannot diverge.
@MainActor
enum MusicServerSelection {
    static func open(_ item: MusicServerItem, among items: [MusicServerItem], session: MusicServerSession, from controller: UIViewController) {
        switch item {
        case .song(let song):
            let songs = items.compactMap { item -> MusicServerSong? in
                if case .song(let value) = item { return value }
                return nil
            }
            guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
            let queue = songs.map { session.musicItem(for: $0) }
            if KakaMusicPlayer.shared.playingMusic == queue[index] {
                KakaMusicPlayer.presentPlayController(fromVC: controller)
            } else {
                ConnectConfigManager.shared.lastPlaylist = queue
                KakaMusicPlayer.shared.startPlayMusic(musics: queue, itemIndex: index)
            }
        case .album(let album):
            browse(.album(id: album.id), title: item.title, session: session, from: controller)
        case .artist(let artist):
            browse(.artist(id: artist.id), title: item.title, session: session, from: controller)
        case .playlist(let playlist):
            browse(.playlist(id: playlist.id), title: item.title, session: session, from: controller)
        case .radio(let radio):
            guard let model = session.musicItem(for: radio) else {
                let alert = UIAlertController(title: item.title, message: "This radio station has no playable stream.".localStr(), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK".localStr(), style: .default))
                controller.present(alert, animated: true)
                return
            }
            ConnectConfigManager.shared.lastPlaylist = [model]
            KakaMusicPlayer.shared.startPlayMusic(musics: [model], itemIndex: 0)
        }
    }

    static func browse(_ route: MusicServerRoute, title: String, session: MusicServerSession, from controller: UIViewController) {
        let destination: UIViewController
        if case .artists = route {
            destination = MusicServerArtistsViewController(session: session)
        } else {
            destination = MusicServerBrowseViewController(session: session, route: route, title: title)
        }
        controller.navigationController?.pushViewController(destination, animated: true)
    }
}
