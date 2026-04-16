//
//  GenreCollectionCell.swift
//  Mobie
//
//  Created by 张文 on 12/27/24.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit

class GenreCollectionCell: UICollectionViewCell {
    
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
        
        contentView.addSubview(coverView)
        coverView.addSubview(selectBtn)
        
        contentView.addSubview(bottomMaskView)
        bottomMaskView.addSubview(genreLabel)
        
    }
    
    private func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        bottomMaskView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(50.ckValue())
        }
        
        genreLabel.snp.makeConstraints { make in
            make.leading.equalTo(15.ckValue())
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        coverView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        selectBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(15.ckValue())
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.equalTo(selectBtn.size)
        }
        
    }
    
    private func preSetupHandleBuness() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 15.ckValue()
        self.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.75)
    }
    
    // MARK:  GET && SET
    
    func update(genre: MusicGenreType) {
        self.genreLabel.text = genre.formatStr()
        self.coverImgView.image = genre.iconImage() ?? UIImage(named: "music_place")
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.backgroundColor = UIColor.clear
        return view
    }()
    
    lazy var bottomMaskView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "video_bottom_shadow"))
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var genreLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.numberOfLines = 2
        view.font = UIFontBold(15.ckValue())
        view.textAlignment = .center
        return view
    }()
    
    lazy var coverView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        return view
    }()
    
    lazy var selectBtn: UIButton = {
        let norImage = Reasource.systemNamed("checkmark.circle", color: UIColor.white)
        let selImage = Reasource.systemNamed("checkmark.circle.fill", color: UIColor.green)
        
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(25.ckValue(), 25.ckValue())
        view.setImage(norImage, for: .normal)
        view.setImage(selImage, for: .selected)
        return view
    }()
}


