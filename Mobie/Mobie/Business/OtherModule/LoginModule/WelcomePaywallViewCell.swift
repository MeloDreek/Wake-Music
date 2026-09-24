import UIKit
import KakaFoundation
import AppGroupKit
import KakaUIKit
import RevenueCat

protocol WelcomePaywallCellDelegate: AnyObject {
    func welcomePurchaseDidLimited(cell: WelcomePaywallViewCell)
    func welcomePurchaseDidRestore(cell: WelcomePaywallViewCell)
    func welcomePurchaseDidAllBenefit(cell: WelcomePaywallViewCell)
}

final class WelcomePaywallViewCell: UICollectionViewCell {
    weak var delegate: WelcomePaywallCellDelegate?

    private let accent = UIColor.rgb(255, 196, 139)
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let topSpacer = UIView()
    private let bottomSpacer = UIView()
    private let artwork = UIImageView()
    private let headline = UILabel()
    private let bodyLabel = UILabel()
    private let productCard = UIView()
    private let productStack = UIStackView()
    private let recommendedLabel = UILabel()
    private let productTitle = UILabel()
    private let priceLabel = UILabel()
    private let termsLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let linksStack = UIStackView()
    private var artworkHeight: NSLayoutConstraint!

    var isProcessingPurchase = false {
        didSet {
            [notnowButton, restoreButton, allPlansButton].forEach {
                $0.isEnabled = !isProcessingPurchase
                $0.alpha = isProcessingPurchase ? 0.45 : 1
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12

        artwork.contentMode = .scaleAspectFit
        artwork.isAccessibilityElement = false
        artwork.layer.shadowColor = accent.cgColor
        artwork.layer.shadowOpacity = 0.16
        artwork.layer.shadowRadius = 18

        let model = WelcomeInfoModel(page: .premium)
        artwork.image = Reasource.named(model.iconName)
        headline.text = model.title
        headline.accessibilityTraits = .header
        bodyLabel.text = model.descStr
        configureLabel(headline, size: 25, weight: .bold, alpha: 1)
        configureLabel(bodyLabel, size: 15, weight: .light, alpha: 0.82)

        configureProductCard()
        linksStack.axis = .horizontal
        linksStack.alignment = .fill
        linksStack.distribution = .fillEqually
        linksStack.spacing = 12
        [allPlansButton, restoreButton].forEach(linksStack.addArrangedSubview)

        contentView.addSubview(notnowButton)
        contentView.addSubview(scrollView)
        scrollView.addSubview(stack)
        [topSpacer, artwork, headline, bodyLabel, productCard, linksStack, bottomSpacer].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(0, after: topSpacer)
        stack.setCustomSpacing(18, after: artwork)
        stack.setCustomSpacing(8, after: headline)
        stack.setCustomSpacing(34, after: bodyLabel)
        stack.setCustomSpacing(12, after: productCard)
        stack.setCustomSpacing(0, after: linksStack)

        [notnowButton, scrollView, stack, artwork, productStack, linksStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        artworkHeight = artwork.heightAnchor.constraint(equalToConstant: 135)
        NSLayoutConstraint.activate([
            notnowButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            notnowButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            notnowButton.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            notnowButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            scrollView.topAnchor.constraint(equalTo: notnowButton.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48).welcomePriority(999),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            topSpacer.heightAnchor.constraint(equalTo: bottomSpacer.heightAnchor),
            artworkHeight,
            productStack.leadingAnchor.constraint(equalTo: productCard.leadingAnchor, constant: 18),
            productStack.trailingAnchor.constraint(equalTo: productCard.trailingAnchor, constant: -18),
            productStack.topAnchor.constraint(equalTo: productCard.topAnchor, constant: 17),
            productStack.bottomAnchor.constraint(equalTo: productCard.bottomAnchor, constant: -17),
            linksStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        // Match PurchaseHeadCell's scale without crowding shorter screens.
        let height = min(145, max(100, bounds.height * 0.20))
        if artworkHeight.constant != height { artworkHeight.constant = height }
        super.layoutSubviews()
    }

    func configure(product: StoreProduct?, trialDays: Int?, isLoading: Bool) {
        productTitle.text = product?.paywallTitle ?? "Purchase.Monthly.Title".localStr()
        priceLabel.text = product?.paywallBillingSummary
        priceLabel.isHidden = product == nil
        spinner.isHidden = !isLoading
        if isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
        if let product {
            if let trialDays {
                termsLabel.text = String(format: "Onboarding.Trial.Terms".localStr(), trialDays, product.localizedPriceString)
            } else {
                termsLabel.text = "Auto-renewable. Cancel anytime.".localStr()
            }
        } else {
            termsLabel.text = isLoading ? nil : "Purchase.ProductsUnavailable".localStr()
        }
    }

    private func configureProductCard() {
        productCard.backgroundColor = accent.withAlphaComponent(0.11)
        productCard.layer.cornerRadius = 22
        productCard.layer.borderWidth = 1.5
        productCard.layer.borderColor = accent.withAlphaComponent(0.72).cgColor
        productCard.layer.shadowColor = accent.cgColor
        productCard.layer.shadowOpacity = 0.12
        productCard.layer.shadowRadius = 16
        productStack.axis = .vertical
        productStack.alignment = .fill
        productStack.spacing = 8
        productCard.addSubview(productStack)

        configureLabel(recommendedLabel, size: 12, weight: .bold, alpha: 1)
        recommendedLabel.text = "Purchase.Recommended".localStr()
        recommendedLabel.textColor = accent
        recommendedLabel.textAlignment = .natural
        configureLabel(productTitle, size: 17, weight: .semibold, alpha: 1)
        productTitle.textAlignment = .natural
        configureLabel(priceLabel, size: 21, weight: .bold, alpha: 1)
        priceLabel.textAlignment = .natural
        priceLabel.textColor = accent
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.8
        configureLabel(termsLabel, size: 12, weight: .regular, alpha: 0.76)
        termsLabel.textAlignment = .natural
        spinner.color = accent
        [recommendedLabel, productTitle, priceLabel, spinner, termsLabel].forEach(productStack.addArrangedSubview)
        productStack.setCustomSpacing(4, after: recommendedLabel)
        productStack.setCustomSpacing(2, after: productTitle)
        productStack.setCustomSpacing(0, after: priceLabel)
    }

    private func configureLabel(_ label: UILabel, size: CGFloat, weight: UIFont.Weight, alpha: CGFloat) {
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.textColor = .white.withAlphaComponent(alpha)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }

    private func linkButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setAttributedTitle(NSAttributedString(string: title.localStr(), attributes: [
            .foregroundColor: UIColor.white.withAlphaComponent(0.82),
            .font: UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 14)),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]), for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private lazy var notnowButton = linkButton("Not Now", action: #selector(skip))
    private lazy var allPlansButton = linkButton("Purchase.AllPlans", action: #selector(allPlans))
    private lazy var restoreButton = linkButton("Restore Purchase", action: #selector(restore))
    @objc private func skip() { delegate?.welcomePurchaseDidLimited(cell: self) }
    @objc private func allPlans() { delegate?.welcomePurchaseDidAllBenefit(cell: self) }
    @objc private func restore() { delegate?.welcomePurchaseDidRestore(cell: self) }
}
