//
//  LyricFontAlignTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/28/25.
//

import KakaFoundation
import AppGroupKit

/// 歌词字体对齐方式
class LyricFontAlignTableCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(centerView)
        contentView.addSubview(leftView)
        contentView.addSubview(rightView)
    }
    
    private func setupAutoLayout() {
        centerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(80.ckValue())
            make.top.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.33)
        }
        
        leftView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(centerView)
        }
        
        rightView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(centerView)
        }
    }
    
    private func setupCusBuness() {
        contentView.isUserInteractionEnabled = true
        self.selectionStyle = .none
    }
    
    // MARK:  GET && SET
    @objc func textAlignmentButtonClick(_ sender: TextAlignmentButton) {
        var lyricConfig = MusicConfigManager.shared.lyricConfig
        lyricConfig.alignment = LyricTextAlignment(rawValue: sender.tag) ?? .center
        
        MusicConfigManager.shared.lyricConfig = lyricConfig
        
        self.refreshDataAction()
    }
    
    var itemType: LyricSetCellGroup? {
        didSet {
            self.refreshDataAction()
        }
    }
    
    func refreshDataAction() {
        centerView.textAlignment = .center
        leftView.textAlignment = .left
        rightView.textAlignment = .right
    }
    
    // MARK:  懒加载
    lazy var centerView: TextAlignmentButton = {
        let view = TextAlignmentButton()
        view.tag = LyricTextAlignment.center.rawValue
        view.addTarget(self, action: #selector(textAlignmentButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var leftView: TextAlignmentButton = {
        let view = TextAlignmentButton()
        view.tag = LyricTextAlignment.left.rawValue
        view.addTarget(self, action: #selector(textAlignmentButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    lazy var rightView: TextAlignmentButton = {
        let view = TextAlignmentButton()
        view.tag = LyricTextAlignment.right.rawValue
        view.addTarget(self, action: #selector(textAlignmentButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
}


class TextAlignmentButton: UIButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        addSubview(colorView)
        colorView.addSubview(iconView)
        colorView.addSubview(textLabel)
    }
    
    private func setupAutoLayout() {
        let space = 10.ckValue()
        colorView.snp.makeConstraints { make in
            make.leading.top.equalTo(space)
            make.centerX.centerY.equalToSuperview()
        }
        
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(colorView.snp.centerY)
            make.size.equalTo(25.ckValue())
        }
        
        textLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-space)
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    private func setupCusBuness() {
        
    }
        
    var textAlignment: LyricTextAlignment? {
        didSet {
            guard let textAlignment = self.textAlignment else { return }
            let curAlignment = MusicConfigManager.shared.lyricConfig.alignment
            let isSelect = curAlignment == textAlignment
            
            textLabel.text = textAlignment.titleStr()
            iconView.image = textAlignment.iconImage(isSelect ? frontSelColor : .label)
            textLabel.textColor = isSelect ? frontSelColor : .label
            colorView.backgroundColor = isSelect ? backSelColor : .clear
            
            self.layoutIfNeeded()
        }
    }
    
    let backSelColor = UIColor.systemGreen.withAlphaComponent(0.2)
    
    let frontSelColor = UIColor.systemGreen
    
    lazy var colorView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
    lazy var iconView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var textLabel: UILabel = {
        let view = UILabel()
        view.isUserInteractionEnabled = false
        view.textAlignment = .center
        view.font = UIFontLight(11.ckValue())
        view.textColor = .label
        return view
    }()
    
}

