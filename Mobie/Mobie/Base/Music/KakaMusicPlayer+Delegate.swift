//
//  KakaMusicPlayer+Delegate.swift
//  Mobie
//
//  Created by 张文 on 9/23/24.
//

import KakaFoundation
import AppGroupKit
import KSPlayer
import MediaPlayer
import StoreKit
import Kingfisher
import KakaTaglibKit
import Alamofire


extension KakaMusicPlayer: @preconcurrency PlayerControllerDelegate {
    
    public func playerController(maskShow: Bool) {
        
    }
    
    public func playerController(action: KSPlayer.PlayerButtonType) {
        
    }
    
    public func playerController(bufferedCount: Int, consumeTime: TimeInterval) {
        
    }
    
    public func playerController(seek: TimeInterval) {
        self.lastUpdateTime = 0
    }
    
    // 时间
    @MainActor public func playerController(currentTime: TimeInterval, totalTime: TimeInterval) {
                
        if !self.isPlaying { return }
        
        var timeSpace = MusicConfigManager.shared.lyricConfig.isLowPowerMode ? 0.5 : 0.25
        if UIApplication.shared.applicationState == .background {
            timeSpace = 1
        }
        
        let interval = currentTime - self.lastUpdateTime
        if interval < timeSpace { return } // 限制更新频率为每 \timeSpace\ 秒
        
        self.totalTime = totalTime
        self.currentTime = currentTime
        self.lastUpdateTime = currentTime
        
//        debugPrint("currentTime = \(currentTime), totalTime = \(totalTime)")
        
        if var playingMusic = self.playingMusic, totalTime > 0, MusicConfigManager.shared.lastTotalTime != totalTime, MusicConfigManager.shared.isLastCache {
            playingMusic.durationSeconds = Int(totalTime)
            MusicConfigManager.shared.lastPlayModel = playingMusic
            
            MusicConfigManager.shared.lastPlayTime = currentTime
            MusicConfigManager.shared.lastTotalTime = totalTime
            
//            debugPrint("currentTime2 = \(currentTime), totalTime2 = \(totalTime)")
        }
                
        if let model = self.playingMusic, let navSong = model.navidromeSong, totalTime == 0 {
            let total = TimeInterval(navSong.duration)
            self.updateControlPlayTime(currentTime: currentTime, totalTime: total)
        }else{
            self.updateControlPlayTime(currentTime: currentTime, totalTime: totalTime)
        }
        
    }
    
    @MainActor public func playerController(state: KSPlayer.KSPlayerState) {
        debugPrint("播放状态 = \(state)")
        
        self.playbackStatus = state
        
        if state == .playedToTheEnd {
            self.currentTime = 0
            if MusicConfigManager.shared.orderType == .single {
                self.perform(#selector(replaySingleItem), with: nil, afterDelay: 0.0)
            }else{
                self.perform(#selector(playNextItem), with: nil, afterDelay: 0.0)
            }
        }
        
        if state == .readyToPlay {
            self.isRetry = false
            
            if self.isDecodingError && UserInfoManager.shared.isVIP() {
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 3) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: windowScene)
                    }
                }
            }
            
            self.isDecodingError = false
        }
        
        if state != .bufferFinished { return }
        
        // 加载完成后的2件事：1️⃣预加载下一首歌；2️⃣解析当前歌曲内嵌的封面和歌词
        self.perform(#selector(self.prepareNextMusic), with: nil, afterDelay: 1)
                        
        guard let playingMusic = self.playingMusic else { return }
        
        // 本地文件无需解析内嵌的元数据
        if playingMusic.isLocalFile() || playingMusic.mediaPlayURL.hasDirectoryPath {
            debugPrint("本地文件不需要解析元数据")
            return
        }
        
        // 非VIP只能在试用期间体验歌词和封面解析能力
        if !UserInfoManager.shared.isVIP() && !UserInfoManager.shared.isFreeTrail3Days_Remote() {
            debugPrint("不是VIP，并且已经过了三天试用期")
            return
        }

        // 读取远程文件的元数据
        DispatchQueue.main.async {
            guard let player = self.playerView.playerLayer?.player else { return }
            
            if player.dynamicInfo.metadata.keys.count > 0 { // 1️⃣ 直接就可以读取的元数据
                debugPrint("ffmpeg元数据：\(playingMusic.showTitleName()) = \(player.dynamicInfo.metadata)")
                let audioTracks = (player.audioTracks as? [FFmpegAssetTrack]) ?? []
            
                let infoModel = VideoInfo(duration: self.totalTime, fileSize: 0, metadata: player.dynamicInfo.metadata, assetTracks: audioTracks)
                self.handleAudioMetadata(infoModel)
                Task {
                    if let cgImage = await player.thumbnailImageAtCurrentTime() {
                        let coverImage = UIImage(cgImage: cgImage)
                        self.saveCacheCoverImage(coverImage: coverImage, musicModel: playingMusic)
                    }
                }
            }else{ // 2️⃣ 可能是AVPlayer或者百度的m3u文件
                // 1、百度网盘，只有是m3u时需要获取下载地址
                if let baiduFile = playingMusic.baiduFileModel, let access_token = baiduFile.baiduUser?.access_token, FileManager.default.fileExists(atPath: baiduFile.m3uCacheURL().path) {
                    
                    self.fetchBaiduDownloadURL(accessToken: access_token, fileModel: baiduFile) { result in
                        switch result {
                        case .success(let downloadURL):
                            self.ffmpegGetMetadata(downloadURL: downloadURL, playingMusic: playingMusic)
                        case .failure(let failure):
                            debugPrint("提取元数据 = \(failure)")
                        }
                    }
                }else{
                    self.ffmpegGetMetadata(downloadURL: playingMusic.mediaPlayURL, playingMusic: playingMusic)
                }
            }
        }
        
    }
    
    // 失败处理
    public func playerController(finish error: (any Error)?) {
        guard let error = error, let playingModel = self.playingMusic else { return }
        
        if self.isRetry {
            let message = error.localizedDescription
            self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: message, confirm: "Done".localStr())
            return
        }
        
        var isDecodingError: Bool = false // 是否播放引擎的问题
        
        if let avError = error as? AVError {
            switch avError.code {
            case .fileFormatNotRecognized, .decodeFailed, .decoderNotFound:
                isDecodingError = true
            default: break
            }
        }
        
        if let nsError = error.nsError {
            if nsError.code == -12865 { // 百度网盘的m3u格式文件
                isDecodingError = true
            }
        }
        
        self.isDecodingError = isDecodingError
        
        if isDecodingError && MusicConfigManager.shared.playerEngine == .avPlayer {
            self.currentViewController()?.showOneAlert(title: "Reminder".localStr(), message: "The system's built-in AVPlayer can't decode this format. Please switch the Player Engine.".localStr(), confirm: "OK".localStr()) {
                let navVC = KakaNavigationController(rootViewController: PlayerEngineViewController())
                navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
                self.currentViewController()?.present(navVC, animated: true)
            }
        }else{
            if let ksError = error as? KSPlayerError, ((ksError.message?.contains("permitted")) != nil), kaka_IsMacOS(), playingModel.isLocalFile() {
                self.handleFilePermission(error.localizedDescription)
            }else if (error as NSError).code == 257 && playingModel.isLocalFile() && kaka_IsMacOS() {
                self.handleFilePermission(error.localizedDescription)
            }
            else{
                debugPrint("播放失败 = \(error):\(self.playingMusic!.mediaPlayURL)")
                DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) { [weak self] () in
                    self?.isRetry = true
                    self?.play()
            }
        }
    }
        
    }
    
}

extension KakaMusicPlayer {
    
    /// 使用ffmpeg提取远程文件内嵌的元数据和封面
    func ffmpegGetMetadata(downloadURL: URL, playingMusic: MusicItemModel) {
        
        DispatchQueue.main.async {
            let currentOption = self.audioOption(playingMusic)
            KSOptions.firstPlayerType = KSMEPlayer.self
            currentOption.playerTypes = [KSMEPlayer.self]
            
            DispatchQueue.global().async {
                do {
                    let metadata = try FFmpegUtility.getMetadata(for: downloadURL, options: currentOption)
                    debugPrint("ffmpeg元数据 = \(metadata.metadata), 封面宽 = \(metadata.coverImage?.width ?? 0)")
                    DispatchQueue.main.async {
                        self.handleAudioMetadata(metadata)
                        if let cgImage = metadata.coverImage {
                            let coverImage = UIImage(cgImage: cgImage)
                            self.saveCacheCoverImage(coverImage: coverImage, musicModel: playingMusic)
                        }
                    }
                } catch {
                    debugPrint("提取元数据失败 = \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 保存封面图
    func saveCacheCoverImage(coverImage: UIImage?, musicModel: MusicItemModel) {
                        
        // 写入沙盒封面并清理缓存
        SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: coverImage) { vURL in
            ImageCache.default.clearMemoryCache()
            
            // 更新播放信息（触发封面刷新）
            let newModel = KakaMusicPlayer.shared.playingMusic
            KakaMusicPlayer.shared.playingMusic = newModel
            
            self.cacheCoverImage = coverImage
            self.updateNowPlayingInfo(musicModel: newModel)
            
        } fail: { error in
            debugPrint("写入封面失败 = \(error.localizedDescription)")
        }
    }

    
    // 处理内嵌元数据
    @MainActor func handleAudioMetadata(_ infoModel: VideoInfo) {
        guard var playingMusic = self.playingMusic else { return }
                
        let titleKeys = ["title", "TITLE", "Title"]
        let artistKeys = ["artist", "ARTIST", "Artist"]
        let albumKeys = ["album", "ALBUM", "Album", "album_artist", "album_name"]
        let yearKeys = ["date", "Date", "DATE", "year", "Year", "YEAR", "release_year", "ReleaseYear", "releaseYear"]
        let genreKeys = ["genre", "Genre", "GENRE", "style", "Style", "STYLE", "music_genre", "MusicGenre", "genre_type", "GenreType"]
        let trackKeys = ["track", "Track", "TRACK", "track_number", "TrackNumber"]
        let lyricKeys = ["lyrics", "Lyrics", "LYRICS", "©lyr", "uslt", "lyric", "LYRIC", "Lyric", "lyrics-XXX"]
        
        
        // 歌词
        if playingMusic.lyricModel == nil {
            for (key, value) in infoModel.metadata {
                // 忽略大小写匹配
                if lyricKeys.contains(where: { key.localizedCaseInsensitiveContains($0) }) {
                    let ocModel = TaglibMetadataParser.parseSynchronizedLyrics(value)
                    playingMusic.lyricModel = ocModel?.convertSwiftModel()
                    break
                }
            }
        }
        
        // 标题
        if playingMusic.title == nil {
            for key in titleKeys {
                if let title = infoModel.metadata[key] {
                    playingMusic.title = title
                    break // 找到后立即退出循环
                }
            }
        }
        
        // 艺术家
        if playingMusic.artist == nil {
            for key in artistKeys {
                if let artist = infoModel.metadata[key] {
                    playingMusic.artist = artist
                    break // 找到后立即退出循环
                }
            }
        }
        
        // 专辑
        if playingMusic.album == nil {
            for key in albumKeys {
                if let album = infoModel.metadata[key] {
                    playingMusic.album = album
                    break
                }
            }
        }
        
        // 流派
        if playingMusic.genre == nil {
            for key in genreKeys {
                if let genre = infoModel.metadata[key] {
                    playingMusic.genre = genre
                    break
                }
            }
        }
        
        // 音轨号
        if playingMusic.track == nil {
            for key in trackKeys {
                if let track = infoModel.metadata[key] {
                    playingMusic.track = Int(track)
                    break
                }
            }
        }
        
        // 年代
        if playingMusic.year == nil {
            for key in yearKeys {
                if let year = infoModel.metadata[key] {
                    if year.count > 4 {
                        let yearString = year.prefix(4)
                        playingMusic.year = Int(yearString)
                    }else{
                        playingMusic.year = Int(year)
                    }
                    break
                }
            }
        }
        
        // 注释
        if playingMusic.comment == nil {
            playingMusic.comment = infoModel.metadata["comment"]
        }
        
        
        
        // 比特率
        if playingMusic.bitrate == nil || playingMusic.bitrate == 0 {
            if let bitRate = infoModel.assetTracks.first?.bitRate, bitRate > 0 {
                playingMusic.bitrate = Int(bitRate)
                debugPrint("比特率 = \(bitRate)")
            }
        }
        
        // 采样率
        if playingMusic.sampleRate == nil || playingMusic.sampleRate == 0 {
            if let audioStream = infoModel.assetTracks.first?.audioStreamBasicDescription, audioStream.mSampleRate > 0 {
                playingMusic.sampleRate = Int(audioStream.mSampleRate)
                debugPrint("采样率 = \(audioStream.mSampleRate)")
            }
        }
        
        // 位深度
        if playingMusic.bitDepth == nil || playingMusic.bitDepth == 0 {
            if let bitDepth = infoModel.assetTracks.first?.bitDepth, bitDepth > 0 {
                playingMusic.bitDepth = Int(bitDepth)
                debugPrint("位深度 = \(bitDepth)")
            }
        }
        
        if playingMusic.lyricModel == nil {
            KakaMusicPlayer.shared.playingMusic = playingMusic
            self.fetchLrcLyricContent()
        }else{
            ConnectConfigManager.shared.addOrUpdateRemotePlaylist(musics: [playingMusic]) {
                KakaMusicPlayer.shared.playingMusic = playingMusic
            }
        }
        
    }
    
    // 查找歌词库、同名文件夹下的LRC文件
    func fetchLrcLyricContent() {
        guard let model = self.playingMusic, model.lyricModel?.lyrics == nil else { return }
        var tempFileURL: URL?
        
        if let webFileModel = model.webFileModel {
            tempFileURL = webFileModel.getSameNameLRCFilePath()
        }else{
            tempFileURL = SandboxFileManager.shared.getSameNameLRCFilePath(model)
        }
        
        guard let lyricFileURL = tempFileURL else { return }
        
        if lyricFileURL.isFileURL {
            if let lyricStr = lyricFileURL.readLRCContentStr() {
                self.setLyricContent(lyricStr)
            }
        }else{
            let targetFileURL = SandboxFileManager.shared.lyricsPathURL().appendingPathComponent(model.filePathName() + ".lrc")

            let destination: DownloadRequest.Destination = { _, response in
                return (targetFileURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            
            AF.download(lyricFileURL, to: destination).downloadProgress { progressValue in
                debugPrint("下载歌词进度 = \(progressValue.fractionCompleted)")
              }.responseURL { response in
                switch response.result {
                case .success(let fileURL):
                    if let lyricStr = fileURL.readLRCContentStr() {
                        self.setLyricContent(lyricStr)
                    }
                    break
                case .failure(let error):
                    debugPrint("下载LRC歌词 = \(error.localizedDescription)")
                    break
                }
            }
        }
        
    }
    
    // 内嵌到歌词
    private func setLyricContent(_ content: String) {
        guard var model = self.playingMusic else { return }
        
        if !model.mediaPlayURL.isFileURL { return }
        
        model.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content).convertSwiftModel()
        
        KakaMusicPlayer.shared.playingMusic = model
        
        let success = TaglibMetadataParser.setLyris(content, toFileURL: model.mediaPlayURL)
        if success {
            appKeyWindow?.makeToast("The LRC lyrics file of the same name has been automatically embedded into the music file.".localStr())
        }else{
            appKeyWindow?.makeToast("Matched LRC lyrics files with the same name".localStr())
        }
    }
    
    /// 处理文件无权限的问题
    private func handleFilePermission(_ errorMsg: String?) {
        
        let alertController = UIAlertController(title: errorMsg ?? "Reminder".localStr(), message: "App Store apps can only access the authorized [Music] folder. Please move these files to the Music folder. Otherwise, you must clear the inaccessible cached paths and re-import files upon every launch.".localStr(), preferredStyle: .alert)
        let action1 = UIAlertAction(title: "Clear Cache for This Folder".localStr(), style: .destructive) { [weak self] (sender) in
            guard let mediaPlayURL = self?.playingMusic?.mediaPlayURL else { return }
            AppLocalManager.shared.removeCachePath(path:mediaPlayURL.path) {
                self?.currentViewController()?.showOneAlert(message: "Cached paths cleared. To avoid repetitive actions, it is recommended to move your frequently used files to the system 【Music/Wake Music】 folder.".localStr()) {
                    self?.showInFinderCatalyst(SandboxFileManager.shared.basePublicFileURL())
                    self?.currentViewController()?.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
        let action2 = UIAlertAction(title: "Clear All Cache".localStr(), style: .destructive) { [weak self] (sender) in
            AppLocalManager.shared.cachePathArray = []
#if targetEnvironment(macCatalyst)
            AppLocalManager.shared.bookmarkDataArray = []
#endif
            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            self?.currentViewController()?.showOneAlert(message: "Cached paths cleared. To avoid repetitive actions, it is recommended to move your frequently used files to the system 【Music/Wake Music】 folder.".localStr()) {
                self?.showInFinderCatalyst(SandboxFileManager.shared.basePublicFileURL())
                self?.currentViewController()?.navigationController?.popToRootViewController(animated: true)
            }
        }
        let action3 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        
        action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action3.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.currentViewController()?.present(alertController, animated: true, completion: nil)
    }
    
    
}
