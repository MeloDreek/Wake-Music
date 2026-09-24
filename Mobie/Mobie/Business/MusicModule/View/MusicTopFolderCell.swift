//
//  MusicTopFolderCell.swift
//  Mobie
//
//  Created by 张文 on 12/26/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import WaketagLibKit

class MusicTopFolderCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(backView)
        contentView.addSubview(coverImgView)
        contentView.addSubview(middleView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(countLabel)
    }
    
    func preSetupContains() {
        
        backView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(kaka_IsMacOS() ? 5 : 3.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(backView.layer.cornerRadius * 2)
        }
        
        coverImgView.snp.makeConstraints { make in
            make.centerX.equalTo(backView)
            make.centerY.equalTo(backView)
            make.size.equalTo(coverImgView.layer.cornerRadius * 2)
        }
        
        middleView.snp.makeConstraints { make in
            make.top.equalTo(backView.snp.bottom).offset(backView.layer.cornerRadius - coverImgView.layer.cornerRadius)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(3.ckValue())
            make.centerY.equalTo(middleView)
            make.height.greaterThanOrEqualTo(0)
        }
        
        countLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(coverImgView.snp.bottom)
            make.width.equalTo(MusicTopFolderHeadView.cellSize().height * (kaka_IsMacOS() ? 0.45 : 0.6))
            make.height.equalTo(countLabel.font.lineHeight * 1.5)
        }
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(appModeSwitchChanged), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    @objc func appModeSwitchChanged() {
        backView.backgroundColor = appMainColor
        countLabel.backgroundColor = appMainColor
        nameLabel.textColor = appMainColor
    }
    
    // MARK:  GET && SET
    
    var localFolderURL: URL? {
        didSet {
            guard let localFolderURL = localFolderURL else { return }
            let allFiles = SandboxFileManager.shared.getAllSubFiles(localFolderURL)
            let isBase = localFolderURL == SandboxFileManager.shared.basePublicFileURL()
            nameLabel.text = isBase ? "All Music".localStr() : localFolderURL.lastPathComponent
            coverImgView.image = isBase ? UIImage(named: "app_logo") : self.getFirstImage(allFiles)
            
            countLabel.isHidden = false
            countLabel.text = "\(allFiles.count)"
        }
    }
    
    
    func getFirstImage(_ allFiles: [URL]) -> UIImage? {
        for file in allFiles {
            if let image = TaglibMetadataParser.extractCoverArt(from: file) {
                return image
            }
        }
        
        return UIImage(named: "music_place")
    }
    
    
    // MARK:  懒加载
    lazy var backView: UIView = {
        let imgWidth = MusicTopFolderHeadView.cellSize().width * 0.75
        let cellSize = kaka_IsMacOS() ? 106.ckValue() : imgWidth + 6.ckValue()

        let view = UIView(frame: CGRectMake(0, 0, cellSize, cellSize))
        view.backgroundColor = appMainColor
        view.layer.masksToBounds = true
        view.layer.cornerRadius = cellSize / 2
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let imgWidth = MusicTopFolderHeadView.cellSize().width * 0.75
        let cellSize = kaka_IsMacOS() ? 100.ckValue() : imgWidth

        let image = UIImage(contentsOfFile: Reasource.fullFilePath("singer_8@3x.png"))
        let view = UIImageView(image: image)
        view.frame = CGRectMake(0, 0, cellSize, cellSize)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = cellSize / 2
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var middleView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.textAlignment = .center
        view.font = UIFontLight(13.ckValue())
        view.textColor = .label
        return view
    }()
    
    lazy var countLabel: UILabel = {
        let view = UILabel()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = kaka_IsMacOS() ? 3 : 6.5.ckValue()
        view.backgroundColor = appMainColor
        view.font = kaka_IsMacOS() ? UIListContentConfiguration.cell().textProperties.font : UIFontBold(13.ckValue())
        view.textColor = UIColor.deAccent
        view.textAlignment = .center
        return view
    }()
    
}
