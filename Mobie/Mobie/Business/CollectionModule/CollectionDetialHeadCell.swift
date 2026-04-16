//
//  CollectionDetialHeadCell.swift
//  Mobie
//
//  Created by 张文 on 12/28/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

/// 合集头部区域
class CollectionDetialHeadCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(sizeLabel)
    }
    
    func preSetupContains() {
        
        coverImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.size.equalTo(250.ckValue())
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.centerX.equalToSuperview()
            make.top.equalTo(coverImgView.snp.bottom).offset(20.ckValue())
            make.height.greaterThanOrEqualTo(nameLabel.font.lineHeight)
        }
        
        sizeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(nameLabel.snp.bottom).offset(5.ckValue())
            make.bottom.equalToSuperview()
        }
        
    }
    
    func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    // 艺术家
    func setArtist(artist: String, musics: [MusicItemModel]) {
        nameLabel.text = artist
        coverImgView.kf.setImage(with: self.getFirstImage(musics), placeholder: UIImage(named: "music_place"))
        
        let totalTime = Int(musics.map { $0.durationSeconds }.reduce(0, +))
        let totalSizeStr = URL.formatFileSize(musics.map { $0.mediaPlayURL.fileSize }.reduce(0, +))
        
        let hours = totalTime / 3600
        let minutes = (totalTime % 3600) / 60
        let seconds = totalTime % 60

        let formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        
        self.sizeLabel.text = totalSizeStr + " - " + formattedTime
    }
    
    // 专辑
    func setAlbum(album: String?, musics: [MusicItemModel]) {
        nameLabel.text = album
        coverImgView.kf.setImage(with: self.getFirstImage(musics), placeholder: UIImage(named: "music_place"))
    }
    
    // 流派
    func setGenre(genre: MusicGenreType?, musics: [MusicItemModel]) {
        nameLabel.text = genre?.formatStr()
        coverImgView.image = genre?.iconImage() ?? UIImage(named: "music_place")
        
        let totalTime = Int(musics.map { $0.durationSeconds }.reduce(0, +))
        let totalSizeStr = URL.formatFileSize(musics.map { $0.mediaPlayURL.fileSize }.reduce(0, +))
        
        let hours = totalTime / 3600
        let minutes = (totalTime % 3600) / 60
        let seconds = totalTime % 60

        let formattedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        
        self.sizeLabel.text = totalSizeStr + " - " + formattedTime
    }
    
    func getFirstImage(_ musics: [MusicItemModel]) -> URL? {
        for subModel in musics {
            if FileManager.default.fileExists(atPath: subModel.coverThumbnailURL().path) {
                return subModel.coverThumbnailURL()
            }
        }
        
        return nil
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = appMainColor
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontBold(24.ckValue())
        view.textColor = .label
        view.numberOfLines = 2
        view.textAlignment = .center
        return view
    }()
    
    lazy var sizeLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(16.ckValue())
        view.textColor = .secondaryLabel
        view.numberOfLines = 2
        view.textAlignment = nameLabel.textAlignment
        return view
    }()
}
