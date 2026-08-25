//
//  ConnectConfigManager.swift
//  AppGroupKit
//
//  Created by 张文 on 3/4/25.
//

import SmartCodable


/// 连接服务器的配置
public class ConnectConfigManager: SmartCodableX, ObservableObject {
    
    required public init() {
        
    }
    
    static public var shared = ConnectConfigManager.read() ?? ConnectConfigManager()
    
    /// 已连接的服务器
    @SmartPublished
    public var connectedModels: [ServerConfigModel] = [] {
        didSet {
            save()
        }
    }
    
    /// 连接页面的文件夹列表
    @SmartPublished
    public var selectFolderArray: [MusicItemModel] = [] {
        didSet {
            save()
        }
    }
    
    /// 连接页面喜欢的歌曲
    @SmartPublished
    public var favoriteMusicArray: [MusicItemModel] = [] {
        didSet {
            save()
        }
    }
    
    /// 上次的播放列表
    @SmartPublished
    public var lastPlaylist: [MusicItemModel] = [] {
        didSet {
            save()
        }
    }
    
    // 我的歌单
    @SmartPublished
    public var playlists: [NavidromePlaylist] = [] {
        didSet {
            save()
        }
    }
    
    /// Nav搜索记录
    @SmartPublished
    public var navSearchArray: [String] = [] {
        didSet {
            save()
        }
    }

    /// 当前服务器
    public func currentServerModel() -> ServerConfigModel? {
        
        var curModel: ServerConfigModel? = self.connectedModels.filter { $0.isSelected }.first
        if let curModel = curModel {
            return curModel
        }else{
            return self.connectedModels.first
        }
    }
    
    // 更新数据结构
    public static func updateConnectNewData() {
        
        // 删除所有m3u缓存
        let m3uArray = SandboxFileManager.shared.preDownloadURL().readLocalSubFiles().filter {
            $0.pathExtension.contains("m3u")
        }
        
        for index in 0..<m3uArray.count {
            let subM3uURL = m3uArray[index]
            try? FileManager.default.removeItem(at: subM3uURL)
        }
        
        // 防止此前未付费的用户继续使用远程功能
//        if let firstFile = ConnectConfigManager.shared.lastPlaylist.first, (!firstFile.isLocalFile() && !UserInfoManager.shared.isPremium()) {
//            ConnectConfigManager.shared.lastPlaylist = []
//            ConnectConfigManager.shared.connectedModels = []
//        }
        
    }
    
    /// 是否为小型数据库
    public func isLargeServer() -> Bool {
        guard let navUser = self.currentServerModel()?.navUser else { return false }

        return navUser.isLargeServer
    }
    
}

extension ConnectConfigManager {
    
    private class func kaka_UserCacheDefaultkey() -> String {
        return "ConnectConfig_key"
    }
    
    private class func read() -> ConnectConfigManager? {
        let key = ConnectConfigManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        guard let json = sharedUD.string(forKey: key) else { return nil }
          
        let model = ConnectConfigManager.deserialize(from: json)
        return model
    }
    
    private func save() {
        let json = self.toJSONString()
        let sharedUD = UserDefaults.standard
        sharedUD.set(json, forKey: ConnectConfigManager.kaka_UserCacheDefaultkey())
        sharedUD.synchronize()
    }
    
    public class func reset() {
        let key = ConnectConfigManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        ConnectConfigManager.shared = ConnectConfigManager()
    }
    
}
