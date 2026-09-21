import UIKit
import KakaFoundation
import Kingfisher

/// Small, reusable presentation pieces shared by the home previews and full lists.
class MusicServerItemCell: UITableViewCell {
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
        if case .song = item {
            placeholder.image = nil
        }
        artwork.kf.cancelDownloadTask()
        let songPlaceholder: UIImage?
        if case .song(let song) = item { songPlaceholder = session.musicItem(for: song).placeImage() }
        else { songPlaceholder = nil }
        artwork.image = songPlaceholder
        if !item.artworkID.isEmpty, let url = session.artworkURL(id: item.artworkID, size: 160) {
            let resource = KF.ImageResource(downloadURL: url, cacheKey: "music-server:\(session.accountID):\(item.artworkID):160")
            artwork.kf.setImage(with: resource, placeholder: songPlaceholder, options: [
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
