//
//  PlayerStyleDefaultCell.swift
//  Mobie
//
//  Created by 张文 on 5/23/25.
//

import KakaFoundation
import AppGroupKit

class PlayerStyleDefaultTableCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var itemType: PlayerUIStyle? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            cellConfig.textProperties.color = .label
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
            self.contentConfiguration = cellConfig
            
            let isSelect = MusicConfigManager.shared.playerStyle == itemType
            self.accessoryView = isSelect ? self.selectImgView : self.unselectImgView
        }
    }
    
    
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
        
}

