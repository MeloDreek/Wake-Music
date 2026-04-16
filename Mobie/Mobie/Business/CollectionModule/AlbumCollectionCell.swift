//
//  AlbumCollectionCell.swift
//  Wake Music
//
//  Created by 张文 on 9/18/24.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit

class AlbumCollectionCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(coverImgView)
        contentView.addSubview(mengView)
        mengView.addSubview(albumLabel)
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        mengView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(50.ckValue())
        }
        
        albumLabel.snp.makeConstraints { make in
            make.leading.equalTo(15.ckValue())
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
    }
    
    private func preSetupHandleBuness() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 15.ckValue()
        self.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.75)
    }
    
    // MARK:  GET && SET
    
    func update(album: String, musics: [MusicItemModel]) {
        self.albumLabel.text = album
        self.coverImgView.kf.setImage(with: self.getFirstImage(musics), placeholder: UIImage(named: "music_place"))
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
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = UIColor.clear
        return view
    }()
    
    lazy var mengView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "video_bottom_shadow"))
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var albumLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.numberOfLines = 2
        view.font = UIFontBold(15.ckValue())
        view.textAlignment = .center
        return view
    }()
    
}
