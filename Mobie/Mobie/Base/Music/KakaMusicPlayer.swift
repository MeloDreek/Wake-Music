//
//  KakaMusicPlayer.swift
//  Wakemusic
//
//  Created by Melo on 7/26/24.
//

import KakaFoundation
import AppGroupKit
import KSPlayer
import AVFAudio
import MediaPlayer
import PanModal
import KakaTaglibKit
import Combine
import Alamofire


/// 音乐播放器
public class KakaMusicPlayer: NSObject, ObservableObject {
    
    static let shared = KakaMusicPlayer()
    
    override init() {
        
        super.init()
        
        let lastMusic = UserDefaults.standard.dictionary(forKey: "kLastPlayMusic")
        self.playingMusic = MusicConfigManager.shared.lastPlayModel ?? MusicItemModel.deserialize(from: lastMusic)
        if self.playingMusic?.fileSourceType == .demoFile {
            self.playingMusic = MusicItemModel.demoMusicModel()
        }
        UserDefaults.standard.removeObject(forKey: "kLastPlayMusic")
                
        self.setupAudioCategory()
        self.addNotiFacation()
    }
    
    func setupAudioCategory() {
        KSOptions.setAudioSession()
    }
    
    // 下一首歌曲
    var nextPlayMusic: MusicItemModel?
    
    /// 是否为失败后的重试
    public var isRetry: Bool = false
    
    /// 是否解码失败
    public var isDecodingError: Bool = false
    
    /// 正在播放的音乐列表
    @Published var musicArray: [MusicItemModel] = []
    {
        didSet {
            debugPrint("播放列表 = \(self.musicArray.count)")
            let old = oldValue
            // 用 uniqueID 去重
            let deduped = self.removeDuplicate(musicArray)

            if deduped != old {
                // 只在真正变化时更新一次，防止 didSet 无限调用
                if deduped != musicArray {
                    self.musicArray = deduped
                }
            }
        }
    }
    
    func removeDuplicate(_ list: [MusicItemModel]) -> [MusicItemModel] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.uniqueID()).inserted }
    }
    
    // 播放列表最初的排序
    var tempMusicArray: [MusicItemModel] = []
    
    /// Invalidates pending pCloud/Box link requests on play/pause/stop.
    var pcloudPlaybackRequestID = UUID()

    var remoteMetadataTask: Task<Void, Never>?
    var remoteMetadataGeneration = UUID()
    var remoteMetadataAttempted = false

    /// 正在播放中的音乐
    @Published var playingMusic: MusicItemModel? {
        didSet {
            if oldValue?.uniqueID() != playingMusic?.uniqueID() || oldValue?.mediaPlayURL != playingMusic?.mediaPlayURL {
                remoteMetadataTask?.cancel()
                remoteMetadataTask = nil
                remoteMetadataGeneration = UUID()
                remoteMetadataAttempted = false
            }
            guard let playingMusic = self.playingMusic else { return }
                        
            self.lastUpdateTime = 0
            self.cacheCoverImage = nil
            
            if playingMusic.isLocalFile() { // 当前音乐为本地的，下一首以防下一首歌是远程的，置空
                self.nextPlayMusic = nil
            }
            
            MusicConfigManager.shared.lastPlayModel = playingMusic
                        
            if let coverImage = playingMusic.musicCoverImage() {
                self.cacheCoverImage = coverImage
            }
        }
    }
    
    /// 当前播放状态
    @Published var playbackStatus: KSPlayerState = .error
    
    /// 当前播放的时间
    @Published var currentTime: TimeInterval = 0
    
    /// 当前播放的总时间
    @Published var totalTime: TimeInterval = 0
    
    /// 睡眠计时器
    @Published var sleepTime: TimeInterval = 0
    
    /// 播放速度
    @MainActor var playbackRate: Float = MusicConfigManager.shared.playRate {
        didSet {
            
            if let baiduFile = self.playingMusic?.baiduFileModel, FileManager.default.fileExists(atPath: baiduFile.m3uCacheURL().path) {
                self.playerView.playerLayer?.player.playbackRate = 1
                return
            }
            
            self.playerView.playerLayer?.player.playbackRate = playbackRate
        }
    }
    
    /// 是否正在播放
    @MainActor var isPlaying: Bool {
        get {
            return self.playerView.playerLayer?.player.isPlaying ?? false
        }
    }
    
    /// 当前播放进度
    @MainActor var playProgress: Float {
        get {
            return Float(self.playerView.playerLayer?.player.progress ?? 0)
        }
    }
    
    var cancellables = Set<AnyCancellable>()
    
    /// 缓存中的封面
    var cacheCoverImage: UIImage?
    
    lazy var playerView: AudioPlayerView = {
        let view = AudioPlayerView()
        view.delegate = self
        return view
    }()
    
    lazy var sleepTimer: KakaTimer = {
        return KakaTimer()
    }()
    
    // 缓解时间回调
    var lastUpdateTime: TimeInterval = 0
    
    @MainActor func audioOption(_ model: MusicItemModel) -> KSOptions {
        KSOptions.canBackgroundPlay = true
        KSOptions.logLevel = .error
        
        let option = KSOptions.init()
        option.isAutoPlay = true // 一设置url就会播放
        option.isSeekedAutoPlay = true
        option.isAccurateSeek = false
        option.isSecondOpen = true
        option.registerRemoteControll = false
        option.maxBufferDuration = 30
        option.preferredForwardBufferDuration = 30
        option.seekUsePacketCache = true
        option.startPlayRate = self.playbackRate
        
        if let _ = model.drive115Model {
            let userAgent = HTTPHeader.defaultUserAgent.description
            debugPrint("播放时的User-Agent = \(userAgent)")
            option.userAgent = userAgent
            
            option.appendHeader(HTTPHeaders.default.dictionary)
            debugPrint("播放时的header = \(HTTPHeaders.default.dictionary.description)")
        }
        
        if let googleFile = model.googleFile, let googleUser = googleFile.googleUser {
            debugPrint("谷歌配置信息 = \(googleUser.toJSONString() ?? "")")
            option.appendHeader(["Authorization": "Bearer \(googleUser.accessToken)"])
        }
        
        let isPlaylist = model.mediaPlayURL.pathExtension.contains("m3u")
        option.formatContextOptions["protocol_whitelist"] = isPlaylist ?  "file,http,https,tcp,tls,crypto,async,cache,data,httpproxy" : nil
        
//        KSOptions.audioPlayerType = AudioEnginePlayer.self
        
        if model.mediaPlayURL.scheme == "ipod-library" {
            KSOptions.firstPlayerType = KSAVPlayer.self
            KSOptions.secondPlayerType = KSMEPlayer.self
            option.playerTypes = [KSAVPlayer.self, KSMEPlayer.self]
        }else if model.fileSourceType == .demoFile {
            KSOptions.firstPlayerType = KSMEPlayer.self
            KSOptions.secondPlayerType = KSAVPlayer.self
            option.playerTypes = [KSMEPlayer.self, KSAVPlayer.self]
        }else{
            // 一些特殊情况，强制使用全格式引擎：1️⃣VIP后台播放时；2️⃣百度网盘m3u时
            let isVipBackPlaying = UIApplication.shared.applicationState == .background && UserInfoManager.shared.isVIP()
            let isPlaying115 = model.fileSourceType == .from115Drive || model.drive115Model != nil
            if isVipBackPlaying || isPlaylist || isPlaying115 {
                KSOptions.firstPlayerType = KSMEPlayer.self
                KSOptions.secondPlayerType = KSAVPlayer.self
                option.playerTypes = [KSMEPlayer.self, KSAVPlayer.self]
            }else{
                let playerEngine = MusicConfigManager.shared.playerEngine
                KSOptions.firstPlayerType = playerEngine.engineTypes().first ?? KSAVPlayer.self
                KSOptions.secondPlayerType = playerEngine.engineTypes().last ?? KSAVPlayer.self
                option.playerTypes = playerEngine.engineTypes()
            }
        }
        
        return option
    }
    
    /// 获取下一首歌
    private func getNextPlayMusic() -> MusicItemModel? {
        
        var model: MusicItemModel?
        let orderType = MusicConfigManager.shared.orderType
        let isRealRandom = MusicConfigManager.shared.randomType == .trueRandom
        
        switch orderType {
        case .normal, .random:
            if isRealRandom && orderType == .random {
                model = self.musicArray.randomElement()
            }else{
                if let index = self.musicArray.firstIndex(where: { $0 == self.playingMusic }) {
                    let nextIndex = index + 1
                    // 确保 nextIndex 没有越界
                    if nextIndex < self.musicArray.count {
                        model = self.musicArray[nextIndex]
                    } else {
                        model = self.musicArray.first
                    }
                }
            }
            break
        case .single:
            model = nil
            break
        }
        
        return model
    }
    
    // 预先下载下一首歌
    @MainActor
    @objc func prepareNextMusic() {
        
        if !MusicConfigManager.shared.isPreDownload { return }
        
        guard let nextPlayMusic = (self.getNextPlayMusic() ?? self.nextPlayMusic), !nextPlayMusic.isLocalFile() else { return }
        
        self.nextPlayMusic = nextPlayMusic
        
        let cacheFolderURL = SandboxFileManager.shared.preDownloadURL()
        
        let cachedFileURLArray = cacheFolderURL.readLocalSubFiles().sorted { fileURL1, fileURL2 in
            // 获取文件属性
            let attributes1 = try? FileManager.default.attributesOfItem(atPath: fileURL1.path)
            let attributes2 = try? FileManager.default.attributesOfItem(atPath: fileURL2.path)

            // 提取创建时间
            let creationDate1 = attributes1?[.creationDate] as? Date ?? Date.distantPast
            let creationDate2 = attributes2?[.creationDate] as? Date ?? Date.distantPast

            // 根据创建时间排序
            return creationDate1 < creationDate2
        }
        
        let documentURLArray = SandboxFileManager.shared.getAllSubFiles(SandboxFileManager.shared.basePublicFileURL())
        
        let allFileURLArray = cachedFileURLArray + documentURLArray
        let allFileNameArray = allFileURLArray.map { $0.lastPathComponent }
        
//        debugPrint("全部文件路径 = \(allFileURLArray)")
//        debugPrint("全部文件名称 = \(allFileNameArray)")
        
        if nextPlayMusic.pcloudFile != nil || nextPlayMusic.boxFile != nil {
            if SandboxFileManager.shared.getDownloadPlayURL(nextPlayMusic) != nil { return }
        } else if allFileNameArray.contains(nextPlayMusic.downloadPathName()) { return }
        
        let cachedMB = Double(cacheFolderURL.totalFileSize()) / 1024.0 / 1024.0
        let maxCacheMB = Double(MusicConfigManager.shared.preDownloadSize.rawValue) * 1000.0
        debugPrint("预加载下一首歌：已缓存 = \(cachedMB) MB, 最大缓存 = \(maxCacheMB) MB")
        if cachedMB > maxCacheMB, let firstURL = cachedFileURLArray.first {
            try? FileManager.default.removeItem(at: firstURL)
            debugPrint("删除最早的一个缓存 = \(firstURL.lastPathComponent)")
        }
        
        let fileName = (nextPlayMusic.pcloudFile == nil && nextPlayMusic.boxFile == nil) ? nextPlayMusic.downloadPathName() : nextPlayMusic.filePathName() + nextPlayMusic.addPathExtension()
        let targetFileURL = cacheFolderURL.appendingPathComponent(fileName)
        
        if let file = nextPlayMusic.boxFile {
            BoxDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let file = nextPlayMusic.pcloudFile {
            PCloudDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let baiduFile = nextPlayMusic.baiduFileModel, let accessToken = baiduFile.baiduUser?.access_token {
            // 1️⃣ 预下载百度网盘文件
            self.fetchBaiduDownloadURL(accessToken: accessToken, fileModel: baiduFile) { result in
                switch result {
                case .success(let downloadURL):
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nil)
                case .failure(let failure):
                    debugPrint("下载百度文件 = \(failure)")
                    break
                }
            }
        }else if let aliFileModel = nextPlayMusic.aliFileModel {
            // 2️⃣ 预下载阿里云盘文件
            self.fetchAliyunDownloadURL(fileModel: aliFileModel) { result in
                switch result {
                case .success(let downloadURL):
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nil)
                case .failure(let failure):
                    debugPrint("下载阿里云文件 = \(failure)")
                    break
                }
            }
        }else if let drive115 = nextPlayMusic.drive115Model {
            // 2️⃣ 预下载115网盘文件
            self.fetch115DownloadPlayURL(file115: drive115) { result in
                switch result {
                case .success(let downloadURL):
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nil)
                case .failure(let failure):
                    debugPrint("下载115文件 = \(failure)")
                    break
                }
            }
        }else if let dropboxFile = nextPlayMusic.dropboxFile {
            // 3️⃣ 预下载Dropbox的网盘文件
            self.fetchDropboxDownloadPlayURL(dropboxFile: dropboxFile) { result in
                switch result {
                case .success(let downloadURL):
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nil)
                case .failure(let failure):
                    debugPrint("预下载Dropbox文件 = \(failure)")
                    break
                }
            }
        }
        else{
            // webdav、nav、谷歌网盘、OneDrive
            self.download(downloadURL: nextPlayMusic.mediaPlayURL, targetFileURL: targetFileURL, model: nextPlayMusic)
        }
        
    }
    
    func download(downloadURL: URL, targetFileURL: URL, model: MusicItemModel?) {
        
        let destination: DownloadRequest.Destination = { _, response in
            return (targetFileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        var headers: HTTPHeaders = HTTPHeaders.default
        if let googleFile = model?.googleFile, let googleUser = googleFile.googleUser {
            headers.add(name: "Authorization", value: "Bearer " + googleUser.accessToken)
        }
        
        let request = AF.download(downloadURL, headers: headers, to: destination)
        if model?.pcloudFile != nil || model?.boxFile != nil { request.validate(statusCode: 200..<300) }
        request.downloadProgress { progressValue in
            debugPrint("下载进度 = \(progressValue.fractionCompleted)")
          }.responseURL { response in
            switch response.result {
            case .success(let fileURL):
                debugPrint("✅下一首歌下载完成 = \(fileURL)")
                break
            case .failure(let error):
                if model?.pcloudFile != nil || model?.boxFile != nil, response.fileURL == targetFileURL {
                    try? FileManager.default.removeItem(at: targetFileURL)
                }
                debugPrint("下载❌ = \(error)")
                appKeyWindow?.makeToast(error.errorDescription ?? error.localizedDescription)
                break
            }
        }
    }
    
}

extension KakaMusicPlayer {
    
    /// 删除一个音乐
    func removeOneMusicModel(_ model: MusicItemModel?) {
        guard let model = model else { return }
        
        guard let index = self.musicArray.firstIndex(where: {
            $0 == model
        }) else { return }
        
        self.musicArray.remove(at: index)
    }
    
    /// 更新播放列表的数据源
    func updateOneMusicModel(newModel: MusicItemModel?, oldFileName: String) {
        guard let newModel = newModel else { return }
        
        guard let index = self.musicArray.firstIndex(where: {
            $0.filePathName() == oldFileName
        }) else { return }
        
        self.musicArray[index] = newModel
    }
    
}


extension KakaMusicPlayer {
    /// 前往音乐播放器页面
    static func presentPlayController(fromVC: UIViewController) {
        
        let musicVC = MusicPlayerViewController()
        
        #if targetEnvironment(macCatalyst)
        
        var currentScene: UIScene?
        for scene in UIApplication.shared.connectedScenes {
            if let addScene = scene as? UIWindowScene {
                let configuration = addScene.session.configuration
                if configuration.name == "MainConfiguration" {
                    currentScene = scene
                }
                
                if configuration.name == "MusicPlayerViewController" {
                    return
                }
            }
        }
        
        let userActivity = NSUserActivity(activityType: "MusicPlayerViewController")

        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        
        if #available(macCatalyst 17.0, *) {
            let request = UISceneSessionActivationRequest(role: .windowApplication, userActivity: userActivity, options: options)
            UIApplication.shared.activateSceneSession(for: request) { error in
                appKeyWindow?.makeToast(error.localizedDescription)
            }
        } else {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: options) { error in
                appKeyWindow?.makeToast(error.localizedDescription)
            }
        }
        
        // 关闭当前主窗口
        guard let currentSession = currentScene?.session else { return }
        UIApplication.shared.requestSceneSessionDestruction(currentSession, options: nil, errorHandler: { error in
            print("关闭主窗口失败: \(error.localizedDescription)")
        })
                
        #else
        if kaka_IsiPhone() {
            fromVC.presentPanModal(musicVC)
        }else{
            musicVC.modalPresentationStyle = .custom
            musicVC.modalPresentationCapturesStatusBarAppearance = true
            musicVC.transitioningDelegate = PanModalPresentationDelegate.default
            
            fromVC.present(musicVC, animated: true)
        }
        #endif
    }
    
}
