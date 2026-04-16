//
//  EmptyStatusView.swift
// Wake Music
//
//  Created by Kaka Inc. on 2023/12/27.
//

import KakaFoundation
import KakaUIKit

class EmptyStatusView: UIView {
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
        self.addSubview(emptyIconView)
        self.addSubview(titleLabel)
        self.addSubview(retryButton)
    }
    
    private func preSetupContains() {
        emptyIconView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(120.ckValue())
            make.height.equalTo(emptyIconView.snp.width)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyIconView.snp.bottom).offset(10.ckValue())
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        retryButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15.ckValue())
            make.width.equalTo(300.ckValue())
            make.height.equalTo(50.ckValue())
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(20.ckValue())
        }
        
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK:  GET && SET 
    func update(message: String) {
        titleLabel.text = message
        self.layoutIfNeeded()
    }
    
    // MARK:  懒加载 
    lazy var emptyIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("exclamationmark.triangle.fill", color: UIColor.systemOrange))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontBold(16.ckValue())
        view.textColor = UIColor.label
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()
    
    lazy var retryButton: UIButton = {
        let view = UIButton(type: .custom)
        view.setTitle("Retry".localStr(), for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor(named: "DeAccentColor"), for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
}
