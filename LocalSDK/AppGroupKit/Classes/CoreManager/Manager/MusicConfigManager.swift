//
//  MusicConfigManager.swift
//  AppGroupKit
//
//  Created by 张文 on 10/23/24.
//

import KakaFoundation
import SmartCodable
import AVFAudio



public class MusicConfigManager: ObservableObject, SmartCodableX {
    
    required public init() {}
    
    static public var shared = MusicConfigManager.read() ?? MusicConfigManager()
    
    /// App内部的音量（0--1）
    @SmartPublished
    public var volume: Float = AVAudioSession.sharedInstance().outputVolume {
        didSet {
            save()
        }
    }
    
    /// 分组方式
    @SmartPublished
    public var groupType = GroupItemType.titleGroup {
        didSet {
            save()
        }
    }
    
    /// 排序方式
    @SmartPublished
    public var sortType = SortedbyType.fileName {
        didSet {
            save()
        }
    }
    
    /// 排序：默认为升序
    public var isSortAscending: Bool = true {
        didSet {
            save()
        }
    }
    
    /// 显示扩展名
    @SmartPublished
    public var isShowExtension: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 屏幕歌词顺序
    @SmartPublished
    public var lyricSortStyle: LyricSortStyle = .dontShow {
        didSet {
            save()
        }
    }
    
    /// 播放器内核
    public var playerEngine: PlayerEngineType = UserInfoManager.shared.isPremium() ? .wakePlayer : .avPlayer {
        didSet {
            save()
            NotificationCenter.default.post(name: Notification.Name(rawValue: kPlayerEngineChangedKey), object: nil)
        }
    }
    
    /// 后台播放模式
    @SmartPublished
    public var playMode = MusicPlayMode.music {
        didSet {
            save()
        }
    }
    
    /// 睡眠计时器（秒）
    @SmartPublished
    public var sleepTime: TimeInterval? = nil {
        didSet {
            save()
        }
    }
    
    /// 是否转码
    @SmartPublished
    public var isTranscoding: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 最大比特率
    @SmartPublished
    public var navMaxBitRate = NavidromeMaxBitRate.bitRate0 {
        didSet {
            save()
        }
    }
    
    /// 转码格式
    @SmartPublished
    public var navFormats = NavidromeTargetFormat.raw {
        didSet {
            save()
        }
    }
    
    /// 歌词字体配置
    @SmartPublished
    public var lyricConfig = LyricConfigModel() {
        didSet {
            save()
        }
    }
    
    /// 播放速度
    @SmartPublished
    public var playRate: Float = 1 {
        didSet {
            save()
        }
    }
    
    /// 播放顺序
    @SmartPublished
    public var orderType: PlaybackOrderType = .normal {
        didSet {
            save()
        }
    }
    
    /// 上一次播放的歌曲
    @SmartPublished
    public var lastPlayModel: MusicItemModel? {
        didSet {
            save()
        }
    }
    
    /// 上一次播放的时间
    @SmartPublished
    public var lastPlayTime: TimeInterval = 0 {
        didSet {
            save()
        }
    }
    
    /// 上一次的总时间
    @SmartPublished
    public var lastTotalTime: TimeInterval = 0 {
        didSet {
            save()
        }
    }
    
    /// 显示缺失的标签
    @SmartPublished
    public var isShowMissTag = true {
        didSet {
            save()
        }
    }
    
    /// 记录上次播放进度
    @SmartPublished
    public var isLastCache = false {
        didSet {
            save()
        }
    }
    
    /// 是否自动裁剪最后3秒
    @SmartPublished
    public var isAutoCrop: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 上次选择的音频格式
    @SmartPublished
    public var lastAudioFormat: AudioFormatEnum = AudioFormatEnum.alac {
        didSet {
            save()
        }
    }
    
    /// 是否开启预加载缓存
    @SmartPublished
    public var isPreDownload = true {
        didSet {
            save()
        }
    }
    
    /// 预加载缓存大小
    @SmartPublished
    public var preDownloadSize = PreDownloadSize.GB8 {
        didSet {
            save()
        }
    }
    
    /// 播放器背景配置
    @SmartPublished
    public var playbackModel = PlayBackgroundModel.init() {
        didSet {
            save()
        }
    }
    
    /// 播放器样式
    @SmartPublished
    public var playerStyle = kaka_IsiPhone() ? PlayerUIStyle.defaultRect : PlayerUIStyle.defaultCircle {
        didSet {
            save()
        }
    }
}

extension MusicConfigManager {
    private class func Kaka_Music_Config_Key() -> String {
        return "Music_Config_Key"
    }
    
    private class func read() -> MusicConfigManager? {
        let key = MusicConfigManager.Kaka_Music_Config_Key()
        let sharedUD = UserDefaults.standard
        guard let json = sharedUD.string(forKey: key) else { return nil }
          
        let model = MusicConfigManager.deserialize(from: json)
        return model
    }
    
    private func save() {
        let json = self.toJSONString()
        let sharedUD = UserDefaults.standard
        sharedUD.set(json, forKey: MusicConfigManager.Kaka_Music_Config_Key())
        sharedUD.synchronize()
    }
    
    public class func reset() {
        let key = MusicConfigManager.Kaka_Music_Config_Key()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        MusicConfigManager.shared = MusicConfigManager()
    }
    
}
