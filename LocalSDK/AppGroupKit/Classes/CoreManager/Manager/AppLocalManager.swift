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

/// Stable raw values are persisted across versions. Unimplemented modes fall
/// back to Classic at launch until their module is available.
public enum AppHomeMode: Int, SmartCaseDefaultable {
    case classic = 0
    case navidrome = 1
    case emby = 2
    case jellyfin = 3
    case plex = 4
}

// 1. 扩展你的 BookmarkError，让它支持精准的错误携带
public enum BookmarkError: Error {
    case partialOrTotalFailure(
        successURLs: [URL],          // 真正成功注销书签的文件
        unnecessaryURLs: [URL],      // 属于系统音乐/公开文件夹，无需注销的文件
        failedURLs: [URL]            // 真正因损坏或找不到而清理失败的文件
    )
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

    @SmartPublished
    public var homeMode: AppHomeMode = .classic {
        didSet { save() }
    }

    /// A reference to the saved connection, never a password or access token.
    @SmartPublished
    public var musicServerAccountID: String? {
        didSet { save() }
    }
            
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
    
    
    /// 一次生命周期只提醒一次好评
    @SmartPublished
    public var isGuideFiveStar: Bool = false {
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
        let filterArray = self.cachePathArray.filter { subPath in
            FileManager.default.fileExists(atPath: subPath) &&
            FileManager.default.isReadableFile(atPath: subPath)
        }
                
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
                let options: URL.BookmarkResolutionOptions = .withSecurityScope

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

    /// 当文件被重命名或移动时，更新书签和路径缓存
    /// - Parameters:
    ///   - oldURL: 重命名前的旧 URL
    ///   - newURL: 重命名后的新 URL
    public func updateMediaURL(oldURL: URL, newURL: URL) {
        let oldPath = oldURL.standardizedFileURL.path
        let newPath = newURL.standardizedFileURL.path
        
        // 如果路径没有改变，无需更新
        guard oldPath != newPath else { return }
        
        // 1. 更新 cachePathArray 路径列表
        var updatedPaths = self.cachePathArray
        if let index = updatedPaths.firstIndex(of: oldPath) {
            updatedPaths[index] = newPath
        } else if !updatedPaths.contains(newPath) {
            updatedPaths.append(newPath)
        }
        self.cachePathArray = Array(Set(updatedPaths))
        
#if targetEnvironment(macCatalyst)
        // 2. 更新 bookmarkDataArray 书签数组
        var updatedBookmarks = self.bookmarkDataArray
        var indicesToRemove = IndexSet()
        
        // 遍历找到旧文件对应的书签位置并标记删除
        for (index, data) in updatedBookmarks.enumerated() {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if resolvedURL.standardizedFileURL.path == oldPath || isStale {
                    indicesToRemove.insert(index)
                }
            } catch {
                // 标记失效/损坏的书签一并清理
                indicesToRemove.insert(index)
            }
        }
        
        // 移除旧书签
        if !indicesToRemove.isEmpty {
            updatedBookmarks.remove(atOffsets: indicesToRemove)
        }
        
        // 3. 为新 URL 创建新的 Security-Scoped Bookmark
        do {
            let options: URL.BookmarkCreationOptions = .withSecurityScope
            let newBookmarkData = try newURL.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            
            // 开启新 URL 的安全权限访问
            if newURL.startAccessingSecurityScopedResource() {
                debugPrint("新路径权限开启成功: \(newPath)")
            }
            
            updatedBookmarks.append(newBookmarkData)
            debugPrint("成功更新书签：\(oldPath) -> \(newPath)")
        } catch {
            debugPrint("为新路径创建书签失败: \(newPath), error: \(error)")
        }
        
        // 触发 didSet 保存
        self.bookmarkDataArray = Array(Set(updatedBookmarks))
#endif
    }
    
#if targetEnvironment(macCatalyst)
    /// 从 App 内部解绑/取消关联选中的文件（仅清理 App 的书签和路径缓存，不移动或删除物理文件）
    /// - Parameters:
    ///   - fileURLs: 需要取消关联的文件 URL 列表
    ///   - completion: 执行结果回调
    public func removeBookmark(fileURLs: [URL], completion: @escaping (Result<[URL], BookmarkError>) -> Void) {
        
        // 1. 获取传入文件的标准化路径集合（消除软链接和路径格式差异）
        let targetPathsToRemove = Set(fileURLs.map { $0.standardizedFileURL.path })
        
        // 2. 第一步：优先清理路径缓存 cachePathArray（确保列表不再展示该文件）
        var currentCachePaths = self.cachePathArray
        currentCachePaths.removeAll { path in
            let standardPath = URL(fileURLWithPath: path).standardizedFileURL.path
            return targetPathsToRemove.contains(standardPath)
        }
        self.cachePathArray = currentCachePaths
        
        // 3. 第二步：分析并清理内存中的书签数组 bookmarkDataArray
        var updatedBookmarks = self.bookmarkDataArray
        var indicesToRemove = IndexSet()
        var successfullyRemovedURLs: [URL] = []
        
        for (index, data) in updatedBookmarks.enumerated() {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                let resolvedPath = resolvedURL.standardizedFileURL.path
                
                // 如果书签指向的目标在删除列表中，或者书签本身已失效，标记移除
                if targetPathsToRemove.contains(resolvedPath) {
                    indicesToRemove.insert(index)
                    // 停止对安全范围资源的访问授权
                    resolvedURL.stopAccessingSecurityScopedResource()
                    successfullyRemovedURLs.append(resolvedURL)
                } else if isStale {
                    indicesToRemove.insert(index)
                }
            } catch {
                // 断头/坏掉的书签一并标记清理
                indicesToRemove.insert(index)
            }
        }
        
        // 统一删除选中的书签元素（重新给 @SmartPublished 属性赋值，自动触发 save() 持久化）
        if !indicesToRemove.isEmpty {
            updatedBookmarks.remove(atOffsets: indicesToRemove)
            self.bookmarkDataArray = updatedBookmarks
        }
        
        // 4. 发送通知通知 UI 刷新界面
        NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
        
        // 5. 回调结果
        DispatchQueue.main.async {
            completion(.success(successfullyRemovedURLs))
        }
    }
#endif

}
