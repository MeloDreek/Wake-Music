import UIKit
import AppGroupKit
import KakaFoundation
import Kingfisher
import Combine

/// A profile, not an album-list route. Each section can fail/retry independently.
final class MusicServerArtistDetailViewController: SuperViewController {
    private enum Section: Int, CaseIterable {
        case topSongs, albums, similar
        var title: String {
            switch self {
            case .topSongs: return "MusicServer.Artist.TopSongs".localStr()
            case .albums: return "Albums".localStr()
            case .similar: return "MusicServer.Artist.SimilarArtists".localStr()
            }
        }
        var emptyMessage: String {
            switch self {
            case .topSongs: return "MusicServer.Artist.NoTopSongs".localStr()
            case .similar: return "MusicServer.Artist.NoSimilarArtists".localStr()
            case .albums: return "No data available".localStr()
            }
        }
    }

    private let session: MusicServerSession
    private var artist: MusicServerArtist
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let header = UIView()
    private let artwork = UIImageView()
    private let nameLabel = UILabel()
    private let biographyView = MusicServerExpandableTextView()
    private let refreshControl = UIRefreshControl()
    private var items: [Section: [MusicServerItem]] = [:]
    private var failures: [Section: String] = [:]
    private var tasks: [Section: Task<Void, Never>] = [:]
    private var generation = UUID()
    private var favoriteOverrides: [String: Bool] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private lazy var songActions: MusicServerSongActions = {
        let actions = MusicServerSongActions(session: session, controller: self)
        actions.onFavoriteChange = { [weak self] id, favorite in
            guard let self else { return }
            self.favoriteOverrides[id] = favorite
            self.items[.topSongs] = self.items[.topSongs]?.map(self.applyingFavoriteOverride)
            self.tableView.reloadSections(IndexSet(integer: Section.topSongs.rawValue), with: .none)
        }
        return actions
    }()

    init(session: MusicServerSession, artist: MusicServerArtist) {
        self.session = session
        self.artist = artist
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { tasks.values.forEach { $0.cancel() } }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        tableView.register(NavidromeFavoriteViewCell.self, forCellReuseIdentifier: "songs")
        tableView.register(MusicServerArtworkShelfCell.self, forCellReuseIdentifier: "covers")
        tableView.register(NavidromeEmptyViewCell.self, forCellReuseIdentifier: "state")
        tableView.register(NavidromeSectionHeadView.self, forHeaderFooterViewReuseIdentifier: "section")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        refreshControl.addTarget(self, action: #selector(reload), for: .valueChanged)
        tableView.refreshControl = refreshControl
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 88
        artwork.tintColor = .tertiaryLabel
        nameLabel.font = .preferredFont(forTextStyle: .title1)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0
        nameLabel.textAlignment = .center
        biographyView.onHeightChange = { [weak self] in self?.view.setNeedsLayout() }
        let stack = UIStackView(arrangedSubviews: [artwork, nameLabel, biographyView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            artwork.widthAnchor.constraint(equalToConstant: 176),
            artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -28),
            nameLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            biographyView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        updateHeader()
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refreshPlayback() }.store(in: &subscriptions)
        KakaMusicPlayer.shared.$playbackStatus.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refreshPlayback() }.store(in: &subscriptions)
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let size = CGSize(width: width, height: ceil(height))
        if header.frame.size != size || tableView.tableHeaderView == nil {
            header.frame.size = size
            tableView.tableHeaderView = header
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tableView.reloadData()
            view.setNeedsLayout()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true { cancelPendingRequests() }
    }

    func cancelPendingRequests() {
        generation = UUID()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func updateHeader() {
        title = artist.name
        nameLabel.text = artist.name
        artwork.kf.cancelDownloadTask()
        let placeholder = UIImage(systemName: "person.crop.circle.fill")
        artwork.image = placeholder
        if let url = session.artworkURL(id: artist.coverArt, size: 600) {
            artwork.kf.setImage(with: KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(artist.coverArt):600"),
                placeholder: placeholder, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 176, height: 176))), .scaleFactor(traitCollection.displayScale)])
        }
        view.setNeedsLayout()
    }

    @objc private func reload() {
        cancelPendingRequests()
        failures.removeAll()
        items.removeAll()
        biographyView.configure(text: nil)
        for section in Section.allCases { load(section) }
        tableView.reloadData()
    }

    private func load(_ section: Section) {
        tasks[section]?.cancel()
        failures[section] = nil
        let expected = generation
        tasks[section] = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await session.authenticate()
                try Task.checkCancellation()
                let result: [MusicServerItem]
                switch section {
                case .albums:
                    let detail = try await session.artistDetails(id: artist.id)
                    try Task.checkCancellation()
                    guard generation == expected else { return }
                    artist = detail.artist
                    updateHeader()
                    result = detail.albums
                case .topSongs:
                    result = try await session.artistTopSongs(name: artist.name)
                case .similar:
                    let info = try await session.artistInfo(id: artist.id)
                    try Task.checkCancellation()
                    guard generation == expected else { return }
                    biographyView.configure(text: info.biography)
                    view.setNeedsLayout()
                    result = info.similarArtists
                }
                try Task.checkCancellation()
                guard generation == expected else { return }
                items[section] = result.map(applyingFavoriteOverride)
            } catch {
                guard !Task.isCancelled, generation == expected else { return }
                failures[section] = (error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()
            }
            tasks[section] = nil
            tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
            if tasks.isEmpty { refreshControl.endRefreshing() }
        }
    }

    private func applyingFavoriteOverride(_ item: MusicServerItem) -> MusicServerItem {
        guard case .song(var song) = item, let favorite = favoriteOverrides[song.id] else { return item }
        song.value.starred = favorite
        return .song(song)
    }
    private func refreshPlayback() {
        for case let cell as NavidromeRecentViewCell in tableView.visibleCells { cell.refreshPlaybackState() }
    }
}

extension MusicServerArtistDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "section") as! NavidromeSectionHeadView
        header.configure(title: Section(rawValue: section)!.title)
        return header
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = Section(rawValue: indexPath.section)!
        guard let values = items[section], !values.isEmpty else { return 168 }
        if section == .topSongs { return NavidromeRecentViewCell.preferredHeight(for: traitCollection, width: tableView.bounds.width, itemCount: values.count) }
        return MusicServerArtworkShelfCell.preferredHeight(for: traitCollection)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!
        let values = items[section] ?? []
        guard !values.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "state", for: indexPath) as! NavidromeEmptyViewCell
            let state: MusicServerLoadState = tasks[section] != nil ? .loading :
                failures[section].map(MusicServerLoadState.failed) ?? .empty(section.emptyMessage)
            cell.configure(state) { [weak self] in
                self?.load(section)
                self?.tableView.reloadSections(IndexSet(integer: section.rawValue), with: .none)
            }
            return cell
        }
        if section == .topSongs {
            let cell = tableView.dequeueReusableCell(withIdentifier: "songs", for: indexPath) as! NavidromeFavoriteViewCell
            cell.configure(items: values, session: session, onSongAction: { [weak self] item, action in
                guard let self, case .song(let song) = item else { return }
                songActions.handle(model: session.musicItem(for: song), action: action)
            }) { [weak self] item in
                guard let self else { return }
                MusicServerSelection.open(item, among: self.items[.topSongs] ?? [], session: session, from: self)
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "covers", for: indexPath) as! MusicServerArtworkShelfCell
        cell.configure(items: values, session: session, round: section == .similar) { [weak self] item in
            guard let self else { return }
            MusicServerSelection.open(item, among: values, session: session, from: self)
        }
        return cell
    }
}

/// Lazy, horizontally scrolling album covers / artist portraits; no decoded-image arrays.
private final class MusicServerArtworkShelfCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var items: [MusicServerItem] = []
    private weak var session: MusicServerSession?
    private var round = false
    private var onSelect: ((MusicServerItem) -> Void)?
    static func preferredHeight(for traits: UITraitCollection) -> CGFloat {
        140 + ceil(UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).lineHeight * 2) + 40
    }
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        let layout = collection.collectionViewLayout as! UICollectionViewFlowLayout
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(MusicServerArtworkCard.self, forCellWithReuseIdentifier: "cover")
        collection.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(collection)
        NSLayoutConstraint.activate([
            collection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), collection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collection.topAnchor.constraint(equalTo: contentView.topAnchor), collection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(items: [MusicServerItem], session: MusicServerSession, round: Bool, onSelect: @escaping (MusicServerItem) -> Void) {
        let changed = self.items.map(\.id) != items.map(\.id) || self.session?.accountID != session.accountID
        self.items = items; self.session = session; self.round = round; self.onSelect = onSelect
        collection.reloadData()
        if changed, !items.isEmpty { collection.layoutIfNeeded(); collection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: false) }
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cover", for: indexPath) as! MusicServerArtworkCard
        if let session { cell.configure(item: items[indexPath.item], session: session, round: round) }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 140, height: Self.preferredHeight(for: traitCollection) - 32)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.item) else { return }
        onSelect?(items[indexPath.item])
    }
}

private final class MusicServerArtworkCard: UICollectionViewCell {
    private let artwork = UIImageView()
    private let nameLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.tintColor = .tertiaryLabel
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        let stack = UIStackView(arrangedSubviews: [artwork, nameLabel])
        stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor), stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
            artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() { super.prepareForReuse(); artwork.kf.cancelDownloadTask(); artwork.image = nil }
    func configure(item: MusicServerItem, session: MusicServerSession, round: Bool) {
        nameLabel.text = item.title
        nameLabel.textAlignment = round ? .center : .natural
        accessibilityLabel = item.title
        artwork.layer.cornerRadius = round ? 70 : 10
        artwork.kf.cancelDownloadTask()
        let placeholder = UIImage(systemName: round ? "person.crop.circle.fill" : "square.stack.fill")
        artwork.image = placeholder
        if let url = session.artworkURL(id: item.artworkID, size: 400) {
            artwork.kf.setImage(with: KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):400"),
                placeholder: placeholder, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 140, height: 140))), .scaleFactor(traitCollection.displayScale)])
        }
    }
}
