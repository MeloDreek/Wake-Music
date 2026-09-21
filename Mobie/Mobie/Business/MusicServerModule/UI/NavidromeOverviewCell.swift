import UIKit
import KakaFoundation
import AppGroupKit
import Kingfisher

final class NavidromeOverviewCell: UITableViewCell {
    private var tiles: [MusicServerOverviewTile] = []
    private var onSelect: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
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
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
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
        let palette = [
            UIColor(red: 0.73, green: 0.19, blue: 0.25, alpha: 0.82),
            UIColor(red: 0.16, green: 0.36, blue: 0.72, alpha: 0.82),
            UIColor(red: 0.08, green: 0.46, blue: 0.35, alpha: 0.82),
            UIColor(red: 0.48, green: 0.27, blue: 0.69, alpha: 0.82)
        ]
        backgroundColor = palette[paletteIndex % palette.count]
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        captionLabel.text = title
        captionLabel.font = .preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .white
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0
        numberLabel.font = UIFontMetrics(forTextStyle: .title1).scaledFont(for: UIFontNumber(29))
        numberLabel.textColor = .white
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
