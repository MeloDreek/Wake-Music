//
//  PurchageListViewcell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/20.
//

import KakaFoundation
import AppGroupKit
import RevenueCat

class PurchageListViewcell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .none
        
        preSetupSubViews()
        preSetupContains()
        preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(vipIconView)
        contentView.addSubview(sanboxView)
        contentView.addSubview(statusView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(purchageDateLabel)
        contentView.addSubview(expireDateLabel)
        contentView.addSubview(addTimeLabel)
    }
    
    private func preSetupContains() {
        
        vipIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(60.ckValue())
            make.leading.equalToSuperview().offset(15.ckValue())
            make.bottom.equalToSuperview().inset(20.ckValue())
        }
        
        sanboxView.snp.makeConstraints { make in
            make.centerX.equalTo(vipIconView)
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(vipIconView.snp.bottom)
        }
        
        statusView.snp.makeConstraints { make in
            make.centerX.equalTo(vipIconView.snp.trailing).offset(-5.ckValue())
            make.size.equalTo(25.ckValue())
            make.top.equalTo(vipIconView.snp.top)
        }
                
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(vipIconView.snp.trailing).offset(20.ckValue())
            make.bottom.equalTo(vipIconView.snp.centerY).offset(-1.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        purchageDateLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(titleLabel.snp.bottom).offset(3.ckValue())
        }
        
        expireDateLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(purchageDateLabel.snp.bottom).offset(3.ckValue())
        }
        
        addTimeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.trailing.equalToSuperview().inset(12.ckValue())
        }
        
    }
    
    private func preSetupHandleBuness() {
        
    }
    
    // MARK:  GET && SET 
    
    func updateRecord(allModel: CustomerInfo, nonSubModel: NonSubscriptionTransaction) {
        sanboxView.isHidden = !Purchases.shared.isSandbox
        let goodsEnum = PurchaseStoreID(rawValue: nonSubModel.productIdentifier)
        
        titleLabel.text = goodsEnum?.formatStr() ?? nonSubModel.productIdentifier
        statusView.image = nil
//        let isDonate = goodsEnum == .option1 || goodsEnum == .option2 || goodsEnum == .option3

        vipIconView.image = Reasource.systemNamed("crown.fill", color: appMainColor)
        purchageDateLabel.text = "Purchase Date:".localStr() +  nonSubModel.purchaseDate.convertToDateString(dateFormat: "yyyy-MM-dd HH:mm:ss")
        expireDateLabel.text = "Effective Date:".localStr() + "♾️"
        addTimeLabel.text = nil
    }
    
    func updateRecord(allModel: CustomerInfo, subModel: SubscriptionInfo) {
        sanboxView.isHidden = !subModel.isSandbox
        
        let goodsEnum = PurchaseStoreID(rawValue: subModel.productIdentifier)
        titleLabel.text = goodsEnum?.formatStr() ?? subModel.productIdentifier
        statusView.image = nil
        vipIconView.image = Reasource.systemNamed("crown.fill", color: appMainColor)
        purchageDateLabel.text = "Purchase Date:".localStr() +  subModel.purchaseDate.convertToDateString(dateFormat: "yyyy-MM-dd HH:mm:ss")
        expireDateLabel.text = "Effective Date:".localStr() + (subModel.expiresDate?.convertToDateString(dateFormat: "yyyy-MM-dd HH:mm:ss") ?? "")
    }
    
    
    // MARK:  懒加载 
    
    lazy var vipIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var statusView: UIImageView = {
        let view = UIImageView()
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontBold(15.ckValue())
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var purchageDateLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(10.ckValue())
        view.textColor = UIColor.secondaryLabel
        return view
    }()
    
    lazy var expireDateLabel: UILabel = {
        let view = UILabel()
        view.font = purchageDateLabel.font
        view.textColor = purchageDateLabel.textColor
        return view
    }()
    
    lazy var addTimeLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontBold(12.ckValue())
        view.textColor = UIColor.systemBlue
        return view
    }()
    
    lazy var sanboxView: UILabel = {
        let view = UILabel()
        view.text = "Sandbox"
        view.font = UIFontBold(8.ckValue())
        view.textAlignment = .center
        view.textColor = UIColor.label
        return view
    }()
    
}

extension PurchaseStoreID {
    public func iconImage() -> UIImage {
        let isYear = (self == .weekly || self == .yearly) ? true : false
        return Reasource.named(isYear ? "vip_365" : "vip_30")
    }
    
    public func formatStr() -> String {
        switch self {
//        case .option1:
//            return "option 1"
//        case .option2:
//            return "option 2"
//        case .option3:
//            return "option 3"
        case .weekly:
            return "Weekly".localStr()
        case .yearly:
            return "Annual".localStr()
        case .lifetime298:
            return "Lifetime".localStr()
        case .lifetime198:
            return "Lifetime Discount".localStr()
        
        }
    }

}
