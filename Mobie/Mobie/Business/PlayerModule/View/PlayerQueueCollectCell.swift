import UIKit
import Combine
import AppGroupKit
import KakaFoundation
import KakaUIKit
import Kingfisher

/// An inline player page. Transport controls and the artwork background remain owned by the player.
final class PlayerQueueCollectCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate,
                                    UITableViewDragDelegate, UITableViewDropDelegate {
    var onClose: (() -> Void)?
    var bottomReservedHeight: CGFloat = 76 {
        didSet { if oldValue != bottomReservedHeight { setNeedsLayout() } }
    }
    let tableView = UITableView(frame: .zero, style: .plain)
    private let queueHeader = UITableViewHeaderFooterView(reuseIdentifier: nil)
    private let artwork = UIImageView()
    private let songTitle = UILabel()
    private let artist = UILabel()
    private let heading = UILabel()
    private let empty = UILabel()
    private let modes = UIStackView()
    private var buttons: [UIButton] = []
    private var items: [MusicItemModel] = []
    private var queueIDs: [String] = []
    private var currentID: String?
    private var subscriptions = Set<AnyCancellable>()
    private let dragOwner = UUID()
    private let orderTypes: [PlaybackOrderType] = [.random, .normal, .single]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        overrideUserInterfaceStyle = .dark
        contentView.addSubview(tableView)
        queueHeader.backgroundConfiguration = .clear()
        [artwork, songTitle, artist, modes, heading].forEach { queueHeader.contentView.addSubview($0) }
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = 10
        artwork.isUserInteractionEnabled = true
        artwork.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeQueue)))
        songTitle.font = .systemFont(ofSize: 20, weight: .semibold)
        songTitle.textColor = .white
        artist.font = .systemFont(ofSize: 16)
        artist.textColor = .white.withAlphaComponent(0.65)
        modes.axis = .horizontal
        modes.distribution = .fillEqually
        modes.spacing = 12
        for (index, symbol) in ["shuffle", "repeat", "repeat.1"].enumerated() {
            let button = UIButton(type: .system)
            // Keep explicit capsule/background and template-icon colors on Mac;
            // the native Mac button otherwise applies its own symbol rendering.
            button.preferredBehavioralStyle = .pad
            button.tag = index
            button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular))?.withRenderingMode(.alwaysTemplate), for: .normal)
            button.layer.cornerRadius = 20
            button.addTarget(self, action: #selector(changeMode(_:)), for: .touchUpInside)
            button.accessibilityLabel = ["Shuffle", "Queue.Sequential", "Queue.RepeatOne"][index].localStr()
            modes.addArrangedSubview(button)
            buttons.append(button)
        }
        heading.font = .systemFont(ofSize: 22, weight: .bold)
        heading.textColor = .white
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.indicatorStyle = .white
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.tableHeaderView = queueHeader
        tableView.dataSource = self
        tableView.delegate = self
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true
        tableView.register(PlayerQueueTrackCell.self, forCellReuseIdentifier: "QueueTrack")
        empty.text = "Queue.Empty".localStr()
        empty.textColor = .white.withAlphaComponent(0.6)
        empty.font = .systemFont(ofSize: 16)
        empty.textAlignment = .center
        empty.numberOfLines = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = contentView.bounds.width
        let margin: CGFloat = width > 500 ? 38 : 24
        let compact = bounds.height < 500
        let top: CGFloat = compact ? 32 : (kaka_IsMacOS() ? 72 : max(safeAreaInsets.top, kStatusBarHeight) + 64)
        let cover: CGFloat = compact ? 44 : 64
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rtl ? width - x - w : x, y: y, width: w, height: h)
        }
        artwork.frame = rect(margin, top, cover, cover)
        let titleX = margin + cover + 14
        let titleWidth = max(0, width - margin - titleX)
        songTitle.frame = rect(titleX, top + (cover - 48) / 2, titleWidth, 27)
        artist.frame = rect(titleX, songTitle.frame.maxY + 1, titleWidth, 22)
        modes.frame = CGRect(x: margin + 4, y: top + cover + (compact ? 10 : 24), width: width - margin * 2 - 8, height: compact ? 34 : 40)
        heading.frame = rect(margin, modes.frame.maxY + (compact ? 10 : 20), width - margin * 2, 29)
        let headerSize = CGSize(width: width, height: heading.frame.maxY + (compact ? 10 : 18))
        if queueHeader.frame.size != headerSize {
            queueHeader.frame = CGRect(origin: .zero, size: headerSize)
            // UITableView only recalculates tableHeaderView's height when it is reassigned.
            tableView.tableHeaderView = queueHeader
        }
        let bottom = bottomReservedHeight + 8
        // Keep the scroll indicator at the page edge; inset row content, not the table.
        tableView.frame = CGRect(x: 0, y: 0, width: width, height: max(0, bounds.height - bottom))
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        subscriptions.removeAll()
        guard window != nil else { return }
        let player = KakaMusicPlayer.shared
        player.$queueItems.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        player.$playingMusic.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        MusicConfigManager.shared.$orderType.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        refresh()
    }

    func refresh() {
        guard !tableView.hasActiveDrag, !tableView.hasActiveDrop else { return }
        let player = KakaMusicPlayer.shared
        currentID = player.playingMusic?.uniqueID()
        queueIDs = player.musicArray.map { $0.uniqueID() }
        items = player.upcomingQueueMusic()
        let model = player.playingMusic
        artwork.kf.cancelDownloadTask()
        artwork.image = player.cacheCoverImage ?? model?.musicCoverImage() ?? model?.placeImage()
        if let model { artwork.kf.setImage(with: model.coverThumbnailURL(), placeholder: artwork.image) }
        songTitle.text = model?.showTitleName() ?? "Queue.Title".localStr()
        artist.text = model?.showArtistName()
        heading.text = "Queue.Title".localStr() + " · \(items.count)"
        for (index, button) in buttons.enumerated() {
            let selected = orderTypes[index] == MusicConfigManager.shared.orderType
            button.backgroundColor = .white.withAlphaComponent(selected ? 0.92 : 0.12)
            button.tintColor = selected ? UIColor(white: 0.12, alpha: 1) : .white
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
        tableView.backgroundView = items.isEmpty ? empty : nil
        tableView.reloadData()
    }

    @objc private func closeQueue() { onClose?() }
    @objc private func changeMode(_ sender: UIButton) {
        guard !tableView.hasActiveDrag, !tableView.hasActiveDrop else { return }
        let order = orderTypes[sender.tag]
        guard MusicConfigManager.shared.orderType != order else { return }
        MusicConfigManager.shared.orderType = order
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 70 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QueueTrack", for: indexPath) as! PlayerQueueTrackCell
        cell.update(items[indexPath.row], reorderable: MusicConfigManager.shared.orderType == .normal)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row),
              let index = KakaMusicPlayer.shared.musicArray.firstIndex(where: { $0.uniqueID() == items[indexPath.row].uniqueID() }) else { return }
        KakaMusicPlayer.shared.playAtIndex(index)
    }

    private struct Drag {
        let owner: UUID
        let id: String
        let queue: [String]
        let current: String?
    }
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard MusicConfigManager.shared.orderType == .normal, items.indices.contains(indexPath.row) else { return [] }
        let id = items[indexPath.row].uniqueID()
        // Supply a harmless local drag representation, never a file URL or account data.
        let item = UIDragItem(itemProvider: NSItemProvider(object: UUID().uuidString as NSString))
        item.localObject = Drag(owner: dragOwner, id: id, queue: queueIDs, current: currentID)
        return [item]
    }
    func tableView(_ tableView: UITableView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool { true }
    func tableView(_ tableView: UITableView, dragSessionAllowsMoveOperation session: UIDragSession) -> Bool { true }
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        guard session.items.count == 1, let payload = session.items.first?.localObject as? Drag else { return false }
        return payload.owner == dragOwner && MusicConfigManager.shared.orderType == .normal
    }
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard let payload = session.items.first?.localObject as? Drag, payload.owner == dragOwner,
              session.localDragSession != nil, MusicConfigManager.shared.orderType == .normal else {
            return UITableViewDropProposal(operation: .forbidden)
        }
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard window != nil, let drop = coordinator.items.first, let from = drop.sourceIndexPath,
              let payload = drop.dragItem.localObject as? Drag, payload.owner == dragOwner,
              !items.isEmpty else { return }
        let to = IndexPath(row: min(coordinator.destinationIndexPath?.row ?? items.count - 1, items.count - 1), section: 0)
        guard KakaMusicPlayer.shared.moveQueuedMusic(id: payload.id, destination: to.row,
                  expectedIDs: payload.queue, currentID: payload.current) else { return }
        items = PlaybackQueue.upcoming(KakaMusicPlayer.shared.musicArray, current: currentID, id: { $0.uniqueID() })
        tableView.performBatchUpdates { tableView.moveRow(at: from, to: to) }
        coordinator.drop(drop.dragItem, toRowAt: to)
    }
    func tableView(_ tableView: UITableView, dragSessionDidEnd session: UIDragSession) {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }
    func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }
}

private final class PlayerQueueTrackCell: UITableViewCell {
    private let artwork = UIImageView()
    private let title = UILabel()
    private let artist = UILabel()
    private let handle = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        [artwork, title, artist, handle].forEach { contentView.addSubview($0) }
        artwork.layer.cornerRadius = 7
        artwork.clipsToBounds = true
        artwork.contentMode = .scaleAspectFill
        title.textColor = .white
        title.font = .systemFont(ofSize: 17)
        artist.textColor = .white.withAlphaComponent(0.60)
        artist.font = .systemFont(ofSize: 14)
        handle.tintColor = .white.withAlphaComponent(0.35)
        handle.contentMode = .scaleAspectFit
        let selection = UIView()
        selection.backgroundColor = .white.withAlphaComponent(0.1)
        selection.layer.cornerRadius = 10
        selectedBackgroundView = selection
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let w = contentView.bounds.width
        let margin: CGFloat = w > 500 ? 38 : 24
        artwork.frame = CGRect(x: rtl ? w - margin - 52 : margin, y: 9, width: 52, height: 52)
        title.frame = CGRect(x: margin + (rtl ? 36 : 65), y: 13, width: max(0, w - margin * 2 - 101), height: 23)
        artist.frame = CGRect(x: title.frame.minX, y: 37, width: title.frame.width, height: 20)
        handle.frame = CGRect(x: rtl ? margin + 2 : w - margin - 28, y: 23, width: 26, height: 24)
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        artwork.kf.cancelDownloadTask()
        artwork.image = nil
        title.text = nil
        artist.text = nil
    }
    func update(_ model: MusicItemModel, reorderable: Bool) {
        title.text = model.showTitleName()
        artist.text = model.showArtistName()
        artwork.kf.cancelDownloadTask()
        // Scrolling must only read cached art, never synchronously parse an audio file.
        artwork.kf.setImage(with: model.coverThumbnailURL(), placeholder: model.musicCoverImage() ?? model.placeImage())
        handle.isHidden = !reorderable
        accessibilityLabel = [model.showTitleName(), model.showArtistName()].joined(separator: ", ")
    }
}
