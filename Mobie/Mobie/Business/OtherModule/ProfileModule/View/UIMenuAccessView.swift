//
//  UIMenuAccessView.swift
//  Wake Music
//
//  Created by Melo on 7/25/24.
//

import KakaFoundation

class UIMenuAccessView: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        addSubview(timeIconView)
        addSubview(timeLabel)
    }
    
    private func preSetupContains() {
        timeIconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(5.ckValue())
            make.centerY.equalToSuperview()
            make.size.equalTo(kaka_IsMacOS() ? 15.ckValue() : 20.ckValue())
        }
        
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(timeIconView.snp.leading)
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    var color: UIColor = appMainColor {
        didSet {
            timeIconView.image = Reasource.systemNamed("chevron.up.chevron.down", color: color)
            timeLabel.textColor = color
        }
    }
    
    // MARK:  懒加载
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .left : .right
        view.font = UIFont.systemFont(ofSize: 11.ckValue())
        view.textColor = appMainColor
        return view
    }()
    
    lazy var timeIconView: UIImageView = {
        let image = Reasource.systemNamed("chevron.up.chevron.down", color: UIColor.placeholderText)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
}

