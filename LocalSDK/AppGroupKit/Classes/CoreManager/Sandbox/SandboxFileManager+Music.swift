//
//  SandboxFileManager+Music.swift
//  AppGroupKit
//
//  Created by 张文 on 10/2/24.
//

import KakaFoundation
import KakaUIKit
import KakaTaglibKit

extension SandboxFileManager {
    
    /// 读取本地文件路径，不遍历子文件夹
    public func readLocalMusicFiles() -> [URL] {
        let baseFileURL = self.basePublicFileURL()
        let baseArray = baseFileURL.readLocalSubFiles()
        
        let allPathArray = baseArray
        
        // 使用 Set 去重
        let uniquePaths = Set(allPathArray)
        
        // 过滤无效路径
        return Array(uniquePaths)
    }
    
    /// 添加新的本地文件路径
    public func addLocalMusicFiles(_ files: [URL]) {
        var tempArray = [URL]()
        
        for subURL in files {
            if subURL.hasDirectoryPath {
                // 如果是文件夹，递归读取子文件
                let subFiles = self.getAllSubFiles(subURL)
                tempArray.append(contentsOf: subFiles)
            } else {
                // 如果是文件，直接添加
                tempArray.append(subURL)
            }
        }
        
        let newFileArray = tempArray.map { $0.path }
        
        var tempPathArray = AppLocalManager.shared.cachePathArray + tempArray.map { $0.path }
        debugPrint("已经有 \(tempPathArray.count) 个项目")
        
        AppLocalManager.shared.cachePathArray = Array(Set(tempPathArray))
        AppLocalManager.shared.addMediaURLs(tempArray)
    }
    
    /// 获取已下载的文件路径
    public func getDownloadPlayURL(_ model: MusicItemModel) -> URL? {
        // A display filename is not a unique identifier across pCloud folders/accounts.
        if model.pcloudFile != nil {
            let url = self.preDownloadURL().appendingPathComponent(model.filePathName() + model.addPathExtension())
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        
        let baseFolderURL = self.basePublicFileURL()
        let allFileURLArray1 = self.preDownloadURL().readLocalSubFiles()
        let allFileURLArray2 = self.getAllSubFiles(baseFolderURL)
        
        let allFileURLArray = allFileURLArray1 + allFileURLArray2
        let allFileNameArray = allFileURLArray.map { $0.lastPathComponent }
        
//        debugPrint("所有缓存的路径 = \(allFileNameArray)")
//        debugPrint("当前要播放的音乐 = \(model.downloadPathName())")
        
        if let index = allFileNameArray.firstIndex(where: { $0 == model.downloadPathName() }) {
            let cacheURL = allFileURLArray[index]
            return FileManager.default.fileExists(atPath: cacheURL.path) ? cacheURL : nil
        }else{
            return nil
        }
    }
        
    /// 递归获取文件夹下的所有子文件路径
    public func getAllSubFiles(_ folderURL: URL) -> [URL] {
        var result = [URL]()
        
        // 1. 必须开启安全作用域访问
        let canAccess = folderURL.startAccessingSecurityScopedResource()
        
        // 无论是否开启成功，都要确保在退出时调用 stop (如果开启成功的话)
        defer {
            if canAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileManager = FileManager.default
        do {
            // 2. 获取目录内容
            let contents = try fileManager.contentsOfDirectory(at: folderURL,
                                                             includingPropertiesForKeys: nil,
                                                             options: .skipsHiddenFiles)
            
            for subURL in contents {
                // 注意：subURL 继承了父目录的权限上下文，但在某些情况下
                // 处理子文件夹递归时，依然需要在下一层递归中再次 startAccessing
                if subURL.hasDirectoryPath {
                    let subFiles = self.getAllSubFiles(subURL) // 递归
                    result.append(contentsOf: subFiles)
                } else {
                    result.append(subURL)
                }
            }
        } catch {
            debugPrint("读取文件夹失败: \(folderURL.path), Error: \(error.localizedDescription)")
        }
        
        return result
    }
        
    /// 新增或更新歌单（文件夹）
    public func addOrUpdateFolder(folderName: String, completion: @escaping (Result<URL, KakaError>) -> Void) {
        let allFolders = self.readLocalMusicFiles().filter { $0.hasDirectoryPath }.compactMap { $0.lastPathComponent }
        
        if allFolders.contains(folderName) {
            DispatchQueue.main.async {
                completion(.failure(KakaError.duplicateNames))
            }
            return
        }
        
        let baseFileURL = self.basePublicFileURL()
        
        let targetURL = baseFileURL.appendingPathComponent(folderName)
        do {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
            completion(.success(targetURL))
        } catch {
            completion(.failure(KakaError.custom(error.localizedDescription)))
        }
    }
    
    /// 保存或移动音乐文件
    /// - Parameters:
    ///   - model: 音乐模型
    ///   - completion: 完成回调
    public func saveMusicToDocument(sourceURL: URL, targetFolderURL: URL, model: MusicItemModel, completion: ((MusicItemModel)->Void)? = nil) {
        let artistName = !(model.artist?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? model.artist! : "Unknown Artist".localStr()
        let songName = !(model.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ? model.title! : "Unknown Title".localStr()
        
        let baseFileName = "\(artistName) - \(songName)".replaceChar(oldChar: ".", newChar: "")
        var fileName = baseFileName
        var fileCount = 1
        
        if sourceURL.hasDirectoryPath {
            fileName = sourceURL.lastPathComponent
        }else{
            while FileManager.default.fileExists(atPath: self.basePublicFileURL().path.ocString.appendingPathComponent("\(fileName).\(sourceURL.pathExtension)")) {
                fileName = "\(baseFileName) (\(fileCount))"
                fileCount += 1
            }
        }
        
        let targetPath = targetFolderURL.path + "/" + fileName + (sourceURL.hasDirectoryPath ? "" : ("." + sourceURL.pathExtension))
        let targetURL = URL(fileURLWithPath: targetPath)
        
        if FileManager.default.isReadableFile(atPath: sourceURL.path) {
            if model.handleType == .move {
                try? FileManager.default.moveItem(at: sourceURL, to: targetURL)
            }else if model.handleType == .copy {
                try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
        } else if sourceURL.startAccessingSecurityScopedResource() {
            defer {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            
            if model.handleType == .move {
                try? FileManager.default.moveItem(at: sourceURL, to: targetURL)
            }else if model.handleType == .copy {
                try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
            
        } else {
            if model.handleType == .move {
                try? FileManager.default.moveItem(at: sourceURL, to: targetURL)
            }else if model.handleType == .copy {
                try? FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
        }
        
        var newModel = model
        newModel.handleType = model.handleType
        newModel.title = songName
        newModel.mediaPlayURL = targetURL
        completion?(newModel)
        
    }
    
    /// 修改歌名的标签，同时修改封面的地址
    /// - Parameters:
    ///   - oldModel: 文件
    ///   - newTitle: 新歌名
    /// - Returns: 修改状态
    public func updateTitleTag(oldModel: MusicItemModel, newTitle: String) -> Bool {
        let success = TaglibMetadataParser.setTitle(newTitle, toFileURL: oldModel.mediaPlayURL)
        if !success {
            return false
        }
        
        // 歌曲封面
        let coverFileURL = self.coverPathURL()
        let oldArtist = oldModel.artist ?? "Unknown Artist".localStr()
                    
        let newTargetURL = coverFileURL.appendingPathComponent(oldArtist + " - " + newTitle + ".jpg")
        let oldTargetURL = coverFileURL.appendingPathComponent(oldModel.filePathName() + ".jpg")
                
        try? FileManager.default.moveItem(at: oldTargetURL, to: newTargetURL)
        
        return success
    }
    
    /// 修改艺术家的标签，同时修改封面的地址
    /// - Parameters:
    ///   - oldModel: 文件
    ///   - newArtist: 新艺术家
    /// - Returns: 修改状态
    public func updateArtistTag(oldModel: MusicItemModel, newArtist: String) -> Bool {
        let success = TaglibMetadataParser.setArtist(newArtist, toFileURL: oldModel.mediaPlayURL)
        if !success {
            return false
        }
        
        // 歌曲封面
        let coverFileURL = self.coverPathURL()
                    
        let newTargetURL = coverFileURL.appendingPathComponent(newArtist + " - " + oldModel.showTitleName() + ".jpg")
        let oldTargetURL = coverFileURL.appendingPathComponent(oldModel.filePathName() + ".jpg")
                
        try? FileManager.default.moveItem(at: oldTargetURL, to: newTargetURL)
        
        return success
    }
    
    /// 保存LRC歌词文件
    /// - Parameters:
    ///   - lrcPath: LRC地址
    ///   - completion: 完成回调
    public func saveLrcFileToDocument(lrcPath: URL, handleType: FileHandleType, completion: ((URL)->Void)? = nil) {
        
        let lyricFoderPath = self.lyricsPathURL()
        
        let baseFileName = lrcPath.lastPathComponent.replaceChar(oldChar: "." + lrcPath.pathExtension, newChar: "")
        var fileName = baseFileName
        var fileCount = 1
        
        while FileManager.default.fileExists(atPath: lyricFoderPath.appendingPathComponent("\(fileName).\(lrcPath.pathExtension)").path) {
            fileName = "\(baseFileName) (\(fileCount))"
            fileCount += 1
        }
        
        let targetPath = self.lyricsPathURL().path + "/" + fileName + "." + lrcPath.pathExtension
        
        let targetURL = URL(fileURLWithPath: targetPath)
        
        if FileManager.default.isReadableFile(atPath: lrcPath.path) {
            if handleType == .copy {
                try? FileManager.default.copyItem(at: lrcPath, to: targetURL)
            }else{
                try? FileManager.default.moveItem(at: lrcPath, to: targetURL)
            }
        } else if lrcPath.startAccessingSecurityScopedResource() {
            defer {
                lrcPath.stopAccessingSecurityScopedResource()
            }
            
            if handleType == .copy {
                try? FileManager.default.copyItem(at: lrcPath, to: targetURL)
            }else{
                try? FileManager.default.moveItem(at: lrcPath, to: targetURL)
            }
            
        } else {
            if handleType == .copy {
                try? FileManager.default.copyItem(at: lrcPath, to: targetURL)
            }else{
                try? FileManager.default.moveItem(at: lrcPath, to: targetURL)
            }
        }
        
        completion?(targetURL)
    }
    
    /// 写入音乐的封面图
    public func writeMusicthumbnailImage(model: MusicItemModel, image: UIImage?, success: ((URL)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        if model.isFolder() {
            fail?(KakaError.custom("This is folder!"))
            return
        }
        
        guard let imageData = image?.dataWithCompression() else {
            fail?(KakaError.custom("convert image failed!"))
            return
        }
        
        do {
            
            // 开始写缩略图
            let accountFolderPath = self.coverPathURL().path
            
            // 1、创建文件夹
            if !FileManager.default.fileExists(atPath: accountFolderPath) {
                // 之前没记录，创建文件夹
                try FileManager.default.createDirectory(atPath: accountFolderPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            let targetFullPathStr = accountFolderPath + "/" + model.filePathName() + ".jpg"
            
            // 账户的沙盒URL
            var targetFolderURL: URL
            if #available(iOS 16.0, *) {
                targetFolderURL = URL(filePath: targetFullPathStr, directoryHint: .notDirectory, relativeTo: nil)
            } else {
                targetFolderURL = URL(fileURLWithPath: targetFullPathStr, isDirectory: false)
            }
            
            try imageData.write(to: targetFolderURL, options: .atomic)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                success?(targetFolderURL)
            }
            
        } catch {
            fail?(KakaError.custom(error.localizedDescription))
        }
    }
    
    /// 写入到本地歌词库
    public func writeMusicLRCLyric(model: MusicItemModel, lyricStr: String, success: ((URL)->Void)? = nil, fail: ((KakaError)->Void)? = nil) {
        
        if model.isFolder() {
            fail?(KakaError.custom("This is folder!"))
            return
        }
                
        do {
            
            // 开始写缩略图
            let accountFolderPath = self.lyricsPathURL().path
            
            // 1、创建文件夹
            if !FileManager.default.fileExists(atPath: accountFolderPath) {
                // 之前没记录，创建文件夹
                try FileManager.default.createDirectory(atPath: accountFolderPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            let targetFullPathStr = accountFolderPath + "/" + model.filePathName() + ".lrc"
            
            // 账户的沙盒URL
            var targetFolderURL: URL
            if #available(iOS 16.0, *) {
                targetFolderURL = URL(filePath: targetFullPathStr, directoryHint: .notDirectory, relativeTo: nil)
            } else {
                targetFolderURL = URL(fileURLWithPath: targetFullPathStr, isDirectory: false)
            }
            
            try lyricStr.write(to: targetFolderURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                success?(targetFolderURL)
            }
            
        } catch {
            fail?(KakaError.custom(error.localizedDescription))
        }
    }
    
    /// 获取同名的LRC文件路径
    public func getSameNameLRCFilePath(_ model: MusicItemModel) -> URL? {
        let mediaPlayURL = model.mediaPlayURL // 音乐路径
        
        let lrcFileName = model.filePathName() + ".lrc"
        let lrcFilePath = mediaPlayURL.deletingLastPathComponent().appendingPathComponent(lrcFileName)
        if FileManager.default.fileExists(atPath: lrcFilePath.path) {
            // 本地同名歌词
            return lrcFilePath
        }else{
            // 歌词库查找
            let lyricsPathURL = self.lyricsPathURL().appendingPathComponent(lrcFileName)
            return FileManager.default.fileExists(atPath: lyricsPathURL.path) ? lyricsPathURL : nil
        }
    }
    
    /// 批量删除本地信息
    /// 批量删除本地信息
    public func deleteMusicModels(models: [MusicItemModel], completion: @escaping (Result<[MusicItemModel], KakaError>) -> Void) {
        
        if models.count == 0 {
            completion(.failure(.emptyData))
            return
        }

        var deleteArray = [MusicItemModel]()
        let fetchDataGroup = DispatchGroup()
        var errorMsg: String?

        for index in 0..<models.count {
            fetchDataGroup.enter()
            let subModel = models[index]

            do {
#if targetEnvironment(macCatalyst)
                try FileManager.default.trashItem(at: subModel.mediaPlayURL, resultingItemURL: nil)
#else
                try FileManager.default.removeItem(at: subModel.mediaPlayURL)
#endif

                deleteArray.append(subModel)
                fetchDataGroup.leave()
            } catch {
                if errorMsg == nil { errorMsg = "" }
                errorMsg?.append(error.localizedDescription)
                errorMsg?.append("\r\n")
                fetchDataGroup.leave()
            }
        }

        fetchDataGroup.notify(queue: .main) { [weak self] in
            if let errorMsg = errorMsg, !errorMsg.isEmpty {
                completion(.failure(.custom(errorMsg)))
            }else{
                completion(.success(deleteArray))
            }
        }
        
    }
    
}
