//
//  WelcomePurchaseCell.swift
//  Mobie
//
//  Created by 张文 on 10/14/25.
//

import KakaFoundation
import AppGroupKit
import RevenueCat

protocol WelcomePurchaseCellDelegate: AnyObject {
    
    // 进入限制版
    func welcomePurchaseDidLimited(cell: WelcomePurchaseCell)
    
    // 恢复购买
    func welcomePurchaseDidRestore(cell: WelcomePurchaseCell)
}

class WelcomePurchaseCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.rgb(235, 235, 255)
        
        contentView.addSubview(starImgView)
        contentView.addSubview(priceLabel)
        contentView.addSubview(descLabel)
        
        contentView.addSubview(notnowButton)
        contentView.addSubview(restoreButton)
        contentView.addSubview(timerLabel)
        
        starImgView.snp.makeConstraints { make in
            make.top.equalTo(app_navHeight + 35.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(155.ckValue())
        }
        
        priceLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(30.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        timerLabel.snp.makeConstraints { make in
            make.top.equalTo(priceLabel.snp.bottom).offset(20.ckValue())
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(timerLabel.size)
        }
        
        descLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(timerLabel.snp.bottom).offset(30.ckValue())
            make.leading.equalTo(25.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
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
        
        
        
    }
    
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:  GET && SET
    // 付款成功
    weak var delegate: WelcomePurchaseCellDelegate?
     
    let textColor = UIColor.rgb(102, 99, 116)
    
    let normalMsg = "Get lifetime access at the lowest price — unlock all feature on iOS and macOS!".localStr()

    // 内购模型
    var products: [StoreProduct] = [] {
        didSet {
            
            let yearModel = products.filter { $0.productIdentifier == PurchaseStoreID.yearly.rawValue }.first
            
            guard let yearModel = yearModel else {
                
                let discountModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }.first
                let lifetimeModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }.first
                
                let lifetimeArray = [discountModel, lifetimeModel].compactMap { $0 }.sorted { product1, product2 in
                    return product1.price < product2.price
                }
                
                let discountPrice = lifetimeArray.first?.localizedPriceString ?? "$19.99"  // 价格更低的终身会员
                let lifetimePrice = lifetimeArray.last?.localizedPriceString ?? "$29.99"    // 价格更高的终身会员，不一定是原价
                
                // 创建可变富文本
                let combined = NSMutableAttributedString()

                // 优惠价样式
                let discountAttr = NSAttributedString(string: discountPrice + " ", attributes: [.font: UIFontNumber(22.ckValue()), .foregroundColor: textColor])
                combined.append(discountAttr)
                
                // 原价样式（带删除线）
                let lifetimeAttr = NSAttributedString(string: lifetimePrice, attributes: [.font: UIFontNumber(15.ckValue()), .foregroundColor: textColor, .strikethroughStyle: NSUnderlineStyle.single.rawValue,]
                )
                combined.append(lifetimeAttr)

                self.descLabel.text = self.normalMsg
                self.priceLabel.attributedText = combined
                
                return
            }
            
            
            self.priceLabel.attributedText = NSAttributedString(string: "Unlock All Premium Features".localStr(), attributes: [.font: UIFontBold(15.ckValue()), .foregroundColor: textColor])
            
//            let freeTrailDays = weeklyModel.freeTrialDays ?? 0
//            let priceStr = String(format: "Free trial for %@ days, then %@/week. Cancel anytime.".localStr(), "\(freeTrailDays)", weeklyModel.localizedPriceString)
//            self.descLabel.text = priceStr
            
            self.descLabel.text = "Get lifetime access at the lowest price — unlock all feature on iOS and macOS!".localStr()
            
        }
    }
    
    
    
    // MARK:  懒加载
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("gift_box"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var priceLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .center
        view.textColor = UIColor.white
        view.font = UIFontBold(22.ckValue())
        return view
    }()
    
    lazy var timerLabel: UILabel = {
        let font = UIFontBold(16.ckValue())
        let fontHeight = font.lineHeight + 32.ckValue()
        let testText = "02:59:59.59"
        
        let view = UILabel(frame: CGRectMake(0, 0, testText.width(font) + 50.ckValue(), fontHeight))
        view.layer.masksToBounds = true
        view.layer.cornerRadius = fontHeight / 2
        view.backgroundColor = .systemRed
        view.textAlignment = .center
        view.textColor = UIColor.white
        view.font = font
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = self.normalMsg
        view.font = UIFontBold(17.ckValue())
        view.textColor = UIColor.rgb(102, 99, 116)
        view.textAlignment = .center
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
        let attbuteStr = NSAttributedString(string: "Maybe later".localStr(), attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.gray, .underlineStyle: 1])
        
        let view = UIButton(type: .custom)
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(notnowButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func notnowButtonClick() {
        self.delegate?.welcomePurchaseDidLimited(cell: self)
    }
    
    
    
}

