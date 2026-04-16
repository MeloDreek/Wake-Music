//
//  PurchageOpsViewcell.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/2/25.
//

import KakaFoundation

enum PurchageOpsStatus: Int {
    case normal = 0  // 默认状态
    case tryed = 1   // 试过后
}

class PurchageOpsViewcell: UITableViewCell {
    
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(loadingView)
        contentView.addSubview(restoreButton)
        contentView.addSubview(tryedIconView)
        contentView.addSubview(tryedLabel)
    }
    
    private func preSetupContains() {
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(20.ckValue())
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.top.equalTo(titleLabel.snp.bottom).offset(5.ckValue())
        }
        
        restoreButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(20.ckValue())
            make.size.equalTo(restoreButton.frame.size)
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(restoreButton)
            make.size.equalTo(30.ckValue())
        }
        
        tryedIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(40.ckValue())
            make.top.equalTo(25.ckValue())
        }
        
        tryedLabel.snp.makeConstraints { make in
            make.top.equalTo(tryedIconView.snp.bottom).offset(20.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .none
    }
    
    // MARK:  GET && SET 
    
    var onClickCallBack: (()->Void)?
    
    var status: PurchageOpsStatus = .normal {
        didSet {
            let isTryed = status == .tryed
            loadingView.stopAnimating()
            
            titleLabel.isHidden = isTryed
            messageLabel.isHidden = isTryed
            restoreButton.isHidden = isTryed
            
            tryedLabel.isHidden = !isTryed
            tryedIconView.isHidden = !isTryed
        }
    }
    
    @objc func restoreButtonClick(_ sender: UIButton) {
        sender.isHidden = true
        loadingView.startAnimating()
        self.onClickCallBack?()
    }
    
    // MARK:  懒加载 
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = UIColor.label
        return view
    }()
    
    lazy var restoreButton: UIButton = {
        let title = "Restore Purchase".localStr()
        let font = UIFontBold(14.ckValue())
        
        let view = UIButton(frame: CGRectMake(0, 0, title.width(font) + 60.ckValue(), 40.ckValue()))
        view.setTitle(title, for: .normal)
        view.titleLabel?.font = font
        view.backgroundColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : appMainColor
        view.setTitleColor(.white, for: .normal)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 20.ckValue()
        view.addTarget(self, action: #selector(restoreButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "No data available".localStr()
        view.font = UIFontBold(17.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    
    lazy var messageLabel: UILabel = {
        let view = UILabel()
        view.text = "New device? Try restoring the cache".localStr()
        view.font = UIFontLight(15.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    
    lazy var tryedIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("exclamationmark.triangle", color: UIColor.secondaryLabel))
        view.contentMode = .scaleAspectFit
        view.isHidden = true
        return view
    }()
    
    lazy var tryedLabel: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.text = "No data available".localStr()
        view.numberOfLines = 0
        view.font = UIFontBold(15.ckValue())
        view.textAlignment = .center
        view.textColor = UIColor.secondaryLabel
        return view
    }()
    
}
