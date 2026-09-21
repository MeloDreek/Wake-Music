import UIKit
import KakaFoundation
import AppGroupKit
import Kingfisher

final class NavidromeEmptyViewCell: UITableViewCell {
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
