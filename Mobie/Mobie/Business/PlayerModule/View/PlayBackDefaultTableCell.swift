//
//  PlayBackDefaultTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/21/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit


class PlayBackDefaultTableCell: UITableViewCell {
    
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
        
    }
    
    private func setupAutoLayout() {
        
    }
    
    private func setupCusBuness() {
        
    }
    
    // MARK:  GET && SET

    
    // 默认使用专辑封面
    var backgroundModel: PlayBackgroundModel? {
        didSet {
            guard let backgroundModel = backgroundModel else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = "Default: Cover Art".localStr()
            cellConfig.textProperties.color = .label
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
            self.contentConfiguration = cellConfig
            
            let isSelect = MusicConfigManager.shared.playbackModel.backgroundType == backgroundModel.backgroundType
            self.accessoryView = isSelect ? self.selectImgView : self.unselectImgView
        }
    }
    
    var playBackConfig: PlayBackgroundEffect? {
        didSet {
            guard let playBackConfig = self.playBackConfig else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = playBackConfig.titleStr()
            cellConfig.secondaryText = playBackConfig.descStr()
            cellConfig.textProperties.color = .label
            cellConfig.secondaryTextProperties.color = .secondaryLabel
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            
            self.contentConfiguration = cellConfig
            
            self.switchView.isOn = MusicConfigManager.shared.playbackModel.isShowAlphaMask
            self.switchView.isEnabled = MusicConfigManager.shared.playbackModel.backgroundConfig == .translucencyMask
            if playBackConfig == .showAlphaMask {
                self.accessoryView = self.switchView
            }else{
                let isSelect = MusicConfigManager.shared.playbackModel.backgroundConfig == playBackConfig
                self.accessoryView = isSelect ? selectImgView : self.unselectImgView
            }
        }
    }
    
    // MARK:  懒加载
    lazy var selectImgView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", compatibleWith: .current))
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.tintColor = appMainColor
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var unselectImgView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "circle", compatibleWith: .current))
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.tintColor = UIColor.tertiaryLabel
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var switchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(switchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func switchViewClick(_ sender: UISwitch) {
        var playbackModel = MusicConfigManager.shared.playbackModel
        playbackModel.isShowAlphaMask = sender.isOn
        
        MusicConfigManager.shared.playbackModel = playbackModel
    }
}

