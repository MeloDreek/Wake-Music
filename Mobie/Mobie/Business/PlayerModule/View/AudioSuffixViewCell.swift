//
//  AudioSuffixViewCell.swift
//  Mobie
//
//  Created by 张文 on 9/25/24.
//

import KakaFoundation
import AppGroupKit

protocol AudioSuffixViewCellDelegate: AnyObject {
    func audioSuffixSelected(cell: AudioSuffixViewCell, audioType: AudioFormatEnum)
    
    func audioSuffixAutoCrop(cell: AudioSuffixViewCell, isCrop: Bool)
}

class AudioSuffixViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:  GET && SET
        
    weak var delegate: AudioSuffixViewCellDelegate?
        
    func update(cellType: VideoAudioInfoType, audioType: AudioFormatEnum, isCrop: Bool) {
        
        self.audioType = audioType
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.text = cellType.titleStr()

        if cellType == .autoCropAudio {
            self.switchView.isEnabled = isCrop || UserInfoManager.shared.isVIP()
            self.switchView.isOn = isCrop
            self.accessoryView = self.switchView
        }else{
            cellConfig.secondaryText = audioType.suffixName().uppercased()
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
        }
        
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)

        self.contentConfiguration = cellConfig
    }
    
    var audioType = UserInfoManager.shared.isVIP() ? AudioFormatEnum.alac : AudioFormatEnum.mp3
    
    // MARK:  懒加载
    
    lazy var switchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(switchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func switchViewClick(_ sender: UISwitch) {
        self.delegate?.audioSuffixAutoCrop(cell: self, isCrop: sender.isOn)
    }
    
    
}
