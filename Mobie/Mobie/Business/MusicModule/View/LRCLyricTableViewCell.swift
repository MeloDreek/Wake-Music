//
//  LRCLyricTableViewCell.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class LRCLyricTableViewCell: UITableViewCell {
    
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
        contentView.addSubview(listView)
        contentView.addSubview(lyricLabel)
    }
    
    private func setupAutoLayout() {
        
        listView.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.top.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        lyricLabel.snp.makeConstraints { make in
            make.leading.equalTo(listView)
            make.top.equalTo(listView.snp.bottom).offset(10.ckValue())
            make.centerX.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview().inset(15.ckValue())
        }
        
    }
    
    private func setupCusBuness() {
        
    }
    
    func updateLyric(lyricModel: LyricInfoModel, isSelect: Bool) {
                
        listView.removeAllTags()
        
        if let title = lyricModel.title {
            let tagView = self.createTagView(title)
            tagView.tagBackgroundColor = .systemBlue
            listView.addTagView(tagView)
        }
        
        if let artist = lyricModel.artist {
            let tagView = self.createTagView(artist)
            tagView.tagBackgroundColor = .systemRed
            listView.addTagView(tagView)
        }
        
        if let album = lyricModel.album {
            let tagView = self.createTagView(album)
            tagView.tagBackgroundColor = .purple
            listView.addTagView(tagView)
        }
        
        if let totalTime = lyricModel.totalTime, totalTime > 0 {
            let minutes = Int(totalTime) / 60
            let seconds = Int(totalTime) % 60
            let totalTimeStr = String(format: "%02d:%02d", minutes, seconds)
            
            let tagView = self.createTagView(totalTimeStr)
            tagView.tagBackgroundColor = .systemOrange
            listView.addTagView(tagView)
        }
        
        if let creater = lyricModel.creater {
            let tagView = self.createTagView(creater)
            tagView.tagBackgroundColor = .systemPink
            listView.addTagView(tagView)
        }
        
        let offset = lyricModel.offset
        let tagView = self.createTagView("offset:\(offset)")
        tagView.tagBackgroundColor = .systemBrown
        listView.addTagView(tagView)
        
        if listView.tagViews.count == 0 {
            let tagView = self.createTagView("···")
            tagView.tagBackgroundColor = .systemBlue
            listView.addTagView(tagView)
        }
        
        lyricLabel.numberOfLines = isSelect ? 0 : 6
        lyricLabel.text = lyricModel.noneTagLyricString()
        
        self.accessoryType = isSelect ? .none : .disclosureIndicator
        self.accessoryView = isSelect ? self.selectIconView : .none
        
        self.layoutIfNeeded()
    }
    
    func createTagView(_ titleStr: String) -> TagView {
        let view = TagView(title: titleStr)
        view.textColor = .white
        view.textFont = UIFontBold(10.ckValue())
        view.tag_cornerRadius = 9.ckValue()
        view.paddingX = 6.ckValue()
        view.paddingY = 4.ckValue()
        return view
    }
    
    lazy var listView: TagListView = {
        let view = TagListView()
        return view
    }()
    
    lazy var lyricLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicCountry() ? .right : .left
        view.textColor = .label
        view.font = UIListContentConfiguration.cell().secondaryTextProperties.font
        return view
    }()
    
    lazy var selectIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle.fill", color: .systemGreen))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        return view
    }()
    
}

