import UIKit
import AppGroupKit
import KakaFoundation
import Kingfisher

/// Cover, metadata and shuffle / play / export controls shared by all details.
final class CollectionDetialHeadCell: UITableViewCell {
    let coverImgView = UIImageView()
    let nameLabel = UILabel()
    let subtitleLabel = UILabel()
    let sizeLabel = UILabel()
    let playButton = UIButton(type: .system)
    let shuffleButton = UIButton(type: .system)
    let exportButton = UIButton(type: .system)
    var onArtwork: ((UIImage?) -> Void)?
    private var artworkKey: String?
    private var artworkRequest = UUID()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        coverImgView.contentMode = .scaleAspectFill
        coverImgView.clipsToBounds = true
        coverImgView.layer.cornerRadius = 12
        coverImgView.layer.cornerCurve = .continuous
        coverImgView.backgroundColor = .white.withAlphaComponent(0.08)
        coverImgView.accessibilityLabel = "Artwork".localStr()
        nameLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: .systemFont(ofSize: 28, weight: .bold))
        subtitleLabel.font = .preferredFont(forTextStyle: .title2)
        sizeLabel.font = .preferredFont(forTextStyle: .subheadline)
        for label in [nameLabel, subtitleLabel, sizeLabel] {
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .white
            label.adjustsFontForContentSizeCategory = true
        }
        sizeLabel.textColor = .white.withAlphaComponent(0.78)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Play".localStr()
        configuration.image = UIImage(systemName: "play.fill")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        configuration.imagePadding = 7
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .callout).scaledFont(for: .systemFont(ofSize: 16, weight: .semibold))
            return attributes
        }
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = ArtworkPalette.neutral.primary
        configuration.cornerStyle = .capsule
        playButton.configuration = configuration
        for (button, symbol, title) in [(shuffleButton, "shuffle", "Shuffle"), (exportButton, "square.and.arrow.up", "Export")] {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            config.contentInsets = .zero
            config.baseBackgroundColor = .white.withAlphaComponent(0.14)
            config.baseForegroundColor = .white
            config.cornerStyle = .capsule
            button.configuration = config
            button.accessibilityLabel = title.localStr()
        }
        let actions = UIStackView(arrangedSubviews: [shuffleButton, playButton, exportButton])
        actions.spacing = 18; actions.alignment = .center
        let labels = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel, sizeLabel]); labels.axis = .vertical; labels.spacing = 7
        for subview in [coverImgView, labels, actions] { subview.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(subview) }
        let coverWidth = coverImgView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.70)
        coverWidth.priority = .defaultHigh
        let playWidth = playButton.widthAnchor.constraint(equalToConstant: 160)
        playWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            coverImgView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverImgView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            coverWidth, coverImgView.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            coverImgView.heightAnchor.constraint(equalTo: coverImgView.widthAnchor),
            labels.topAnchor.constraint(equalTo: coverImgView.bottomAnchor, constant: 26),
            labels.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            labels.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            actions.topAnchor.constraint(equalTo: labels.bottomAnchor, constant: 24),
            actions.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actions.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            actions.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            actions.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28),
            playWidth, playButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            shuffleButton.widthAnchor.constraint(equalToConstant: 44),
            shuffleButton.heightAnchor.constraint(equalToConstant: 44),
            exportButton.widthAnchor.constraint(equalToConstant: 44),
            exportButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(kind: LibraryDetailKind, musics: [MusicItemModel]) {
        nameLabel.text = kind.title
        if case .album = kind {
            let artists = Array(Set(musics.map { LibraryGrouping.name($0.showArtistName(), fallback: "Unknown Artist".localStr()) })).sorted()
            subtitleLabel.text = artists.prefix(3).joined(separator: " · ")
        } else { subtitleLabel.text = nil }
        subtitleLabel.isHidden = subtitleLabel.text?.isEmpty != false
        let seconds = musics.reduce(0.0) { $0 + max(0, Double($1.durationSeconds)) }
        let duration = Int(min(seconds.isFinite ? seconds : 0, Double(Int32.max)))
        let time = duration >= 3600 ? String(format: "%d:%02d:%02d", duration / 3600, duration / 60 % 60, duration % 60)
            : String(format: "%d:%02d", duration / 60, duration % 60)
        var metadata = [String(format: "%d songs".localStr(), musics.count)]
        if !musics.isEmpty { metadata.append(time) }
        if case .album = kind, let year = musics.first?.year, year > 0 { metadata.insert(String(year), at: 0) }
        sizeLabel.text = metadata.joined(separator: " · ")
        for button in [playButton, shuffleButton, exportButton] { button.isEnabled = !musics.isEmpty; button.alpha = musics.isEmpty ? 0.4 : 1 }
        // Genre artwork is the genre's own icon, independent of track order.
        if case .genre(let genre) = kind {
            let key = "genre:\(genre.rawValue)"
            guard artworkKey != key else { return }
            artworkKey = key
            artworkRequest = UUID()
            coverImgView.kf.cancelDownloadTask()
            let image = genre.iconImage()
            coverImgView.image = image ?? UIImage(named: "music_place")
            onArtwork?(image)
            return
        }
        let coverURL = musics.lazy.map { $0.coverThumbnailURL() }.first { FileManager.default.fileExists(atPath: $0.path) }
        let memoryArtwork = musics.lazy.compactMap { $0.coverArt }.first
        let modified = coverURL.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        let key = (coverURL?.path ?? memoryArtwork.map { String(describing: ObjectIdentifier($0)) } ?? "placeholder") + String(describing: modified)
        guard key != artworkKey else { return }
        artworkKey = key
        let request = UUID(); artworkRequest = request
        let placeholder = UIImage(named: "music_place")
        coverImgView.kf.cancelDownloadTask()
        coverImgView.image = placeholder
        onArtwork?(nil)
        guard let coverURL else {
            if let memoryArtwork { coverImgView.image = memoryArtwork; onArtwork?(memoryArtwork) }
            return
        }
        coverImgView.kf.setImage(with: coverURL, placeholder: placeholder, options: [.forceRefresh]) { [weak self] result in
            guard let self, self.artworkRequest == request else { return }
            if case .success(let value) = result { self.onArtwork?(value.image) }
        }
    }
}
