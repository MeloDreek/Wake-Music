//
//  MusicPlayerViewController+Play.swift
//  Wake Music
//
//  Created by Melo on 9/5/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer
import PanModal
import KakaPhotoBrowser
import SafariServices


extension MusicPlayerViewController {
    
    // 播放列表
    @objc func playlistButtonClick(_ sender: UIButton) {
        
        if KakaMusicPlayer.shared.playingMusic?.fileSourceType == .demoFile {
            self.view.kaka_playShakeAnim()
            return
        }
        
        if kaka_IsiPhone() {
            let playlistView = MusicPlaylistView(frame: self.view.bounds)
            self.view.addSubview(playlistView)
        }else{
            let playlistVC = MusicPlaylistViewController()
            playlistVC.preferredContentSize = CGSize(width: 400.ckValue(), height: 580.ckValue())
            playlistVC.modalPresentationStyle = .popover
            let popVC = playlistVC.popoverPresentationController
            popVC?.backgroundColor = UIColor.clear
            popVC?.permittedArrowDirections = .any
            popVC?.sourceRect = sender.bounds
            popVC?.sourceView = sender
            self.present(playlistVC, animated: true)
        }

    }
    
    // 点击喜欢或不喜欢
    @objc func favoriteViewClick() {
        if KakaMusicPlayer.shared.playingMusic?.fileSourceType == .demoFile {
            self.view.kaka_playShakeAnim()
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
            self?.view?.makeToast(error.errorDescription)
        }
    }
}

extension MusicPlayerViewController: PlayerSubViewDelegate {
    
    func playerBasicCellDidAudioFinger(basicView: UIView) {
        self.view.makeToast("音频指纹")
    }
    
    func playerBasicCellDidSelectLyric(basicView: UIView) {
        self.view.makeToast("选择歌词")
    }
    
    // 点击模拟歌词区域
    func controlViewDidBottomControl(controlView: UIView) {
        let isLandscape = OrientationManager.shared.isLandscape
        if isLandscape {
            self.lyricCollectionCellClick(!isLandscape)
        }else{
            let isLyricCell = abs(self.collectionView.contentOffset.x - self.flowLayout.itemSize.width) < 10
            self.lyricCollectionCellClick(!isLyricCell)
        }
        
    }
    
    // 滑动歌词区域
    func controlViewDidScrollLyric(lyricCell: PlayerLyricCollectCell, isScrollTop: Bool) {
//        let style = MusicConfigManager.shared.playerStyle
//        if style.isDefaultStyle() {
//            self.playDefaultControl.isHidden = isScrollTop
//        }
//
//        if style.isTapeStyle() {
//            self.playTapeControl.isHidden = isScrollTop
//        }
//
//        if style.isVinylStyle() {
//            self.playVinylControl.isHidden = isScrollTop
//        }
//        
//        lyricCell.isShowControl = isScrollTop
    }
    
    // 手动旋转屏幕
    func playerViewDidClickLyricBtn(playerView: UIView) {
        
        self.forceSetDeviceOrientation()
    }
    
    // 点击歌词自定义
    func controlViewDidLyricSetBtn(controlView: UIView, lyricSetBtn: UIButton) {
        self.lyricSetButtonClick()
    }
    
    // 点击播放列表
    func controlViewDidPlaylistBtn(controlView: UIView, playlistBtn: UIButton) {
        self.playlistButtonClick(playlistBtn)
    }
    
    // 歌词设置
    func playerBasicCellDidLyricSettings(basicView: UIView) {
        self.lyricSetButtonClick()
    }
    
    // 点击封面
    func playerBasicCellDidCoverImage(backView: UIImageView, coverImage: UIImage) {
        let photoItem = KakaPhotoItem(sourceView: backView, image: coverImage)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: self)
    }
    
    // 查看支持的声道
    func playerBasicCellDidChannel(backView: UIView) {
        self.setupAudioChannel()
    }
    
    // 查看睡眠计时器
    func playerBasicCellDidSleepTimer(basicView: UIView, sleepView: UIView?) {
        self.setupSleepTimer()
    }
    
//    // AI搜索封面
//    func playerBasicCellDidAICover(basicView: UIView) {
//        self.searchAlbumCoverWithAI()
//    }
//    
//    // AI搜索歌词
//    func playerBasicCellDidAILyric(basicView: UIView) {
//        self.searchLyricWithAI()
//    }
    
    // 音乐标签编辑器
    func playerBasicCellDidMusicEditor(basicView: UIView) {
        self.presentMusicTagController()
    }
    
    // 播放器引擎
    func playerBasicCellDidPlayerEngine(basicView: UIView) {
        self.presentPlayerEngine()
    }
    
    // 播放器样式
    func playerBasicCellDidPlayerStyle(basicView: UIView) {
        self.presentPlayerStyle()
    }
    
    // 播放器背景
    func playerBasicCellDidPlayerBackground(basicView: UIView) {
        self.presentPlayerBackground()
    }
    
    // 前往VIP
    func playerSubViewDidClickPurchage(baseView: UIView) {
        self.vipCenterClick()
    }
    
    // 添加到歌单
    func playerSubViewDidClickAddPlaylisy(baseView: UIView) {
        self.addToLocalPlaylist()
    }
    
    // 喜欢/不喜欢
    func playerSubViewDidClickFavorite(baseView: UIView) {
        self.favoriteViewClick()
    }
    
}
