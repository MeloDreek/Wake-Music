//
//  SandboxFileManager.swift
//  PassLock
//
//  Created by Melo Dreek on 2023/6/18.
//

import KakaFoundation
import KakaObjcKit


public final class SandboxFileManager: @unchecked Sendable {
    
    // 单例
    public static let shared = SandboxFileManager()
    
    // 喜欢的本地音乐
    public lazy var favoriteArray: [String] = {
        return [String]()
    }()
    
    public init() {
        self.favoriteArray = self.getFavorites()
        debugPrint("Document路径 = \(self.basePublicFileURL())")
        
        // 删除可能下载失败的文件
        let subURLs = self.preDownloadURL().readLocalSubFiles()
        let smallURLs = subURLs.filter { $0.fileSize < 5 * 1024 * 1024 } // 删除5MB以下的
        for i in 0..<smallURLs.count {
            let subURL = smallURLs[i]
            try? FileManager.default.removeItem(at: subURL)
        }
    }
    
    // 存储位置
    public func basePublicFileURL() -> URL {
        if kaka_IsMacOS() {
            return self.createAppFolderInMusic() ?? self.getDocumentFilePath()
        }else{
            return self.getDocumentFilePath()
        }
    }
    
    // Document路径
    public func getDocumentFilePath() -> URL {
        if #available(iOS 16.0, *) {
            let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path(percentEncoded: false)
            return URL(filePath: documentUrl, directoryHint: .isDirectory)
        } else {
            let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
            return URL(fileURLWithPath: documentUrl)
        }
    }
    
    // 预加载缓存的地址
    public func preDownloadURL() -> URL {
        var cacheURLStr: String = ""
        if #available(iOS 16.0, *) {
            cacheURLStr = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path(percentEncoded: false)
        } else {
            let documentUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.path
            cacheURLStr = documentUrl + "/"
        }
        
#if targetEnvironment(macCatalyst)
        let bundleID = (Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String) ?? "Wakemusic"
        cacheURLStr = cacheURLStr + bundleID + "/" + SandboxType_PreDownload
#else
        cacheURLStr = cacheURLStr + SandboxType_PreDownload
#endif
        
        if !FileManager.default.fileExists(atPath: cacheURLStr) {
            try? FileManager.default.createDirectory(atPath: cacheURLStr, withIntermediateDirectories: true, attributes: nil)
        }
        
        let cacheURL = URL(fileURLWithPath: cacheURLStr)
        
        return cacheURL
    }
    
    // 封面地址
    public func coverPathURL() -> URL {
        let coverPath = self.basePublicFileURL().appendingPathComponent(SandboxType_MusicCovers).path
        
        if !FileManager.default.fileExists(atPath: coverPath) {
            try? FileManager.default.createDirectory(atPath: coverPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        return URL(fileURLWithPath: coverPath)
    }
    
    // 本地歌词地址
    public func lyricsPathURL() -> URL {
        let lyricPath = self.basePublicFileURL().appendingPathComponent(SandboxType_AllLyric).path
        
        if !FileManager.default.fileExists(atPath: lyricPath) {
            try? FileManager.default.createDirectory(atPath: lyricPath, withIntermediateDirectories: true, attributes: nil)
        }
        return URL(fileURLWithPath: lyricPath)
    }
    
    // 自定义的播放器背景
    public func customPlayerbackURL() -> URL {
        let lyricPath = self.basePublicFileURL().appendingPathComponent(SandboxType_PlayerBack).path
        
        if !FileManager.default.fileExists(atPath: lyricPath) {
            try? FileManager.default.createDirectory(atPath: lyricPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        return URL(fileURLWithPath: lyricPath)
    }
        
    /// macOS下的文件夹
    private func createAppFolderInMusic() -> URL? {
        // 获取用户的 Music 目录
        let musicDirectory = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
        
        // 创建应用程序文件夹的名称
        let appFolderName = "Wakemusic"
        
        // 创建完整的文件夹路径
        guard let appFolderURL = musicDirectory?.appendingPathComponent(appFolderName) else {
            debugPrint("无法获取 Music 目录")
            return nil
        }
        
        // 检查文件夹是否存在
        if !FileManager.default.fileExists(atPath: appFolderURL.path) {
            do {
                // 创建文件夹
                try FileManager.default.createDirectory(at: appFolderURL, withIntermediateDirectories: true, attributes: nil)
                return appFolderURL
            } catch {
                debugPrint("创建文件夹失败: \(error.localizedDescription)")
                return nil
            }
        } else {
            return appFolderURL
        }
    }
    
    
    // 共享容器
    public func getSharedFilePath() -> URL {
        
        if #available(iOS 16.0, *) {
            let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path(percentEncoded: false)

            guard let shareGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Application.wakeMusic.sharedGroupName())?.path(percentEncoded: false) else {
                return URL(filePath: documentUrl, directoryHint: .isDirectory)
            }
            
            return URL(filePath: shareGroupUrl, directoryHint: .isDirectory)
        } else {
            guard let shareGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Application.wakeMusic.sharedGroupName())?.path else {
                let documentUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
                return URL(fileURLWithPath: documentUrl)
            }
            
            return URL(fileURLWithPath: shareGroupUrl)
        }
    }
    
    
}
