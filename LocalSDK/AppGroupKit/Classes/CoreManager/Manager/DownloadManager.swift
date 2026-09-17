//
//  DownloadManager.swift
//  AppGroupKit
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import SmartCodable

/// 下载管理器
public class DownloadManager: ObservableObject, SmartCodableX {
    required public init() {
        
    }
    
    static public var shared = DownloadManager.read() ?? DownloadManager()
    static public let didEnqueue = Notification.Name("com.wakemusic.download.enqueued")

    /// 下载任务
    @SmartPublished
    public var taskArray: [MusicItemModel] = [] {
        didSet {
            save()
        }
    }
        
    /// 添加到下载池
    public func addMusicModel(_ models: [MusicItemModel]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.addMusicModel(models) }
            return
        }
        var tempArray = self.taskArray
        
        for model in models {
            if let index = tempArray.firstIndex(where: { $0.preDownloadIdentity() == model.preDownloadIdentity() }) {
                tempArray.remove(at: index)
                tempArray.insert(model, at: 0)
            } else {
                tempArray.append(model)
            }
        }
        
        self.taskArray = tempArray
        NotificationCenter.default.post(name: Self.didEnqueue, object: models.map { $0.preDownloadIdentity() })
        
    }
    
    /// 从下载池中删除
    public func removeFromDownloads(_ model: MusicItemModel) -> [MusicItemModel] {
        var tempArray = self.taskArray
        
        tempArray.removeAll { $0.preDownloadIdentity() == model.preDownloadIdentity() }
        
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
