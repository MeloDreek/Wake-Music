//
//  ConnectListTableCell.swift
//  Mobie
//
//  Created by 张文 on 2/26/25.
//

import KakaFoundation
import AppGroupKit


class ConnectListTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
            
    var serverModel: ServerConfigModel? {
        didSet {
            guard let serverModel = self.serverModel else { return  }
                        
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = serverModel.showTitle()
            if serverModel.serverType == .fromNavidrome {
                // Do not replace the user's server name with the shared protocol label.
                cellConfig.secondaryText = [serverModel.serverType.titleStr(), serverModel.descString()]
                    .compactMap { $0 }.joined(separator: " · ")
            } else {
                cellConfig.secondaryText = serverModel.descString()
            }
            cellConfig.secondaryTextProperties.numberOfLines = 0
            cellConfig.image = serverModel.serverType.iconImage()
            cellConfig.imageProperties.maximumSize = CGSize(width: 30.ckValue(), height: 30.ckValue())
            cellConfig.imageProperties.cornerRadius = 4.ckValue()
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            self.contentConfiguration = cellConfig
            
        }
    }
    
}
