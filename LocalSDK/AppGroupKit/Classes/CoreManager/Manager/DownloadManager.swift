//
//  DownloadManager.swift
//  AppGroupKit
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import SmartCodable

/// 下载管理器
public class DownloadManager: ObservableObject, SmartCodable {
    required public init() {
        
    }
    
    static public var shared = DownloadManager.read() ?? DownloadManager()

    /// 下载任务
    @SmartPublished
    public var taskArray: [MusicItemModel] = [] {
        didSet {
            save()
        }
    }
        
    /// 添加到下载池
    public func addMusicModel(_ models: [MusicItemModel]) {
        var tempArray = self.taskArray
        
        for model in models {
            if let index = tempArray.firstIndex(where: { $0 == model }) {
                tempArray.remove(at: index)
                tempArray.insert(model, at: 0)
            } else {
                tempArray.append(model)
            }
        }
        
        self.taskArray = tempArray
        
    }
    
    /// 从下载池中删除
    public func removeFromDownloads(_ model: MusicItemModel) -> [MusicItemModel] {
        var tempArray = self.taskArray
        
        if let index = tempArray.firstIndex(where: { $0 == model }) {
            tempArray.remove(at: index)
        }
        
        self.taskArray = tempArray
        return tempArray
    }
}

extension DownloadManager {
    private class func kaka_UserCacheDefaultkey() -> String {
        return "MusicTag_download_key"
    }
    
    private class func read() -> DownloadManager? {
        let key = DownloadManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        guard let json = sharedUD.string(forKey: key) else { return nil }
          
        let model = DownloadManager.deserialize(from: json)
        return model
    }
    
    private func save() {
        let json = self.toJSONString()
        let sharedUD = UserDefaults.standard
        sharedUD.set(json, forKey: DownloadManager.kaka_UserCacheDefaultkey())
        sharedUD.synchronize()
    }
    
    public class func reset() {
        let key = DownloadManager.kaka_UserCacheDefaultkey()
        let sharedUD = UserDefaults.standard
        sharedUD.set(nil, forKey: key)
        sharedUD.synchronize()
        
        DownloadManager.shared = DownloadManager()
    }
    
}

