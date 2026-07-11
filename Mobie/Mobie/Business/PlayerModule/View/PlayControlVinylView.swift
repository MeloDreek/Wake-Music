//
//  PlayControlVinylView.swift
//  Mobie
//
//  Created by 张文 on 6/2/25.
//

import KakaFoundation
import AppGroupKit
import Combine
import KSPlayer
import WakeMusicPlayer
import NVActivityIndicatorView

/// 磁带控制层
class PlayControlVinylView: UIView {
    
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
        self.addSubview(playButton)
        self.addSubview(lastButton)
        self.addSubview(nextButton)
        self.addSubview(moreButton)
        self.addSubview(playlistButton)
        
        playButton.addSubview(loadingView)
        
        self.addSubview(playIconView)
        self.addSubview(nextIconView)
        self.addSubview(lastIconView)
        self.addSubview(listIconView)
        self.addSubview(moreIconView)
        
        self.addSubview(sleepTimerLabel)
        self.addSubview(pauseIconView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let isPhoneLandscape = kaka_IsiPhone() && OrientationManager.shared.isLandscape
        
        playButton.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            if isPhoneLandscape {
                make.top.equalToSuperview()
            }else{
                make.centerY.equalToSuperview().offset(8.ckValue())
            }
            make.size.equalTo(playBtnSize)
        }
        
        lastButton.snp.remakeConstraints { make in
            make.right.equalTo(playButton.snp.left).offset(-btnSpace)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        nextButton.snp.remakeConstraints { make in
            make.left.equalTo(playButton.snp.right).offset(btnSpace)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        playlistButton.snp.remakeConstraints { make in
            make.right.equalTo(lastButton.snp.left).offset(-btnSpace)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        moreButton.snp.remakeConstraints { make in
            make.left.equalTo(nextButton.snp.right).offset(btnSpace)
            make.centerY.equalTo(playButton)
            make.size.equalTo(playButton)
        }
        
        loadingView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-3.ckValue())
            make.size.equalTo(loadingView.size)
        }
        
        playIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playButton)
            make.bottom.equalTo(playButton.snp.top).offset(-5.ckValue())
            make.size.equalTo(playIconView)
        }
        
        nextIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(nextButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(nextIconView)
        }
        
        lastIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(lastButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(lastIconView)
        }
        
        listIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playlistButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(listIconView)
        }
        
        moreIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(moreButton)
            make.centerY.equalTo(playIconView)
            make.size.equalTo(moreIconView)
        }
        
        pauseIconView.snp.remakeConstraints { make in
            make.centerX.equalTo(playButton)
            make.top.equalTo(playButton.snp.bottom).offset(8.ckValue())
            make.size.equalTo(pauseIconView.layer.cornerRadius * 2)
        }
        
        sleepTimerLabel.snp.remakeConstraints { make in
            make.top.equalTo(pauseIconView.snp.bottom).offset(10.ckValue())
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear

        //  播放状态
        KakaMusicPlayer.shared.$playbackStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updatePlayStatus(status)
            }.store(in: &cancellables)
        
        // 睡眠时间
        KakaMusicPlayer.shared.$sleepTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sleepTime in
                self?.updateSleepTime(sleepTime)
            }.store(in: &cancellables)
        
        // 点击显示歌词
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(showLyricClick))
        self.addGestureRecognizer(clickTap)
    }
    
    // 点击显示歌词
    @objc func showLyricClick() {
        self.delegate?.controlViewDidBottomControl(controlView: self)
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    weak var delegate: PlayerSubViewDelegate?
    
    var playBtnSize: CGSize {
        get {
            let norImage = UIImage(named: "player_red_normal")!
            let imagevalue = norImage.size.height / norImage.size.width

            switch kaka_osType() {
            case .macOS:
                var btnWidth = self.bounds.width * 0.15
                let maxWidth = 100.ckValue()
                
                btnWidth = min(btnWidth, maxWidth)
                return CGSizeMake(btnWidth, btnWidth * imagevalue)
            case .iPadOS:
                let contentWidth = self.bounds.width
                let btnWidth = (contentWidth * 0.68) / 5.0
                return CGSizeMake(btnWidth, btnWidth * imagevalue)
            case .iOS:
                let screenWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
                let btnWidth = (screenWidth - btnSpace * 6) / 5.0
                return CGSizeMake(btnWidth, btnWidth * imagevalue)
            }
        }
    }
    
    var btnSpace: CGFloat {
        get {
            return 8.ckValue()
        }
    }
    
    
    var playIconSize: CGFloat {
        get {
            return playBtnSize.width * 16.0 / 75.0
        }
    }
    
    
    // MARK:  懒加载
    lazy var playButton: UIButton = {
        
        let norImage = UIImage(named: "player_red_normal")!
        let selImage = UIImage(named: "player_red_highted")!
        
        let view = UIButton(type: .custom)
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.frame.size = CGSizeMake(playBtnSize.width, playBtnSize.height)
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(norImage, for: .normal)
        view.setBackgroundImage(selImage, for: .highlighted)
        return view
    }()
    lazy var playIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_play"))
        view.frame = CGRectMake(0, 0, playIconSize, playIconSize)
        view.contentMode = .scaleAspectFit
        return view
    }()
    lazy var pauseIconView: UIButton = {
        let size = CGSizeMake(10.ckValue(), 10.ckValue())
        let view = UIButton()
        view.isSelected = KakaMusicPlayer.shared.isPlaying
        view.setBackgroundImage(UIImage.createImage(color: .systemRed, size: size), for: .normal)
        view.setBackgroundImage(UIImage.createImage(color: .systemGreen, size: size), for: .selected)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = size.width / 2
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let height = playButton.height * 0.5
        let view = NVActivityIndicatorView(frame: CGRectMake(0, 0, height, height), type: .circleStrokeSpin, color: .white)
        return view
    }()
    
    lazy var lastButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playLastButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "player_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "player_black_highted"), for: .highlighted)
        return view
    }()
    lazy var lastIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_last"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var nextButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playNextButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "player_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "player_black_highted"), for: .highlighted)
        return view
    }()
    lazy var nextIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_next"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var moreButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.setBackgroundImage(UIImage(named: "player_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "player_black_highted"), for: .highlighted)
        view.showsMenuAsPrimaryAction = true
        view.menu = self.moreMenu()
        view.addTarget(self, action: #selector(moreButtonClick(_:)), for: .touchDown)
        return view
    }()
    lazy var moreIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_more"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var playlistButton: UIButton = {
        let view = UIButton(type: .custom)
        view.frame.size = playButton.frame.size
        view.contentMode = .scaleAspectFit
        view.addTarget(self, action: #selector(playlistButtonClick(_:)), for: .touchUpInside)
        view.setBackgroundImage(UIImage(named: "player_black_normal"), for: .normal)
        view.setBackgroundImage(UIImage(named: "player_black_highted"), for: .highlighted)
        return view
    }()
    lazy var listIconView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "player_tape_list"))
        view.frame = playIconView.bounds
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var sleepTimerLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(10.ckValue())
        view.textColor = UIColor.white.withAlphaComponent(0.5)
        view.text = nil
        view.textAlignment = .center
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(setupSleepTimer))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    lazy var wakePlayer: WakeMusicPlayer = {
        return WakeMusicPlayer()
    }()
    
    func moreMenu() -> UIMenu {
        
        // 1️⃣ AI封面、AI歌词、音乐标签编辑器
        let aiCoverAction = UIAction(title: MusicActionType.searchCoverAI.formatStr(), image: MusicActionType.searchCoverAI.iconImage()) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidAICover(basicView: wSelf)
        }
        let aiLyricAction = UIAction(title: MusicActionType.searchLyricAI.formatStr(), image: MusicActionType.searchLyricAI.iconImage()) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidAILyric(basicView: wSelf)
        }
        let musictagAction = UIAction(title: "Music Tag Editor".localStr(), image: MusicActionType.musictag.iconImage()) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidMusicEditor(basicView: wSelf)
        }
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.formatStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerSubViewDidClickAddPlaylisy(baseView: wSelf)
        }
        let isLike = KakaMusicPlayer.shared.playingMusic?.isFlagFavorite() ?? false
        let likeType = isLike ? MusicActionType.removeFavirote : MusicActionType.addFavirote
        let likeAction = UIAction(title: likeType.formatStr(), image: likeType.iconImage()) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerSubViewDidClickFavorite(baseView: wSelf)
            wSelf.moreButton.menu = wSelf.moreMenu()
        }
        
        let musictagMenu = UIMenu(title: "", options: .displayInline, children: [aiCoverAction, aiLyricAction, musictagAction, playlistAction, likeAction])
        
        // 2️⃣ 播放器内核、播放器样式、播放器背景
        let engineAction = UIAction(title: "Playback Engine".localStr(), image: UIImage(systemName: "play.rectangle"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerEngine(basicView: wSelf)
        })
        
        let playerAction = UIAction(title: "Player Style".localStr(), image: UIImage(systemName: "camera.filters"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerStyle(basicView: wSelf)
        })
        
        let playbackAction = UIAction(title: "Player background".localStr(), image: UIImage(systemName: "wand.and.rays"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidPlayerBackground(basicView: wSelf)
        })
        
        let lyricsetAction = UIAction(title: "Lyrics Settings".localStr(), image: UIImage(systemName: "slider.vertical.3"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.playerBasicCellDidLyricSettings(basicView: wSelf)
        })
        
        let isShowAudioTag = AppLocalManager.shared.isShowAudioTag
        let showTagAction = UIAction(title: "Audio Tags".localStr(), image: isShowAudioTag ? nil : UIImage(systemName: "tag.slash"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: isShowAudioTag ? .on : .off, handler: { [weak self] _ in
            AppLocalManager.shared.isShowAudioTag = !AppLocalManager.shared.isShowAudioTag
            self?.moreButton.menu = self?.moreMenu()
        })
        
        let playStylegMenu = UIMenu(title: "", options: .displayInline, children: [engineAction, playerAction, playbackAction, lyricsetAction, showTagAction])
        
        // 3️⃣ 睡眠计时器，下载，倍数
        let sleepAction = UIAction(title: "Sleep Timer".localStr(), image: UIImage(systemName: "clock.arrow.circlepath"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.setupSleepTimer()
        })
        
        let downloadAction = UIAction(title: "Download".localStr(), image: UIImage(systemName: "square.and.arrow.down"), identifier: nil, discoverabilityTitle: nil, attributes: (KakaMusicPlayer.shared.playingMusic?.isLocalFile() ?? true) ? [.disabled] : [], state: .off, handler: { [weak self] _ in
            self?.addDownloadQueue()
        })
        
        let otherMenu = UIMenu(title: "", options: .displayInline, children: [sleepAction, downloadAction, self.rateTypeMenu()])
        
        let mainMenu = UIMenu(title: "", children: [musictagMenu, playStylegMenu, otherMenu])
        
        return mainMenu
    }
    
    // 播放倍速
    func rateTypeMenu() -> UIMenu {
        let storageArray: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0, 8.0]
        var actionArray: [UIAction] = [UIAction]()
        
        for subItem in storageArray {
            let subMenu = UIAction(title: "\(subItem)", image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: MusicConfigManager.shared.playRate == subItem ? .on : .off, handler: { [weak self] _ in
                
                if let baiduFile = KakaMusicPlayer.shared.playingMusic?.baiduFileModel, FileManager.default.fileExists(atPath: baiduFile.m3uCacheURL().path) {
                    appKeyWindow?.makeToast("Due to partner requirements, this feature cannot be used.".localStr())
                    self?.moreButton.menu = self?.moreMenu()
                    return
                }
                
                KakaMusicPlayer.shared.pause()
                
                MusicConfigManager.shared.playRate = subItem
                KakaMusicPlayer.shared.playbackRate = subItem
                
                KakaMusicPlayer.shared.play()
                
                self?.moreButton.menu = self?.moreMenu()
            })
            
            actionArray.append(subMenu)
        }
                
        var editImage = UIImage(systemName: "goforward.45")
        if #available(iOS 17.0, *) {
            editImage = UIImage(systemName: "gauge.with.dots.needle.67percent")
        }
        
        let sortMenu = UIMenu(title: "Rate".localStr(), image: editImage, options: .singleSelection, children: actionArray)
        return sortMenu
        
    }
}

extension PlayControlVinylView {
    // 播放暂停
    @objc func playButtonClick(_ sender: UIButton) {
        
        if self.loadingView.isAnimating {
            return
        }
        
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("vinyl_click.mp3"))
        self.wakePlayer.play(url: clickURL) {
            var isLocal = false
            if let model = KakaMusicPlayer.shared.playingMusic {
                isLocal = model.isLocalFile()
            }
            
            if isLocal {
                sender.isSelected = !sender.isSelected
            }
            
            if KakaMusicPlayer.shared.isPlaying {
                KakaMusicPlayer.shared.pause()
            }else{
                KakaMusicPlayer.shared.play()
            }
        }
    }
    
    // 更多按钮
    @objc func moreButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("vinyl_click.mp3"))
        self.wakePlayer.play(url: clickURL)
    }
    
    // 上一首
    @objc func playLastButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("vinyl_click.mp3"))
        self.wakePlayer.play(url: clickURL)
        
        KakaMusicPlayer.shared.playLastItem()
    }
    
    // 下一首
    @objc func playNextButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("vinyl_click.mp3"))
        self.wakePlayer.play(url: clickURL)
        
        KakaMusicPlayer.shared.playNextItem()
    }

    // 播放列表
    @objc func playlistButtonClick(_ sender: UIButton) {
        let clickURL = URL(fileURLWithPath: Reasource.fullFilePath("vinyl_click.mp3"))
        self.wakePlayer.play(url: clickURL)
        
        self.delegate?.controlViewDidPlaylistBtn(controlView: self, playlistBtn: sender)
    }
    
    // 睡眠计时器
    @objc func setupSleepTimer() {
        self.delegate?.playerBasicCellDidSleepTimer(basicView: self, sleepView: self.sleepTimerLabel)
    }
    
    // 睡眠计时器
    func updateSleepTime(_ sleepTime: TimeInterval) {
        
        if self.isHidden { return }
        
        let minutes = Int(sleepTime) / 60
        let seconds = Int(sleepTime) % 60
        
        let sleepStr = "💤" + String(format: "%02d:%02d", minutes, seconds)
        self.sleepTimerLabel.text = sleepStr
        self.sleepTimerLabel.isHidden = sleepTime <= 0
    }
    
    // 播放状态
    func updatePlayStatus(_ playStatus: KSPlayerState) {
        
        if self.isHidden { return }
        
        guard let playingModel = KakaMusicPlayer.shared.playingMusic else { return }

        let isLocal = playingModel.isLocalFile()
        
        if !isLocal {
            self.playButton.isSelected = KakaMusicPlayer.shared.isPlaying
        }
        
        self.pauseIconView.isSelected = KakaMusicPlayer.shared.isPlaying
        
        switch playStatus {
        case .initialized:
            if !self.loadingView.isAnimating {
                self.loadingView.startAnimating()
            }
            break
        case .buffering, .preparing:
            if !isLocal {
                if !self.loadingView.isAnimating {
                    self.loadingView.startAnimating()
                }
            }
            break
        case .bufferFinished:
            self.loadingView.stopAnimating()
            break
        case .readyToPlay:
            break
        case .paused:
            self.loadingView.stopAnimating()
            break
        case .playedToTheEnd, .error:
            self.loadingView.stopAnimating()
            break
        }
        
    }
    
    // 下载
    func addDownloadQueue() {
        guard let musicModel = KakaMusicPlayer.shared.playingMusic, SandboxFileManager.shared.getDownloadPlayURL(musicModel) == nil else { return }
        
        DownloadManager.shared.addMusicModel([musicModel])
        self.makeToast("Added to Downloads".localStr())
    }
    
    // 声道支持页面
    @objc func setupAudioChannel() {
        self.delegate?.playerBasicCellDidChannel(backView: self)
    }
    
    
}
