import UIKit
import KakaFoundation
import AppGroupKit
import NVActivityIndicatorView

/// A viewport-sized state, not a placeholder row. Uses the same pulse animation
/// as the local music library, without showing its import controls on a server.
final class MusicServerLoadingView: UIView {
    private let indicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 25, height: 25),
                                                   type: .lineScalePulseOutRapid)
    private let messageLabel = UILabel()
    private let detailLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var onAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .secondaryLabel
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        detailLabel.textColor = .secondaryLabel
        detailLabel.isHidden = true
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [indicator, messageLabel, detailLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let indicatorHeight = indicator.heightAnchor.constraint(equalToConstant: 25)
        let retryHeight = retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        indicatorHeight.priority = .defaultHigh
        retryHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 25), indicatorHeight, retryHeight,
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -15),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            detailLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -56)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHidden: Bool {
        didSet {
            if isHidden { indicator.stopAnimating() }
            else if !indicator.isHidden { indicator.startAnimating() }
        }
    }

    func configure(_ state: MusicServerLoadState, action: (() -> Void)? = nil) {
        onAction = action
        indicator.stopAnimating()
        indicator.isHidden = true
        retryButton.isHidden = true
        detailLabel.isHidden = true
        switch state {
        case .loading:
            indicator.color = appMainColor
            indicator.isHidden = false
            indicator.startAnimating()
            messageLabel.text = "Processing...".localStr()
        case .empty(let message):
            messageLabel.text = message
        case .failed(let message):
            messageLabel.text = message
            retryButton.setTitle("Retry".localStr(), for: .normal)
            retryButton.isHidden = action == nil
        case .more:
            messageLabel.text = nil
            retryButton.setTitle("Load More".localStr(), for: .normal)
            retryButton.isHidden = action == nil
        }
    }

    func setProgress(loaded: Int, total: Int?) {
        let count = loaded.formatted()
        let progress = total.map { count + " / " + $0.formatted() } ?? count
        messageLabel.text = "Processing...".localStr() + "\n" + progress
    }

    func setLoadingHint(_ text: String?) {
        detailLabel.text = text
        detailLabel.isHidden = text == nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { indicator.stopAnimating() }
        else if !isHidden && !indicator.isHidden { indicator.startAnimating() }
    }

    @objc private func retryTapped() { onAction?() }
}
