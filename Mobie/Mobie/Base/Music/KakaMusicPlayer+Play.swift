//
//  KakaMusicPlayer+Play.swift
//  Wakemusic
//
//  Created by Melo on 9/4/24.
//

import KakaFoundation
import AppGroupKit
import AVFAudio
import Toast
import MediaPlayer
import KSPlayer
import KakaTaglibKit

extension KakaMusicPlayer {
    
    @MainActor
    public func startPlayMusic(musics: [MusicItemModel], itemIndex: Int) {
        
        guard musics.indices.contains(itemIndex) else { return }
        // Keep the selected identity from the original list, not its filtered index.
        // An empty folder must not stop the current song or become a playable item.
        let model = musics[itemIndex]
        guard !model.isFolder() else { return }
        
        retirePlayback()
        MusicConfigManager.shared.lastPlayTime = 0
        
        self.musicArray = musics
        self.tempMusicArray = musics
        self.nextPlayMusic = nil
        
        self.playingMusic = model
        self.playlistSortTypeChanged()
        
        self.play()
    }

}

extension KakaMusicPlayer {
    @MainActor func acceptsPlaybackRequest(_ requestID: UUID, model: MusicItemModel) -> Bool {
        wantsPlayback && playbackRequestID == requestID && playingMusic?.uniqueID() == model.uniqueID()
    }

    /// Detach and silence even paused/buffering engines before changing song identity.
    @MainActor func retirePlayback() {
        playbackRequestID = UUID()
        seekRequestID = UUID()
        pendingSeekTime = nil
        isSeeking = false
        wantsPlayback = false
        let layer = playerView.playerLayer
        layer?.delegate = nil
        layer?.player.delegate = nil
        layer?.player.playbackVolume = 0
        layer?.pause()
        playerView.resetPlayer()
    }

    @MainActor func togglePlayback() {
        if wantsPlayback && playbackStatus != .paused && playbackStatus != .error && playbackStatus != .playedToTheEnd {
            pause()
        } else {
            play()
        }
    }

    // 播放
    @MainActor func play() {
        self.playbackRequestID = UUID()
        
        guard var model = self.playingMusic else {
            resetToPausedDemo(clearRemotePlaylist: false)
            return
        }
        // Defensive guard for old persisted current-song records and direct callers.
        guard !model.isFolder() else {
            retirePlayback()
            resetToPausedDemo(clearRemotePlaylist: false)
            return
        }

        // History and restored queues must not bypass the connection paywall.
        // Already downloaded files remain available without a new connection.
        if !model.isLocalFile(),
           !UserInfoManager.shared.isVIP(),
           SandboxFileManager.shared.getDownloadPlayURL(model) == nil {
            retirePlayback()
            self.playbackStatus = .error
            if let controller = self.currentViewController() {
                SuperViewController.showRemoteConnectionPaywall(on: controller)
            }
            return
        }

        // Also reject persisted 115 playlists from before the format policy
        // changed, before resolving links or reusing a paused streaming URL.
        if model.drive115Model?.isUnsupportedStreamingAudio == true {
            retirePlayback()
            self.playbackStatus = .error
            self.currentViewController()?.show115StreamingDownloadAlert(for: model)
            return
        }

        // Re-resolve temporary cloud links after a pause; the previous URL may have expired.
        let isResumingPCloud = (model.pcloudFile != nil || model.megaFile != nil || model.yandexFile != nil || model.guangyaFile != nil || model.pan123File != nil || model.boxFile != nil || model.smbFile != nil) && self.playerView.playerLayer?.player.playbackState == .paused && self.playerView.playerLayer?.url == model.mediaPlayURL
        let pcloudResumeTime = isResumingPCloud ? self.currentTime : MusicConfigManager.shared.lastPlayTime
        
        let fileExtension = model.megaFile?.fileExtension() ?? model.smbFile?.fileExtension() ?? model.yandexFile?.fileExtension() ?? model.guangyaFile?.fileExtension() ?? model.pan123File?.fileExtension() ?? model.boxFile?.fileExtension() ?? model.mediaPlayURL.pathExtension.lowercased()
        let isPremiumType = AudioExtensionType.premiumExtensions().contains(fileExtension)
        if !UserInfoManager.shared.isVIP() && isPremiumType && (model.fileSourceType != .demoFile) {
            retirePlayback()
            playbackStatus = .error
            self.currentViewController()?.showOneAlert(message: "The system's built-in AVPlayer can't decode this format. Please switch the Player Engine.".localStr(), confirm: "OK".localStr()) {
                let navVC = KakaNavigationController(rootViewController: PlayerEngineViewController())
                navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
                self.currentViewController()?.present(navVC, animated: true)
            }
            return
        }
        
        wantsPlayback = true
        // FFmpeg changes paused -> seeking immediately. Do not mistake an in-flight
        // seek for a new song and destroy the engine (and its requested position).
        if isSeeking, let layer = playerView.playerLayer, layer.url == model.mediaPlayURL {
            playbackStatus = .buffering
            return
        }
        if let playerLayer = self.playerView.playerLayer, model.pcloudFile == nil, model.megaFile == nil, model.yandexFile == nil, model.guangyaFile == nil, model.pan123File == nil, model.boxFile == nil, model.smbFile == nil, playerLayer.player.playbackState == .paused, self.playingMusic?.mediaPlayURL == playerLayer.url {
            // 继续播放
            debugPrint("继续播放")
        }else{
            // 开始播放
            retirePlayback()
            wantsPlayback = true
            self.currentTime = 0
            self.playbackStatus = .buffering
            self.totalTime = TimeInterval(model.durationSeconds)
            
            self.updateNowPlayingInfo(musicModel: model)
            self.deleteAllM3uCache() // 删除所有m3u缓存文件
                                    
            if let cacheURL = SandboxFileManager.shared.getDownloadPlayURL(model) {
                // 优先读取缓存路径
                // Remote caches follow the same engine gate as streaming. Their tags/artwork
                // are loaded asynchronously after buffering, not synchronously on the UI thread.
                if model.isLocalFile() {
                    let metadata = TaglibMetadataParser.readMetadata(withFileURL: cacheURL, read: .all)
                    self.playingMusic?.lyricModel = metadata?.lyricModel?.convertSwiftModel()
                }
                
                model.mediaPlayURL = cacheURL
                self.playingMusic?.mediaPlayURL = cacheURL
                
                debugPrint("开始播放缓存 = \(cacheURL)")
                
                self.playerView.set(url: cacheURL, options: self.audioOption(model))
            }else{
                if model.smbFile != nil {
                    self.handleSMBStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.megaFile != nil {
                    self.handleMEGAStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.yandexFile != nil {
                    self.handleYandexStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.pan123File != nil {
                    self.handlePan123Streaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.guangyaFile != nil {
                    self.handleGuangyaStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.boxFile != nil {
                    self.handleBoxStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if model.pcloudFile != nil {
                    self.handlePCloudStreaming(model, resumeTime: pcloudResumeTime)
                    return
                }else if let _ = model.baiduFileModel {
                    // 1️⃣获取百度的播放地址
                    self.handleBaiduStreaming(model)
                    return
                }else if let _ = model.aliFileModel {
                    // 2️⃣ 获取阿里云盘的播放地址
                    self.handleAliyunpanStreaming(model)
                    return
                }else if let _ = model.drive115Model {
                    // 3️⃣ 获取115的播放地址
                    self.handle115DriveStreaming(model)
                    return
                }else if let _ = model.dropboxFile {
                    // 4️⃣ 获取Dropbox的播放地址
                    self.handleDropboxStreaming(model)
                    return
                }else if let _ = model.googleFile {
                    // 5️⃣ 获取Google的播放地址
                    self.handleGoogleStreaming(model)
                    return
                }else if let _ = model.onedriveFile {
                    // 6️⃣ 获取OneDrive的播放地址
                    self.handleOneDriveStreaming(model)
                    return
                }
                else{
                    debugPrint("开始播放新URL = \(model.mediaPlayURL)")
                    self.playerView.set(url: model.mediaPlayURL, options: self.audioOption(model))
                }
            }
            
            let lastPlayTime = MusicConfigManager.shared.lastPlayTime

            if lastPlayTime > 0 {
                self.seek(time: lastPlayTime)
            }
            
            self.setupLocalNotification(model)
        }
        
        self.playbackRate = MusicConfigManager.shared.playRate
        
        if !isSeeking { self.playerView.play() }
        
        self.setupRemoteTransportControls()
        self.updateNowPlayingInfo(musicModel: model)
        self.fetchLrcLyricContent()
    }
    
    // 继续播放
    @MainActor func continueToPlay(_ model: MusicItemModel) {
        guard wantsPlayback, playingMusic?.uniqueID() == model.uniqueID() else { return }
        
        self.setupLocalNotification(model)
        
        self.playbackRate = MusicConfigManager.shared.playRate
//        self.playerView.set(url: model.mediaPlayURL, options: self.audioOption(model))
        if !isSeeking { self.playerView.play() }
        
        self.setupRemoteTransportControls()
        self.updateNowPlayingInfo(musicModel: model)
        self.fetchLrcLyricContent()
    }

    // 暂停
    @MainActor func pause() {
        self.playbackRequestID = UUID()
        self.seekRequestID = UUID()
        self.isSeeking = false
        self.wantsPlayback = false
        self.playerView.pause()
        self.playbackStatus = .paused
        updatePlaybackState()
    }
    
    // 停止
    @MainActor func stop() {
        retirePlayback()
        self.cacheCoverImage = nil
        self.playbackStatus = .paused
        updatePlaybackState()

        self.currentTime = 0
        self.totalTime = 0
    }

    /// Leaving the music-server shell is not account logout. Keep account/history
    /// data, but retire its live playback and expose the bundled demo, paused.
    @MainActor func resetToPausedDemo(clearRemotePlaylist: Bool = true) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(prepareNextMusic), object: nil)
        retirePlayback()
        remoteMetadataTask?.cancel()
        remoteMetadataTask = nil
        remoteMetadataGeneration = UUID()
        remoteMetadataAttempted = false
        DownloadManager.shared.cancelPreDownload()
        nextPlayMusic = nil
        pendingShuffleRound = nil
        isRetry = false
        isDecodingError = false
        sleepTimer.stopTimer()
        sleepTime = 0
        MusicConfigManager.shared.sleepTime = nil

        let demo = MusicItemModel.demoMusicModel()
        currentTime = 0
        totalTime = TimeInterval(demo.durationSeconds)
        MusicConfigManager.shared.lastPlayTime = 0
        MusicConfigManager.shared.lastTotalTime = totalTime
        musicArray = [demo]
        tempMusicArray = [demo]
        // This persistence slot stores remote queues, not bundled/local audio.
        if clearRemotePlaylist {
            ConnectConfigManager.shared.lastPlaylist = []
        }
        playingMusic = demo
        playbackStatus = .paused
        setupRemoteTransportControls()
        updateNowPlayingInfo(musicModel: demo)
        updateControlPlayTime(currentTime: 0, totalTime: totalTime)
        var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
        updatePlaybackState()
    }
    
    // 拖动播放进度
    @MainActor func seek(time: TimeInterval, resumePlayback: Bool = false) {
        guard time.isFinite, time >= 0, let layer = playerView.playerLayer else { return }
        // UI scrubbing requests seek-and-resume as one operation; never seek then
        // call play(), which may re-resolve the URL while the engine is seeking.
        if resumePlayback {
            playbackRequestID = UUID()
            wantsPlayback = true
        }
        seekRequestID = UUID()
        let requestID = seekRequestID
        self.lastUpdateTime = 0
        self.playbackStatus = wantsPlayback ? .buffering : .paused
        self.currentTime = time
        guard layer.player.isReadyToPlay else {
            pendingSeekTime = time
            if resumePlayback { layer.play() }
            return
        }
        pendingSeekTime = nil
        isSeeking = true
        layer.seek(time: time, autoPlay: false) { [weak self, weak layer] finished in
            guard let self, let layer, self.playerView.playerLayer === layer,
                  self.seekRequestID == requestID else { return }
            self.isSeeking = false
            if finished && self.wantsPlayback {
                layer.play()
            } else if !self.wantsPlayback {
                layer.pause()
                self.playbackStatus = .paused
            } else {
                self.playbackStatus = .error
            }
        }
    }
    
    
    // 单曲循环
    @MainActor @objc func replaySingleItem() {
        guard let musicModel = self.playingMusic else { return }
        
        retirePlayback()
        MusicConfigManager.shared.lastPlayTime = 0
        
        self.playingMusic = musicModel
        self.play()
    }
    
    /// 播放上一首
    @MainActor func playLastItem() {

        var index = 0
        
        index = self.musicArray.firstIndex(where: { $0 == self.playingMusic }) ?? 0
        
        index = index - 1
        if (index >= self.musicArray.count) || (index < 0) {
            index = 0
        }
        
        self.playAtIndex(index)
        
    }
    
    // 播放下一首
    @MainActor @objc func playNextItem() {
        guard !musicArray.isEmpty else { return }
        if musicArray.count == 1 {
            playAtIndex(0)
            return
        }
        // Use the same decision as pre-download, whether or not pre-download is enabled.
        guard let next = getNextPlayMusic() else { return }
        if MusicConfigManager.shared.orderType == .random, let round = preparedShuffleMusic() {
            musicArray = round
            pendingShuffleRound = nil
        }
        guard let index = musicArray.firstIndex(where: { $0.uniqueID() == next.uniqueID() }) else { return }
        playAtIndex(index)
    }
    
    // 播放某首歌
    @MainActor func playAtIndex(_ index: Int) {
        self.nextPlayMusic = nil
        self.pendingShuffleRound = nil
                
        var model: MusicItemModel?
        if index >= 0 && (index < musicArray.count) {
            model = self.musicArray[index]
        }else{
            model = self.musicArray.first
        }
        
        retirePlayback()
        guard let model else {
            resetToPausedDemo(clearRemotePlaylist: false)
            return
        }
        self.playingMusic = model
        
        MusicConfigManager.shared.lastPlayTime = 0
        
        self.play()
    }
    
    
}

extension KakaMusicPlayer {
    
    // 设置定时器
    @MainActor func setupSleepTimer() {
        guard let sleepTime = MusicConfigManager.shared.sleepTime else {
            self.sleepTimer.stopTimer()
            MusicConfigManager.shared.sleepTime = nil
            self.sleepTime = 0
            return
        }
        
        var time: TimeInterval = sleepTime
        self.sleepTimer.startTimer(seconds: 1, repeats: true, callSoon: true) { [weak self] vTimer in
            time -= 1
            
            if time <= 0 {
                self?.pause()
                MusicConfigManager.shared.sleepTime = nil
                self?.sleepTimer.stopTimer()
                self?.sleepTime = 0
            }else{
                self?.sleepTime = time
            }
            
        }
    }
    
    /// Mac设置本地通知提醒
    func setupLocalNotification(_ model: MusicItemModel) {
        guard kaka_IsMacOS() else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if !granted { return }
            
            let content = UNMutableNotificationContent()
            content.title = model.showTitleName()
            content.body = model.showArtistName()
            content.sound = nil

            // 设置触发器：立即触发（1 秒后）
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            let request = UNNotificationRequest(identifier: "wake_music_push", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request)
        }
    }
    
}
