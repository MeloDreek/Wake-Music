import UIKit
import KakaFoundation
import AppGroupKit

/// Reused by every See All / overview destination. Only the current page is requested.
final class MusicServerBrowseViewController: SuperViewController {
    private let session: MusicServerSession
    private let route: MusicServerRoute
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private var items: [MusicServerItem] = []
    private var nextOffset = 0
    private var hasMore = true
    private var isLoading = false
    private var didFail = false
    private var errorMessage = "This section could not be loaded.".localStr()
    private var request: Task<Void, Never>?
    private var generation = UUID()

    init(session: MusicServerSession, route: MusicServerRoute, title: String) {
        self.session = session
        self.route = route
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { request?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MusicServerItemCell.self, forCellReuseIdentifier: "item")
        tableView.register(MusicServerStatusCell.self, forCellReuseIdentifier: "status")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        if case .random = route {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "shuffle"), style: .plain, target: self, action: #selector(playRandomSelection))
            navigationItem.rightBarButtonItem?.accessibilityLabel = "Shuffle Play".localStr()
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        loadNextPage()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            request?.cancel()
        }
    }

    @objc private func refresh() {
        request?.cancel()
        generation = UUID()
        items.removeAll()
        nextOffset = 0
        hasMore = true
        isLoading = false
        didFail = false
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        didFail = false
        tableView.reloadData()
        let requestGeneration = generation
        let offset = nextOffset
        let session = session
        let route = route
        request = Task { [weak self] in
            do {
                let page = try await session.page(route, offset: offset, limit: 40)
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                var known = Set(self.items.map(Self.stableKey))
                let additions = page.items.filter { known.insert(Self.stableKey($0)).inserted }
                self.items.append(contentsOf: additions)
                // Offset follows the server page, not the deduplicated UI count.
                // A repeated/empty page stops pagination rather than looping forever.
                self.nextOffset = page.nextOffset ?? (self.nextOffset + page.items.count)
                self.hasMore = page.hasMore && !page.items.isEmpty && !additions.isEmpty
                self.isLoading = false
                self.refreshControl.endRefreshing()
                self.navigationItem.rightBarButtonItem?.isEnabled = !self.items.isEmpty
                self.tableView.reloadData()
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.isLoading = false
                self.didFail = true
                self.errorMessage = (error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()
                self.refreshControl.endRefreshing()
                self.tableView.reloadData()
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

    private var showsStatusRow: Bool { items.isEmpty || hasMore || isLoading || didFail }

    private var emptyMessage: String {
        switch route {
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
        items.count + (showsStatusRow ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if items.indices.contains(indexPath.row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath) as! MusicServerItemCell
            cell.configure(item: items[indexPath.row], session: session)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "status", for: indexPath) as! MusicServerStatusCell
        let state: MusicServerLoadState
        if isLoading { state = .loading }
        else if didFail { state = .failed(errorMessage) }
        else if items.isEmpty { state = .empty(emptyMessage) }
        else { state = .more }
        cell.configure(state) { [weak self] in self?.loadNextPage() }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // An explicit Load More button is also available for keyboard/VoiceOver.
        if !items.isEmpty, indexPath.row == items.count, !isLoading, hasMore, !didFail {
            // Do not reload the table inside its own cell-display callback.
            DispatchQueue.main.async { [weak self] in self?.loadNextPage() }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        MusicServerSelection.open(items[indexPath.row], among: items, session: session, from: self)
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
            push(.album(id: album.id), title: item.title, session: session, from: controller)
        case .artist(let artist):
            push(.artist(id: artist.id), title: item.title, session: session, from: controller)
        case .playlist(let playlist):
            push(.playlist(id: playlist.id), title: item.title, session: session, from: controller)
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

    private static func push(_ route: MusicServerRoute, title: String, session: MusicServerSession, from controller: UIViewController) {
        controller.navigationController?.pushViewController(MusicServerBrowseViewController(session: session, route: route, title: title), animated: true)
    }
}
