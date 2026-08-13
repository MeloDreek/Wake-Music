//
//  AudioMatchLyricsFootView.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit


class AudioMatchLyricsFootView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        contentView.addSubview(tagLabel)
        contentView.addSubview(loadingView)
    }
    
    func setupContains() {
        tagLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18.ckValue())
            make.top.equalToSuperview().offset(13.ckValue())
            make.leading.lessThanOrEqualToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        loadingView.snp.makeConstraints { make in
            make.trailing.equalTo(tagLabel)
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.equalTo(20.ckValue())
        }
    }
    
    func handleBuness() {
        
    }
    
    @objc func clickViewAction() {
        guard let cellType = self.cellType, let model = self.model, let attributedText = self.tagLabel.attributedText else {
            return
        }
        
        if attributedText.string == editManuaStr { return }
        
        self.delegate?.audioMatchTagClickType(cellType: cellType, model: model)
    }
    
    // MARK: GET && SET
    weak var delegate: AudioMatchTagDelete?
    
    var model: AudioFingerprintModel?
    var cellType: MeteDataCellItemType?
    
    let textFont = kaka_IsMacOS() ? UIListContentConfiguration.cell().textProperties.font : UIFontLight(16.ckValue())
    
    let editManuaStr = "Please edit manually".localStr()
    
    func update(cellType: MeteDataCellItemType, model: AudioFingerprintModel?) {
        
        self.cellType = cellType
        self.model = model
        
        guard let model = model else {
            self.loadingView.startAnimating()
            return
        }
        
        self.loadingView.stopAnimating()
        
        var message: String?
        
        if let lyrics = model.lyrics, lyrics.count > 0 {
            message = String(format: "Choose from %@ other lyrics".localStr(), "\(lyrics.count)")
        }
        
        if let message = message, !message.isEmpty {
            tagLabel.attributedText = NSAttributedString(string: "  \(message)  ", attributes: [.font: textFont, .foregroundColor: appMainColor, .underlineStyle: 1])
        }else{
            tagLabel.attributedText = NSAttributedString(string: editManuaStr, attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.secondaryLabel])
        }
    }
    
    func setupFailedStatus() {
        self.model = nil
        self.tagLabel.attributedText = NSAttributedString(string: editManuaStr, attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.secondaryLabel])
        self.loadingView.stopAnimating()
    }
    
    // MARK: 懒加载
    lazy var tagLabel: UILabel = {
        let view = UILabel()
        view.isUserInteractionEnabled = true
        view.numberOfLines = 2
        view.textColor = appMainColor
        view.font = textFont
        view.textAlignment = PhoneSetManager.isArabicCountry() ? .left : .right
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickViewAction))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .label
        return view
    }()
    
}


