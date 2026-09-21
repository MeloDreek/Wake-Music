import UIKit
import KakaFoundation
import AppGroupKit
import Kingfisher

/// Horizontal pages of song rows, never artwork cards. Each collection item is one song.
class NavidromeRecentViewCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    private let listLayout = NavidromeSongListLayout()
    private lazy var collectionView = NavidromeSongCollectionView(frame: .zero, collectionViewLayout: listLayout)
    private let pageControl = UIPageControl()
    private var collectionHeight: NSLayoutConstraint!
    private var pageControlHeight: NSLayoutConstraint!
    private var items: [MusicServerItem] = []
    private var session: MusicServerSession?
    private var onSongAction: ((MusicServerItem, MusicActionType) -> Void)?
    private var onSelect: ((MusicServerItem) -> Void)?
    private var identity: [String] = []
    private var currentPage = 0
    private var positioningPage = false
    private var previousSize = CGSize.zero
    private var needsPagePosition = true

    static func preferredHeight(for traits: UITraitCollection, width: CGFloat, itemCount: Int = 3) -> CGFloat {
        NavidromeSongListMetrics(traits: traits).rowHeight * CGFloat(min(3, max(0, itemCount))) + (itemCount > 3 ? 24 : 0)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        // Keep UIKit's existing cell/contentView/collection backgrounds.
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.alwaysBounceVertical = false
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NavidromeSongListCollectionCell.self, forCellWithReuseIdentifier: "song")
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = .tertiaryLabel
        pageControl.currentPageIndicatorTintColor = .secondaryLabel
        pageControl.addTarget(self, action: #selector(pageChanged), for: .valueChanged)
        [collectionView, pageControl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: 0)
        collectionHeight.priority = UILayoutPriority(999)
        pageControlHeight = pageControl.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            pageControl.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pageControl.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor),
            pageControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionHeight, pageControlHeight
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var pageCount: Int { (items.count + 2) / 3 }

    private func updateMetrics() {
        listLayout.rowHeight = NavidromeSongListMetrics(traits: traitCollection).rowHeight
        collectionHeight.constant = listLayout.rowHeight * CGFloat(min(3, items.count))
        pageControlHeight.constant = pageCount > 1 ? 24 : 0
        pageControl.numberOfPages = pageCount
        currentPage = min(currentPage, max(0, pageCount - 1))
        pageControl.currentPage = currentPage
        collectionView.alwaysBounceHorizontal = pageCount > 1
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                         withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                         verticalFittingPriority: UILayoutPriority) -> CGSize {
        updateMetrics()
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority,
                                            verticalFittingPriority: verticalFittingPriority)
    }

    func configure(items: [MusicServerItem], session: MusicServerSession,
                   onSongAction: ((MusicServerItem, MusicActionType) -> Void)? = nil,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        let newIdentity = [session.accountID] + items.map(\.id)
        if identity != newIdentity { currentPage = 0 }
        identity = newIdentity
        self.items = items
        self.session = session
        self.onSongAction = onSongAction
        self.onSelect = onSelect
        updateMetrics()
        needsPagePosition = true
        collectionView.reloadData()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard collectionView.bounds.width > 0 else { return }
        updateMetrics()
        contentView.layoutIfNeeded()
        guard needsPagePosition || previousSize != collectionView.bounds.size else { return }
        needsPagePosition = false
        previousSize = collectionView.bounds.size
        positioningPage = true
        defer { positioningPage = false }
        listLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        scrollToPage(currentPage, animated: false)
    }

    private func scrollToPage(_ page: Int, animated: Bool) {
        guard (0..<pageCount).contains(page),
              let frame = listLayout.layoutAttributesForItem(at: IndexPath(item: page * 3, section: 0))?.frame else { return }
        currentPage = page
        pageControl.currentPage = page
        collectionView.setContentOffset(CGPoint(x: frame.minX, y: 0), animated: animated)
    }

    @objc private func pageChanged() { scrollToPage(pageControl.currentPage, animated: true) }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !positioningPage, !needsPagePosition, pageCount > 0,
              collectionView.bounds.width > 0, collectionView.bounds.size == previousSize else { return }
        let physical = min(pageCount - 1, max(0, Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded())))
        currentPage = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? pageCount - 1 - physical : physical
        pageControl.currentPage = currentPage
    }

    func refreshPlaybackState() {
        for case let cell as NavidromeSongListCollectionCell in collectionView.visibleCells { cell.refreshPlaybackState() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateMetrics()
            needsPagePosition = true
            collectionView.reloadData()
            setNeedsLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
        onSongAction = nil
        session = nil
        for case let cell as NavidromeSongListCollectionCell in collectionView.visibleCells { cell.cancelArtwork() }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "song", for: indexPath) as! NavidromeSongListCollectionCell
        guard let session, items.indices.contains(indexPath.item) else { return cell }
        cell.semanticContentAttribute = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        cell.configure(item: items[indexPath.item], session: session, metrics: NavidromeSongListMetrics(traits: traitCollection),
                       showsSeparator: indexPath.item % 3 != 2 && indexPath.item != items.count - 1,
                       onSongAction: onSongAction) { [weak self] in self?.onSelect?($0) }
        return cell
    }
}

private struct NavidromeSongListMetrics {
    let titleFont: UIFont
    let subtitleFont: UIFont
    let artworkSide: CGFloat = 44
    var rowHeight: CGFloat { max(68, ceil(titleFont.lineHeight + subtitleFont.lineHeight + 2 + 24)) }
    init(traits: UITraitCollection) {
        titleFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17, weight: .medium), compatibleWith: traits)
        subtitleFont = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14), compatibleWith: traits)
    }
}

private final class NavidromeSongCollectionView: UICollectionView {
    override func touchesShouldCancel(in view: UIView) -> Bool { view is UIControl || super.touchesShouldCancel(in: view) }
}

/// Fill a page top-to-bottom with three full-width rows, then move to the next page.
private final class NavidromeSongListLayout: UICollectionViewLayout {
    var rowHeight: CGFloat = 68
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { false }
    private var count: Int {
        guard let collectionView, collectionView.numberOfSections > 0 else { return 0 }
        return collectionView.numberOfItems(inSection: 0)
    }
    private var pages: Int { (count + 2) / 3 }
    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return CGSize(width: collectionView.bounds.width * CGFloat(pages), height: collectionView.bounds.height)
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let collectionView, indexPath.section == 0, (0..<count).contains(indexPath.item) else { return nil }
        let logicalPage = indexPath.item / 3
        let physicalPage = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft ? pages - 1 - logicalPage : logicalPage
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: CGFloat(physicalPage) * collectionView.bounds.width,
                                  y: CGFloat(indexPath.item % 3) * rowHeight,
                                  width: collectionView.bounds.width, height: rowHeight)
        return attributes
    }
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        (0..<count).compactMap { layoutAttributesForItem(at: IndexPath(item: $0, section: 0)) }.filter { $0.frame.intersects(rect) }
    }
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { collectionView?.bounds.size != newBounds.size }
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView, collectionView.bounds.width > 0 else { return .zero }
        let width = collectionView.bounds.width
        return CGPoint(x: min(max(0, CGFloat(pages - 1) * width), max(0, (proposedContentOffset.x / width).rounded() * width)), y: 0)
    }
}

private final class NavidromeSongListCollectionCell: UICollectionViewCell {
    private let row = NavidromeSongRowView()
    private let separator = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        [row, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        separator.backgroundColor = .separator
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 69),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale))
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(item: MusicServerItem, session: MusicServerSession, metrics: NavidromeSongListMetrics,
                   showsSeparator: Bool, onSongAction: ((MusicServerItem, MusicActionType) -> Void)?,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        row.semanticContentAttribute = semanticContentAttribute
        row.configure(item: item, session: session, metrics: metrics, onSongAction: onSongAction, onSelect: onSelect)
        separator.isHidden = !showsSeparator
    }
    func refreshPlaybackState() { row.refreshPlaybackState() }
    func cancelArtwork() { row.cancelArtwork() }
    override func prepareForReuse() { super.prepareForReuse(); row.reset() }
}

private final class NavidromeSongRowView: UIView {
    private let artworkContainer = UIView()
    private let artworkPlaceholder = UIImageView()
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let playArea = NavidromeSongPlayArea()
    private let moreButton = UIButton(type: .system)
    private var artworkSide: NSLayoutConstraint!
    private var titleCenter: NSLayoutConstraint!
    private var hasActivePlayback: (() -> Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        moreButton.accessibilityIdentifier = "music.server.row.more"
        [playArea, moreButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        [artworkContainer, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            playArea.addSubview($0)
        }
        [artworkPlaceholder, artwork].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            artworkContainer.addSubview($0)
        }
        artworkSide = artworkContainer.widthAnchor.constraint(equalToConstant: 44)
        titleCenter = titleLabel.centerYAnchor.constraint(equalTo: playArea.centerYAnchor, constant: -10)
        NSLayoutConstraint.activate([
            playArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            playArea.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor),
            playArea.topAnchor.constraint(equalTo: topAnchor),
            playArea.bottomAnchor.constraint(equalTo: bottomAnchor),
            artworkContainer.centerYAnchor.constraint(equalTo: playArea.centerYAnchor),
            artworkContainer.leadingAnchor.constraint(equalTo: playArea.leadingAnchor, constant: 15),
            artworkSide,
            artworkContainer.heightAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            artworkPlaceholder.centerXAnchor.constraint(equalTo: artworkContainer.centerXAnchor),
            artworkPlaceholder.centerYAnchor.constraint(equalTo: artworkContainer.centerYAnchor),
            artworkPlaceholder.widthAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            artworkPlaceholder.heightAnchor.constraint(equalTo: artworkContainer.heightAnchor),
            artwork.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkContainer.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkContainer.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: artworkContainer.trailingAnchor, constant: 10),
            titleCenter,
            titleLabel.trailingAnchor.constraint(equalTo: playArea.trailingAnchor, constant: -4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: playArea.bottomAnchor, constant: -8),
            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            moreButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 44),
            moreButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        playArea.isAccessibilityElement = true
        playArea.accessibilityTraits = .button
        playArea.accessibilityIdentifier = "music.server.row.play"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: MusicServerItem, session: MusicServerSession, metrics: NavidromeSongListMetrics,
                   onSongAction: ((MusicServerItem, MusicActionType) -> Void)?,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        artwork.kf.cancelDownloadTask()
        // Explicitly mirror both sides of cross-view leading/trailing constraints.
        // UIKit image/label containers can otherwise retain the application's base direction.
        [playArea, artworkContainer, artworkPlaceholder, artwork, titleLabel, subtitleLabel, moreButton].forEach {
            $0.semanticContentAttribute = semanticContentAttribute
        }
        artwork.image = nil
        artworkPlaceholder.image = nil
        artworkSide.constant = metrics.artworkSide
        titleCenter.constant = -(metrics.subtitleFont.lineHeight + 2) / 2
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
            artworkPlaceholder.image = model.placeImage()
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
        if !item.artworkID.isEmpty, let url = session.artworkURL(id: item.artworkID, size: 160) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):160")
            artwork.kf.setImage(with: resource, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: metrics.artworkSide, height: metrics.artworkSide))),
                .scaleFactor(traitCollection.displayScale), .transition(.fade(0.15))
            ])
        }
        refreshPlaybackState()
    }

    func refreshPlaybackState() { titleLabel.textColor = hasActivePlayback?() == true ? tintColor : .label }
    func cancelArtwork() { artwork.kf.cancelDownloadTask() }
    func reset() {
        cancelArtwork()
        artwork.image = nil
        playArea.onActivate = nil
        moreButton.menu = nil
        hasActivePlayback = nil
    }
}

/// A card is activated only by a completed tap, never by a scroll view's delayed selection callback.
private final class NavidromeSongPlayArea: UIView, UIGestureRecognizerDelegate {
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
