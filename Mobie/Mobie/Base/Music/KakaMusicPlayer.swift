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
    var nextPlayMusic: MusicItemModel? {
        didSet {
            if oldValue?.preDownloadIdentity() != nextPlayMusic?.preDownloadIdentity() {
                DownloadManager.shared.cancelPreDownload()
            }
        }
    }
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
    
    /// Invalidates ALL provider callbacks on play/pause/stop, including replaying the same song.
    var playbackRequestID = UUID()
    var wantsPlayback = false
    var seekRequestID = UUID()
    var pendingSeekTime: TimeInterval?
    var isSeeking = false

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
            return wantsPlayback && (self.playerView.playerLayer?.player.isPlaying ?? false)
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
        // Resuming after a seek is owned by our request gate, not an old SDK callback.
        option.isSeekedAutoPlay = false
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
    
    // Pre-download uses the same cancellable executor as the manual queue.
    @MainActor
    @objc func prepareNextMusic() {
        guard MusicConfigManager.shared.isPreDownload, MusicConfigManager.shared.orderType != .single,
              let next = getNextPlayMusic(), !next.isLocalFile(),
              next.drive115Model?.isUnsupportedStreamingAudio != true else {
            nextPlayMusic = nil
            DownloadManager.shared.cancelPreDownload()
            return
        }
        nextPlayMusic = next
        DownloadManager.shared.preDownload(next)
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
