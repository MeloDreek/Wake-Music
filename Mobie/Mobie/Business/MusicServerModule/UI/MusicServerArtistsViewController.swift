import UIKit
import KakaFoundation
import Kingfisher

/// The artist directory loads completely before local search is enabled. Transport
/// batching stays inside the session; the UI never exposes partial alphabet indexes.
final class MusicServerArtistsViewController: SuperViewController, UISearchResultsUpdating, UISearchBarDelegate {
    private let session: MusicServerSession
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingView = MusicServerLoadingView()
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    private let collation = UILocalizedIndexedCollation.current()
    private var artistsByID: [String: MusicServerArtist] = [:]
    private var indexRecords: [MusicServerArtistIndexRecord] = []
    private var groups: [MusicServerArtistIndexGroup] = []
    private var favoriteIDs: [String] = []
    private var starredArtistIDs = Set<String>()
    private var favoriteOverrides: [String: Bool] = [:]
    private var artistRequest: Task<Void, Never>?
    private var pendingSearch: Task<Void, Never>?
    private var mutations: [String: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var searchGeneration = UUID()
    private var mutationGeneration = UUID()
    private var query = ""
    private var isLoaded = false

    init(session: MusicServerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        artistRequest?.cancel()
        pendingSearch?.cancel()
        mutations.values.forEach { $0.cancel() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Artists".localStr()
        navigationItem.largeTitleDisplayMode = .never
        definesPresentationContext = true
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Search".localStr()
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.keyboardDismissMode = .onDrag
        tableView.sectionIndexColor = view.tintColor
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MusicServerArtistCell.self, forCellReuseIdentifier: "artist")
        [tableView, loadingView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            loadingView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor)
        ])
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        loadAllArtists()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true { cancelPendingRequests() }
    }

    func cancelPendingRequests() {
        generation = UUID()
        searchGeneration = UUID()
        mutationGeneration = UUID()
        artistRequest?.cancel()
        pendingSearch?.cancel()
        mutations.values.forEach { $0.cancel() }
        mutations.removeAll()
    }

    @objc private func refresh() {
        // Accept annotations changed on another device unless a local write is in flight.
        if mutations.isEmpty { favoriteOverrides.removeAll() }
        loadAllArtists(forceReload: true)
    }

    private func loadAllArtists(forceReload: Bool = false) {
        artistRequest?.cancel()
        pendingSearch?.cancel()
        pendingSearch = nil
        generation = UUID()
        searchGeneration = UUID()
        isLoaded = false
        searchController.searchBar.searchTextField.isEnabled = false
        artistsByID.removeAll()
        indexRecords.removeAll()
        starredArtistIDs.removeAll()
        showState(.loading)
        loadingView.setLoadingHint(!session.hasCachedArtistCatalog
                                  ? "MusicServer.Artists.InitialLoadHint".localStr() : nil)
        let requestGeneration = generation
        let session = session
        artistRequest = Task { [weak self] in
            do {
                _ = try await session.authenticate()
                try Task.checkCancellation()
                let all = try await session.allArtists(forceReload: forceReload, onProgress: { [weak self] loaded, total in
                    guard let self, self.generation == requestGeneration else { return }
                    self.loadingView.setProgress(loaded: loaded, total: total)
                })
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                var artists: [String: MusicServerArtist] = [:]
                var records: [MusicServerArtistIndexRecord] = []
                var starredIDs = Set<String>()
                var nameSections: [String: Int] = [:]
                artists.reserveCapacity(all.count)
                records.reserveCapacity(all.count)
                // UIKit collation remains on the main actor, in short cancellable batches.
                // Name sorting and filtering run separately on the worker executor.
                for (offset, artist) in all.enumerated() {
                    if offset.isMultiple(of: 64) {
                        await Task.yield()
                        try Task.checkCancellation()
                        guard self.generation == requestGeneration else { return }
                    }
                    guard !artist.id.isEmpty, artists[artist.id] == nil else { continue }
                    artists[artist.id] = artist
                    if artist.starred { starredIDs.insert(artist.id) }
                    let section: Int
                    if let cached = nameSections[artist.name] { section = cached }
                    else {
                        let candidate = self.collation.section(for: MusicServerArtistCollationName(artist.name),
                            collationStringSelector: #selector(getter: MusicServerArtistCollationName.name))
                        section = min(max(0, candidate), self.collation.sectionTitles.count - 1)
                        nameSections[artist.name] = section
                    }
                    records.append(MusicServerArtistIndexRecord(id: artist.id, name: artist.name, section: section))
                }
                let sorted = try await MusicServerArtistLocalIndex.prepare(records)
                guard !Task.isCancelled, self.generation == requestGeneration else { return }
                // A favorite write may have completed while the full index was loading.
                for (id, favorite) in self.favoriteOverrides {
                    artists[id]?.starred = favorite
                    if favorite { starredIDs.insert(id) } else { starredIDs.remove(id) }
                }
                self.artistsByID = artists
                self.indexRecords = sorted
                self.starredArtistIDs = starredIDs
                self.isLoaded = true
                self.refreshControl.endRefreshing()
                self.searchController.searchBar.searchTextField.isEnabled = true
                self.scheduleSearch(immediately: true, force: true)
            } catch {
                guard !Task.isCancelled, let self, self.generation == requestGeneration else { return }
                self.refreshControl.endRefreshing()
                self.showState(.failed((error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()))
            }
        }
    }

    private func showState(_ state: MusicServerLoadState) {
        groups.removeAll()
        favoriteIDs.removeAll()
        tableView.reloadData()
        loadingView.isHidden = false
        loadingView.configure(state, action: { [weak self] in self?.refresh() })
    }

    private func toggleFavorite(_ artist: MusicServerArtist) {
        guard mutations[artist.id] == nil, let current = artistsByID[artist.id] else { return }
        let target = !current.starred
        let mutationGeneration = self.mutationGeneration
        let session = session
        mutations[artist.id] = Task { [weak self] in
            do {
                try await session.setArtistFavorite(id: artist.id, isFavorite: target)
                guard !Task.isCancelled, let self, self.mutationGeneration == mutationGeneration else { return }
                self.mutations[artist.id] = nil
                self.favoriteOverrides[artist.id] = target
                self.artistsByID[artist.id]?.starred = target
                if target { self.starredArtistIDs.insert(artist.id) } else { self.starredArtistIDs.remove(artist.id) }
                // Only the local result is rebuilt; no 90,000-artist reload for a heart tap.
                if self.isLoaded { self.scheduleSearch(immediately: true, force: true, showLoading: false) }
            } catch {
                guard !Task.isCancelled, let self, self.mutationGeneration == mutationGeneration else { return }
                self.mutations[artist.id] = nil
                self.tableView.reloadData()
                guard self.view.window != nil else { return }
                let message = (error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()
                let alert = UIAlertController(title: "Artists".localStr(), message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK".localStr(), style: .default))
                let presenter: UIViewController = self.searchController.isActive ? self.searchController : self
                guard presenter.presentedViewController == nil, !presenter.isBeingDismissed else { return }
                presenter.present(alert, animated: true)
            }
        }
        tableView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) { scheduleSearch() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        scheduleSearch(immediately: true)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        scheduleSearch(immediately: true)
    }

    private func scheduleSearch(immediately: Bool = false, force: Bool = false, showLoading: Bool = true) {
        guard isLoaded else { return }
        let nextQuery = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || nextQuery != query || pendingSearch != nil else { return }
        query = nextQuery
        pendingSearch?.cancel()
        searchGeneration = UUID()
        let requestGeneration = generation
        let filterGeneration = searchGeneration
        let records = indexRecords
        let starredIDs = starredArtistIDs
        // Never leave results from an older query tappable during the debounce.
        if showLoading { showState(.loading) }
        pendingSearch = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(nanoseconds: 250_000_000) }
                let result = try await MusicServerArtistLocalIndex.filter(records, query: nextQuery, favoriteIDs: starredIDs)
                guard !Task.isCancelled, let self, self.generation == requestGeneration,
                      self.searchGeneration == filterGeneration else { return }
                self.pendingSearch = nil
                self.groups = result.groups
                self.favoriteIDs = result.favorites
                if result.groups.isEmpty {
                    let message = (nextQuery.isEmpty ? "No data available" : "No search results. Try another keyword.").localStr()
                    self.loadingView.configure(.empty(message))
                    self.loadingView.isHidden = false
                } else {
                    self.loadingView.isHidden = true
                }
                self.tableView.reloadData()
            } catch { /* A newer query or root exit superseded this local result. */ }
        }
    }

    private var groupOffset: Int { favoriteIDs.isEmpty ? 0 : 1 }
    private func artist(at indexPath: IndexPath) -> MusicServerArtist? {
        let ids: [String]
        if groupOffset == 1 && indexPath.section == 0 { ids = favoriteIDs }
        else {
            let index = indexPath.section - groupOffset
            guard groups.indices.contains(index) else { return nil }
            ids = groups[index].ids
        }
        guard ids.indices.contains(indexPath.row) else { return nil }
        return artistsByID[ids[indexPath.row]]
    }
}

extension MusicServerArtistsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { groupOffset + groups.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if groupOffset == 1 && section == 0 { return favoriteIDs.count }
        return groups[section - groupOffset].ids.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if groupOffset == 1 && section == 0 { return "Favorite Artists".localStr() }
        return collation.sectionTitles[groups[section - groupOffset].section]
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        let titles = (groupOffset == 1 ? ["♥"] : []) + groups.map { collation.sectionTitles[$0.section] }
        return titles.isEmpty ? nil : titles
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int { index }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "artist", for: indexPath) as! MusicServerArtistCell
        if let artist = artist(at: indexPath) {
            cell.configure(artist: artist, session: session, isUpdating: mutations[artist.id] != nil) { [weak self] in self?.toggleFavorite(artist) }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let artist = artist(at: indexPath) else { return }
        MusicServerSelection.open(.artist(artist), among: [], session: session, from: self)
    }
}

private final class MusicServerArtistCollationName: NSObject {
    @objc let name: String
    init(_ name: String) { self.name = name }
}

/// Lightweight, sendable index: worker tasks never capture UIKit or account credentials.
struct MusicServerArtistIndexRecord: Sendable {
    let id: String
    let name: String
    let section: Int
    var searchKey = ""
}
struct MusicServerArtistIndexGroup: Sendable {
    let section: Int
    let ids: [String]
}
struct MusicServerArtistIndexResult: Sendable {
    let groups: [MusicServerArtistIndexGroup]
    let favorites: [String]
}

enum MusicServerArtistLocalIndex {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    static func prepare(_ input: [MusicServerArtistIndexRecord]) async throws -> [MusicServerArtistIndexRecord] {
        let worker = Task.detached(priority: .userInitiated) { () throws -> [MusicServerArtistIndexRecord] in
            var seen = Set<String>()
            var records: [MusicServerArtistIndexRecord] = []
            records.reserveCapacity(input.count)
            for (offset, var record) in input.enumerated() {
                if offset.isMultiple(of: 128) { try Task.checkCancellation() }
                guard !record.id.isEmpty, seen.insert(record.id).inserted else { continue }
                let direct = normalized(record.name)
                let latin = normalized(record.name.applyingTransform(.toLatin, reverse: false) ?? record.name)
                record.searchKey = direct + "\n" + latin
                records.append(record)
            }
            return try records.sorted { lhs, rhs in
                try Task.checkCancellation()
                if lhs.section != rhs.section { return lhs.section < rhs.section }
                let order = lhs.name.localizedStandardCompare(rhs.name)
                return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
            }
        }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }

    static func filter(_ records: [MusicServerArtistIndexRecord], query: String, favoriteIDs: Set<String>) async throws -> MusicServerArtistIndexResult {
        let worker = Task.detached(priority: .userInitiated) { () throws -> MusicServerArtistIndexResult in
            let key = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
            var buckets: [Int: [String]] = [:]
            var favorites: [String] = []
            for (offset, record) in records.enumerated() {
                if offset.isMultiple(of: 128) { try Task.checkCancellation() }
                guard key.isEmpty || record.searchKey.contains(key) else { continue }
                buckets[record.section, default: []].append(record.id)
                if favoriteIDs.contains(record.id) { favorites.append(record.id) }
            }
            return MusicServerArtistIndexResult(
                groups: buckets.keys.sorted().map { MusicServerArtistIndexGroup(section: $0, ids: buckets[$0] ?? []) },
                favorites: favorites)
        }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }
}

private final class MusicServerArtistCell: UITableViewCell {
    private let artwork = UIImageView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private var onFavorite: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        artwork.backgroundColor = .tertiarySystemFill
        artwork.tintColor = .secondaryLabel
        artwork.contentMode = .scaleAspectFill
        artwork.layer.cornerRadius = 25
        artwork.clipsToBounds = true
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        let labels = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 3
        favoriteButton.setPreferredSymbolConfiguration(.init(pointSize: 21, weight: .regular), forImageIn: .normal)
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        [artwork, labels, favoriteButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            artwork.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 50),
            artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor),
            artwork.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            artwork.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            labels.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 13),
            labels.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labels.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            labels.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            labels.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            favoriteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        // Keep normal table-row activation, with a named VoiceOver action for the heart.
        isAccessibilityElement = true
        accessibilityTraits = .button
        favoriteButton.isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.kf.cancelDownloadTask()
        artwork.image = nil
        onFavorite = nil
        accessibilityCustomActions = nil
        accessibilityLabel = nil
    }

    func configure(artist: MusicServerArtist, session: MusicServerSession, isUpdating: Bool, onFavorite: @escaping () -> Void) {
        self.onFavorite = onFavorite
        nameLabel.text = artist.name
        if let count = artist.songCount { detailLabel.text = String(format: "%d songs".localStr(), count) }
        else if let count = artist.albumCount { detailLabel.text = "\(count.formatted()) · \("Albums".localStr())" }
        else { detailLabel.text = nil }
        detailLabel.isHidden = detailLabel.text == nil
        accessibilityLabel = [artist.name, detailLabel.text].compactMap { $0 }.joined(separator: ", ")
        favoriteButton.setImage(UIImage(systemName: artist.starred ? "heart.fill" : "heart"), for: .normal)
        favoriteButton.tintColor = artist.starred ? .systemPink : .secondaryLabel
        favoriteButton.isEnabled = !isUpdating
        favoriteButton.accessibilityLabel = (artist.starred ? "Dislike" : "Like").localStr() + ": " + artist.name
        favoriteButton.accessibilityTraits = artist.starred ? [.button, .selected] : .button
        accessibilityCustomActions = isUpdating ? [] : [UIAccessibilityCustomAction(name: favoriteButton.accessibilityLabel ?? "Like".localStr()) { [weak self] _ in
            self?.onFavorite?()
            return true
        }]
        artwork.kf.cancelDownloadTask()
        artwork.image = UIImage(systemName: "person.crop.circle.fill")
        if !artist.coverArt.isEmpty, let url = session.artworkURL(id: artist.coverArt, size: 160) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(artist.coverArt):160")
            artwork.kf.setImage(with: resource, placeholder: UIImage(systemName: "person.crop.circle.fill"), options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 50, height: 50))),
                .scaleFactor(traitCollection.displayScale)
            ])
        }
    }

    @objc private func favoriteTapped() { onFavorite?() }
}
