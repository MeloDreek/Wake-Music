//
//  PurchasePriceCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/28.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import RevenueCat


class PurchasePriceCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.selectionStyle = .default
        contentView.addSubview(selectImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(recommentView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(price298Label)
    }
    
    private func preSetupContains() {
        selectImgView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.size.equalTo(21.ckValue())
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(selectImgView.snp.trailing).offset(16.ckValue())
            make.bottom.equalTo(selectImgView.snp.centerY)
            make.size.greaterThanOrEqualTo(0)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(3.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        recommentView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
            make.size.equalTo(recommentView.size)
        }
        
        priceLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(15.ckValue())
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
    }
    
    private func preSetupHandleBuness() {
        
    }
    
    // MARK:  GET && SET
    var leftDiscountTime: Double = 0 {
        didSet {
            
            let totalMilliseconds = Int(leftDiscountTime * 100)
            let hours = totalMilliseconds / (60 * 60 * 100)
            let minutes = (totalMilliseconds % (60 * 60 * 100)) / (60 * 100)
            let seconds = (totalMilliseconds % (60 * 100)) / 100
            let milliseconds = totalMilliseconds % 100
            
            let timerString = String(format: "⏰ %02d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
            self.timeLabel.text = timerString
            
        }
    }
    
    func update(model: StoreProduct, isSelect: Bool) {
        let products = AppStoreKitManager.shared.saleArray
        
        let discountModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }.first
        let lifetimeModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }.first
        
        let lifetimeArray = [discountModel, lifetimeModel].compactMap { $0 }.sorted { product1, product2 in
            return product1.price < product2.price
        }
        
        selectImgView.isSelected = isSelect
        recommentView.isHidden = model.productIdentifier != lifetimeArray.first?.productIdentifier
        price298Label.isHidden = recommentView.isHidden
        
        nameLabel.text = model.localizedTitle
        priceLabel.text = model.localizedPriceString
        price298Label.attributedText = self.priceAttbuteStr(lifetimeArray)
        
        let saveStr = lifetimeArray.calculateDiscountPercentage().formatted(.percent.precision(.fractionLength(0...2)))
        recommentView.text = String(format: "Save %@".localStr(), saveStr)
        
        let isAutoRenew = model.productType == .autoRenewableSubscription
        timeLabel.text = model.secondStr()
        timeLabel.textColor = model.secondTextColor()
        
        if isAutoRenew {
            priceLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(15.ckValue())
                make.centerY.equalToSuperview()
                make.size.greaterThanOrEqualTo(0)
            }
            
            price298Label.snp.removeConstraints()
        }else{
            priceLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(15.ckValue())
                make.centerY.equalTo(nameLabel)
                make.size.greaterThanOrEqualTo(0)
            }
            
            price298Label.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(15.ckValue())
                make.centerY.equalTo(timeLabel)
                make.size.greaterThanOrEqualTo(0)
            }
        }
        
    }
    
    func priceAttbuteStr(_ lifetimeArray: [StoreProduct]) -> NSAttributedString {
        let price = lifetimeArray.last
        
        let attbuteStr = NSAttributedString(string: (price?.localizedPriceString ?? "$29.99"), attributes: [.font: UIFontLight(13.ckValue()), .foregroundColor: UIColor.secondaryLabel, .strikethroughStyle: 1])
        
        return attbuteStr
    }
    
    // MARK:  懒加载
    lazy var selectImgView: UIButton = {
        let view = UIButton()
        view.isUserInteractionEnabled = false
        view.setBackgroundImage(Reasource.systemNamed("circle", color: .label), for: .normal)
        view.setBackgroundImage(Reasource.systemNamed("checkmark.circle.fill", color: appMainColor), for: .selected)
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.textColor = UIColor.label
        view.font = UIFontBold(16.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        return view
    }()
    
    lazy var priceLabel: UILabel = {
        let view = UILabel()
        view.textColor = UIColor.label
        view.font = UIFontBold(14.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .left : .right
        return view
    }()
    
    // 原价
    lazy var price298Label: UILabel = {
        let view = UILabel()
        view.textAlignment = priceLabel.textAlignment
        return view
    }()
    
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.text = "23:59:59.99"
        view.textColor = UIColor.systemRed
        view.font = UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        return view
    }()
    
    lazy var recommentView: UILabel = {
        let text = String(format: "Save %@".localStr(), 46.5.formatted(.percent.precision(.fractionLength(0...2))))
        let font = UIFontLight(10.ckValue())
        let corners: UIRectCorner = PhoneSetManager.isArabicLanguage() ? [UIRectCorner.topRight] : [UIRectCorner.topLeft]
        
        let height = font.lineHeight + 4.ckValue()
        let view = UILabel(frame: CGRectMake(0, 0, text.width(font) + 15.ckValue(), height))
        view.text = text
        view.layer.masksToBounds = true
        view.corner(byRoundingCorners: corners, radii: 12.ckValue())
        view.backgroundColor = UIColor.systemRed
        view.font = font
        view.textColor = UIColor.white
        view.textAlignment = .center
        return view
    }()
    
}

