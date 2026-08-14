//
//  PlayerLyricCollectCell.swift
//  Mobie
//
//  Created by 张文 on 5/26/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import MediaPlayer
import NVActivityIndicatorView
import Combine

/// 播放器-歌词
class PlayerLyricCollectCell: UICollectionViewCell {
    
    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.layoutSubviews()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        self.addSubview(tableView)
        self.addSubview(noneView)
        self.addSubview(loadingView)
        self.addSubview(rotateButton)
        self.addSubview(lyricSetButton)
        
        self.addSubview(lineView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let isRTL = UIView.userInterfaceLayoutDirection(for: self.semanticContentAttribute) == .rightToLeft

        let isLandscape = OrientationManager.shared.isLandscape
        let btnSize = 44.ckValue()
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        var lyricSetLeft = contentView.bounds.width - btnSize - 20.ckValue()
        if isRTL {
            lyricSetLeft = 15.ckValue()
        }
        lyricSetButton.frame = CGRectMake(lyricSetLeft, isPhoneLandscape ? 26 : kStatusBarHeight + 10.ckValue(), btnSize, btnSize)
        rotateButton.frame = CGRectMake(20, lyricSetButton.top, btnSize, btnSize)
        
        let tableTop = isPhoneLandscape ? 21 : CGRectGetMaxY(lyricSetButton.frame) + 10.ckValue()
        let bottomHeight = (isLandscape || !isShowControl) ? -kaka_safeAreaInsets().bottom / 2 : OrientationManager.shared.playerControlHeight
        tableView.frame = CGRectMake(0, tableTop, contentView.bounds.width, contentView.bounds.height - tableTop - bottomHeight)
        
        noneView.frame = CGRectMake(0, rotateButton.frame.maxY, contentView.bounds.width, contentView.height - rotateButton.frame.maxY - OrientationManager.shared.playerControlHeight)
        
        loadingView.frame = CGRectMake((contentView.width - loadingView.width) / 2, (contentView.height - loadingView.height) / 2, loadingView.width, loadingView.height)
        
        lineView.frame = CGRectMake(0, (contentView.height - 30.ckValue()) / 2 - 40.ckValue(), contentView.width, 30.ckValue())
        
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.overrideUserInterfaceStyle = .dark
        
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(dismissAction))
        self.noneView.addGestureRecognizer(clickTap)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged(model)
            }.store(in: &cancellables)
        
        // 播放时间
        KakaMusicPlayer.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentTime in
                let timeOffset: Double = Double(KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0)
                self?.updatePlayTime(currentTime * 1000 + timeOffset)
            }.store(in: &cancellables)
        
        // 歌词字体设置
        MusicConfigManager.shared.$lyricConfig
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lyricConfig in
                self?.tableView.reloadData()
            }.store(in: &cancellables)
        
        // 设备朝向变化了
        OrientationManager.shared.$isLandscape
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLandscape in
                self?.rotateButton.isHidden = isLandscape || kaka_IsMacOS()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.layoutSubviews()
                    self?.tableView.reloadData()
                }
            }.store(in: &cancellables)
    }
    
    func playingMusicChanged(_ model: MusicItemModel?) {
        guard let model = model else { return }
        
        if self.model != model { // 切歌了
            self.playingIndex = nil
            self.lastTime = nil
            self.middleIndexPath = nil
            self.isTracking = false
            self.tableView.reloadData()
            self.tableView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        self.model = model
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    var isShowControl: Bool = true {
        didSet {
            self.layoutSubviews()
            self.tableView.reloadData()
        }
    }
    
    
    var isShowLyric: Bool {
        get {
            guard let model = self.model else { return false }
            
            if model.fileSourceType == .demoFile {
                return true
            }else{
                return model.isHaveLyric()
            }
        }
    }
    
    // 更新播放时间
    public func updatePlayTime(_ millisecond: TimeInterval) {
                
//        debugPrint("播放时间 = \(millisecond)")
        
        guard let isNoneTime = self.model?.lyricModel?.isNoneTime, isNoneTime == false else {
            self.playingIndex = nil
            self.middleIndexPath = nil
            self.tableView.reloadData()
            return
        }
        
        if !self.isShowLyric { return }
        
        self.lastTime = millisecond
        
        if let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 {
            if let tempIndex = self.getCurrentLyricIndex(playbackTime: millisecond, lyrics: lyrics) {
                if tempIndex == self.playingIndex {
                    return
                }
                
                self.playingIndex = tempIndex
            }
        }
        
        self.tableView.reloadData()
        
        if self.isTracking { return }
        
        guard let playingIndex = self.playingIndex else { return }
        
        if playingIndex >= (self.model?.lyricModel?.lyrics?.count ?? 0) - 2 {
            return
        }
        
//        if playingIndex == 0 || playingIndex == 1 { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            let indexPath = IndexPath(row: playingIndex, section: 0)
            
            if self.tableView.numberOfSections > 0,
               self.tableView.numberOfRows(inSection: 0) > playingIndex {
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                self.setFirstShowLyricDate()
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
    
    /// 是否在拖拽
    var isTracking: Bool = false
    
    /// 上一次的播放时间
    var lastTime: TimeInterval?
    
    /// 播放中的索引
    var playingIndex: Int?
    
    /// 获取最中间的那行
    var middleIndexPath: IndexPath?
    
#if !targetEnvironment(macCatalyst)
    var lastContentOffset: CGPoint = .zero
    
    var lastScrollDirection: ScrollDirection? = nil

    enum ScrollDirection {
        case up
        case down
    }
#endif
    
    var model: MusicItemModel? {
        didSet {
            guard let model = self.model else { return }
                                    
            self.noneView.updateContent(model)
            
            guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
                self.noneView.isHidden = true
                self.tableView.isHidden = true
                self.loadingView.startAnimating()
                
                let meteData = TaglibMetadataParser.readMetadata(withFileURL: model.mediaPlayURL, read: .all)
                let newLyric = meteData?.lyricModel?.convertSwiftModel()
                self.model?.lyricModel = newLyric
                
                if let newModel = self.model, let lyrics = newLyric?.lyrics, lyrics.count > 0 {
                    KakaMusicPlayer.shared.updateOneMusicModel(newModel: newModel, oldFileName: newModel.filePathName())
                    
                    self.tableView.isHidden = !self.isShowLyric
                    self.noneView.isHidden = self.isShowLyric
                }else{
                    self.tableView.isHidden = true
                    self.noneView.isHidden = false
                    self.noneView.updateContent(model)
                }
                
                self.loadingView.stopAnimating()
                self.tableView.reloadData()
                return
            }
                        
            if self.playingIndex == nil {
                self.tableView.contentOffset = .zero
            }
            self.tableView.isHidden = !self.isShowLyric
            self.noneView.isHidden = self.isShowLyric
            self.tableView.reloadData()
            
        }
    }
    
    // 设置首次查看歌词的时间
    func setFirstShowLyricDate() {
        guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
            return
        }
        
        if UserInfoManager.shared.firstFileDate == nil {
            UserInfoManager.shared.firstFileDate = Date().timeIntervalSince1970
        }
    }
    
    
    // 点击查看歌词设置
    @objc func lyricSetButtonClick(_ sender: UIButton) {
        self.delegate?.controlViewDidLyricSetBtn(controlView: self, lyricSetBtn: sender)
    }
    
    // 点击进入横屏
    @objc func changeDeviceOrientation() {
        self.delegate?.playerViewDidClickLyricBtn(playerView: self)
    }
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .grouped)
        view.isHidden = !self.isShowLyric
        view.dataSource = self
        view.delegate = self
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.alwaysBounceHorizontal = false
        view.alwaysBounceVertical = true
        view.overrideUserInterfaceStyle = .dark
        view.contentInsetAdjustmentBehavior = .always
        view.rowHeight = UITableView.automaticDimension
        view.register(PlayerLyricsCell.self, forCellReuseIdentifier: "PlayerLyricsCell")
        return view
    }()
    
    lazy var noneView: NoneLyriclistView = {
        let view = NoneLyriclistView(frame: self.tableView.bounds, isShowIcon: true)
        view.backgroundColor = .clear
        view.isHidden = self.isShowLyric
        view.onClickCallBack = { [weak self] () in
            guard let wSelf = self, let model = wSelf.model else { return }
            if model.isHaveLyric() {
                if !UserInfoManager.shared.isVIP() {
                    wSelf.upgradePremiumTag()
                }
            }else{
                wSelf.delegate?.playerBasicCellDidSelectLyric(basicView: wSelf)
            }
        }
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 20.ckValue(), 20.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .pacman, color: .white)
        return view
    }()
    
    lazy var lineView: DragTimeLineView = {
        let view = DragTimeLineView(frame: CGRectMake(0, (contentView.height - 30.ckValue()) / 2 - 40.ckValue(), contentView.width, 30.ckValue()))
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    // 进入横屏，只有iPhone+竖屏时出现
    lazy var rotateButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isHidden = true
        view.setImage(Reasource.systemNamed("rectangle.portrait.rotate", color: .white), for: .normal)
        view.addTarget(self, action: #selector(changeDeviceOrientation), for: .touchUpInside)
        return view
    }()
    
    lazy var lyricSetButton: UIButton = {
        let image: UIImage = Reasource.systemNamed("slider.vertical.3", color: .white)
        let view = UIButton(type: .custom)
        view.addTarget(self, action: #selector(lyricSetButtonClick(_:)), for: .touchUpInside)
        view.setImage(image, for: .normal)
        return view
    }()
    
}


extension PlayerLyricCollectCell: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let lyrics = self.model?.lyricModel?.lyrics, lyrics.count > 0 else {
            return 0
        }
        
        return lyrics.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerLyricsCell", for: indexPath) as! PlayerLyricsCell
        let lyricModel = self.model?.lyricModel?.lyrics?[indexPath.row]
        let isPlaying = self.playingIndex == indexPath.row
        let isDragPlay = (self.middleIndexPath == indexPath)

        cell.update(model: lyricModel, isPlaying: isPlaying, isDragPlay: isDragPlay)
        
        return cell
    }
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let musicModel = self.model else { return }
        guard let lyricModel = musicModel.lyricModel?.lyrics?[indexPath.row], var playTime = lyricModel.startTimestamp else {
            self.dismissAction()
            return
        }
        
        let isDragPlay = (self.middleIndexPath == indexPath)
        
        if isDragPlay {

            playTime = playTime / 1000.0
            
            if KakaMusicPlayer.shared.isPlaying {
                KakaMusicPlayer.shared.seek(time: playTime)
            }else{
                KakaMusicPlayer.shared.play()
            }
            
            self.middleIndexPath = nil
            self.tableView.reloadData()
            
        }else{
            self.dismissAction()
        }
    }
    
    @objc func dismissAction() {
        self.middleIndexPath = nil
        self.tableView.reloadData()
        
        self.delegate?.controlViewDidBottomControl(controlView: self)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let testText = "120'\r55.999"
        let timeFont = UIFontBold(8.ckValue())
        
        let timeFontWidth = testText.width(timeFont) + 3.ckValue()
        let allSpace = PlayerLyricsCell.timeLabelLeading + timeFontWidth + 5.ckValue() + PlayerLyricsCell.playIconViewSize + 5.ckValue() + PlayerLyricsCell.playIconViewTraing
        
        let isPlaying = self.playingIndex == indexPath.row

        let lyricConfig = MusicConfigManager.shared.lyricConfig
        let lyricFont = isPlaying ? UIFontBold(CGFloat(lyricConfig.selFontSize)) : UIFontLight(CGFloat(lyricConfig.norFontSize))
        
        guard let lyricModel = self.model?.lyricModel?.lyrics?[indexPath.row], let fullLyric = lyricModel.fullLyric, fullLyric.count > 0 else {
            return UITableView.automaticDimension
        }
        
        let textHeight = fullLyric.height(forWidth: tableView.bounds.width - allSpace, font: lyricFont)
        
        return textHeight + CGFloat(lyricConfig.lineSpace) * 2 + lyricFont.lineHeight
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
//#if targetEnvironment(macCatalyst)
//        return 10.ckValue()
//#else
        let minHeight = (160 + 17 + 15 + 25 + 25 + 26 + 20).ckValue()
        let halfHeight = contentView.bounds.height * 0.5
        return halfHeight > minHeight ? halfHeight : minHeight
//#endif
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
//#if targetEnvironment(macCatalyst)
//        let headView = UIView(frame: CGRectMake(0, 0, contentView.width, 10))
//        
//        return headView
//#else
        let minHeight = (160 + 20 + 15 + 25 + 25 + 30 + 30).ckValue()
        let halfHeight = contentView.bounds.height * 0.5
        let headHeight = halfHeight > minHeight ? halfHeight : minHeight
        
        let headView = UIView(frame: CGRectMake(0, 0, contentView.width, headHeight))
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(dismissAction))
        headView.addGestureRecognizer(clickTap)
        
        // 160 + 20 + 15 + 25 + 25 + 25 + 30
        
        let coverImgView = UIImageView()
        coverImgView.kf.setImage(with: self.model?.coverThumbnailURL(), placeholder: self.model?.placeImage())
        coverImgView.contentMode = .scaleAspectFill
        coverImgView.clipsToBounds = true
        coverImgView.isUserInteractionEnabled = false
        coverImgView.layer.cornerRadius = 80.ckValue()
        headView.addSubview(coverImgView)
        coverImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.equalTo(160.ckValue())
            make.centerY.equalToSuperview().offset(-50.ckValue())
        }
        let titleLabel = UILabel()
        titleLabel.text = self.model?.showTitleName()
        titleLabel.textColor = .label
        titleLabel.isUserInteractionEnabled = false
        titleLabel.textAlignment = .center
        titleLabel.font = UIFontBold(kaka_IsiPhone() ? 17 : 22)
        headView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(coverImgView.snp.bottom).offset(15.ckValue())
            make.leading.equalTo(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        let artistLabel = UILabel()
        artistLabel.text = self.model?.showArtistName()
        artistLabel.textColor = .secondaryLabel
        artistLabel.isUserInteractionEnabled = false
        artistLabel.textAlignment = .center
        artistLabel.font = UIFontBold(kaka_IsiPhone() ? 15 : 20)
        headView.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(5.ckValue())
            make.leading.equalTo(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        let albumLabel = UILabel()
        albumLabel.text = self.model?.album
        if let year = self.model?.year, year > 1, let album = self.model?.album {
            albumLabel.text = album + " - " + "\(year)"
        }
        albumLabel.numberOfLines = 0
        albumLabel.textColor = .secondaryLabel
        albumLabel.textAlignment = .center
        albumLabel.font = artistLabel.font
        if !UserInfoManager.shared.isVIP() && (self.model?.fileSourceType != .demoFile) {
            albumLabel.text = nil
            let font = UIFontLight(kaka_IsiPhone() ? 15 : 20)
            let attbuteStr = NSAttributedString(string: "You are enjoying a free three-day lyrics experience!".localStr() + "\r" + "Upgrade to Premium".localStr(), attributes: [.font: font, .foregroundColor: UIColor.accent, .underlineStyle: 1])
            albumLabel.attributedText = attbuteStr
            albumLabel.isUserInteractionEnabled = true
            let clickTap = UITapGestureRecognizer(target: self, action: #selector(upgradePremiumTag))
            albumLabel.addGestureRecognizer(clickTap)
        }else{
            albumLabel.attributedText = nil
        }
        headView.addSubview(albumLabel)
        albumLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(artistLabel.snp.bottom).offset(5.ckValue())
            make.leading.equalTo(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        let isNoneTime = self.model?.lyricModel?.isNoneTime ?? true
        let tipsLabel = UILabel()
        tipsLabel.isHidden = !isNoneTime
        tipsLabel.numberOfLines = 0
        tipsLabel.text = "The lyrics tag for this song has no time line".localStr()
        tipsLabel.textColor = UIColor.yellow
        tipsLabel.textAlignment = .center
        tipsLabel.font = UIFontLight(kaka_IsiPhone() ? 13 : 15)
        headView.addSubview(tipsLabel)
        tipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(albumLabel.snp.bottom).offset(15.ckValue())
            make.leading.equalTo(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        
        return headView
//#endif
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return contentView.bounds.height * 0.4
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footView = UIView(frame: CGRectMake(0, 0, contentView.width, contentView.bounds.height * 0.4))
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(dismissAction))
        footView.addGestureRecognizer(clickTap)
        
        return footView
    }
    
//#if !targetEnvironment(macCatalyst)
//    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        let currentOffset = scrollView.contentOffset.y
//        var currentDirection: ScrollDirection?
//
//        // 比较当前的内容偏移量和最后记录的偏移量
//        if currentOffset > lastContentOffset.y {
//            currentDirection = .down
//        } else if currentOffset < lastContentOffset.y {
//            currentDirection = .up
//        }
//
//        // 只有当滚动方向发生变化时，才进行回调
//        if currentDirection != lastScrollDirection {
//            lastScrollDirection = currentDirection
//
//            if let direction = currentDirection {
//                switch direction {
//                case .down:
//                    debugPrint("向下滚动")
//                    self.delegate?.controlViewDidScrollLyric(lyricCell: self, isScrollTop: false)
//                case .up:
//                    debugPrint("向上滚动")
//                    self.delegate?.controlViewDidScrollLyric(lyricCell: self, isScrollTop: true)
//                }
//            }
//        }
//
//        // 更新最后的内容偏移量
//        lastContentOffset = scrollView.contentOffset
//    }
//#endif
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let isNoneTime = self.model?.lyricModel?.isNoneTime, isNoneTime == false else { return }
        
//        // 记录当前的内容偏移量
//        lastContentOffset = scrollView.contentOffset

        self.isTracking = true
        self.lineView.isHidden = false
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let isNoneTime = self.model?.lyricModel?.isNoneTime, isNoneTime == false else { return }

        self.perform(#selector(endDraggAction), with: self, afterDelay: 3)
        self.perform(#selector(getWatchIndexPath), with: self, afterDelay: 0.1)
    }
    
    @objc func getWatchIndexPath() {
        
        self.lineView.isHidden = true
                
        // 计算当前停留在在那一行Cell
        guard let lineViewCenter = self.lineView.superview?.convert(self.lineView.center, to: self.tableView) else {
            return
        }

        let visibleIndexPaths = self.tableView.indexPathsForVisibleRows ?? []
        var closestIndexPath: IndexPath?
        var closestDistance: CGFloat = CGFloat.greatestFiniteMagnitude

        for indexPath in visibleIndexPaths {
            if let cell = self.tableView.cellForRow(at: indexPath) {
                let cellCenter = cell.center
                let distance = abs(cellCenter.y - lineViewCenter.y)

                if distance < closestDistance {
                    closestDistance = distance
                    closestIndexPath = indexPath
                }
            }
        }

        if let closestPath = closestIndexPath {
            // 更新中间索引路径
            self.middleIndexPath = closestPath
            
            self.tableView.reloadData()
        }
        
    }
    
    @objc func endDraggAction() {
        self.isTracking = false
        self.middleIndexPath = nil
    }
    
    func getCenterVisibleCell(in tableView: UITableView) -> IndexPath? {
        guard let visiblePaths = tableView.indexPathsForVisibleRows else {
            return nil
        }
        
        guard !visiblePaths.isEmpty else { return nil }
        
        // 获取可见Cell的中间位置
        let centerIndex = visiblePaths.count / 2 - 1
        return visiblePaths[centerIndex]
    }

    @objc func upgradePremiumTag() {
        self.delegate?.playerSubViewDidClickPurchage(baseView: self)
    }
    
}
