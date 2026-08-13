//
//  MusicDescInfoView.swift
//  Mobie
//
//  Created by 张文 on 6/6/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MarqueeLabel
import Combine

class MusicDescInfoView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(musicLabel)
        self.addSubview(singerLabel)
        self.addSubview(desctagView)
        
        self.addSubview(favoriteView)
    }
    
    private func setupAutoLayout() {
        singerLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(kaka_IsMacOS() ? 36 : 30.ckValue())
            make.bottom.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.5)
            make.height.greaterThanOrEqualTo(singerLabel.font.lineHeight)
        }
        
        desctagView.snp.makeConstraints { make in
            make.centerY.equalTo(singerLabel.snp.centerY).offset(2.ckValue())
            make.leading.equalTo(singerLabel.snp.trailing).offset(10.ckValue())
            make.width.equalToSuperview().multipliedBy(0.75)
            make.height.equalTo(singerLabel)
        }
        
        favoriteView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-25.ckValue())
            make.bottom.equalTo(singerLabel.snp.top).offset(-8.ckValue())
            make.size.equalTo(favoriteView.size)
        }
        
        let traningSpace = 25.ckValue() + favoriteView.width + 12.ckValue()  + 10.ckValue()
        musicLabel.snp.makeConstraints { make in
            make.leading.equalTo(singerLabel)
            make.centerY.equalTo(favoriteView)
            make.trailing.equalToSuperview().offset(-traningSpace)
            make.height.equalTo(favoriteView)
        }
    }
    
    private func setupCusBuness() {
        self.isUserInteractionEnabled = true
        self.backgroundColor = .clear
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 显示音乐标签
        AppLocalManager.shared.$isShowAudioTag
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShowAudioTag in
                self?.desctagView.isHidden = !isShowAudioTag
            }.store(in: &cancellables)
        
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
        
    let buttonSize = 24.ckValue()
    
    var serverModel: ServerConfigModel?
    
    // MARK:  懒加载
    lazy var musicLabel: MarqueeLabel = {
        let playingModel = KakaMusicPlayer.shared.playingMusic
        let addStr = MusicConfigManager.shared.isShowExtension ? (playingModel?.addPathExtension() ?? "") : ""
        
        let view = MarqueeLabel()
        view.text = (playingModel?.showTitleName() ?? "") + addStr + "  "
        view.font = UIFontBold(20.ckValue())
        view.textColor = UIColor.white
        view.type = PhoneSetManager.isArabicCountry() ? .rightLeft : .leftRight
        return view
    }()
    
    lazy var singerLabel: MarqueeLabel = {
        let playingModel = KakaMusicPlayer.shared.playingMusic

        let view = MarqueeLabel()
        view.text = (playingModel?.showArtistName() ?? "") + "  "
        view.numberOfLines = 1
        view.font = UIFontLight(14.ckValue())
        view.textColor = UIColor.white.withAlphaComponent(0.6)
        view.type = PhoneSetManager.isArabicCountry() ? .rightLeft : .leftRight
        return view
    }()
    
    lazy var desctagView: MusicInfoTagView = {
        let playingModel = KakaMusicPlayer.shared.playingMusic

        let view = MusicInfoTagView()
        view.model = playingModel
        view.isHidden = !AppLocalManager.shared.isShowAudioTag
        return view
    }()
    
    lazy var favoriteView: UIButton = {
        let config = UIImage.SymbolConfiguration(pointSize: buttonSize, weight: .medium)
        let view = UIButton(type: .custom)
        view.size = CGSizeMake(33.ckValue(), 33.ckValue())
        view.isSelected = KakaMusicPlayer.shared.playingMusic?.isFlagFavorite() ?? false
        view.setImage(Reasource.systemNamed("heart", color: .white, config: config), for: .normal)
        view.setImage(Reasource.systemNamed("heart.fill", color: .white, config: config), for: .selected)
        view.addTarget(self, action: #selector(favoriteViewClick(_:)), for: .touchUpInside)
        return view
    }()
    
}

extension MusicDescInfoView {
    
    // 当前音乐模型变化了
    func playingMusicChanged() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
                
        self.serverModel = nil
        
        if let navUser = model.navidromeSong?.navUser {
            self.serverModel = ServerConfigModel(serverType: model.fileSourceType, navUser: navUser)
        }
        
        if let webdavUser = model.webFileModel?.webdavUser {
            self.serverModel = ServerConfigModel(serverType: model.fileSourceType, webdavUser: webdavUser)
        }
        
        let addStr = MusicConfigManager.shared.isShowExtension ? model.addPathExtension() : ""
        self.musicLabel.text = model.showTitleName() + addStr + "  "
        self.singerLabel.text = model.showArtistName() + "  "
        self.desctagView.model = model
        self.favoriteView.isSelected = model.isFlagFavorite()
    }
    
    @objc func favoriteViewClick(_ sender: UIButton) {
        if KakaMusicPlayer.shared.playingMusic?.fileSourceType == .demoFile {
            self.favoriteView.kaka_playShakeAnim()
            return
        }
        
        guard let playingMusic = KakaMusicPlayer.shared.playingMusic else { return }
        
        if playingMusic.isLocalFile() {
            SandboxFileManager.shared.addOrDeleteFavirote(playingMusic.mediaPlayURL)
            
            KakaMusicPlayer.shared.playingMusic = playingMusic
            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            
        }else{
            if let navSong = playingMusic.navidromeSong {
                self.likeNavSongClick(navSong)
            }else {
                ConnectConfigManager.shared.likeOrDislikeOneMusic(playingMusic)
                
                var newModel = playingMusic
                newModel.isFavorite.toggle()
                
                ConnectConfigManager.shared.addOrUpdateRemotePlaylist(musics: [newModel]) {
                    KakaMusicPlayer.shared.playingMusic = playingMusic
                }
            }
        }
    }
    
    // 喜欢这首歌
    func likeNavSongClick(_ navSong: NavidromeSong) {
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.serverModel?.navUser, endpoint: navSong.starred ? API.Subsonic.unstar : API.Subsonic.star, parameters: params) { response in
            
            if var playingMusic = KakaMusicPlayer.shared.playingMusic {
                playingMusic.navidromeSong?.starred = !navSong.starred
                playingMusic.isFavorite = !navSong.starred
                
                KakaMusicPlayer.shared.playingMusic = playingMusic
                
                let index = KakaMusicPlayer.shared.musicArray.firstIndex {
                    $0.navidromeSong?.id == playingMusic.navidromeSong?.id
                }
                
                if let index = index {
                    KakaMusicPlayer.shared.musicArray[index] = playingMusic
                }
            }
            
            NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            
        } fail: { [weak self] error in
            self?.makeToast(error.errorDescription)
        }
    }
    
}
