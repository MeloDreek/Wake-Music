import UIKit

/// Shared plain-text biography/album notes. Collapsed text is limited to three lines;
/// the button exists only when text actually overflows at the current width and text size.
final class MusicServerExpandableTextView: UIView {
    var onHeightChange: (() -> Void)?
    private let label = UILabel()
    private let measurementLabel = UILabel()
    private let button = UIButton(type: .custom)
    private let stack = UIStackView()
    private var expanded = false
    private var text: String?
    private var previousWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.textAlignment = .natural
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentHorizontalAlignment = .leading
        button.setTitleColor(.tintColor, for: .normal)
        button.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)
        let buttonHeight = button.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        buttonHeight.priority = .defaultHigh
        buttonHeight.isActive = true
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 2
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(button)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        configure(text: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String?) {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let valueOrNil = value.flatMap { $0.isEmpty ? nil : $0 }
        if self.text != valueOrNil { expanded = false }
        self.text = valueOrNil
        label.text = valueOrNil
        isHidden = valueOrNil == nil
        updateExpansion()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(previousWidth - bounds.width) > 0.5 {
            previousWidth = bounds.width
            updateExpansion()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateExpansion()
        }
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        updateExpansion()
        onHeightChange?()
    }

    private func updateExpansion() {
        label.numberOfLines = expanded ? 0 : 3
        button.setTitle(NSLocalizedString(expanded ? "MusicServer.Description.Less" : "MusicServer.Description.More", comment: "Expand music server description"), for: .normal)
        let width = bounds.width
        let overflows: Bool
        if let text, width > 0 {
            // UILabel includes paragraph/font leading that lineHeight * 3 alone misses.
            // Compare native unlimited and three-line measurements to avoid a spurious button
            // on descriptions which already fit, including large accessibility fonts.
            measurementLabel.font = label.font
            measurementLabel.text = text
            measurementLabel.numberOfLines = 0
            let size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let fullHeight = measurementLabel.sizeThatFits(size).height
            measurementLabel.numberOfLines = 3
            let collapsedHeight = measurementLabel.sizeThatFits(size).height
            overflows = fullHeight > collapsedHeight + 1
        } else { overflows = false }
        let visibilityChanged = button.isHidden == overflows
        button.isHidden = !overflows
        if visibilityChanged { onHeightChange?() }
    }
}
