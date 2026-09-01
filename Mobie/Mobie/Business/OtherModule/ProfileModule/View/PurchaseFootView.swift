//
//  PurchaseFootView.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/28.
//

import KakaFoundation

protocol PurchaseFootViewDelegate: AnyObject {
    func purchaseFootViewClickRestore(view: PurchaseFootView)
    func purchaseFootViewClickService(view: PurchaseFootView)
    func purchaseFootViewClickPrivacy(view: PurchaseFootView)
}

class PurchaseFootView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(restoreButton)
        contentView.addSubview(serviceButton)
        contentView.addSubview(privacyButton)
        
        contentView.addSubview(loadingView)
    }
    
    private func preSetupContains() {
        restoreButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
        serviceButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
        privacyButton.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(restoreButton)
            make.size.equalTo(30.ckValue())
        }
    }
    
    
    private func preSetupHandleBuness() {
        
    }
    
    // MARK:  GET && SET 
    weak var delegate: PurchaseFootViewDelegate?
    
    // MARK:  懒加载 
    lazy var restoreButton: UIButton = {
        let view = UIButton()
        view.setTitleColor(.secondaryLabel, for: .normal)
        view.setTitle("Restore Purchase".localStr(), for: .normal)
        view.titleLabel?.font = UIFontLight(10.ckValue())
        view.addTarget(self, action: #selector(restoreButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var privacyButton: UIButton = {
        let view = UIButton()
        view.setTitle("Privacy Policy".localStr(), for: .normal)
        view.setTitleColor(.secondaryLabel, for: .normal)
        view.titleLabel?.font = restoreButton.titleLabel?.font
        view.addTarget(self, action: #selector(privacyButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var serviceButton: UIButton = {
        let view = UIButton()
        view.setTitle("Terms of Service".localStr(), for: .normal)
        view.setTitleColor(.secondaryLabel, for: .normal)
        view.titleLabel?.font = restoreButton.titleLabel?.font
        view.addTarget(self, action: #selector(serviceButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = UIColor.label
        return view
    }()
    
    func startRestoreLoading() {
        self.restoreButton.setTitle(nil, for: .normal)
        self.loadingView.startAnimating()
    }
    
    func stopRestoreLoading() {
        self.restoreButton.setTitle("Restore Purchase".localStr(), for: .normal)
        self.loadingView.stopAnimating()
    }
    
    @objc func restoreButtonClick() {
        self.delegate?.purchaseFootViewClickRestore(view: self)
    }
    
    @objc func serviceButtonClick() {
        self.delegate?.purchaseFootViewClickService(view: self)
    }
    
    @objc func privacyButtonClick() {
        self.delegate?.purchaseFootViewClickPrivacy(view: self)
    }
    
}
