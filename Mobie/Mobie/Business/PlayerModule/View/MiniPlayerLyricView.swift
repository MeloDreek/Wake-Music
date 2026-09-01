//
//  MiniPlayerLyricView.swift
//  Mobie
//
//  Created by 张文 on 6/2/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import KakaTaglibKit
import MorphingLabel


/// 迷你歌词区域
class MiniPlayerLyricView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.layoutSubviews()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(tableView)
        self.addSubview(aniLyricLabel)
        self.addSubview(expiredLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        tableView.frame = self.bounds
        
        aniLyricLabel.frame = CGRectMake(5.ckValue(), 0, self.bounds.width - 10.ckValue(), self.bounds.height)

        let expireHeight = expiredLabel.font.lineHeight * 2
        expiredLabel.frame = CGRectMake(self.bounds.width * 0.05, (self.bounds.height - expireHeight) / 2, self.bounds.width * 0.9, expireHeight)
        
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                guard let wSelf = self, let model = model else { return }
                if wSelf.model != model {
                    let textFont = wSelf.calculateMaxFontSize(content: model.showTitleName(), maxWidth: wSelf.bounds.width - 10.ckValue(), maxFont: wSelf.maxFontSize)

                    self?.playingIndex = nil
                    self?.aniLyricLabel.font = textFont
                    self?.aniLyricLabel.text = model.showTitleName()
                }
                self?.model = model
            }.store(in: &cancellables)
        
        // 播放时间
        KakaMusicPlayer.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                if !KakaMusicPlayer.shared.isPlaying { return }
                let timeOffset: Double = Double(KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0)
                self?.updatePlayTime(currentTime * 1000 + timeOffset)
            }.store(in: &cancellables)
        
        // 歌词字体设置
        MusicConfigManager.shared.$lyricConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyricConfig in
                self?.updateLyricConfig()
            }.store(in: &cancellables)
        
//#warning("模拟mock数据")
//#if DEBUG
//        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1) {
//            self.aniLyricLabel.text = "Wakemusic".localStr()
//        }
//#endif
    }
    
    // 无歌词、动画歌词、歌词体验过期
    func updateLyricConfig() {
        
        let lyricConfig = MusicConfigManager.shared.lyricConfig
        self.aniLyricLabel.textColor = UIColor.hexColor(lyricConfig.selFontColor)
        
        guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
            self.tableView.isHidden = false
            self.aniLyricLabel.isHidden = true
            self.expiredLabel.isHidden = true
            self.tableView.reloadData()
            return
        }
        
        let isNoneAnimation = lyricConfig.miniLyricAnimation == .normal
        
        if isShowLyric {
            self.tableView.isHidden = !isNoneAnimation
            self.aniLyricLabel.isHidden = isNoneAnimation
            self.expiredLabel.isHidden = true
            self.tableView.reloadData()
        }else{
            // 歌词体验已过期
            self.expiredLabel.text = KakaMusicPlayer.shared.playingMusic?.showTitleName()
            self.tableView.isHidden = true
            self.aniLyricLabel.isHidden = true
            self.expiredLabel.isHidden = false
            self.tableView.reloadData()
        }
    }
        
    // MARK:  GET && SET
        
    var cancellables = Set<AnyCancellable>()
    
    var isShowLyric: Bool {
        get {
            guard let model = KakaMusicPlayer.shared.playingMusic else { return false }
            
            if model.fileSourceType == .demoFile {
                return true
            }else{
                return model.isHaveLyric()
            }
        }
    }
    
    /// 上一次的播放时间
    var lastTime: TimeInterval?
    
    /// 播放中的索引
    var playingIndex: Int?
    
    var maxFontSize: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 24
            case .iPadOS: return 40
            case .macOS: return 30
            }
        }
    }
    
    /// 音乐模型
    private(set) var model: MusicItemModel? {
        didSet {
            self.updateLyricConfig()
        }
    }
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.bounds, style: .plain)
        view.dataSource = self
        view.delegate = self
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.isScrollEnabled = false
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.overrideUserInterfaceStyle = .dark
        view.contentInsetAdjustmentBehavior = .always
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "EmptyTextTableCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PlayerMiniLyricsCell")
        return view
    }()
    
    lazy var aniLyricLabel: LTMorphingLabel = {
        let view = LTMorphingLabel(frame: CGRectMake(5.ckValue(), 0, self.bounds.width - 10.ckValue(), self.bounds.height))
        view.bounds = self.bounds
        view.morphingEffect = .scale
        view.textAlignment = .center
        view.font = UIFontBold(maxFontSize)
        view.numberOfLines = 0
        view.textColor = UIColor.hexColor(MusicConfigManager.shared.lyricConfig.selFontColor)
        if let playingMusic = KakaMusicPlayer.shared.playingMusic {
            view.text = playingMusic.showTitleName()
        }
        return view
    }()
    
    lazy var expiredLabel: UILabel = {
        let textFont = UIFontBold(maxFontSize)
        
        let view = UILabel(frame: CGRectMake(0, 0, self.bounds.width * 0.9, textFont.lineHeight * 2))
        view.isHidden = true
        view.textAlignment = .center
        view.font = textFont
        view.numberOfLines = 0
        view.textColor = UIColor.hexColor(MusicConfigManager.shared.lyricConfig.selFontColor)
        if let playingMusic = KakaMusicPlayer.shared.playingMusic {
            view.text = playingMusic.showTitleName()
        }
        return view
    }()
    
}

extension MiniPlayerLyricView: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let model = self.model else { return 0 }
        guard let lyrics = model.lyricModel?.lyrics, lyrics.count > 0 else {
            return 1
        }
        
        return lyrics.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
            let emptyCell = tableView.dequeueReusableCell(withIdentifier: "EmptyTextTableCell", for: indexPath)
            emptyCell.selectionStyle = .none
            emptyCell.backgroundColor = .clear
            emptyCell.contentView.backgroundColor = .clear
            var emptyText = (self.model?.showTitleName() ?? "")
            if KakaMusicPlayer.shared.isPlaying {
                emptyText = emptyText + "\r\n" + "No Embedded Lyrics in This Song".localStr()
            }
            
            let textFont = UIFontBold(15.ckValue())
            let textHeight = emptyText.height(forWidth: tableView.width, font: textFont) + 5
            let spaceTop = (tableView.bounds.height - textHeight) / 2 - tableView.contentInset.top - tableView.contentInset.bottom
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = emptyText
            cellConfig.textProperties.numberOfLines = 0
            cellConfig.textProperties.font = textFont
            cellConfig.textProperties.color = .secondaryLabel
            cellConfig.textProperties.alignment = .center
            cellConfig.axesPreservingSuperviewLayoutMargins = .horizontal
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: spaceTop, leading: 25, bottom: spaceTop, trailing: 25)
            emptyCell.contentConfiguration = cellConfig
            
            return emptyCell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerMiniLyricsCell", for: indexPath)
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        let lyricModel = self.model?.lyricModel?.lyrics?[indexPath.row]
        let isPlaying = self.playingIndex == indexPath.row
        let lyricConfig = MusicConfigManager.shared.lyricConfig
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = lyricModel?.fullLyric ?? ""
        cellConfig.textProperties.font = kaka_IsiPad() ? UIFontBold(20.ckValue()) : UIFontLight(16.ckValue())
        cellConfig.textProperties.alignment = lyricConfig.alignment.cellAlignment()
        cellConfig.textProperties.adjustsFontSizeToFitWidth = true
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.textProperties.color = UIColor.hexColor(isPlaying ? lyricConfig.selFontColor : lyricConfig.norFontColor)
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
#if targetEnvironment(macCatalyst)
        cellConfig.textProperties.font = UIFontBold(14.ckValue())
#endif
        cell.contentConfiguration = cellConfig
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}

// MARK:  歌词
extension MiniPlayerLyricView {
    // 更新播放时间
    public func updatePlayTime(_ millisecond: TimeInterval) {
        
        if self.isHidden {
            return
        }
                        
        guard let isNoneTime = self.model?.lyricModel?.isNoneTime, isNoneTime == false else {
            self.playingIndex = nil
            self.tableView.reloadData()
            return
        }
                        
        if let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 {
            if let tempIndex = self.getCurrentLyricIndex(playbackTime: millisecond, lyrics: lyrics) {
                if tempIndex == self.playingIndex {
                    return
                }
                
                self.playingIndex = tempIndex
            }
        }
        
        self.tableView.reloadData()
                
        guard let playingIndex = self.playingIndex else { return }
        
        if let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 {
            
            let fullLyric = lyrics[playingIndex].fullLyric ?? ""
            let textFont = self.calculateMaxFontSize(content: fullLyric, maxWidth: self.bounds.width - 10.ckValue(), maxFont: maxFontSize)
            
            let animation = MusicConfigManager.shared.lyricConfig.miniLyricAnimation.animationType() ?? .anvil
            self.aniLyricLabel.morphingEffect = animation
            self.aniLyricLabel.font = textFont
            self.aniLyricLabel.text = fullLyric
        }
        
        let isNoneAnimation = MusicConfigManager.shared.lyricConfig.miniLyricAnimation == .normal

        if !isNoneAnimation { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            let indexPath = IndexPath(row: playingIndex, section: 0)
            
            if self.tableView.numberOfSections > 0,
               self.tableView.numberOfRows(inSection: 0) > playingIndex {
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            }
        }
        
    }
    
    private func getCurrentLyricIndex(playbackTime: TimeInterval, lyrics: [LyricModel]) -> Int? {
        for (index, lyric) in lyrics.enumerated() {
            if let startTimestamp = lyric.startTimestamp, let endTimestamp = lyric.endTimestamp {
                if playbackTime >= startTimestamp && playbackTime < endTimestamp {
                    return index
                }
            }
        }
        
        return nil
    }
    
    func calculateMaxFontSize(content: String, maxWidth: CGFloat, maxFont: CGFloat) -> UIFont {
        var fontSize: CGFloat = maxFontSize
        
        while true {
            let estimatedWidth = content.width(UIFontBold(fontSize))
            
            if estimatedWidth <= maxWidth {
                break
            }
            
            fontSize -= 1
        }
        
        return UIFontBold(fontSize > maxFont ? maxFont : fontSize)
    }
    
}
