//
//  ConnectArtistTableCell.swift
//  Mobie
//
//  Created by 张文 on 3/2/25.
//

import KakaFoundation
import AppGroupKit

class ConnectArtistTableCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
    }
    
    private func setupAutoLayout() {
        coverImgView.snp.makeConstraints { make in
            make.top.equalTo(12.ckValue())
            make.leading.equalTo(18.ckValue())
            make.size.equalTo(50.ckValue())
            make.centerY.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImgView.snp.trailing).offset(10.ckValue())
            make.trailing.equalToSuperview().offset(-5.ckValue())
            make.height.greaterThanOrEqualTo(nameLabel.font.lineHeight)
            make.centerY.equalTo(coverImgView.snp.centerY).offset(-descLabel.font.lineHeight / 2)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.height.greaterThanOrEqualTo(descLabel.font.lineHeight)
            make.top.equalTo(nameLabel.snp.bottom)
        }
    }
    
    private func setupCusBuness() {
        self.accessoryView = self.likeButton
    }
    
    // MARK:  GET && SET
    
    var onArtistBlock: ((NavidromeArtist)->Void)?
    
    var navArtist: NavidromeArtist? {
        didSet {
            guard let navArtist = self.navArtist else { return }
            
            nameLabel.text = navArtist.name
            let secondStr = String(format: "%@ songs".localStr(), "\(navArtist.songCount ?? 0)")
            descLabel.text = secondStr
            likeButton.isSelected = navArtist.starred
            
            coverImgView.kf.setImage(with: navArtist.artistAvatarURL(), placeholder: UIImage(named: "music_place"))
        }
    }
    
    @objc func likeButtonClick(_ sender: UIButton) {
        guard let navArtist = self.navArtist else { return }
        self.onArtistBlock?(navArtist)
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.numberOfLines = 1
        view.font = UIFontBold(15.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.font = UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var likeButton: UIButton = {
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.setImage(Reasource.systemNamed("heart"), for: .normal)
        view.setImage(Reasource.systemNamed("heart.fill", color: UIColor.red), for: .selected)
        view.addTarget(self, action: #selector(likeButtonClick(_:)), for: .touchUpInside)
        return view
    }()
}

