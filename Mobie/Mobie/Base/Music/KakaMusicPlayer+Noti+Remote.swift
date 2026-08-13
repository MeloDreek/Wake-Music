//
//  KakaMusicPlayer+Noti.swift
//  Wake Music
//
//  Created by Melo on 7/29/24.
//

import KakaFoundation
import AppGroupKit
import AVFAudio
import KSPlayer
import MediaPlayer
import Kingfisher


extension KakaMusicPlayer {
    
    func setupRemoteCommand() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.likeCommand.isEnabled = true
        commandCenter.dislikeCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
    }
    
    @MainActor
    @objc func setupRemoteTransportControls() {
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.likeCommand.removeTarget(nil)
        commandCenter.dislikeCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        self.setupRemoteCommand()
                
        commandCenter.likeCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.favoriteButtonClick()
                        
            return .success
        }
                
        commandCenter.dislikeCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.favoriteButtonClick()
            
            return .success
        }
        
        commandCenter.likeCommand.isActive = self.playingMusic?.isFlagFavorite() ?? false
        
        // Mac物理按键
        commandCenter.togglePlayPauseCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            if self.isPlaying {
                self.pause()
            }else{
                self.play()
            }
            
            self.performSelector(onMainThread: #selector(updatePlaybackState), with: nil, waitUntilDone: false)
            
            return .success
        }

        commandCenter.playCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.play()
            self.performSelector(onMainThread: #selector(updatePlaybackState), with: nil, waitUntilDone: false)
            
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.pause()
            self.performSelector(onMainThread: #selector(updatePlaybackState), with: nil, waitUntilDone: false)
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.playNextItem()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            guard let _ = self.playingMusic else {
                return .noSuchContent
            }
            
            self.playLastItem()
            return .success
        }
        
        // 拖动播放时间
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            guard let playingMusic = self.playingMusic else { return .noSuchContent }

            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                
                if let baiduFile = playingMusic.baiduFileModel, FileManager.default.fileExists(atPath: baiduFile.m3uCacheURL().path) {
                    debugPrint("百度m3u不允许拖拽播放时间")
                    return .commandFailed
                }else{
                    self.seek(time: positionEvent.positionTime)
                    
                    return self.playerView.playerLayer?.player.seekable == true ? .success : .commandFailed
                }
                                    
            }
            
            return .noActionableNowPlayingItem
        }
                
    }
    
    @MainActor @objc func updatePlaybackState() {
        MPNowPlayingInfoCenter.default().playbackState = self.isPlaying ? .playing : .paused
    }
    
    /// 更新外部控制中心UI
    /// - Parameters:
    ///   - image: 封面
    ///   - title: 标题
    ///   - artistName: 歌手名
    ///   - albumTitle: 专辑名称
    func updateNowPlayingInfo(musicModel: MusicItemModel?) {
        
        guard let musicModel = musicModel else { return }

        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] = musicModel.filePathName().MD5String()
        nowPlayingInfo[MPMediaItemPropertyTitle] = musicModel.showTitleName()
        nowPlayingInfo[MPMediaItemPropertyArtist] = musicModel.showArtistName()
#if !targetEnvironment(macCatalyst)
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = musicModel.album ?? "Unknown Album".localStr()
#endif
                
        let coverImg = musicModel.musicCoverImage() ?? musicModel.placeImage()
        let imgValue = coverImg.size.height / coverImg.size.width
        var imgSize = coverImg.size
        if imgValue - 1 > 0.1 {
            imgSize = CGSizeMake(coverImg.size.width, coverImg.size.width)
        }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: imgSize) { size in
            self.cacheCoverImage = coverImg
            return coverImg
        }
        
        self.lastPlayingLryicIndex = nil
        self.performSelector(onMainThread: #selector(updatePlaybackState), with: nil, waitUntilDone: false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
    }
    
    // 更新控制中心的播放进度
    func updateControlPlayTime(currentTime: TimeInterval, totalTime: TimeInterval) {
        
        guard let playingMusic = self.playingMusic else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyExternalContentIdentifier] = playingMusic.filePathName().MD5String()
        nowPlayingInfo[MPMediaItemPropertyTitle] = playingMusic.showTitleName()
        nowPlayingInfo[MPMediaItemPropertyArtist] = playingMusic.showArtistName()
#if !targetEnvironment(macCatalyst)
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = playingMusic.album ?? "Unknown Album".localStr()
#endif
        
        if let coverImage = self.cacheCoverImage ?? playingMusic.musicCoverImage() {
            let imgValue = coverImage.size.height / coverImage.size.width
            var imgSize = coverImage.size
            if imgValue - 1 > 0.1 {
                imgSize = CGSizeMake(coverImage.size.width, coverImage.size.width)
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: imgSize) { size in
                self.cacheCoverImage = coverImage
                return coverImage
            }
        }else {
            // 没有封面的话设置占位图
            if let coverImage = playingMusic.musicCoverImage() {
                self.cacheCoverImage = coverImage
            }
            
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSizeMake(100, 100)) { size in
                return self.cacheCoverImage ?? playingMusic.placeImage()
            }
        }
        
        if totalTime == 0 {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0
        }else{
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalTime
            // 设置控制中心歌词
            let lyricInfo = self.setupRemoteLyric(nowPlayingInfo: nowPlayingInfo, millisecond: currentTime * 1000)
            if let lyricInfo = lyricInfo {
                nowPlayingInfo = lyricInfo
            }
        }
                
        self.performSelector(onMainThread: #selector(updatePlaybackState), with: nil, waitUntilDone: false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // 设置远程歌词
    private func setupRemoteLyric(nowPlayingInfo: [String: Any], millisecond: TimeInterval) -> [String : Any]? {
        
        guard let playingMusic = self.playingMusic else { return nil }

        if !UserInfoManager.shared.isVIP() {
            if !UserInfoManager.shared.isFreeTrail3Days_Local() && playingMusic.fileSourceType != .demoFile {
                return nil
            }
        }
        
        if MusicConfigManager.shared.lyricSortStyle == .dontShow || playingMusic.fileSourceType == .demoFile {
            return nil
        }
        
        guard let isNoneTime = playingMusic.lyricModel?.isNoneTime, isNoneTime == false else {
            return nil
        }
                        
        if let lyrics = playingMusic.lyricModel?.lyrics, lyrics.count > 0 {
            let timeOffset: Double = Double(KakaMusicPlayer.shared.playingMusic?.lyricModel?.offset ?? 0)
            if let tempIndex = self.getCurrentLyricIndex(playbackTime: millisecond + timeOffset, lyrics: lyrics) {
                if tempIndex != self.lastPlayingLryicIndex {
                    self.lastPlayingLryicIndex = tempIndex
                }
            }
        }
        
        guard let playingIndex = lastPlayingLryicIndex else { return nil }
        
        var newPlayingInfo = nowPlayingInfo
        let isLyricFirst = MusicConfigManager.shared.lyricSortStyle == .firstLine && playingMusic.fileSourceType != .demoFile
        
        if let lyrics = playingMusic.lyricModel?.lyrics, playingIndex >= 0 && playingIndex < lyrics.count {
            let lyricModel = lyrics[playingIndex]
            // 继续处理 lyricModel
            newPlayingInfo[isLyricFirst ? MPMediaItemPropertyTitle : MPMediaItemPropertyArtist] = lyricModel.fullLyric ?? playingMusic.showTitleName()
            newPlayingInfo[isLyricFirst ? MPMediaItemPropertyArtist : MPMediaItemPropertyTitle] = playingMusic.showTitleName()
        } else {
            // 处理越界情况，例如设置为 nil 或者其他默认值
            newPlayingInfo[MPMediaItemPropertyTitle] = playingMusic.showTitleName()
            newPlayingInfo[MPMediaItemPropertyArtist] = playingMusic.showArtistName()
        }
                
        return newPlayingInfo
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
    
    /// 喜欢
    @objc func favoriteButtonClick() {
        
        guard let playingMusic = self.playingMusic else { return }
        
        if playingMusic.isLocalFile() {
            SandboxFileManager.shared.addOrDeleteFavirote(playingMusic.mediaPlayURL)
            
            KakaMusicPlayer.shared.playingMusic = playingMusic
            
            MPRemoteCommandCenter.shared().likeCommand.isActive.toggle()
            
            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            
        }else{
            
            if let _ = playingMusic.navidromeSong {
                self.likeNavSongClick(playingMusic)
            }else {
                ConnectConfigManager.shared.likeOrDislikeOneMusic(playingMusic)
                
                var newModel = playingMusic
                newModel.isFavorite.toggle()
                
                ConnectConfigManager.shared.addOrUpdateRemotePlaylist(musics: [newModel]) {
                    KakaMusicPlayer.shared.playingMusic = playingMusic
                }
                
                MPRemoteCommandCenter.shared().likeCommand.isActive.toggle()
            }
        }
        
    }
    
    // 喜欢这首歌
    private func likeNavSongClick(_ model: MusicItemModel) {
        guard let navSong = model.navidromeSong, let navUser = model.navidromeSong?.navUser else { return }
        
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: navUser, endpoint: navSong.starred ? API.Subsonic.unstar : API.Subsonic.star, parameters: params) { response in
            
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
                
                MPRemoteCommandCenter.shared().likeCommand.isActive.toggle()
            }
                        
        } fail: { error in
            appKeyWindow?.makeToast(error.errorDescription)
        }
    }
    
    // 上一次播放歌词是哪一行
    private var lastPlayingLryicIndex: Int? {
        get {
            guard let cacheArr = objc_getAssociatedObject(self, &MusicPlayerRemoteKeys.kPlayingLryicIndexKey) as? Int else {
                return nil
            }
            
            return cacheArr
        }
        set {
            objc_setAssociatedObject(self, &MusicPlayerRemoteKeys.kPlayingLryicIndexKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    private struct MusicPlayerRemoteKeys {
        static var kPlayingLryicIndexKey: Void?
    }
    
}

extension KakaMusicPlayer {
    
    func addNotiFacation() {
        
        // 播放引擎切换了
        NotificationCenter.default.addObserver(self, selector: #selector(playerEngineChanged), name: Notification.Name(kPlayerEngineChangedKey), object: nil)
        
        // 排序变化了
        MusicConfigManager.shared.$orderType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sortType in
                self?.playlistSortTypeChanged()
            }.store(in: &cancellables)
        
        // 真假随机
        MusicConfigManager.shared.$randomType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sortType in
                self?.playlistSortTypeChanged()
            }.store(in: &cancellables)
    }
    
    // 排序方式变了
    @objc func playlistSortTypeChanged() {
        let sortType = MusicConfigManager.shared.orderType
        let isRealRandom = MusicConfigManager.shared.randomType == .trueRandom
        
        let tempArray = self.musicArray.compactMap { $0 }
        
        self.nextPlayMusic = nil
        if sortType == .random {
            if isRealRandom {
                self.musicArray = self.tempMusicArray.isEmpty ? tempArray : self.tempMusicArray
            }else{
                self.musicArray = tempArray.shuffled()
            }
        }else{
            self.musicArray = self.tempMusicArray.isEmpty ? tempArray : self.tempMusicArray
        }
    }
    
    // 播放引擎已变更
    @MainActor @objc func playerEngineChanged() {
        
        guard let playingMusic = self.playingMusic, MusicConfigManager.shared.playerEngine != .avPlayer else {
            return
        }
        
        self.playerView.resetPlayer()
        
        MusicConfigManager.shared.lastPlayTime = 0
        self.playingMusic = playingMusic
        self.play()
    }
    
}
