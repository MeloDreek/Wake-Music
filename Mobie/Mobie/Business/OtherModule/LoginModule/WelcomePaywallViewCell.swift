//
//  WelcomePaywallViewCell.swift
//  Mobie
//
//  Created by kaka on 2026/7/20.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit
import RevenueCat

protocol WelcomePaywallCellDelegate: AnyObject {
    
    // 进入限制版
    func welcomePurchaseDidLimited(cell: WelcomePaywallViewCell)
    
    // 恢复购买
    func welcomePurchaseDidRestore(cell: WelcomePaywallViewCell)
    
    // 查看全部购买方案
    func welcomePurchaseDidAllBenefit(cell: WelcomePaywallViewCell)
}


class WelcomePaywallViewCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        contentView.addSubview(notnowButton)
        
        contentView.addSubview(detailScrollView)
        detailScrollView.addSubview(detailStack)
        let artworkContainer = UIView()
        artworkContainer.addSubview(starImgView)
        starImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.size.equalTo(140.ckValue())
        }
        let detailViews: [UIView] = [artworkContainer, recommendedLabel, titleLabel, billingLabel, descLabel, renewalLabel, viewVipButton, restoreButton]
        detailViews.forEach {
            detailStack.addArrangedSubview($0)
        }
        detailStack.setCustomSpacing(24.ckValue(), after: artworkContainer)
        detailStack.setCustomSpacing(10.ckValue(), after: recommendedLabel)
        detailStack.setCustomSpacing(20.ckValue(), after: descLabel)
    }
    
    func setupContains() {
        notnowButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.top.equalToSuperview().offset(kaka_safeAreaInsets().top + 15.ckValue())
            make.height.greaterThanOrEqualTo(44.ckValue())
        }
        
        detailScrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(notnowButton.snp.bottom).offset(12.ckValue())
            // The controller owns the fixed Continue button below this scrolling area.
            make.bottom.equalToSuperview().inset(kaka_safeAreaInsets().bottom + 180.ckValue())
        }
        detailStack.snp.makeConstraints { make in
            make.edges.equalTo(detailScrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 8.ckValue(), left: 25.ckValue(), bottom: 20.ckValue(), right: 25.ckValue()))
            make.width.equalTo(detailScrollView.frameLayoutGuide).offset(-50.ckValue())
        }
        viewVipButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44.ckValue())
        }
        restoreButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(44.ckValue())
        }
    }
    
    func handleBuness() {
        self.backgroundColor = UIColor.rgb(195, 217, 230)
        self.overrideUserInterfaceStyle = .light
    }
    
    // MARK: GET && SET
    // 付款成功
    weak var delegate: WelcomePaywallCellDelegate?

    var isProcessingPurchase = false {
        didSet {
            [notnowButton, restoreButton, viewVipButton].forEach {
                $0.isEnabled = !isProcessingPurchase
                $0.alpha = isProcessingPurchase ? 0.45 : 1
            }
        }
    }
    var product: StoreProduct? {
        didSet {
            titleLabel.text = product?.paywallTitle ?? "Unlock Premium".localStr()
            billingLabel.text = product?.paywallBillingSummary
            billingLabel.isHidden = product == nil
            descLabel.text = product?.paywallDetail ?? "Purchase.ProductsUnavailable".localStr()
            recommendedLabel.isHidden = product?.productIdentifier != PurchaseStoreID.yearly.rawValue
            renewalLabel.isHidden = product?.productType != .autoRenewableSubscription
        }
    }

    
    // MARK: 懒加载
    private lazy var detailScrollView: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.alwaysBounceVertical = false
        view.showsHorizontalScrollIndicator = false
        return view
    }()

    private lazy var detailStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = 16.ckValue()
        return view
    }()

    private lazy var recommendedLabel: UILabel = {
        let view = UILabel()
        view.text = "Purchase.Recommended".localStr()
        view.textAlignment = .center
        view.numberOfLines = 0
        view.font = UIFontBold(13.ckValue())
        view.textColor = UIColor.rgb(69, 88, 112)
        view.isHidden = true
        return view
    }()

    private lazy var renewalLabel: UILabel = {
        let view = UILabel()
        view.text = "Auto-renewable. Cancel anytime.".localStr()
        view.textAlignment = .center
        view.numberOfLines = 0
        view.font = UIFontLight(13.ckValue())
        view.textColor = UIColor.rgb(102, 99, 116)
        view.isHidden = true
        return view
    }()

    lazy var restoreButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "Restore Purchase".localStr(), attributes: [.font: UIFontLight(13.ckValue()), .foregroundColor: UIColor.gray])
                        
        let view = UIButton()
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(restoreButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func restoreButtonClick() {
        self.delegate?.welcomePurchaseDidRestore(cell: self)
    }
    
    lazy var notnowButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "Not Now".localStr(), attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.gray, .underlineStyle: 1])
        
        let view = UIButton(type: .custom)
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(notnowButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func notnowButtonClick() {
        self.delegate?.welcomePurchaseDidLimited(cell: self)
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("vip_gift_crown"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.rgb(102, 99, 116)
        view.font = UIFontBold(22.ckValue())
        return view
    }()
    
    private lazy var billingLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.rgb(59, 65, 79)
        view.font = UIFontBold(20.ckValue())
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = "Unlock Premium".localStr()
        view.font = UIFontLight(16.ckValue())
        view.textColor = UIColor.rgb(102, 99, 116)
        view.textAlignment = .center
        return view
    }()
    
    lazy var viewVipButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "Purchase.AllPlans".localStr(), attributes: [.font: UIFontLight(15.ckValue()), .foregroundColor: UIColor.rgb(59, 65, 79), .underlineStyle: 1])
        let view = UIButton(type: .custom)
        view.titleLabel?.numberOfLines = 0
        view.titleLabel?.textAlignment = .center
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(viewVipButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func viewVipButtonClick() {
        self.delegate?.welcomePurchaseDidAllBenefit(cell: self)
    }
    
}
