//
//  MusicInfoTagView.swift
//  Mobie
//
//  Created by 张文 on 11/14/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class MusicInfoTagView: UIView {
    
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
        self.addSubview(listView)
    }
    
    func preSetupContains() {
        listView.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(listView.paddingY / 2)
            make.height.equalTo(listView.tag_cornerRadius * 2 + listView.paddingY  + listView.borderWidth * 2)
            make.leading.equalToSuperview()
            make.width.greaterThanOrEqualToSuperview()
        }
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.model = KakaMusicPlayer.shared.playingMusic
    }
    
    // MARK:  GET && SET
    var model: MusicItemModel? {
        didSet {
            guard let model = self.model else { return }
            
            self.listView.removeAllTags()
            
            // 年代
            if let year = model.year, year > 0 {
                self.listView.addTag("\(year)")
            }
            
            // 流派
            if let genre = model.genre, genre.count > 1 {
                let genreType = MusicGenreType.initGenre(genre)
                self.listView.addTag("\(genreType?.formatStr() ?? genre)")
            }
                                
            // 文件大小
            if model.fileSourceType != .demoFile && model.fileSourceType != .fromApple {
                let fileSizeStr = URL.formatFileSize(model.fileSize())
                if !fileSizeStr.isEmpty {
                    self.listView.addTag(fileSizeStr)
                }
            }
            
            self.listView.layoutIfNeeded()
        }
    }
    
    func setBitrateValue(_ bitrate: Int?) {
        guard let bitrate = bitrate, bitrate > 0 else { return }
        
        var bitrateStr: String = ""
        
        if bitrate >= 1_000_000 {
            // 大于等于 1 Mbps
            let bitrateInMbps = Double(bitrate) / 1_000_000.0
            bitrateStr = String(format: "%.1f Mbps", bitrateInMbps)
        } else if bitrate >= 1000 {
            // 大于等于 1 kbps 小于 1 Mbps
            let bitrateInKbps = Double(bitrate) / 1000.0
            
            if bitrateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                // 整数时去掉小数点
                bitrateStr = String(format: "%.0f kbps", bitrateInKbps)
            } else {
                // 非整数时保留小数点后1位
                bitrateStr = String(format: "%.1f kbps", bitrateInKbps)
            }
        } else {
            // 低于 1000 bps
            bitrateStr = String(format: "%.0f bps", Double(bitrate))
        }
        
        // 添加比特率标签
        self.listView.addTag(bitrateStr)
    }

    
    // MARK:  懒加载
    lazy var listView: TagListView = {
        let view = TagListView()
        view.alignment = PhoneSetManager.isArabicCountry() ? .right : .left
        view.textFont = UIFontBold(10.ckValue())
        view.tagBackgroundColor = .clear
        view.textColor = UIColor.lightGray
        view.borderColor = UIColor.lightGray
        view.tag_cornerRadius = 10.ckValue()
        view.borderWidth = 0.5.ckValue()
        view.paddingX = 6.ckValue()
        view.paddingY = 4.ckValue()
        return view
    }()
    
}
