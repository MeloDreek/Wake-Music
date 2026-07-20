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
    
    // 查看全部权益
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
        contentView.addSubview(restoreButton)
        
        contentView.addSubview(starImgView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(timerLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(viewVipButton)
        
    }
    
    func setupContains() {
        notnowButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.top.equalToSuperview().offset(kaka_safeAreaInsets().top + 15.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        restoreButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(18.ckValue())
            make.leading.equalToSuperview().offset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(app_navHeight + 30.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(155.ckValue())
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(20.ckValue())
            make.leading.equalToSuperview().offset(25.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        timerLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(timerLabel.size)
        }
        
        descLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(timerLabel.snp.bottom).offset(20.ckValue())
            make.leading.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        viewVipButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(descLabel.snp.bottom).offset(20.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    func handleBuness() {
        self.backgroundColor = UIColor.rgb(195, 217, 230)
        self.overrideUserInterfaceStyle = .light
    }
    
    // MARK: GET && SET
    // 付款成功
    weak var delegate: WelcomePaywallCellDelegate?
    
    var products: [StoreProduct]? {
        didSet {
            
            guard let products = self.products else { return }
            
            if let firstModel = products.first, let freeTrailDays = firstModel.freeTrialDays {

                var freeTrialStr: String
                
                if firstModel.productIdentifier == PurchaseStoreID.yearly.rawValue {
                    freeTrialStr = String(format: "Best Value: %d-Day Free Trial, then %@/year (Only %@/month)".localStr(), freeTrailDays, firstModel.localizedPriceString, firstModel.localizedPricePerMonth ?? "??")
                }else{
                    freeTrialStr = String(format: "Free Trial for %d Days, then %@/week. Cancel anytime.".localStr(), freeTrailDays, firstModel.localizedPricePerWeek ?? "??")
                }
                
                let autoRenewAttr = NSAttributedString(
                    string: freeTrialStr,
                    attributes: [.font: UIFontBold(17.ckValue()),.foregroundColor: UIColor.rgb(102, 99, 116)])
                
                self.timerLabel.isHidden = true
                self.titleLabel.text = "Unlock Premium".localStr()
                self.descLabel.attributedText = autoRenewAttr
                
            }else{
                
                let discountModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }.first
                let lifetimeModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }.first
                
                let lifetimeArray = [discountModel, lifetimeModel].compactMap { $0 }.sorted { product1, product2 in
                    return product1.price < product2.price
                }
                
                let discountPrice = lifetimeArray.first?.localizedPriceString ?? "$24.99"
                let lifetimePrice = lifetimeArray.last?.localizedPriceString ?? "$39.99"
                
                // 创建可变富文本
                let combined = NSMutableAttributedString()

                // 优惠价样式
                let discountAttr = NSAttributedString(
                    string: discountPrice + " ",
                    attributes: [.font: UIFontNumber(22.ckValue()),.foregroundColor: UIColor.rgb(102, 99, 116)])
                combined.append(discountAttr)
                
                // 原价样式（带删除线）
                let lifetimeAttr = NSAttributedString(
                    string: lifetimePrice,
                    attributes: [.font: UIFontNumber(15.ckValue()), .foregroundColor: UIColor.rgb(102, 99, 116), .strikethroughStyle: NSUnderlineStyle.single.rawValue])
                combined.append(lifetimeAttr)
                
                let offerStr = lifetimeArray.calculateDiscountPercentage()
                let lifetimeStr = String(format: "Limited Time Offer: Get Lifetime Access for %@ before the timer expires! Save %d%% permanently.".localStr(), lifetimeArray.first?.localizedPriceString ?? "??", offerStr)
                self.descLabel.attributedText = NSAttributedString(
                    string: lifetimeStr,
                    attributes: [.font: UIFontBold(17.ckValue()),.foregroundColor: UIColor.rgb(102, 99, 116)])
                self.timerLabel.isHidden = false
                self.titleLabel.attributedText = combined
                
            }
            
        }
    }

    
    // MARK: 懒加载
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
        let view = UIImageView(image: Reasource.named("gift_box"))
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
    
    lazy var timerLabel: UILabel = {
        let font = UIFontBold(16.ckValue())
        let fontHeight = font.lineHeight + 32.ckValue()
        let testText = "⏰ 01:00.00"
        
        let view = UILabel(frame: CGRectMake(0, 0, testText.width(font) + 50.ckValue(), fontHeight))
        view.layer.masksToBounds = true
        view.layer.cornerRadius = fontHeight / 2
        view.backgroundColor = UIColor.systemBlue
        view.textAlignment = .center
        view.textColor = UIColor.white
        view.font = font
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = "Unlock Premium".localStr()
        view.font = UIFontBold(17.ckValue())
        view.textColor = UIColor.rgb(102, 99, 116)
        view.textAlignment = .center
        return view
    }()
    
    lazy var viewVipButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "View All Benefits".localStr(), attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.secondaryLabel, .underlineStyle: 1])
        let view = UIButton(type: .custom)
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(viewVipButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func viewVipButtonClick() {
        self.delegate?.welcomePurchaseDidAllBenefit(cell: self)
    }
    
}

