//
//  ConnectSectionHeadView.swift
//  Mobie
//
//  Created by 张文 on 3/3/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

protocol ConnectSectionHeadViewDelegate: AnyObject {
    
    // 点击事件
    func connectSectionHeadViewDidClick(footView: ConnectSectionHeadView, sectionType: ConnectCellSection)
}

class ConnectSectionHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(handleButton)
        contentView.addSubview(loadingView)
    }
    
    private func setupAutoLayout() {
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.bottom.equalToSuperview().inset(10.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        handleButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(15.ckValue())
            make.bottom.equalToSuperview()
            make.width.greaterThanOrEqualTo(0)
            make.height.equalTo(40.ckValue())
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerY.equalTo(handleButton)
            make.trailing.equalTo(handleButton)
            make.size.equalTo(25.ckValue())
        }
    }
    
    private func setupCusBuness() {
        contentView.backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let sectionType = self.sectionType else { return }
        self.sectionType = sectionType
    }
    
    // MARK:  GET && SET
    
    weak var delegate: ConnectSectionHeadViewDelegate?
    
    var sectionType: ConnectCellSection? {
        didSet {
            guard let sectionType = self.sectionType else {
                self.handleButton.setTitle(nil, for: .normal)
                self.handleButton.setImage(nil, for: .normal)
                return
            }

            if sectionType == .starredSongs {
                self.handleButton.setTitle("More".localStr(), for: .normal)
                self.handleButton.setImage(nil, for: .normal)
            } else if sectionType == .myPlaylists {
                self.handleButton.setTitle(nil, for: .normal)
                self.handleButton.setImage(Reasource.systemNamed("plus", color: appMainColor), for: .normal)
            } else if sectionType == .todayRandom {
                self.handleButton.setTitle("Reload".localStr(), for: .normal)
                self.handleButton.setImage(nil, for: .normal)
            } else {
                self.handleButton.setTitle(nil, for: .normal)
                self.handleButton.setImage(nil, for: .normal)
            }
            
            self.handleButton.setTitleColor(appMainColor, for: .normal)
            self.titleLabel.text = sectionType.titleStr(nil)
            self.layoutIfNeeded()
        }
    }
    
    private func titleAttbuteStr(_ textStr: String) -> NSAttributedString {
        let textFont = UIFontLight(16.ckValue())
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = PhoneSetManager.isArabicLanguage() ? .left : .right

        let attbuteStr = NSAttributedString(string: textStr, attributes: [.font: textFont, .foregroundColor: appMainColor, .paragraphStyle: paraStyle])
        return attbuteStr
    }
    
    var appMainColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    func startLoading() {
        self.handleButton.isHidden = true
        self.loadingView.startAnimating()
    }
    
    func stopLoading() {
        self.handleButton.isHidden = false
        self.loadingView.stopAnimating()
    }
    
    // MARK:  懒加载
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textColor = .secondaryLabel
        view.font = UIFontLight(13.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        return view
    }()
    
    lazy var handleButton: UIButton = {
        let view = UIButton()
        view.titleLabel?.font = UIFontLight(16.ckValue())
        view.setTitleColor(appMainColor, for: .normal)
        view.addTarget(self, action: #selector(handleButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = UIColor.label
        return view
    }()
    
    @objc func handleButtonClick(_ sender: UIButton) {
        guard let sectionType = self.sectionType else { return }
        self.delegate?.connectSectionHeadViewDidClick(footView: self, sectionType: sectionType)
    }
    
}

