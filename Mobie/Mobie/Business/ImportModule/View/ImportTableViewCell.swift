//
//  ImportTableViewCell.swift
//  Mobie
//
//  Created by 张文 on 12/16/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class ImportTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
        self.accessoryType = .disclosureIndicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateItemType(itemType: ImportFileType) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.image = itemType.iconImage()
        cellConfig.text = itemType.titleStr()
        cellConfig.secondaryText = itemType.freeDiskStr()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        if kaka_IsMacOS() {
            cellConfig.imageToTextPadding = 20
        }
        cellConfig.textProperties.color = itemType.isAvailble() ? .label : .secondaryLabel
        cellConfig.secondaryTextProperties.color = UIColor.systemRed
        cellConfig.imageProperties.maximumSize = CGSize(width: 30.ckValue(), height: 30.ckValue())
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: itemType.freeDiskStr() == nil ? 15 : 5)
        
        self.accessoryView = nil
        self.contentConfiguration = cellConfig
    }
    
}
