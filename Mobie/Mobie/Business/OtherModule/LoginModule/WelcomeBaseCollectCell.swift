import UIKit
import KakaFoundation
import AppGroupKit
import KakaUIKit

/// Pages scroll vertically on small windows or with accessibility text.
/// The controller reserves a separate area for the action and legal links.
class WelcomeBaseCollectCell: UICollectionViewCell {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let tagsView = WelcomeFormatTagsView()
    private var artworkHeight: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        stack.axis = .vertical
        stack.spacing = 20
        artwork.contentMode = .scaleAspectFit
        artwork.isAccessibilityElement = false
        titleLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 32, weight: .bold))
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        bodyLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17))
        bodyLabel.textColor = .white.withAlphaComponent(0.8)
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        bodyLabel.adjustsFontForContentSizeCategory = true
        tagsView.textColor = .white
        tagsView.textFont = .systemFont(ofSize: 13, weight: .semibold)
        tagsView.tag_cornerRadius = 10
        tagsView.paddingX = 11
        tagsView.paddingY = 7
        tagsView.marginX = 7
        tagsView.marginY = 8
        tagsView.alignment = .center
        tagsView.isUserInteractionEnabled = false
        tagsView.semanticContentAttribute = .forceLeftToRight
        contentView.addSubview(scrollView)
        scrollView.addSubview(stack)
        [artwork, titleLabel, bodyLabel, tagsView].forEach(stack.addArrangedSubview)
        [scrollView, stack, artwork].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        artworkHeight = artwork.heightAnchor.constraint(equalToConstant: 260)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48).welcomePriority(999),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            stack.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerYAnchor).welcomePriority(750),
            artworkHeight
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var model: WelcomeInfoModel? {
        didSet {
            guard let model else { return }
            artwork.image = Reasource.named(model.iconName)
            titleLabel.text = model.title
            bodyLabel.text = model.descStr
            bodyLabel.isHidden = model.descStr.isEmpty
            tagsView.removeAllTags()
            tagsView.isHidden = model.page != .formats
            if model.page == .formats {
                // Stable vivid colors, not randomized again on cell reuse.
                let colors: [UIColor] = [.rgb(100, 69, 201), .rgb(0, 104, 173), .rgb(179, 51, 116),
                                         .rgb(0, 117, 106), .rgb(175, 71, 30), .rgb(74, 87, 189)]
                let preferred = ["FLAC", "MP3", "DSD", "WAV", "ALAC", "APE", "DTS", "AAC"]
                let all = AudioExtension.audioSuffixs.map { $0.uppercased() }
                let formats = preferred.filter(all.contains) + all.filter { !preferred.contains($0) }
                for (index, format) in formats.enumerated() {
                    tagsView.addTag(format).tagBackgroundColor = colors[index % colors.count]
                }
            }
            scrollView.setContentOffset(.zero, animated: false)
            setNeedsLayout()
        }
    }
    override func layoutSubviews() {
        let height = min(340, max(150, bounds.height * (model?.page == .formats ? 0.36 : 0.53)), max(0, bounds.width - 72))
        if artworkHeight.constant != height { artworkHeight.constant = height }
        super.layoutSubviews()
        tagsView.invalidateIntrinsicContentSize()
    }
}

private final class WelcomeFormatTagsView: TagListView {
    override var intrinsicContentSize: CGSize {
        guard !tagViews.isEmpty else { return .zero }
        let width = max(1, bounds.width)
        var rows: CGFloat = 1, used: CGFloat = 0, height: CGFloat = 0
        for tag in tagViews {
            let size = tag.intrinsicContentSize
            let tagWidth = min(size.width, width)
            if used > 0 && used + marginX + tagWidth > width { rows += 1; used = 0 }
            used += (used > 0 ? marginX : 0) + tagWidth
            height = max(height, size.height)
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: rows * height + (rows - 1) * marginY)
    }
}

extension NSLayoutConstraint {
    func welcomePriority(_ value: Float) -> NSLayoutConstraint {
        priority = UILayoutPriority(value)
        return self
    }
}
