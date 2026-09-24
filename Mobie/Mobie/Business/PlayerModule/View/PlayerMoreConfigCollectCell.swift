import UIKit
import Combine
import AppGroupKit
import KakaFoundation
import Kingfisher

enum PlayerMoreActionID {
    static let favorite = UIAction.Identifier("player.favorite")
    static let showAudioInformation = UIAction.Identifier("player.showAudioInformation")
    static let showMiniLyrics = UIAction.Identifier("player.showMiniLyrics")
}

/// Inline settings list, sharing action handlers without presenting a popup menu.
final class PlayerMoreConfigCollectCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate {
    var actionsProvider: (() -> UIMenu?)?
    var onSpectrum: (() -> Void)?
    var bottomReservedHeight: CGFloat = 76 {
        didSet { if oldValue != bottomReservedHeight { setNeedsLayout() } }
    }
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let songHeader = UITableViewHeaderFooterView()
    private let artwork = UIImageView()
    private let songTitle = UILabel()
    private let artistLabel = UILabel()
    private var subscriptions = Set<AnyCancellable>()
    private struct Section {
        let rows: [UIMenuElement]
    }
    private var sections: [Section] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        overrideUserInterfaceStyle = .dark
        contentView.addSubview(tableView)
        songHeader.contentView.addSubview(artwork)
        songHeader.contentView.addSubview(songTitle)
        songHeader.contentView.addSubview(artistLabel)
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        songTitle.textAlignment = .center
        songTitle.textColor = .white
        songTitle.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 20, weight: .semibold))
        songTitle.adjustsFontForContentSizeCategory = true
        songTitle.numberOfLines = 2
        artistLabel.textAlignment = .center
        artistLabel.textColor = .white.withAlphaComponent(0.65)
        artistLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 16))
        artistLabel.adjustsFontForContentSizeCategory = true
        artistLabel.numberOfLines = 1
        artistLabel.lineBreakMode = .byTruncatingTail
        tableView.tableHeaderView = songHeader
        tableView.backgroundColor = .clear
        tableView.indicatorStyle = .white
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.separatorColor = .white.withAlphaComponent(0.12)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MoreConfigRow")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let compact = bounds.height < 500
        let top: CGFloat = compact ? 24 : (kaka_IsMacOS() ? 32 : max(safeAreaInsets.top, kStatusBarHeight) + 32)
        tableView.frame = CGRect(x: 0, y: top, width: bounds.width,
            height: max(0, bounds.height - bottomReservedHeight - 12 - top))
        layoutSongHeader()
    }

    private func layoutSongHeader() {
        let width = songHeader.contentView.width
        guard width > 0 else { return }
        let compact = bounds.height < 500
        let size: CGFloat = compact ? 72 : 140
        artwork.frame = CGRect(x: (width - size) / 2, y: compact ? 20 : 32, width: size, height: size)
        artwork.layer.cornerRadius = size / 2
        let titleWidth = max(0, width - 48)
        let titleHeight = songTitle.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height
        songTitle.frame = CGRect(x: 24, y: artwork.frame.maxY + (compact ? 20 : 28), width: titleWidth, height: titleHeight)
        let artistHeight = artistLabel.isHidden ? 0 : artistLabel.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height
        artistLabel.frame = CGRect(x: 24, y: songTitle.frame.maxY + (artistLabel.isHidden ? 0 : 8), width: titleWidth, height: artistHeight)
        let headerSize = CGSize(width: width, height: artistLabel.frame.maxY + (compact ? 24 : 36))
        if songHeader.frame.size != headerSize {
            songHeader.frame = CGRect(origin: .zero, size: headerSize)
            tableView.tableHeaderView = songHeader
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        subscriptions.removeAll()
        guard window != nil else { return }
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        MusicConfigManager.shared.$lyricConfig.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        MusicConfigManager.shared.$playRate.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        refresh()
    }

    func refresh() {
        guard let definition = actionsProvider?() else { return }
        let offset = tableView.contentOffset
        let player = KakaMusicPlayer.shared
        let model = player.playingMusic
        artwork.kf.cancelDownloadTask()
        artwork.image = player.cacheCoverImage ?? model?.musicCoverImage() ?? model?.placeImage()
        if let model { artwork.kf.setImage(with: model.coverThumbnailURL(), placeholder: artwork.image) }
        songTitle.text = model?.showTitleName()
        artistLabel.text = model?.showArtistName()
        artistLabel.isHidden = artistLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        layoutSongHeader()
        let spectrumAction = UIAction(title: "Spectrum.Title".localStr(), image: UIImage(systemName: "waveform.path.ecg")) { [weak self] _ in
            self?.onSpectrum?()
        }
        sections = [Section(rows: [spectrumAction])]
        for group in definition.children.compactMap({ $0 as? UIMenu }) {
            let rows = group.children.filter { ($0 as? UIAction)?.attributes.contains(.hidden) != true }
            if !rows.isEmpty { sections.append(Section(rows: rows)) }
        }
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableView.contentOffset = CGPoint(x: 0, y: min(max(0, offset.y), max(0, tableView.contentSize.height - tableView.bounds.height)))
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 12 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 4 }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = .white.withAlphaComponent(0.65)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MoreConfigRow", for: indexPath)
        let element = sections[indexPath.section].rows[indexPath.row]
        let action = element as? UIAction
        let menu = element as? UIMenu
        let enabled = action?.attributes.contains(.disabled) != true
        let color = UIColor.white.withAlphaComponent(enabled ? 1 : 0.35)
        var config = cell.defaultContentConfiguration()
        config.text = element.title
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.textProperties.numberOfLines = 0
        config.textProperties.color = color
        config.image = element.image ?? UIImage(systemName: "tag")
        config.imageProperties.tintColor = color
        config.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        config.imageProperties.maximumSize = CGSize(width: 24, height: 24)
        config.directionalLayoutMargins.top = 16
        config.directionalLayoutMargins.bottom = 16
        cell.contentConfiguration = config
        cell.backgroundColor = .white.withAlphaComponent(0.08)
        cell.tintColor = color
        // Reset both accessories on reuse: rate uses its own compact selector.
        cell.accessoryView = nil
        let isBoolean = action?.identifier == PlayerMoreActionID.favorite ||
            action?.identifier == PlayerMoreActionID.showAudioInformation ||
            action?.identifier == PlayerMoreActionID.showMiniLyrics
        if isBoolean {
            cell.accessoryType = action?.state == .on ? .checkmark : .none
        } else {
            cell.accessoryType = enabled && menu == nil ? .disclosureIndicator : .none
        }
        cell.selectionStyle = enabled && menu == nil ? .default : .none
        if let menu {
            let selector = UIMenuAccessView(frame: CGRect(x: 0, y: 0, width: 88, height: 44))
            selector.menu = menu
            selector.showsMenuAsPrimaryAction = true
            selector.color = .white.withAlphaComponent(0.7)
            selector.contentHorizontalAlignment = .trailing
            selector.timeLabel.font = .preferredFont(forTextStyle: .subheadline)
            selector.timeLabel.adjustsFontForContentSizeCategory = true
            let selected = menu.children.compactMap { $0 as? UIAction }.first { $0.state == .on }
            selector.timeLabel.text = (selected?.title ?? String(MusicConfigManager.shared.playRate)) + "×"
            selector.accessibilityLabel = menu.title
            selector.accessibilityValue = selector.timeLabel.text
            cell.accessoryView = selector
        }
        let selection = UIView()
        selection.backgroundColor = .white.withAlphaComponent(0.14)
        cell.selectedBackgroundView = selection
        cell.accessibilityTraits = menu == nil ? [.button] : []
        if action?.state == .on { cell.accessibilityTraits.insert(.selected) }
        if !enabled { cell.accessibilityTraits.insert(.notEnabled) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let action = sections[indexPath.section].rows[indexPath.row] as? UIAction else { return }
        guard !action.attributes.contains(.disabled) else { return }
        // UIControl dispatch preserves the original UIAction handler and its restrictions.
        let dispatcher = UIButton(type: .system)
        dispatcher.addAction(action, for: .touchUpInside)
        dispatcher.sendActions(for: .touchUpInside)
        refresh()
    }
}
