// PurchasePriceCell.swift
// A compact plan picker; full billing terms remain next to the purchase button.

import KakaFoundation
import AppGroupKit
import RevenueCat

class PurchasePriceCell: UITableViewCell {
    private let selectionImage = UIImageView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let priceLabel = UILabel()
    private let recommendationLabel = UILabel()
    private let recommendationView = UIView()
    private let titleStack = UIStackView()
    private let priceStack = UIStackView()
    private let rowStack = UIStackView()
    private var priceWidthConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionImage.contentMode = .scaleAspectFit
        selectionImage.tintColor = appMainColor
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.addArrangedSubview(nameLabel)
        titleStack.addArrangedSubview(detailLabel)
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.textColor = .secondaryLabel
        priceLabel.font = .preferredFont(forTextStyle: .headline)
        recommendationLabel.font = .preferredFont(forTextStyle: .caption2)
        recommendationLabel.textColor = .white
        recommendationLabel.textAlignment = .center
        recommendationView.backgroundColor = .systemRed
        recommendationView.layer.cornerRadius = 5
        for label in [nameLabel, detailLabel, priceLabel, recommendationLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        nameLabel.textAlignment = .natural
        detailLabel.textAlignment = .natural
        recommendationView.addSubview(recommendationLabel)
        recommendationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recommendationLabel.leadingAnchor.constraint(equalTo: recommendationView.leadingAnchor, constant: 7),
            recommendationLabel.trailingAnchor.constraint(equalTo: recommendationView.trailingAnchor, constant: -7),
            recommendationLabel.topAnchor.constraint(equalTo: recommendationView.topAnchor, constant: 3),
            recommendationLabel.bottomAnchor.constraint(equalTo: recommendationView.bottomAnchor, constant: -3)
        ])
        priceStack.axis = .vertical
        priceStack.alignment = .trailing
        priceStack.spacing = 5
        priceStack.addArrangedSubview(priceLabel)
        priceStack.addArrangedSubview(recommendationView)
        priceStack.setContentHuggingPriority(.required, for: .horizontal)
        priceStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 12
        rowStack.addArrangedSubview(titleStack)
        rowStack.addArrangedSubview(priceStack)
        contentView.addSubview(selectionImage)
        contentView.addSubview(rowStack)
        selectionImage.translatesAutoresizingMaskIntoConstraints = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        // Keep a long localized price from taking the entire row away from the title.
        // At accessibility sizes the columns become stacked instead.
        priceWidthConstraint = priceStack.widthAnchor.constraint(lessThanOrEqualTo: rowStack.widthAnchor, multiplier: 0.46)
        NSLayoutConstraint.activate([
            selectionImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            selectionImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionImage.widthAnchor.constraint(equalToConstant: 19),
            selectionImage.heightAnchor.constraint(equalToConstant: 19),
            rowStack.leadingAnchor.constraint(equalTo: selectionImage.trailingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
        updateLayoutDirectionAndTextSize()
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLayoutDirectionAndTextSize()
    }

    override func layoutSubviews() {
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let direction: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        if rowStack.semanticContentAttribute != direction {
            rowStack.semanticContentAttribute = direction
            priceStack.semanticContentAttribute = direction
        }
        super.layoutSubviews()
        priceLabel.textAlignment = isRTL ? .left : .right
    }

    private func updateLayoutDirectionAndTextSize() {
        let useVerticalLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        priceWidthConstraint.isActive = !useVerticalLayout
        rowStack.axis = useVerticalLayout ? .vertical : .horizontal
        rowStack.alignment = useVerticalLayout ? .fill : .center
        rowStack.spacing = useVerticalLayout ? 8 : 12
    }

    func update(model: StoreProduct, isSelect: Bool, subtitle: String? = nil) {
        selectionImage.image = UIImage(systemName: isSelect ? "checkmark.circle.fill" : "circle")
        nameLabel.text = model.paywallTitle
        let detail = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        detailLabel.text = detail
        detailLabel.isHidden = detail?.isEmpty != false
        priceLabel.text = model.localizedPriceString
        let isRecommended = model.productIdentifier == PurchaseStoreID.lifetime198.rawValue
        recommendationLabel.text = isRecommended ? "Purchase.BestChoice".localStr() : nil
        recommendationView.isHidden = !isRecommended
        accessibilityLabel = [model.paywallTitle, detail, model.localizedPriceString, recommendationLabel.text]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        accessibilityTraits = isSelect ? [.button, .selected] : .button
    }
}
