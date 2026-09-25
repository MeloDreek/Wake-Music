import UIKit
import AppGroupKit
import KakaFoundation
import Kingfisher
import Combine

/// Album-specific presentation. Only this album's tracks are requested, in bounded pages.
final class MusicServerAlbumDetailViewController: SuperViewController {
    private let session: MusicServerSession
    private var album: MusicServerAlbum
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private let header = UIView()
    private let artworkContainer = UIView()
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let metadataLabel = UILabel()
    private let summaryLabel = UILabel()
    private let descriptionView = MusicServerExpandableTextView()
    private let actionStack = UIStackView()
    private let playButton = UIButton(type: .custom)
    private let shuffleButton = UIButton(type: .custom)
    private var artworkKey: String?
    private var didLoadArtwork = false
    private var songs: [MusicServerSong] = []
    private var nextOffset = 0
    private var hasMore = true
    private var isLoadingSongs = false
    private var songFailure: String?
    private var generation = UUID()
    private var songsTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var descriptionTask: Task<Void, Never>?
    private var favoriteOverrides: [String: Bool] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private lazy var songActions: MusicServerSongActions = {
        let actions = MusicServerSongActions(session: session, controller: self)
        actions.onFavoriteChange = { [weak self] id, favorite in
            guard let self else { return }
            favoriteOverrides[id] = favorite
            songs = songs.map(applyingFavoriteOverride)
            tableView.reloadData()
        }
        return actions
    }()

    init(session: MusicServerSession, album: MusicServerAlbum) {
        self.session = session
        self.album = album
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { songsTask?.cancel(); detailTask?.cancel(); descriptionTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.register(MusicTableViewCell.self, forCellReuseIdentifier: "song")
        tableView.register(NavidromeEmptyViewCell.self, forCellReuseIdentifier: "state")
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
        configureHeader()
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshVisibleSongs() }.store(in: &subscriptions)
        KakaMusicPlayer.shared.$playbackStatus.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshVisibleSongs() }.store(in: &subscriptions)
        reload()
    }

    private func configureHeader() {
        artworkContainer.layer.shadowColor = UIColor.black.cgColor
        artworkContainer.layer.shadowOpacity = 0.14
        artworkContainer.layer.shadowRadius = 18
        artworkContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 18
        artwork.layer.cornerCurve = .continuous
        artwork.tintColor = .tertiaryLabel
        artwork.backgroundColor = .secondarySystemGroupedBackground
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artworkContainer.addSubview(artwork)
        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkContainer.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkContainer.bottomAnchor)
        ])
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        artistLabel.font = .preferredFont(forTextStyle: .title3)
        artistLabel.textColor = .secondaryLabel
        metadataLabel.font = .preferredFont(forTextStyle: .subheadline)
        metadataLabel.textColor = .secondaryLabel
        summaryLabel.font = .preferredFont(forTextStyle: .footnote)
        summaryLabel.textColor = .secondaryLabel
        [titleLabel, artistLabel, metadataLabel, summaryLabel].forEach {
            $0.adjustsFontForContentSizeCategory = true
            $0.numberOfLines = 0
            $0.textAlignment = .center
        }
        let identity = UIStackView(arrangedSubviews: [titleLabel, artistLabel, metadataLabel])
        identity.axis = .vertical
        identity.spacing = 8
        configureButton(playButton, title: "Play".localStr(), symbol: "play.fill", action: #selector(playAlbum))
        configureButton(shuffleButton, title: "Shuffle Play".localStr(), symbol: "shuffle", action: #selector(shuffleAlbum))
        actionStack.addArrangedSubview(playButton)
        actionStack.addArrangedSubview(shuffleButton)
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually
        let stack = UIStackView(arrangedSubviews: [artworkContainer, identity, actionStack, summaryLabel, descriptionView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 22
        stack.setCustomSpacing(28, after: artworkContainer)
        stack.setCustomSpacing(14, after: actionStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(stack)
        let preferredWidth = stack.widthAnchor.constraint(equalTo: header.widthAnchor, constant: -48)
        preferredWidth.priority = .defaultHigh
        let artworkWidth = artworkContainer.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.76)
        artworkWidth.priority = .defaultHigh
        let actionsWidth = actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        actionsWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: header.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 560), preferredWidth,
            artworkWidth, artworkContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            artworkContainer.heightAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            identity.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionsWidth, actionStack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            summaryLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            descriptionView.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        descriptionView.onHeightChange = { [weak self] in self?.view.setNeedsLayout() }
    }

    private func configureButton(_ button: UIButton, title: String, symbol: String, action: Selector) {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        config.imagePadding = 8
        config.baseForegroundColor = appMainColor
        config.baseBackgroundColor = appMainColor
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .preferredFont(forTextStyle: .headline)
            return outgoing
        }
        button.configuration = config
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        actionStack.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        let size = CGSize(width: width, height: ceil(height))
        if header.frame.size != size || tableView.tableHeaderView == nil {
            header.frame.size = size
            tableView.tableHeaderView = header
        }
        artworkContainer.layer.shadowPath = UIBezierPath(roundedRect: artworkContainer.bounds, cornerRadius: 18).cgPath
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
        songsTask?.cancel(); songsTask = nil
        detailTask?.cancel(); detailTask = nil
        descriptionTask?.cancel(); descriptionTask = nil
    }

    @objc private func reload() {
        cancelPendingRequests()
        session.invalidateAlbumDetails(id: album.id)
        songs.removeAll()
        nextOffset = 0
        hasMore = true
        isLoadingSongs = false
        songFailure = nil
        descriptionView.configure(text: nil)
        updateHeader()
        let expected = generation
        detailTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await session.authenticate()
                let detail = try await session.albumDetails(id: album.id)
                guard !Task.isCancelled, generation == expected else { return }
                album = detail
                updateHeader()
            } catch { /* Optional metadata must not block the album's music. */ }
        }
        descriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await session.authenticate()
                let text = try await session.albumDescription(id: album.id)
                guard !Task.isCancelled, generation == expected else { return }
                descriptionView.configure(text: text)
                view.setNeedsLayout()
            } catch { /* Many servers do not provide album notes. Leave no empty space. */ }
        }
        loadSongs()
    }

    private func loadSongs() {
        guard !isLoadingSongs, hasMore else { return }
        isLoadingSongs = true
        songFailure = nil
        updatePresentation()
        let expected = generation
        songsTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await session.authenticate()
                while hasMore {
                    try Task.checkCancellation()
                    // A malformed album must not cause an unbounded server scan.
                    guard nextOffset < 10_000 else { throw MusicServerError.responseTooLarge }
                    let offset = nextOffset
                    let page = try await session.page(.album(id: album.id), offset: offset, limit: 100)
                    guard !Task.isCancelled, generation == expected else { return }
                    var known = Set(songs.map(\.id))
                    let additions = page.items.compactMap { item -> MusicServerSong? in
                        guard case .song(let song) = item, known.insert(song.id).inserted else { return nil }
                        return applyingFavoriteOverride(song)
                    }
                    songs.append(contentsOf: additions)
                    nextOffset = page.nextOffset ?? (offset + page.items.count)
                    hasMore = page.hasMore
                    if hasMore && (page.items.isEmpty || additions.isEmpty || nextOffset <= offset) {
                        throw MusicServerError.invalidResponse
                    }
                    // First tracks appear while the rest of this album loads. Album actions
                    // wait for completion, so Play/Shuffle never silently omit later discs.
                    updatePresentation()
                }
                isLoadingSongs = false
            } catch {
                guard !Task.isCancelled, generation == expected else { return }
                isLoadingSongs = false
                songFailure = (error as? MusicServerError)?.localizedDescription ?? "This section could not be loaded.".localStr()
            }
            refreshControl.endRefreshing()
            updatePresentation()
        }
    }

    private func updateHeader() {
        title = album.name
        titleLabel.text = album.name
        artistLabel.text = album.artist
        artistLabel.isHidden = album.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let year = album.year.flatMap { $0 > 0 ? String($0) : nil }
        let genre = album.genre.trimmingCharacters(in: .whitespacesAndNewlines)
        metadataLabel.text = [genre.isEmpty ? nil : genre, year].compactMap { $0 }.joined(separator: " · ")
        metadataLabel.isHidden = metadataLabel.text?.isEmpty != false
        var summary: [String] = []
        if let count = album.songCount ?? (hasMore ? nil : songs.count) {
            summary.append(String(format: "%d songs".localStr(), count))
        }
        let duration = Self.displayDuration(albumDuration: album.duration,
            songDurations: songs.map { $0.value.duration }, isComplete: !hasMore)
        if let duration, duration > 0 {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = duration < 60 ? [.second] : [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            if let text = formatter.string(from: duration) { summary.append(text) }
        }
        summaryLabel.text = summary.joined(separator: " · ")
        summaryLabel.isHidden = summary.isEmpty
        let placeholder = songs.first.map { session.musicItem(for: $0).placeImage() } ?? UIImage(systemName: "square.stack")
        let key = album.coverArt
        if artworkKey != key {
            artworkKey = key
            didLoadArtwork = false
            artwork.kf.cancelDownloadTask()
            artwork.image = placeholder
            if !key.isEmpty, let url = session.artworkURL(id: key, size: 900) {
                artwork.kf.setImage(with: KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(key):900"),
                    placeholder: placeholder, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 300, height: 300))),
                        .scaleFactor(traitCollection.displayScale), .transition(.fade(0.2))]) { [weak self] result in
                            guard let self, artworkKey == key else { return }
                            if case .success = result { didLoadArtwork = true }
                        }
            }
        } else if !didLoadArtwork {
            // Once the first track supplies its format, use the same placeholder
            // as MusicTableViewCell instead of leaving a generic album symbol.
            artwork.image = placeholder
        }
        playButton.isEnabled = !songs.isEmpty && !hasMore && !isLoadingSongs && songFailure == nil
        shuffleButton.isEnabled = playButton.isEnabled
        view.setNeedsLayout()
    }

    /// Do not add untrusted integer durations directly, or send enormous date
    /// intervals into Foundation's calendar formatter. Invalid metadata is omitted.
    private static func displayDuration(albumDuration: Int?, songDurations: [Int], isComplete: Bool) -> TimeInterval? {
        let maximum: TimeInterval = 100 * 365 * 24 * 60 * 60
        if let albumDuration, albumDuration > 0, TimeInterval(albumDuration) <= maximum {
            return TimeInterval(albumDuration)
        }
        guard isComplete else { return nil }
        var total: TimeInterval = 0
        for seconds in songDurations {
            let duration = TimeInterval(max(0, seconds))
            guard duration <= maximum - total else { return nil }
            total += duration
        }
        return total > 0 ? total : nil
    }

    private func updatePresentation() {
        updateHeader()
        tableView.reloadData()
    }

    private func applyingFavoriteOverride(_ original: MusicServerSong) -> MusicServerSong {
        var song = original
        if let favorite = favoriteOverrides[song.id] { song.value.starred = favorite }
        return song
    }

    private func refreshVisibleSongs() {
        for case let cell as MusicTableViewCell in tableView.visibleCells {
            if let model = cell.musicModel { cell.update(musicModel: model, cellType: .navidromeTrack) }
        }
    }

    @objc private func playAlbum() { play(shuffled: false) }
    @objc private func shuffleAlbum() { play(shuffled: true) }
    private func play(shuffled: Bool) {
        guard playButton.isEnabled else { return }
        let queue = (shuffled ? songs.shuffled() : songs).map { session.musicItem(for: $0) }
        guard !queue.isEmpty else { return }
        ConnectConfigManager.shared.lastPlaylist = queue
        KakaMusicPlayer.shared.startPlayMusic(musics: queue, itemIndex: 0)
    }
}

extension MusicServerAlbumDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        songs.count + ((songs.isEmpty || isLoadingSongs || songFailure != nil) ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Songs".localStr() }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard songs.indices.contains(indexPath.row) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "state", for: indexPath) as! NavidromeEmptyViewCell
            cell.minimumHeight = songs.isEmpty ? 168 : 96
            let state: MusicServerLoadState = isLoadingSongs ? .loading : songFailure.map(MusicServerLoadState.failed) ?? .empty("No data available".localStr())
            cell.configure(state) { [weak self] in self?.loadSongs() }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "song", for: indexPath) as! MusicTableViewCell
        cell.delegate = self
        cell.update(musicModel: session.musicItem(for: songs[indexPath.row]), cellType: .navidromeTrack)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard songs.indices.contains(indexPath.row) else { return }
        MusicServerSelection.open(.song(songs[indexPath.row]), among: songs.map(MusicServerItem.song), session: session, from: self)
    }
}

extension MusicServerAlbumDetailViewController: MusicTableViewCellDelegate {
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        songActions.handle(model: model, action: action)
    }
}
