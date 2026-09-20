import UIKit
import KakaFoundation
import Kingfisher

/// Small, reusable presentation pieces shared by the home previews and full lists.
final class MusicServerItemCell: UITableViewCell {
    private let artworkContainer = UIView()
    private let placeholder = UIImageView()
    private let artwork = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        artworkContainer.backgroundColor = .tertiarySystemFill
        artworkContainer.layer.cornerRadius = 9
        artworkContainer.clipsToBounds = true
        placeholder.tintColor = .secondaryLabel
        placeholder.contentMode = .scaleAspectFit
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 1
        let labels = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        [artworkContainer, labels].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        [placeholder, artwork].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            artworkContainer.addSubview($0)
        }
        NSLayoutConstraint.activate([
            artworkContainer.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            artworkContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artworkContainer.widthAnchor.constraint(equalToConstant: 50),
            artworkContainer.heightAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            artworkContainer.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            artworkContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
            placeholder.centerXAnchor.constraint(equalTo: artworkContainer.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: artworkContainer.centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 24),
            placeholder.heightAnchor.constraint(equalToConstant: 24),
            artwork.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkContainer.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkContainer.bottomAnchor),
            labels.leadingAnchor.constraint(equalTo: artworkContainer.trailingAnchor, constant: 13),
            labels.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            labels.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labels.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            labels.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
        separatorInset.left = 79
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.kf.cancelDownloadTask()
        artwork.image = nil
        accessoryType = .none
    }

    func configure(item: MusicServerItem, session: MusicServerSession) {
        nameLabel.text = item.title
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = item.subtitle.isEmpty
        let symbol: String
        switch item {
        case .song: symbol = "music.note"; accessoryType = .none
        case .artist: symbol = "person.fill"; accessoryType = .disclosureIndicator
        case .album: symbol = "square.stack.fill"; accessoryType = .disclosureIndicator
        case .playlist: symbol = "music.note.list"; accessoryType = .disclosureIndicator
        case .radio: symbol = "antenna.radiowaves.left.and.right"; accessoryType = .none
        }
        placeholder.image = UIImage(systemName: symbol)
        artwork.kf.cancelDownloadTask()
        artwork.image = nil
        if !item.artworkID.isEmpty, let url = session.artworkURL(id: item.artworkID, size: 160) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):160")
            artwork.kf.setImage(with: resource, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 50, height: 50))),
                .scaleFactor(traitCollection.displayScale),
                .transition(.fade(0.15))
            ])
        }
        accessibilityLabel = [item.title, item.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

enum MusicServerLoadState {
    case loading
    case empty(String)
    case failed(String)
    case more
}

/// Full-width artwork grids. The enclosing grouped table owns the section appearance.
final class MusicServerCarouselCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    private let collectionView = MusicServerCarouselCollectionView(frame: .zero, collectionViewLayout: MusicServerCarouselLayout())
    private let pageControl = UIPageControl()
    private var collectionHeight: NSLayoutConstraint!
    private var items: [MusicServerItem] = []
    private var session: MusicServerSession?
    private var onSongAction: ((MusicServerItem, MusicActionType) -> Void)?
    private var onSelect: ((MusicServerItem) -> Void)?
    private var identity: [String] = []
    private var metrics: MusicServerGridMetrics?
    private var pendingScrollReset = false
    private var currentPage = 0
    private var isPositioningPage = false
    private var previousViewportSize: CGSize = .zero

    static func preferredHeight(for traits: UITraitCollection, width: CGFloat) -> CGFloat {
        MusicServerGridMetrics(width: width, traits: traits).totalHeight
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.alwaysBounceHorizontal = false
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MusicServerGridPage.self, forCellWithReuseIdentifier: "page")
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = .tertiaryLabel
        pageControl.currentPageIndicatorTintColor = .secondaryLabel
        pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
        [collectionView, pageControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: MusicServerGridMetrics(width: 393, traits: traitCollection).gridHeight)
        collectionHeight.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            pageControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pageControl.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: MusicServerGridMetrics.pageControlHeight),
            pageControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionHeight
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [MusicServerItem], session: MusicServerSession,
                   onSongAction: ((MusicServerItem, MusicActionType) -> Void)? = nil,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        let newIdentity = [session.accountID] + items.map(\.id)
        // Metadata/playback refreshes must not send an actively browsed grid back to page one.
        pendingScrollReset = pendingScrollReset || identity != newIdentity
        identity = newIdentity
        self.items = items
        self.session = session
        self.onSongAction = onSongAction
        self.onSelect = onSelect
        updatePageCount()
        collectionView.reloadData()
        setNeedsLayout()
    }

    func refreshPlaybackState() {
        for case let page as MusicServerGridPage in collectionView.visibleCells { page.refreshPlaybackState() }
    }

    private var pageMetrics: MusicServerGridMetrics {
        metrics ?? MusicServerGridMetrics(width: max(1, contentView.bounds.width), traits: traitCollection)
    }

    private var pageCount: Int { (items.count + pageMetrics.itemsPerPage - 1) / pageMetrics.itemsPerPage }

    private func updatePageCount() {
        pageControl.numberOfPages = pageCount
        pageControl.currentPage = min(currentPage, max(0, pageCount - 1))
        collectionView.alwaysBounceHorizontal = pageCount > 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = collectionView.bounds.width
        guard width > 0 else { return }
        let newMetrics = MusicServerGridMetrics(width: width, traits: traitCollection)
        let oldMetrics = metrics
        let metricsChanged = oldMetrics?.columns != newMetrics.columns ||
            oldMetrics?.artworkSide != newMetrics.artworkSide || oldMetrics?.gridHeight != newMetrics.gridHeight
        let viewportChanged = previousViewportSize != collectionView.bounds.size
        guard pendingScrollReset || metricsChanged || viewportChanged else { return }
        let firstVisibleSong = currentPage * (oldMetrics?.itemsPerPage ?? newMetrics.itemsPerPage)
        if pendingScrollReset { currentPage = 0 }
        else if oldMetrics?.columns != newMetrics.columns { currentPage = firstVisibleSong / newMetrics.itemsPerPage }
        pendingScrollReset = false
        metrics = newMetrics
        collectionHeight.constant = newMetrics.gridHeight
        currentPage = min(currentPage, max(0, pageCount - 1))
        updatePageCount()

        isPositioningPage = true
        defer { isPositioningPage = false }
        contentView.layoutIfNeeded()
        previousViewportSize = collectionView.bounds.size
        if metricsChanged { collectionView.reloadData() }
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        scrollToPage(currentPage, animated: false)
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        guard (0..<pageCount).contains(page),
              let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: page, section: 0))?.frame else { return }
        currentPage = page
        pageControl.currentPage = page
        // Physical page positions are resolved by the pager, including its RTL order.
        collectionView.setContentOffset(CGPoint(x: frame.minX, y: 0), animated: animated)
    }

    @objc private func pageChanged() { scrollToPage(pageControl.currentPage, animated: true) }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isPositioningPage, !pendingScrollReset,
              collectionView.bounds.size == previousViewportSize, collectionView.bounds.width > 0 else { return }
        let center = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        if let page = collectionView.indexPathForItem(at: center) {
            currentPage = page.item
            pageControl.currentPage = currentPage
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            setNeedsLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
        onSongAction = nil
        session = nil
        for case let page as MusicServerGridPage in collectionView.visibleCells { page.cancelArtwork() }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { pageCount }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath) as! MusicServerGridPage
        let start = indexPath.item * pageMetrics.itemsPerPage
        let values = Array(items[start..<min(start + pageMetrics.itemsPerPage, items.count)])
        if let session {
            cell.configure(items: values, session: session, metrics: pageMetrics,
                           layoutDirection: collectionView.effectiveUserInterfaceLayoutDirection,
                           onSongAction: onSongAction) { [weak self] in self?.onSelect?($0) }
        }
        return cell
    }

}

private struct MusicServerGridMetrics {
    static let pageControlHeight: CGFloat = 24
    let columns: Int
    let artworkSide: CGFloat
    let titleFont: UIFont
    let subtitleFont: UIFont
    var itemsPerPage: Int { columns * 2 }
    var cardHeight: CGFloat { artworkSide + 8 + ceil(titleFont.lineHeight) + 2 + ceil(subtitleFont.lineHeight) }
    var gridHeight: CGFloat { cardHeight * 2 + 18 + 16 }
    var totalHeight: CGFloat { gridHeight + Self.pageControlHeight }

    init(width: CGFloat, traits: UITraitCollection) {
        columns = min(4, max(2, Int((max(1, width) - 16) / 176)))
        let columnWidth = max(1, (width - 32 - CGFloat(columns - 1) * 16) / CGFloat(columns))
        artworkSide = min(140, columnWidth)
        titleFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold), compatibleWith: traits)
        subtitleFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12), compatibleWith: traits)
    }
}

private final class MusicServerCarouselCollectionView: UICollectionView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl || super.touchesShouldCancel(in: view)
    }
}

/// Pages have no inter-item layout: each one always equals the current viewport.
/// Computing frames directly avoids stale FlowLayout metrics while split-view size changes.
private final class MusicServerCarouselLayout: UICollectionViewLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { false }

    private var pageCount: Int {
        guard let collectionView, collectionView.numberOfSections > 0 else { return 0 }
        return collectionView.numberOfItems(inSection: 0)
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return CGSize(width: collectionView.bounds.width * CGFloat(pageCount), height: collectionView.bounds.height)
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView, indexPath.section == 0, (0..<pageCount).contains(indexPath.item) else { return nil }
        let physicalPage = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? pageCount - 1 - indexPath.item : indexPath.item
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: CGFloat(physicalPage) * collectionView.bounds.width, y: 0,
                                  width: collectionView.bounds.width, height: collectionView.bounds.height)
        return attributes
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        (0..<pageCount).compactMap { layoutAttributesForItem(at: IndexPath(item: $0, section: 0)) }
            .filter { $0.frame.intersects(rect) }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        collectionView?.bounds.size != newBounds.size
    }

    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds)
        if let collectionView, collectionView.bounds.width > 0,
           collectionView.bounds.width != newBounds.width {
            let physicalPage = (collectionView.contentOffset.x / collectionView.bounds.width).rounded()
            context.contentOffsetAdjustment.x = physicalPage * newBounds.width - collectionView.contentOffset.x
        }
        return context
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint,
                                     withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView, collectionView.bounds.width > 0 else { return proposedContentOffset }
        let width = collectionView.bounds.width
        let pageOffset = (proposedContentOffset.x / width).rounded() * width
        let maximum = max(0, collectionViewContentSize.width - width)
        return CGPoint(x: min(maximum, max(0, pageOffset)), y: 0)
    }
}

private final class MusicServerGridPage: UICollectionViewCell {
    private let rows = UIStackView()
    private var cards: [MusicServerGridSongView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        rows.axis = .vertical
        rows.spacing = 18
        rows.distribution = .fillEqually
        rows.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rows.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            rows.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [MusicServerItem], session: MusicServerSession, metrics: MusicServerGridMetrics,
                   layoutDirection: UIUserInterfaceLayoutDirection,
                   onSongAction: ((MusicServerItem, MusicActionType) -> Void)?,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        cancelArtwork()
        cards.removeAll()
        for row in rows.arrangedSubviews { rows.removeArrangedSubview(row); row.removeFromSuperview() }
        let semantic: UISemanticContentAttribute = layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        rows.semanticContentAttribute = semantic
        for rowIndex in 0..<2 {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 16
            row.distribution = .fillEqually
            row.semanticContentAttribute = semantic
            for column in 0..<metrics.columns {
                let index = rowIndex * metrics.columns + column
                if items.indices.contains(index) {
                    let card = MusicServerGridSongView()
                    card.semanticContentAttribute = semantic
                    card.configure(item: items[index], session: session, metrics: metrics,
                                   onSongAction: onSongAction, onSelect: onSelect)
                    cards.append(card)
                    row.addArrangedSubview(card)
                } else {
                    row.addArrangedSubview(UIView())
                }
            }
            rows.addArrangedSubview(row)
        }
    }

    func cancelArtwork() { cards.forEach { $0.cancelArtwork() } }
    func refreshPlaybackState() { cards.forEach { $0.refreshPlaybackState() } }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelArtwork()
    }
}

private final class MusicServerGridSongView: UIView {
    private let artworkContainer = UIView()
    private let artworkPlaceholder = UIImageView(image: UIImage(systemName: "music.note"))
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let playArea = MusicServerGridPlayArea()
    private let moreButton = UIButton(type: .system)
    private var artworkSide: NSLayoutConstraint!
    private var hasActivePlayback: (() -> Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artworkContainer.backgroundColor = .tertiarySystemFill
        artworkContainer.layer.cornerRadius = 8
        artworkContainer.layer.cornerCurve = .continuous
        artworkContainer.clipsToBounds = true
        artworkPlaceholder.contentMode = .scaleAspectFit
        artworkPlaceholder.tintColor = .tertiaryLabel
        titleLabel.numberOfLines = 1
        subtitleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        moreButton.setImage(UIImage(systemName: "ellipsis", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)), for: .normal)
        moreButton.tintColor = .secondaryLabel
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.accessibilityLabel = "More".localStr()
        moreButton.accessibilityIdentifier = "music.server.grid.more"
        [playArea, moreButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        [artworkContainer, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            playArea.addSubview($0)
        }
        [artworkPlaceholder, artwork].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            artworkContainer.addSubview($0)
        }
        artworkSide = artworkContainer.widthAnchor.constraint(equalToConstant: 140)
        NSLayoutConstraint.activate([
            playArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            playArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            playArea.topAnchor.constraint(equalTo: topAnchor),
            playArea.bottomAnchor.constraint(equalTo: bottomAnchor),
            artworkContainer.topAnchor.constraint(equalTo: playArea.topAnchor),
            artworkContainer.centerXAnchor.constraint(equalTo: playArea.centerXAnchor),
            artworkSide,
            artworkContainer.heightAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            artworkPlaceholder.centerXAnchor.constraint(equalTo: artworkContainer.centerXAnchor),
            artworkPlaceholder.centerYAnchor.constraint(equalTo: artworkContainer.centerYAnchor),
            artworkPlaceholder.widthAnchor.constraint(equalToConstant: 32),
            artworkPlaceholder.heightAnchor.constraint(equalToConstant: 32),
            artwork.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkContainer.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkContainer.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: artworkContainer.bottomAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: playArea.bottomAnchor),
            moreButton.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            moreButton.topAnchor.constraint(equalTo: artworkContainer.bottomAnchor, constant: 4),
            moreButton.widthAnchor.constraint(equalToConstant: 32),
            moreButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        playArea.isAccessibilityElement = true
        playArea.accessibilityTraits = .button
        playArea.accessibilityIdentifier = "music.server.grid.play"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: MusicServerItem, session: MusicServerSession, metrics: MusicServerGridMetrics,
                   onSongAction: ((MusicServerItem, MusicActionType) -> Void)?,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        artwork.kf.cancelDownloadTask()
        // Explicitly mirror both sides of cross-view leading/trailing constraints.
        // UIKit image/label containers can otherwise retain the application's base direction.
        [playArea, artworkContainer, artworkPlaceholder, artwork, titleLabel, subtitleLabel, moreButton].forEach {
            $0.semanticContentAttribute = semanticContentAttribute
        }
        artwork.image = nil
        artworkSide.constant = metrics.artworkSide
        titleLabel.font = metrics.titleFont
        subtitleLabel.font = metrics.subtitleFont
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        titleLabel.textAlignment = effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
        subtitleLabel.textAlignment = titleLabel.textAlignment
        playArea.accessibilityLabel = [item.title, item.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        playArea.onActivate = { onSelect(item) }
        playArea.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Play".localStr()) { [weak playArea] _ in
            playArea?.accessibilityActivate() ?? false
        }]
        moreButton.isEnabled = onSongAction != nil
        if case .song(let song) = item {
            let model = session.musicItem(for: song)
            hasActivePlayback = { KakaMusicPlayer.shared.playingMusic == model && KakaMusicPlayer.shared.isPlaying }
            let likeAction: MusicActionType = model.isFlagFavorite() ? .removeFavirote : .addFavirote
            func action(_ type: MusicActionType) -> UIAction {
                UIAction(title: type.titleStr(), image: type.iconImage(), attributes: type == .download ? .destructive : []) { _ in
                    onSongAction?(item, type)
                }
            }
            moreButton.menu = UIMenu(title: item.title, children: [
                UIMenu(options: .displayInline, children: [action(likeAction), action(.addPlaylist)]),
                UIMenu(options: .displayInline, children: [action(.artistDetial), action(.albumDetial)]),
                UIMenu(options: .displayInline, children: [action(.download)])
            ])
        } else {
            hasActivePlayback = nil
            moreButton.menu = nil
        }
        if !item.artworkID.isEmpty, let url = session.artworkURL(id: item.artworkID, size: 300) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):300")
            artwork.kf.setImage(with: resource, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: metrics.artworkSide, height: metrics.artworkSide))),
                .scaleFactor(traitCollection.displayScale), .transition(.fade(0.15))
            ])
        }
        refreshPlaybackState()
    }

    func refreshPlaybackState() { titleLabel.textColor = hasActivePlayback?() == true ? tintColor : .label }
    func cancelArtwork() { artwork.kf.cancelDownloadTask() }
}

/// A card is activated only by a completed tap, never by a scroll view's delayed selection callback.
private final class MusicServerGridPlayArea: UIView, UIGestureRecognizerDelegate {
    var onActivate: (() -> Void)?
    private lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
    private let requiredScrollGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

    override init(frame: CGRect) {
        super.init(frame: frame)
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() { super.didMoveToWindow(); bindScrollGestures() }
    override func layoutSubviews() { super.layoutSubviews(); bindScrollGestures() }

    private func bindScrollGestures() {
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView, scroll.isScrollEnabled,
               !requiredScrollGestures.contains(scroll.panGestureRecognizer) {
                tapGesture.require(toFail: scroll.panGestureRecognizer)
                requiredScrollGestures.add(scroll.panGestureRecognizer)
            }
            ancestor = view.superview
        }
    }

    private var hasActiveScrollingAncestor: Bool {
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView,
               scroll.isDragging || scroll.isDecelerating ||
                scroll.panGestureRecognizer.state == .began || scroll.panGestureRecognizer.state == .changed { return true }
            ancestor = view.superview
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let view = touchedView, view !== self {
            if view is UIControl { return false }
            touchedView = view.superview
        }
        return true
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        super.gestureRecognizerShouldBegin(gestureRecognizer) && !hasActiveScrollingAncestor
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        _ = accessibilityActivate()
    }

    override func accessibilityActivate() -> Bool {
        guard !hasActiveScrollingAncestor, let onActivate else { return false }
        onActivate()
        return true
    }

    override var canBecomeFirstResponder: Bool { true }
    override var canBecomeFocused: Bool { true }
    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(activateFromKeyboard)),
         UIKeyCommand(input: " ", modifierFlags: [], action: #selector(activateFromKeyboard))]
        + (super.keyCommands ?? []).filter { $0.input != "\r" && $0.input != " " }
    }
    @objc private func activateFromKeyboard() { _ = accessibilityActivate() }
}

final class MusicServerStatusCell: UITableViewCell {
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let button = UIButton(type: .system)
    private var onAction: (() -> Void)?
    private var minimumHeightConstraint: NSLayoutConstraint!

    /// Full-width home sections use a generous empty state; paginated lists retain their compact sizing.
    var minimumHeight: CGFloat = 0 {
        didSet { minimumHeightConstraint.constant = minimumHeight }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        let buttonHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        buttonHeight.priority = .defaultHigh // UIStackView collapses this button while loading/empty.
        buttonHeight.isActive = true
        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        minimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        minimumHeightConstraint.priority = UILayoutPriority(999)
        minimumHeightConstraint.isActive = true
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        minimumHeight = 0
        onAction = nil
    }

    func configure(_ state: MusicServerLoadState, action: (() -> Void)? = nil) {
        onAction = action
        spinner.stopAnimating()
        spinner.isHidden = true
        messageLabel.isHidden = true
        button.isHidden = true
        switch state {
        case .loading:
            spinner.isHidden = false
            spinner.startAnimating()
        case .empty(let text):
            messageLabel.isHidden = false
            messageLabel.text = text
        case .failed(let text):
            messageLabel.isHidden = false
            messageLabel.text = text
            button.isHidden = false
            button.setTitle("Retry".localStr(), for: .normal)
        case .more:
            button.isHidden = false
            button.setTitle("Load More".localStr(), for: .normal)
        }
    }

    @objc private func actionTapped() { onAction?() }
}

final class MusicServerSectionHeader: UITableViewHeaderFooterView {
    private let titleButton = UIButton(type: .system)
    private let button = UIButton(type: .system)
    private var onNavigation: (() -> Void)?
    private var onAction: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        titleButton.titleLabel?.adjustsFontForContentSizeCategory = true
        titleButton.titleLabel?.numberOfLines = 0
        titleButton.contentHorizontalAlignment = .leading
        titleButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleButton.addTarget(self, action: #selector(titleTapped), for: .touchUpInside)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .natural
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [titleButton, spacer, button])
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        let actionWidth = button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44)
        actionWidth.priority = UILayoutPriority(999) // Hidden actions collapse without reserving trailing space.
        actionWidth.isActive = true
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, navigation: (() -> Void)? = nil, actionTitle: String? = nil,
                   actionSymbol: String? = nil, actionEnabled: Bool = true, action: (() -> Void)? = nil) {
        onNavigation = navigation
        onAction = action
        var titleConfig = UIButton.Configuration.plain()
        titleConfig.title = title
        titleConfig.baseForegroundColor = .label
        titleConfig.contentInsets = .zero
        titleConfig.titleLineBreakMode = .byWordWrapping
        titleConfig.imagePlacement = .trailing
        titleConfig.imagePadding = 5
        titleConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return attributes
        }
        if navigation != nil {
            titleConfig.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))?
                .imageFlippedForRightToLeftLayoutDirection()
            titleConfig.imageColorTransformer = UIConfigurationColorTransformer { _ in .tertiaryLabel }
        }
        titleButton.configuration = titleConfig
        titleButton.isUserInteractionEnabled = navigation != nil
        titleButton.accessibilityLabel = title
        titleButton.accessibilityTraits = navigation == nil ? [.header] : [.header, .button]

        var actionConfig = UIButton.Configuration.plain()
        actionConfig.title = actionSymbol == nil ? actionTitle : nil
        actionConfig.image = actionSymbol.flatMap { UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)) }
        actionConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0)
        actionConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline)
            return attributes
        }
        button.configuration = actionConfig
        button.isHidden = action == nil
        button.isEnabled = actionEnabled
        button.accessibilityLabel = actionTitle
    }

    // Keeps the original entry point source-compatible for other server screens.
    func configure(title: String, onSeeAll: (() -> Void)?) {
        configure(title: title, navigation: onSeeAll)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onNavigation = nil
        onAction = nil
    }

    @objc private func titleTapped() { onNavigation?() }
    @objc private func actionTapped() { onAction?() }
}

final class MusicServerOverviewCell: UITableViewCell {
    private var tiles: [MusicServerOverviewTile] = []
    private var onSelect: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        let titles = ["Songs", "Artists", "Albums", "Radio Stations"]
        tiles = titles.indices.map { index in
            let tile = MusicServerOverviewTile(title: titles[index].localStr(), paletteIndex: index)
            tile.tag = index
            tile.addTarget(self, action: #selector(tileTapped(_:)), for: .touchUpInside)
            return tile
        }
        let rows = [Array(tiles.prefix(2)), Array(tiles.suffix(2))].map { elements in
            let row = UIStackView(arrangedSubviews: elements)
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 12
            return row
        }
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ overview: MusicServerOverview, onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
        let counts = [overview.songs, overview.artists, overview.albums, overview.radios]
        for (index, count) in counts.enumerated() { tiles[index].setCount(count) }
    }

    @objc private func tileTapped(_ sender: UIControl) { onSelect?(sender.tag) }
}

private final class MusicServerOverviewTile: UIControl {
    private let numberLabel = UILabel()
    private let captionLabel = UILabel()

    init(title: String, paletteIndex: Int) {
        super.init(frame: .zero)
        let hues: [CGFloat] = [0.04, 0.60, 0.36, 0.74]
        let hue = hues[paletteIndex % hues.count]
        backgroundColor = UIColor { traits in
            UIColor(hue: hue, saturation: traits.userInterfaceStyle == .dark ? 0.24 : 0.07,
                    brightness: traits.userInterfaceStyle == .dark ? 0.21 : 0.98, alpha: 1)
        }
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        captionLabel.text = title
        captionLabel.font = .preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .secondaryLabel
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0
        numberLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: UIFontNumber(29))
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.75
        let stack = UIStackView(arrangedSubviews: [numberLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 7
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 17),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -17)
        ])
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setCount(_ count: Int?) {
        let text = count.map { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) } ?? "—"
        numberLabel.text = text
        accessibilityValue = text
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }
}
