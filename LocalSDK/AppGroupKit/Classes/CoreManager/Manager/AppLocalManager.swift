//
//  AppLocalManager.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/1.
//

import KakaFoundation
import SmartCodable
import NVActivityIndicatorView

public enum AppearanceStyle: Int, SmartCaseDefaultable {
    case auto = 0
    case light = 1
    case dark = 2
}

public enum PlayAnimationType: Int, SmartCaseDefaultable {
    case animation0 = 31
    case animation1 = 19
    case animation2 = 14
    case animation3 = 16
    case animation4 = 20
    
    public func nvType() -> NVActivityIndicatorType {
        switch self {
        case .animation0:
            return NVActivityIndicatorType.ballScaleMultiple
        case .animation1:
            return NVActivityIndicatorType.audioEqualizer
        case .animation2:
            return NVActivityIndicatorType.lineScalePulseOutRapid
        case .animation3:
            return NVActivityIndicatorType.lineScalePulseOut
        case .animation4:
            return NVActivityIndicatorType.lineScale
        }
    }
}

public class AppLocalManager: SmartCodableX, ObservableObject {
    
    required public init() {
        let _ = self.refreshCachePaths()
    }
    
    static public var shared = AppLocalManager.read() ?? AppLocalManager()
            
    /// 是否创建了本地通知
    @SmartPublished
    public var isRegisterLocalPush: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 是否第一次启动
    @SmartPublished
    public var isFirstLaunch: Bool = true {
        didSet {
            save()
        }
    }
    
    /// 是否领取了优惠
    @SmartPublished
    public var isReceiveOffer: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 删除引导好评
    @SmartPublished
    public var isDeleteRanting: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 图标名称
    @SmartPublished
    public var logoName: String? {
        didSet {
            save()
        }
    }
    
    /// 外观模式
    @SmartPublished
    public var appearanceStyle = AppearanceStyle.auto {
        didSet {
            save()
        }
    }
    
    /// 显示音频标签
    @SmartPublished
    public var isShowAudioTag: Bool = kaka_IsMacOS() {
        didSet {
            save()
        }
    }
    
    
    /// 是否已授权Apple Music
    @SmartPublished
    public var isGrantedAppleMusic = false {
        didSet {
            save()
        }
    }
    
    /// 播放动画
    @SmartPublished
    public var playAnimation = PlayAnimationType.animation0 {
        didSet {
            save()
        }
    }
    
    /// 告诉用户维克音乐与百度网盘签署高级合伙伙伴
    @SmartPublished
    public var isBaiduTips: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 是否出现过AirPlay提示
    @SmartPublished
    public var isShowAirPlay: Int = 0 {
        didSet {
            save()
        }
    }
    
    /// 是否引导过卡式磁带
    @SmartPublished
    public var isShowTapePlayer: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 提示自定义壁纸
    @SmartPublished
    public var isShowCustomBg: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 显示AI助手
    @SmartPublished
    public var isShowAI: Bool = false {
        didSet {
            save()
        }
    }
    
    /// 歌词Token
    @SmartPublished
    public var lyricToken: LRCLyricTokenModel? {
        didSet {
            save()
        }
    }
    
#if targetEnvironment(macCatalyst)
    /// 核心修改：新增一个用于持久化权限的书签数组
    @SmartPublished
    public var bookmarkDataArray: [Data] = [] {
        didSet {
            debugPrint("书签文件数量 = \(bookmarkDataArray.count)")
            save()
        }
    }
#endif
    
    /// 此前引入的文件路径
    @SmartPublished
    public var cachePathArray: [String] = [] {
        didSet {
            
            save()
        }
    }
    
    /// 显示macOS免费消息
    @SmartPublished
    public var isFreeMacos: Bool = false {
        didSet {
            save()
        }
    }
}

extension AppLocalManager {
    private class func kaka_UserCacheDefaultkey() -> String {
        return "Passbook_local_default_key"
    }
    
    private class func read() -> AppLocalManager? {
        let key = AppLocalManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        guard let json = sharedUD.string(forKey: key) else { return nil }
          
        let model = AppLocalManager.deserialize(from: json)
        return model
    }
    
    private func save() {
        let json = self.toJSONString()
        let sharedUD = UserDefaults.standard
        sharedUD.set(json, forKey: AppLocalManager.kaka_UserCacheDefaultkey())
        sharedUD.synchronize()
    }
    
    public class func reset() {
        let key = AppLocalManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        AppLocalManager.shared = AppLocalManager()
    }
    
}

extension AppLocalManager {
    
    // 把已经不存在的文件路径过滤掉
    public func refreshCachePaths() -> [URL] {
        let filterArray = self.cachePathArray.filter { FileManager.default.fileExists(atPath: $0) }
                
        let pathArray = filterArray.map { URL(fileURLWithPath: $0) }
        
        return Array(Set(pathArray))
    }
    
    // 删除缓存路径
    public func removeCachePath(path: String, completion: (()->Void)? = nil) {
        // 获取文件夹路径
        let directoryPath = (path as NSString).deletingLastPathComponent
        
        // 创建 FileManager 实例
        let fileManager = FileManager.default
        
        // 从 cachePathArray 中移除与路径相同文件夹内的所有文件
        var tempArray = self.cachePathArray
        
        // 使用 filter 来获取需要删除的文件路径
        let filesToRemove = tempArray.filter { filePath in
            let fileDirectoryPath = (filePath as NSString).deletingLastPathComponent
            return fileDirectoryPath == directoryPath
        }
        
        // 从 tempArray 中移除这些文件
        for filePath in filesToRemove {
            if let index = tempArray.firstIndex(where: { $0 == filePath }) {
                tempArray.remove(at: index)
            }
        }
        
        // 更新 cachePathArray
        self.cachePathArray = tempArray
        
        // 发送通知
        completion?()
        NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
    }

    /// 当用户选择新文件时调用此方法
    public func addMediaURLs(_ urls: [URL]) {
        
        // 1. 先拷贝当前数据到本地副本
#if targetEnvironment(macCatalyst)
        var newBookmarks = self.bookmarkDataArray
#endif
        var newPaths = self.cachePathArray
        
        for subURL in urls {
            do {
                #if targetEnvironment(macCatalyst)
                let options: URL.BookmarkCreationOptions = .withSecurityScope
                #else
                let options: URL.BookmarkCreationOptions = .withoutImplicitSecurityScope
                #endif
                
                let data = try subURL.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
                
#if targetEnvironment(macCatalyst)
                newBookmarks.append(data)
#endif
                newPaths.append(subURL.path)
                debugPrint("创建书签成功：\(subURL.path)")
            } catch {
                debugPrint("创建书签失败: \(subURL.path), error: \(error)")
            }
        }
        
        // 2. 只有发生变化时，才重新赋值。这一定会触发 didSet
#if targetEnvironment(macCatalyst)
        self.bookmarkDataArray = Array(Set(newBookmarks))
#endif
        
        self.cachePathArray = Array(Set(newPaths))
    }

    /// 激活书签权限
    public func activateAllBookmarks() {
#if targetEnvironment(macCatalyst)
        for (index, data) in self.bookmarkDataArray.enumerated() {
            var isStale = false
            do {
                // 解析书签：根据系统选择选项
                #if targetEnvironment(macCatalyst)
                let options: URL.BookmarkResolutionOptions = .withSecurityScope
                #else
                // iOS 解析安全书签时，通常使用 empty 或 .withoutUI
                let options: URL.BookmarkResolutionOptions = .withoutImplicitStartAccessing
                #endif

                let url = try URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    debugPrint("书签已过期，建议重新创建: \(url.path)")
                    // 此时可以调用上面的 addMediaURLs([url]) 来更新 Data
                }

                // 激活权限（iOS 和 macOS 方法名相同）
                if url.startAccessingSecurityScopedResource() {
                    debugPrint("成功恢复书签权限: \(url.path)")
                }
            } catch {
                debugPrint("解析书签失败，索引: \(index), error: \(error)")
            }
        }
#endif
    }
    
}
