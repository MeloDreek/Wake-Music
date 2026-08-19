//
//  PurchaseHeadCell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/28.
//

import KakaFoundation
import KakaUIKit
import FLAnimatedImage

class PurchaseHeadCell: UITableViewCell {
    
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
        self.addSubview(starImgView)
        self.addSubview(premiumLabel)
        self.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        premiumLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descLabel.snp.top).offset(-6.ckValue())
            make.leading.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        starImgView.snp.makeConstraints { make in
            make.bottom.equalTo(premiumLabel.snp.top).offset(-15.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(135.ckValue())
            make.top.equalToSuperview()
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    // MARK:  GET && SET 
    var isDiscount: Bool = true {
        didSet {
            starImgView.image = Reasource.named(isDiscount ? "gift_box" : "vip_gift_crown")
        }
    }
    
    
    // MARK:  懒加载 
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("vip_gift_crown"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var premiumLabel: UILabel = {
        let view = UILabel()
        view.text = "Upgrade to Premium".localStr()
        view.font = UIFontBold(20.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.text = "Your ultimate music player. Play anytime, anywhere, and enjoy total listening freedom!".localStr()
        view.font = UIFontLight(14.ckValue())
        view.textAlignment = .center
        return view
    }()
    
}

