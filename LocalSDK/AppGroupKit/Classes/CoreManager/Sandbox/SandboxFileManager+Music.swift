//
//  SandboxFileManager+Music.swift
//  AppGroupKit
//
//  Created by 张文 on 10/2/24.
//

import KakaFoundation
import KakaUIKit
import CryptoKit
import Darwin

extension MusicItemModel {
    /// Artwork belongs to a source file/account, not editable (or localized) tags.
    public func artworkCacheKey() -> String {
        let identity: String
        if isLocalFile(), mediaPlayURL.isFileURL {
            identity = MusicArtworkCache.localIdentity(url: mediaPlayURL, documents: SandboxFileManager.shared.basePublicFileURL())
        } else {
            identity = "remote:" + preDownloadIdentity()
        }
        return MusicArtworkCache.key(identity: identity)
    }

    public func localArtworkCacheURL() -> URL {
        SandboxFileManager.shared.coverPathURL().appendingPathComponent(artworkCacheKey() + ".jpg")
    }

    /// Only old provider-scoped identities can be reused safely. Legacy local
    /// title/artist names can collide and are rebuilt from the source on scan.
    public func existingArtworkCacheURL() -> URL? {
        let url = localArtworkCacheURL()
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard smbFile != nil || megaFile != nil || yandexFile != nil || pan123File != nil ||
                guangyaFile != nil || boxFile != nil || pcloudFile != nil else { return nil }
        let name = filePathName()
        guard !name.contains("/"), !name.contains("\0"), name.utf8.count < 240 else { return nil }
        let legacy = SandboxFileManager.shared.coverPathURL().appendingPathComponent(name + ".jpg")
        return FileManager.default.fileExists(atPath: legacy.path) ? legacy : nil
    }

    /// Stable source/account key, independent of the human-readable filename and tags.
    public func preDownloadIdentity() -> String {
        var parts = [fileSourceType.rawValue, uniqueID()]
        // Keep pre-download markers compatible with older versions. Account
        // identity was already included below before queue IDs became scoped.
        if let song = navidromeSong { parts[1] = "navidrome-\(song.id)" }
        if let file = webFileModel, let user = file.webdavUser {
            parts += [user.hostUrl, user.port ?? "", user.username ?? "", file.filePath]
        }
        if let user = navidromeSong?.navUser { parts += [user.hostUrl, user.id, user.username] }
        if let file = aliFileModel { parts += [file.aliyunUser?.aliUser?.user_id ?? "", file.drive_id, file.file_id] }
        if let user = googleFile?.googleUser { parts += [user.userID ?? ""] }
        if let user = dropboxFile?.dropboxUser { parts += [user.userID ?? ""] }
        if let user = onedriveFile?.onedriveUser { parts += [user.account?.msalID ?? ""] }
        if let user = drive115Model?.drive115User { parts += [user.user_id] }
        if let user = baiduFileModel?.baiduUser { parts += [String(user.uk)] }
        return SHA256.hash(data: Data(parts.joined(separator: "\u{0}").utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

public enum MusicArtworkCache {
    public static func revision(at url: URL) -> String {
        // URL resource values can retain a previous modification date when the
        // same URL instance is reused after an atomic replacement.
        let values = try? FileManager.default.attributesOfItem(atPath: url.path)
        let date = values?[.modificationDate] as? Date
        let size = values?[.size] as? NSNumber
        return "\(date?.timeIntervalSince1970 ?? 0)-\(size?.int64Value ?? 0)"
    }

    public static func localIdentity(url: URL, documents: URL) -> String {
        // Lexical normalization must not depend on whether an imported file
        // already exists (standardizedFileURL may resolve /private symlinks).
        let path = url.standardized.path.precomposedStringWithCanonicalMapping
        let root = documents.standardized.path.precomposedStringWithCanonicalMapping + "/"
        // iOS may change the sandbox UUID after installing an app update.
        if path.hasPrefix(root) { return "documents:" + String(path.dropFirst(root.count)) }
        return "file:" + path
    }

    public static func key(identity: String) -> String {
        "artwork-v2-" + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension Notification.Name {
    public static let musicArtworkCacheDidChange = Notification.Name("Wakemusic.PlaybackArtworkCached")
}

/// A source marker travels with the file when renamed/moved; no stale filename index
/// can accidentally select another song after cache eviction or a filename collision.
public enum PreDownloadedAudioFile {
    /// Move only completed audio files. Never overwrite, evict, or delete failed sources.
    /// No one-shot flag: a failed move is retried on the next launch.
    public static func migrateLegacyFiles(from source: URL, to destination: URL, extensions: Set<String>,
                                          didMove: ((URL, URL) -> Void)? = nil) -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        guard source.standardizedFileURL != destination.standardizedFileURL else { return [] }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey], options: .skipsHiddenFiles),
              (try? fm.createDirectory(at: destination, withIntermediateDirectories: true)) != nil else { return [] }
        var moved: [URL] = []
        for file in files {
            guard extensions.contains(file.pathExtension.lowercased()),
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else { continue }
            if sourceIdentity(at: file) == nil {
                // Preserve old lookup names even when a home-folder collision requires renaming.
                let name = Data(file.lastPathComponent.utf8)
                let status = name.withUnsafeBytes { setxattr(file.path, legacyAttribute, $0.baseAddress, name.count, 0, 0) }
                if status != 0 { continue }
            }
            var number = 1
            while true {
                let name = number == 1 ? file.lastPathComponent :
                    file.deletingPathExtension().lastPathComponent + " \(number)." + file.pathExtension
                let target = destination.appendingPathComponent(name)
                if !fm.fileExists(atPath: target.path) {
                    do {
                        try fm.moveItem(at: file, to: target)
                        moved.append(target)
                        didMove?(file, target)
                        break
                    } catch {
                        if !fm.fileExists(atPath: target.path) { break }
                    }
                }
                number += 1
            }
        }
        return moved
    }

    private static let attribute = "com.wakemusic.predownload.source"
    private static let legacyAttribute = "com.wakemusic.predownload.legacyName"
    private static let lock = NSLock()

    public static func sourceIdentity(at url: URL) -> String? {
        readAttribute(attribute, at: url)
    }

    public static func legacyFilename(at url: URL) -> String? {
        readAttribute(legacyAttribute, at: url)
    }

    private static func readAttribute(_ attribute: String, at url: URL) -> String? {
        let size = getxattr(url.path, attribute, nil, 0, 0, 0)
        guard size > 0, size <= 256 else { return nil }
        var data = Data(count: size)
        let count = data.withUnsafeMutableBytes { getxattr(url.path, attribute, $0.baseAddress, size, 0, 0) }
        guard count == size else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func filename(title: String?, artist: String?, originalName: String) -> String {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let original = (originalName as NSString).lastPathComponent
        let ext = (original as NSString).pathExtension
        let stem = !title.isEmpty && !artist.isEmpty ? title + "-" + artist : (original as NSString).deletingPathExtension
        return safeComponent(stem) + (ext.isEmpty ? "" : "." + safeComponent(ext, maxBytes: 20))
    }

    private static func safeComponent(_ value: String, maxBytes: Int = 210) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
        var result = value.components(separatedBy: illegal).joined(separator: "_")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        while result.utf8.count > maxBytes { result.removeLast() }
        return result.isEmpty ? "Audio" : result
    }

    /// Called after HTTP completion and local TagLib parsing, never on a partial file.
    public static func store(_ downloadedURL: URL, in folder: URL, title: String?, artist: String?,
                             originalName: String, identity: String) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let existing = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        if let cached = existing.first(where: { sourceIdentity(at: $0) == identity }) {
            if downloadedURL != cached { try fm.removeItem(at: downloadedURL) }
            return cached
        }
        let marker = Data(identity.utf8)
        let status = marker.withUnsafeBytes { setxattr(downloadedURL.path, attribute, $0.baseAddress, marker.count, 0, 0) }
        guard status == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let name = filename(title: title, artist: artist, originalName: originalName)
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var number = 1
        while true {
            let suffix = number == 1 ? "" : " \(number)"
            let candidate = folder.appendingPathComponent(stem + suffix + (ext.isEmpty ? "" : "." + ext))
            if !fm.fileExists(atPath: candidate.path) {
                do {
                    // moveItem never overwrites an existing destination, including races.
                    try fm.moveItem(at: downloadedURL, to: candidate)
                    return candidate
                } catch {
                    guard fm.fileExists(atPath: candidate.path) else { throw error }
                }
            }
            number += 1
        }
    }
}

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
        let cachedFiles = self.preDownloadURL().readLocalSubFiles()
        let identity = model.preDownloadIdentity()
        if let cached = cachedFiles.first(where: { PreDownloadedAudioFile.sourceIdentity(at: $0) == identity }) {
            return cached
        }
        let publicFiles = self.getAllSubFiles(self.basePublicFileURL())
        if let cached = publicFiles.first(where: { PreDownloadedAudioFile.sourceIdentity(at: $0) == identity }) {
            return cached
        }
        // FTP was introduced after source markers became mandatory. An untagged
        // file with the same display name may belong to another server (or a
        // local import), so it must never satisfy an FTP cache lookup.
        if model.ftpFile != nil { return nil }
        let legacyName = (model.pcloudFile != nil || model.megaFile != nil || model.yandexFile != nil ||
                          model.guangyaFile != nil || model.pan123File != nil || model.boxFile != nil || model.smbFile != nil)
            ? model.filePathName() + model.addPathExtension() : model.downloadPathName()
        if let migrated = publicFiles.first(where: { PreDownloadedAudioFile.legacyFilename(at: $0) == legacyName }) {
            return migrated
        }
        // A display filename is not a unique identifier across cloud folders/accounts.
        if model.pcloudFile != nil || model.megaFile != nil || model.yandexFile != nil || model.guangyaFile != nil || model.pan123File != nil || model.boxFile != nil || model.smbFile != nil {
            let url = self.preDownloadURL().appendingPathComponent(model.filePathName() + model.addPathExtension())
            if FileManager.default.fileExists(atPath: url.path) { return url }
            let migrated = self.basePublicFileURL().appendingPathComponent(url.lastPathComponent)
            return PreDownloadedAudioFile.sourceIdentity(at: migrated) == nil && FileManager.default.fileExists(atPath: migrated.path) ? migrated : nil
        }
        
        let allFileURLArray1 = cachedFiles
        let allFileURLArray2 = publicFiles
        
        let allFileURLArray = allFileURLArray1 + allFileURLArray2
        // Legacy untagged downloads retain their old lookup behavior. A renamed cache
        // belonging to a different source must never be selected just by its name.
        let legacyFiles = allFileURLArray.filter { PreDownloadedAudioFile.sourceIdentity(at: $0) == nil }
        let allFileNameArray = legacyFiles.map { $0.lastPathComponent }
        
//        debugPrint("所有缓存的路径 = \(allFileNameArray)")
//        debugPrint("当前要播放的音乐 = \(model.downloadPathName())")
        
        if let index = allFileNameArray.firstIndex(where: { $0 == model.downloadPathName() }) {
            let cacheURL = legacyFiles[index]
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
        
        guard let image, image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else {
            fail?(KakaError.custom("convert image failed!"))
            return
        }

        // Bound decoded cache size as well as file size. Compression alone still
        // leaves a huge source image huge when decoded by a scrolling list.
        let ratio = min(1, 1200 / max(image.size.width * image.scale, image.size.height * image.scale))
        let size = CGSize(width: max(1, image.size.width * image.scale * ratio),
                          height: max(1, image.size.height * image.scale * ratio))
        let imageData: Data? = autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                UIColor.black.setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            return thumbnail.jpegData(compressionQuality: 0.88)
        }
        guard let imageData else {
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
            
            let targetFolderURL = model.localArtworkCacheURL()
            
            try imageData.write(to: targetFolderURL, options: .atomic)
            
            DispatchQueue.main.async {
                success?(targetFolderURL)
                NotificationCenter.default.post(name: .musicArtworkCacheDidChange, object: model.artworkCacheKey())
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
