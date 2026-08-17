//
//  LyricOtherConfigTableCell.swift
//  Mobie
//
//  Created by 张文 on 6/10/25.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

class LyricOtherConfigTableCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var itemType: LyricSetCellGroup? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            cellConfig.textProperties.color = .label
            cellConfig.secondaryTextProperties.color = .secondaryLabel
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            
            self.accessoryType = .none
            self.accessoryView = itemType == .timeOffsetGroup ? self.timeOffsetView() : self.switchView
            self.contentConfiguration = cellConfig
        }
    }
    
    // 时间偏移量
    func timeOffsetView() -> UIView {
        let curOffset = KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0

        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.timeOffsetMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = "\(curOffset)ms"
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    func timeOffsetMenu() -> UIMenu {
        
        let normalArray: [Int] = [-1000, -800, -600, -400, -200, 0, 200, 400, 600, 800, 1000]
        var actionArray1 = [UIAction]()
        let curOffset = KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0

        for subTime in normalArray {
            let title = "\(subTime)"
            let action = UIAction(title: title, image: nil, state: curOffset == subTime ? .on : .off, handler: { [weak self] _ in
                self?.setupLyricTimeOffset(subTime)
            })

            actionArray1.append(action)
        }
        let normalMenu = UIMenu(title: "Milliseconds".localStr(), options: .displayInline, children: actionArray1)
        return normalMenu
    }
    
    func setupLyricTimeOffset(_ timeOffset: Int) {
        guard var playingModel = KakaMusicPlayer.shared.playingMusic, var lyricModel = playingModel.lyricModel, let lyrics = lyricModel.lyrics, !lyrics.isEmpty else {
            self.kaka_playShakeAnim()
            appKeyWindow?.makeToast("No Embedded Lyrics in This Song".localStr())
            return
        }
        lyricModel.offset = timeOffset
        
        let content = lyricModel.toLyricString()
        let success = TaglibMetadataParser.setLyris(content, toFileURL: playingModel.mediaPlayURL)
        if success {
            appKeyWindow?.makeToast("Embedded Success".localStr())
            
            playingModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content).convertSwiftModel()
            KakaMusicPlayer.shared.playingMusic = playingModel
        }else{
            playingModel.lyricModel = lyricModel
            KakaMusicPlayer.shared.playingMusic = playingModel
        }
        
        debugPrint("写入歌词 = \(success)")
        self.accessoryView = self.itemType == .timeOffsetGroup ? self.timeOffsetView() : self.switchView
    }
    
    lazy var switchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.isOn = MusicConfigManager.shared.lyricConfig.isLowPowerMode
        view.addTarget(self, action: #selector(switchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func switchViewClick(_ sender: UISwitch) {
        var lyricConfig = MusicConfigManager.shared.lyricConfig
        lyricConfig.isLowPowerMode = sender.isOn
        
        MusicConfigManager.shared.lyricConfig = lyricConfig
    }
    
    
}

