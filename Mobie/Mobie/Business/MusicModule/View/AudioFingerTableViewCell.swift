//
//  AudioFingerTableViewCell.swift
//  Mobie
//
//  Created by kaka on 2026/8/19.
//

import KakaFoundation
import AppGroupKit

class AudioFingerTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
//        self.backgroundColor = UIColor.black
        self.backgroundColor = appMainColor
        self.selectionStyle = .default
        self.accessoryType = .disclosureIndicator
        self.accessoryView = nil
        self.overrideUserInterfaceStyle = .dark
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var title: String? {
        didSet {
            guard let title = self.title else { return }
            var cellConfig = UIListContentConfiguration.cell()

            cellConfig.image = Reasource.systemNamed("touchid", color: .white)
            cellConfig.imageProperties.maximumSize = CGSizeMake(35.ckValue(), 35.ckValue())
            cellConfig.text = title
            cellConfig.textProperties.alignment = .center
            cellConfig.textProperties.color = .white
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: self.accessoryType == .disclosureIndicator ? 5 : 15)
            self.contentConfiguration = cellConfig
        }
    }
    
    
}
