import UIKit
import KakaFoundation
import AppGroupKit
import Kingfisher

final class NavidromeSectionHeadView: UITableViewHeaderFooterView {
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
