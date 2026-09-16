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
    private var activePreDownloads = Set<String>()
    private static let preDownloadFileQueue = DispatchQueue(label: "com.wakemusic.predownload.files", qos: .utility)
    
    override init() {
        
        super.init()
        
        let lastMusic = UserDefaults.standard.dictionary(forKey: "kLastPlayMusic")
        self.playingMusic = MusicConfigManager.shared.lastPlayModel ?? MusicItemModel.deserialize(from: lastMusic)
        // 旧版本的系统媒体库记录已不可用，不能把它恢复为本地文件或演示曲目。
        if self.playingMusic?.mediaPlayURL.scheme == "ipod-library" {
            self.playingMusic = nil
            MusicConfigManager.shared.lastPlayModel = nil
            MusicConfigManager.shared.lastPlayTime = 0
        }
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
    // Prepared once at a round boundary; preview/pre-download must not draw again.
    var pendingShuffleRound: [String]?
    
    /// 是否为失败后的重试
    public var isRetry: Bool = false
    
    /// 是否解码失败
    public var isDecodingError: Bool = false
    
    /// 正在播放的音乐列表
    @Published private(set) var queueItems: [MusicItemModel] = []
    var musicArray: [MusicItemModel] {
        get { queueItems }
        set {
            let items = removeDuplicate(newValue)
            if items.map({ $0.uniqueID() }) != queueItems.map({ $0.uniqueID() }) {
                nextPlayMusic = nil
                pendingShuffleRound = nil
            }
            // Normalize BEFORE publishing. A didSet correction publishes a duplicate snapshot
            // and can skip correction entirely when the normalized list equals the old list.
            queueItems = items
        }
    }
    
    func removeDuplicate(_ list: [MusicItemModel]) -> [MusicItemModel] {
        PlaybackQueue.unique(list, id: { $0.uniqueID() })
    }

    /// Restore once at cold launch; entering another shell or foregrounding a
    /// second window must not replace/re-sort an active playback queue.
    func restoreRemoteQueueIfNeeded() {
        guard musicArray.isEmpty, let current = playingMusic, !current.isLocalFile() else { return }
        let saved = ConnectConfigManager.shared.lastPlaylist
        let items = saved.contains(where: { $0.uniqueID() == current.uniqueID() }) ? saved : [current]
        musicArray = items
        tempMusicArray = items
    }
    
    // 播放列表最初的排序
    private var originalQueue: [MusicItemModel] = []
    var tempMusicArray: [MusicItemModel] {
        get { originalQueue }
        set { originalQueue = removeDuplicate(newValue) }
    }

    /// A drag is committed only against the exact queue/current song it started with.
    @MainActor
    func moveQueuedMusic(id: String, destination: Int, expectedIDs: [String], currentID: String?) -> Bool {
        guard MusicConfigManager.shared.orderType == .normal,
              PlaybackQueue.matchesSnapshot(musicArray, current: playingMusic?.uniqueID(),
                  expectedIDs: expectedIDs, expectedCurrent: currentID, id: { $0.uniqueID() }),
              let reordered = PlaybackQueue.moving(musicArray, current: currentID, source: id,
                  destination: destination, id: { $0.uniqueID() }) else { return false }
        nextPlayMusic = nil
        tempMusicArray = reordered
        musicArray = reordered
        return true
    }
    
    /// Invalidates pending pCloud/Box link requests on play/pause/stop.
    var pcloudPlaybackRequestID = UUID()

    var remoteMetadataTask: Task<Void, Never>?
    var remoteMetadataGeneration = UUID()
    var remoteMetadataAttempted = false

    /// 正在播放中的音乐
    @Published var playingMusic: MusicItemModel? {
        didSet {
            if oldValue?.uniqueID() != playingMusic?.uniqueID() {
                nextPlayMusic = nil
                pendingShuffleRound = nil
            }
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

        // KSPlayer's DEBUG system-proxy helper sets the process-wide http_proxy.
        // The MEGA/SMB bridge is on this device, not on that proxy's loopback host.
        // An explicit empty FFmpeg option overrides the environment for this URL only.
        if ["http", "https"].contains(model.mediaPlayURL.scheme?.lowercased() ?? ""),
           ["::1", "[::1]", "127.0.0.1", "localhost"].contains(model.mediaPlayURL.host?.lowercased() ?? "") {
            option.formatContextOptions["http_proxy"] = ""
        }
        
        if let _ = model.drive115Model {
            let userAgent = HTTPHeader.defaultUserAgent.description
            debugPrint("播放时的User-Agent = \(userAgent)")
            option.userAgent = userAgent
            
            option.appendHeader(HTTPHeaders.default.dictionary)
            debugPrint("播放时的header = \(HTTPHeaders.default.dictionary.description)")
        }
        
        if let file = model.yandexFile {
            option.appendHeader(YandexDriveService.shared.playbackHeaders(for: file, url: model.mediaPlayURL))
        }
        if let googleFile = model.googleFile, let googleUser = googleFile.googleUser {
            debugPrint("谷歌配置信息 = \(googleUser.toJSONString() ?? "")")
            option.appendHeader(["Authorization": "Bearer \(googleUser.accessToken)"])
        }
        
        let isPlaylist = model.mediaPlayURL.pathExtension.contains("m3u")
        option.formatContextOptions["protocol_whitelist"] = isPlaylist ?  "file,http,https,tcp,tls,crypto,async,cache,data,httpproxy" : nil
        
//        KSOptions.audioPlayerType = AudioEnginePlayer.self
        
        if model.fileSourceType == .demoFile {
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
    func getNextPlayMusic() -> MusicItemModel? {
        let nextID = PlaybackQueue.nextID(in: musicArray.map { $0.uniqueID() },
            current: playingMusic?.uniqueID(), shuffle: MusicConfigManager.shared.orderType == .random,
            pendingRound: &pendingShuffleRound)
        return musicArray.first { $0.uniqueID() == nextID }
    }

    func preparedShuffleMusic() -> [MusicItemModel]? {
        guard let pendingShuffleRound else { return nil }
        // Store identities, not stale model/temporary-URL snapshots captured by pre-download.
        let models = Dictionary(uniqueKeysWithValues: musicArray.map { ($0.uniqueID(), $0) })
        return pendingShuffleRound.compactMap { models[$0] }
    }

    /// Show the actual prepared next round when the current round is exhausted.
    func upcomingQueueMusic() -> [MusicItemModel] {
        if MusicConfigManager.shared.orderType == .random {
            _ = getNextPlayMusic()
            if let round = preparedShuffleMusic() {
                return round.filter { $0.uniqueID() != playingMusic?.uniqueID() }
            }
        }
        return PlaybackQueue.upcoming(musicArray, current: playingMusic?.uniqueID(), id: { $0.uniqueID() })
    }
    
    // 预先下载下一首歌
    @MainActor
    @objc func prepareNextMusic() {
        
        if !MusicConfigManager.shared.isPreDownload || MusicConfigManager.shared.orderType == .single { return }
        
        guard let nextPlayMusic = self.getNextPlayMusic(), !nextPlayMusic.isLocalFile() else { return }
        guard nextPlayMusic.drive115Model?.isUnsupportedStreamingAudio != true else { return }
        
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
        
        if SandboxFileManager.shared.getDownloadPlayURL(nextPlayMusic) != nil { return }
        if activePreDownloads.contains(nextPlayMusic.preDownloadIdentity()) { return }
        
        let cachedMB = Double(cacheFolderURL.totalFileSize()) / 1024.0 / 1024.0
        let maxCacheMB = Double(MusicConfigManager.shared.preDownloadSize.rawValue) * 1000.0
        debugPrint("预加载下一首歌：已缓存 = \(cachedMB) MB, 最大缓存 = \(maxCacheMB) MB")
        if cachedMB > maxCacheMB, let firstURL = cachedFileURLArray.first {
            try? FileManager.default.removeItem(at: firstURL)
            debugPrint("删除最早的一个缓存 = \(firstURL.lastPathComponent)")
        }
        
        let fileName = nextPlayMusic.downloadPathName()
        let targetFileURL = cacheFolderURL.appendingPathComponent(fileName)
        
        if let file = nextPlayMusic.smbFile {
            SMBDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let file = nextPlayMusic.megaFile {
            MEGADriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let file = nextPlayMusic.yandexFile {
            YandexDriveService.shared.fileSource(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let source) = result {
                    self.download(downloadURL: source.url, targetFileURL: targetFileURL, model: nextPlayMusic, additionalHeaders: source.headers)
                }
            }
        }else if let file = nextPlayMusic.pan123File {
            Pan123DriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let file = nextPlayMusic.guangyaFile {
            GuangyaDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self, self.nextPlayMusic?.uniqueID() == nextPlayMusic.uniqueID(),
                      MusicConfigManager.shared.isPreDownload else { return }
                if case .success(let url) = result {
                    self.download(downloadURL: url, targetFileURL: targetFileURL, model: nextPlayMusic)
                }
            }
        }else if let file = nextPlayMusic.boxFile {
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
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nextPlayMusic)
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
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nextPlayMusic)
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
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nextPlayMusic)
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
                    self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: nextPlayMusic)
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
    
    func download(downloadURL: URL, targetFileURL: URL, model: MusicItemModel?, additionalHeaders: [String: String] = [:]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.download(downloadURL: downloadURL, targetFileURL: targetFileURL, model: model, additionalHeaders: additionalHeaders)
            }
            return
        }
        guard let model = model, MusicConfigManager.shared.isPreDownload,
              nextPlayMusic?.preDownloadIdentity() == model.preDownloadIdentity(),
              SandboxFileManager.shared.getDownloadPlayURL(model) == nil else { return }
        let identity = model.preDownloadIdentity()
        guard activePreDownloads.insert(identity).inserted else { return }
        // Keep partial files outside the visible cache and preserve the format for TagLib.
        let stagingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("predownload-" + UUID().uuidString)
            .appendingPathExtension(targetFileURL.pathExtension)
        let destination: DownloadRequest.Destination = { _, response in
            return (stagingURL, [.createIntermediateDirectories])
        }
        
        var headers: HTTPHeaders = HTTPHeaders.default
        if let googleFile = model.googleFile, let googleUser = googleFile.googleUser {
            headers.add(name: "Authorization", value: "Bearer " + googleUser.accessToken)
        }
        
        additionalHeaders.forEach { headers.update(name: $0.key, value: $0.value) }
        let request = AF.download(downloadURL, headers: headers, to: destination)
        if model.yandexFile != nil {
            request.redirect(using: Redirector(behavior: .modify { _, redirect, _ in
                guard let url = redirect.url, YandexDriveAPI.validDownloadURL(url) else { return nil }
                return redirect
            }))
        }
        if model.pan123File != nil {
            request.redirect(using: Redirector(behavior: .modify { _, redirect, _ in
                guard let url = redirect.url, Pan123DriveAPI.validDownloadURL(url) else { return nil }
                return redirect
            }))
        }
        if model.guangyaFile != nil {
            request.redirect(using: Redirector(behavior: .modify { _, redirect, _ in
                guard let url = redirect.url, GuangyaDriveAPI.validDownloadURL(url) else { return nil }
                return redirect
            }))
        }
        request.validate(statusCode: 200..<300)
        request.downloadProgress { progressValue in
            debugPrint("下载进度 = \(progressValue.fractionCompleted)")
          }.responseURL { response in
            switch response.result {
            case .success(let fileURL):
                Self.preDownloadFileQueue.async {
                    defer {
                        try? FileManager.default.removeItem(at: stagingURL)
                        DispatchQueue.main.async { self.activePreDownloads.remove(identity) }
                    }
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                        guard (attributes[.size] as? NSNumber)?.int64Value ?? 0 > 0 else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        let metadata = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .basic)
                        _ = try PreDownloadedAudioFile.store(fileURL, in: targetFileURL.deletingLastPathComponent(),
                                                            title: metadata?.title, artist: metadata?.artist,
                                                            originalName: model.downloadPathName(), identity: identity)
                    } catch {
                        DispatchQueue.main.async { appKeyWindow?.makeToast(error.localizedDescription) }
                    }
                }
            case .failure(let error):
                self.activePreDownloads.remove(identity)
                try? FileManager.default.removeItem(at: stagingURL)
                appKeyWindow?.makeToast(error.localizedDescription)
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
