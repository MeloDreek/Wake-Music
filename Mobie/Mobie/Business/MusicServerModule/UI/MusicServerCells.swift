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

/// Three-song shelves, with the next column peeking in to make horizontal browsing discoverable.
final class MusicServerCarouselCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collectionView = MusicServerCarouselCollectionView(frame: .zero, collectionViewLayout: MusicServerCarouselLayout())
    private var collectionHeight: NSLayoutConstraint!
    private var items: [MusicServerItem] = []
    private var session: MusicServerSession?
    private var onSelect: ((MusicServerItem) -> Void)?
    private var identity: [String] = []
    private var pendingScrollReset = false

    static func preferredHeight(for traits: UITraitCollection) -> CGFloat {
        rowHeight(for: traits) * 3 + 4
    }

    private static func rowHeight(for traits: UITraitCollection) -> CGFloat {
        let title = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let subtitle = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits)
        return max(74, ceil(title.lineHeight + subtitle.lineHeight + 23))
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MusicServerCarouselColumn.self, forCellWithReuseIdentifier: "column")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(collectionView)
        collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: Self.preferredHeight(for: traitCollection))
        collectionHeight.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionHeight
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [MusicServerItem], session: MusicServerSession,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        let newIdentity = [session.accountID] + items.map(\.id)
        // A progress/count refresh should not jump an actively browsed shelf back to its beginning.
        pendingScrollReset = pendingScrollReset || identity != newIdentity
        identity = newIdentity
        self.items = items
        self.session = session
        self.onSelect = onSelect
        collectionView.reloadData()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if pendingScrollReset, collectionView.bounds.width > 0, !items.isEmpty {
            pendingScrollReset = false
            collectionView.layoutIfNeeded()
            // Preserve the 20 pt leading gutter, including when the first column is at the right in RTL.
            let maximum = max(0, collectionView.contentSize.width - collectionView.bounds.width)
            let firstFrame = collectionView.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame ?? .zero
            let desired = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft
                ? firstFrame.maxX - collectionView.bounds.width + 20 : firstFrame.minX - 20
            collectionView.setContentOffset(CGPoint(x: min(maximum, max(0, desired)), y: 0), animated: false)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            collectionHeight.constant = Self.preferredHeight(for: traitCollection)
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelect = nil
        session = nil
        for case let column as MusicServerCarouselColumn in collectionView.visibleCells { column.cancelArtwork() }
        // Keep identity/offset until the next configure, so returning to the same section retains its position.
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        (items.count + 2) / 3
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "column", for: indexPath) as! MusicServerCarouselColumn
        let start = indexPath.item * 3
        let values = Array(items[start..<min(start + 3, items.count)])
        if let session {
            cell.configure(items: values, session: session) { [weak self] in self?.onSelect?($0) }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = min(420, max(1, collectionView.bounds.width - 64))
        return CGSize(width: width, height: Self.rowHeight(for: traitCollection) * 3)
    }

}

private final class MusicServerCarouselCollectionView: UICollectionView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        // Song rows are UIControls; the default UIScrollView implementation may keep their tap
        // tracking alive instead of letting the horizontal pan take over.
        view is UIControl || super.touchesShouldCancel(in: view)
    }
}

private final class MusicServerCarouselLayout: UICollectionViewFlowLayout {
    override init() {
        super.init()
        scrollDirection = .horizontal
        minimumLineSpacing = 20
        minimumInteritemSpacing = 0
        sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 4, right: 20)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    // FlowLayout already lays out columns in its environment's direction. Flipping again makes an
    // Arabic shelf start at the last column instead of the first.
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { false }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return collectionView.bounds.size != newBounds.size
    }

    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint,
                                     withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView else { return proposedContentOffset }
        let rect = CGRect(origin: CGPoint(x: proposedContentOffset.x - collectionView.bounds.width, y: 0),
                          size: CGSize(width: collectionView.bounds.width * 3, height: collectionView.bounds.height))
        let rtl = collectionView.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let offsets = (layoutAttributesForElements(in: rect) ?? []).filter { $0.representedElementCategory == .cell }.map {
            rtl ? $0.frame.maxX - collectionView.bounds.width + sectionInset.right : $0.frame.minX - sectionInset.left
        }
        guard let nearest = offsets.min(by: { abs($0 - proposedContentOffset.x) < abs($1 - proposedContentOffset.x) }) else {
            return proposedContentOffset
        }
        let maximum = max(0, collectionViewContentSize.width - collectionView.bounds.width)
        return CGPoint(x: min(maximum, max(0, nearest)), y: proposedContentOffset.y)
    }
}

private final class MusicServerCarouselColumn: UICollectionViewCell {
    private let rows = (0..<3).map { _ in MusicServerCarouselSongRow() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [MusicServerItem], session: MusicServerSession, onSelect: @escaping (MusicServerItem) -> Void) {
        for (index, row) in rows.enumerated() {
            row.configure(item: index < items.count ? items[index] : nil, session: session,
                          showsSeparator: index + 1 < items.count, onSelect: onSelect)
        }
    }

    func cancelArtwork() { rows.forEach { $0.cancelArtwork() } }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelArtwork()
    }
}

private final class MusicServerCarouselSongRow: UIControl, UIGestureRecognizerDelegate {
    private let artworkContainer = UIView()
    private let placeholder = UIImageView(image: UIImage(systemName: "music.note"))
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let separator = UIView()
    private var onTap: (() -> Void)?
    private lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
    private let requiredScrollGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

    override init(frame: CGRect) {
        super.init(frame: frame)
        artworkContainer.backgroundColor = .tertiarySystemFill
        artworkContainer.layer.cornerRadius = 8
        artworkContainer.layer.cornerCurve = .continuous
        artworkContainer.clipsToBounds = true
        placeholder.tintColor = .tertiaryLabel
        placeholder.contentMode = .scaleAspectFit
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        titleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        [titleLabel, subtitleLabel].forEach { $0.adjustsFontForContentSizeCategory = true; $0.numberOfLines = 1 }
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        separator.backgroundColor = .separator
        separator.alpha = 0.45
        [artworkContainer, labels, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        [placeholder, artwork].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            artworkContainer.addSubview($0)
        }
        NSLayoutConstraint.activate([
            artworkContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            artworkContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkContainer.widthAnchor.constraint(equalToConstant: 54),
            artworkContainer.heightAnchor.constraint(equalTo: artworkContainer.widthAnchor),
            placeholder.centerXAnchor.constraint(equalTo: artworkContainer.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: artworkContainer.centerYAnchor),
            placeholder.widthAnchor.constraint(equalToConstant: 22),
            placeholder.heightAnchor.constraint(equalToConstant: 22),
            artwork.leadingAnchor.constraint(equalTo: artworkContainer.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkContainer.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkContainer.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkContainer.bottomAnchor),
            labels.leadingAnchor.constraint(equalTo: artworkContainer.trailingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: labels.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        // A touchUpInside action can fire at the end of a drag across nested scroll views.
        // Recognize a completed tap instead, after both horizontal and vertical pans have failed.
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        bindScrollGestureRequirements()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bindScrollGestureRequirements()
    }

    private func bindScrollGestureRequirements() {
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView, !requiredScrollGestures.contains(scroll.panGestureRecognizer) {
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
               scroll.isDragging || scroll.isDecelerating || scroll.panGestureRecognizer.state == .began || scroll.panGestureRecognizer.state == .changed {
                return true
            }
            ancestor = view.superview
        }
        return false
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        super.gestureRecognizerShouldBegin(gestureRecognizer) && onTap != nil && !hasActiveScrollingAncestor
    }

    func configure(item: MusicServerItem?, session: MusicServerSession, showsSeparator: Bool,
                   onSelect: @escaping (MusicServerItem) -> Void) {
        cancelArtwork()
        artwork.image = nil
        titleLabel.text = item?.title
        subtitleLabel.text = item?.subtitle
        subtitleLabel.isHidden = item?.subtitle.isEmpty != false
        artworkContainer.isHidden = item == nil
        separator.isHidden = !showsSeparator
        isUserInteractionEnabled = item != nil
        isAccessibilityElement = item != nil
        onTap = nil
        accessibilityLabel = nil
        guard let item else { return }
        onTap = { onSelect(item) }
        accessibilityLabel = [item.title, item.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        if !item.artworkID.isEmpty, let url = session.artworkURL(id: item.artworkID, size: 160) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):160")
            artwork.kf.setImage(with: resource, options: [
                .processor(DownsamplingImageProcessor(size: CGSize(width: 54, height: 54))),
                .scaleFactor(traitCollection.displayScale),
                .transition(.fade(0.15))
            ])
        }
    }

    func cancelArtwork() { artwork.kf.cancelDownloadTask() }
    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, !hasActiveScrollingAncestor else { return }
        onTap?()
    }

    override func accessibilityActivate() -> Bool {
        guard let onTap, !hasActiveScrollingAncestor else { return false }
        onTap()
        return true
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.55 : 1 } }
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
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
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
            attributes.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .bold))
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
