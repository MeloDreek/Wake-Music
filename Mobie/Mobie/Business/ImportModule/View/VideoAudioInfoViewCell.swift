//
//  VideoAudioInfoViewCell.swift
//  Wake Music
//
//  Created by Melo on 9/10/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

enum VideoAudioInfoType: Int {
    case selectVideo = 0
    case selectSuffix = 1
    case autoCropAudio = 2
    
    case pcmUI = 3

    case musicName = 4
    case singerName = 5
    case albumName = 6
    case coverImage = 7
    case fileSize = 8
    
    func titleStr() -> String? {
        switch self {
        case .selectVideo:
            return "Select Video".localStr()
        case .selectSuffix:
            return "Audio Quality".localStr()
        case .autoCropAudio:
            return "Crop the last 3 seconds".localStr()
            
        case .pcmUI:
            return nil
            
        case .musicName:
            return MusicActionType.title.formatStr()
        case .singerName:
            return MusicActionType.artist.formatStr()
        case .albumName:
            return MusicActionType.album.formatStr()
        case .coverImage:
            return MusicActionType.coverArt.formatStr()
        case .fileSize:
            return SortedbyType.fileSize.formatStr()
        }
    }
    
}

class VideoAudioInfoViewCell: UITableViewCell {
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
        
    }
    
    private func preSetupContains() {
        
    }
    
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .default
        self.accessoryType = .disclosureIndicator
    }
    
    // MARK:  GET && SET
    func update(type: VideoAudioInfoType, model: MusicItemModel?, coverImage: UIImage?) {
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = type.titleStr()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        
        if type == .musicName {
            cellConfig.secondaryText = model?.showTitleName()
            self.accessoryType = .disclosureIndicator
            self.accessoryView = nil
        }else if type == .fileSize {
            cellConfig.secondaryText = model?.mediaPlayURL.fileSizeString
            self.accessoryType = .none
            self.accessoryView = nil
        }else if type == .albumName {
            cellConfig.secondaryText = model?.album ?? "Unknown Album".localStr()
            self.accessoryType = .disclosureIndicator
            self.accessoryView = nil
        }else if type == .coverImage {
            cellConfig.secondaryText = nil
            self.accessoryType = .none
            self.coverImgView.image = coverImage
            self.accessoryView = self.coverImgView
        }else if type == .singerName {
            cellConfig.secondaryText = model?.showArtistName() ?? "Unknown Artist".localStr()
            self.accessoryType = .disclosureIndicator
            self.accessoryView = nil
        }
        
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        
        self.contentConfiguration = cellConfig
    }
        
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(frame: CGRectMake(0, 0, 55.ckValue(), 55.ckValue()))
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 6.ckValue()
        view.clipsToBounds = true
        return view
    }()
    
}
