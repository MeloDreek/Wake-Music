//
//  KakaCacheTools.swift
//  AppGroupKit
//
//  Created by 张文 on 5/8/25.
//

import KakaFoundation
import WebKit

public class KakaCacheTools {
    
    // 获取缓存大小
    public class func getCacheSize() -> String {
        // 获取缓冲文件的沙盒路径
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let cachePathURL = kaka_IsMacOS() ? SandboxFileManager.shared.preDownloadURL() : URL(fileURLWithPath: cachePath)
        debugPrint("cachePath路径: \(cachePath)")
        
        let cacheSize = cachePathURL.totalFileSize()
        
        return URL.formatFileSize(cacheSize)
    }
    
    // 完成缓存清理
    public class func finishCacheCompletion(completion: @escaping () -> Void) {
        // 获取缓冲文件的沙盒路径
        let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let cachePathURL = kaka_IsMacOS() ? SandboxFileManager.shared.preDownloadURL() : URL(fileURLWithPath: cachePath)
        
        do {
            try FileManager.default.removeItem(at: cachePathURL)
            completion()
        } catch {
            completion()
            debugPrint(error.localizedDescription)
        }
    }
    
    // 删除Web登录缓存
    public class func clearWebViewCache(displayName: String, completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore.default()

        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            
            debugPrint("Web缓存 = \(records)")
            let baiduRecords = records.filter { $0.displayName.contains(displayName) }

            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: baiduRecords) {
                completion?()
            }
        }
    }
    
}

