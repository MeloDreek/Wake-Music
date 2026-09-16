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
            artwork.kf.setImage(with: resource, options: [.transition(.fade(0.15))])
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

final class MusicServerStatusCell: UITableViewCell {
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let button = UIButton(type: .system)
    private var onAction: (() -> Void)?

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
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            messageLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
    private let titleLabel = UILabel()
    private let button = UIButton(type: .system)
    private var onSeeAll: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.setTitle("See All".localStr(), for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .natural
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [titleLabel, button])
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -9),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        titleLabel.accessibilityTraits = .header
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, onSeeAll: (() -> Void)?) {
        titleLabel.text = title
        self.onSeeAll = onSeeAll
        button.isHidden = onSeeAll == nil
        button.accessibilityLabel = "\("See All".localStr()), \(title)"
    }

    @objc private func seeAllTapped() { onSeeAll?() }
}

final class MusicServerOverviewCell: UITableViewCell {
    private var tiles: [MusicServerOverviewTile] = []
    private var onSelect: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        let titles = ["Songs", "Artists", "Albums", "Radio Stations"]
        let symbols = ["music.note", "person.2.fill", "square.stack.fill", "antenna.radiowaves.left.and.right"]
        tiles = titles.indices.map { index in
            let tile = MusicServerOverviewTile(title: titles[index].localStr(), symbol: symbols[index])
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
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
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

    init(title: String, symbol: String) {
        super.init(frame: .zero)
        backgroundColor = .tertiarySystemGroupedBackground
        layer.cornerRadius = 12
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 17).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 17).isActive = true
        captionLabel.text = title
        captionLabel.font = .preferredFont(forTextStyle: .caption1)
        captionLabel.textColor = .secondaryLabel
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0
        numberLabel.font = .preferredFont(forTextStyle: .title2)
        numberLabel.adjustsFontForContentSizeCategory = true
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.75
        let caption = UIStackView(arrangedSubviews: [icon, captionLabel])
        caption.spacing = 6
        caption.alignment = .center
        let stack = UIStackView(arrangedSubviews: [numberLabel, caption])
        stack.axis = .vertical
        stack.spacing = 7
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
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
