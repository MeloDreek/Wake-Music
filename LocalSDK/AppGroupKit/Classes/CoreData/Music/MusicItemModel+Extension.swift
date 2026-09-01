//
//  MusicItemModel+Extension.swift
//  AppGroupKit
//
//  Created by 张文 on 7/16/25.
//

import KakaFoundation

extension MusicItemModel {
    /// 是否为本地音乐
    public func isLocalFile() -> Bool {
        switch fileSourceType {
        case .demoFile, .localFile, .fromFolder, .fromApple, .fromVideos, .fromUSB, .fromWiFi:
            return true
        default:
            return false
        }
    }
    
    /// 文件路径名称，以 歌手名 - 歌名为格式
    public func filePathName() -> String {
        if self.isLocalFile() {
            let title = self.showTitleName()
            let artist = self.artist ?? "Unknown Artist".localStr()
            
            return artist + " - " + title
        }else{
            // 远程文件
            if let navSong = self.navidromeSong {
                let fullName = navSong.artist + " - " + navSong.title
                return fullName
            }else if let webFileModel = self.webFileModel {
                let fullName = self.mediaPlayURL.lastPathComponent.ocString.deletingPathExtension
                return fullName
            }else if let baidFile = self.baiduFileModel {
                let fullName = baidFile.server_filename.ocString.deletingPathExtension + "_\(baidFile.fs_id)"
                return fullName
            }else if let aliFileModel = self.aliFileModel {
                let fullName = aliFileModel.name.ocString.deletingPathExtension + "_\(aliFileModel.file_id)"
                return fullName
            }else if let drive115Model = self.drive115Model {
                let fullName = drive115Model.fileName()
                return fullName
            }else if let googleFile = self.googleFile {
                let fullName = googleFile.name
                return fullName
            }else if let dropboxFile = self.dropboxFile {
                let fullName = dropboxFile.name
                return fullName
            }else if let onedriveFile = self.onedriveFile {
                let fullName = onedriveFile.name
                return fullName
            }
            else{
                let fullName = self.mediaPlayURL.lastPathComponent.ocString.deletingPathExtension
                return fullName
            }
        }
    }
    
    /// 歌手名 - 歌名.mp3
    public func downloadPathName() -> String {
        if self.isLocalFile() {
            let artist = self.artist ?? "Unknown Artist".localStr()
            let title = self.title ?? "Unknown Title".localStr()
            let fullName = artist + " - " + title
            return fullName + self.addPathExtension()
        }else{
            if let navSong = self.navidromeSong {
                let fullName = navSong.artist + " - " + navSong.title + "." + navSong.suffix
                return fullName
            }
            
            if let webFileModel = self.webFileModel {
                return webFileModel.fileName
            }
            
            if let baiduFile = self.baiduFileModel {
                return baiduFile.server_filename
            }
            
            if let aliFileModel = self.aliFileModel {
                return aliFileModel.name
            }
            
            if let drive115Model = self.drive115Model {
                return drive115Model.fileName()
            }
            
            if let googleFile = self.googleFile {
                return googleFile.name
            }
            
            if let dropboxFile = self.dropboxFile {
                return dropboxFile.name
            }
            
            if let onedriveFile = self.onedriveFile {
                return onedriveFile.name
            }
            
            return self.mediaPlayURL.lastPathComponent
        }
    }
    
    /// 是否为文件夹
    public func isFolder() -> Bool {
        
        if let webFileModel = self.webFileModel {
            return webFileModel.isDirectory
        }
        
        if let baiduFileModel = self.baiduFileModel {
            return baiduFileModel.isDirectory()
        }
        
        if let aliFileModel = self.aliFileModel {
            return aliFileModel.isDirectory()
        }
        
        if let drive115Model = self.drive115Model {
            return drive115Model.isDirectory()
        }
        
        if let googleFile = self.googleFile {
            return googleFile.isDirectory()
        }
        
        if let dropboxFile = self.dropboxFile {
            return dropboxFile.isDirectory()
        }
        
        if let onedriveFile = self.onedriveFile {
            return onedriveFile.isDirectory()
        }
        
        if let _ = self.navidromeSong {
            return false
        }
        
        return self.mediaPlayURL.hasDirectoryPath
    }
    
    /// 文件类型<文件夹、音乐、其他>
    public func fileType() -> ConnectFileType {
        if self.isFolder() { return .folder }
        
        if let webFileModel = self.webFileModel {
            return self.mediaPlayURL.isSupportMusicFile(false) ? .music : .other
        }
        
        if let baiduFileModel = self.baiduFileModel {
            return baiduFileModel.isMusic() ? .music : .other
        }
        
        if let aliFileModel = self.aliFileModel {
            return aliFileModel.isMusic() ? .music : .other
        }
        
        if let drive115Model = self.drive115Model {
            return drive115Model.isMusic() ? .music : .other
        }
        
        if let googleFile = self.googleFile {
            return googleFile.isMusic() ? .music : .other
        }
        
        if let dropboxFile = self.dropboxFile {
            return dropboxFile.isMusic() ? .music : .other
        }
        
        if let onedriveFile = self.onedriveFile {
            return onedriveFile.isMusic() ? .music : .other
        }
        
        if let _ = self.navidromeSong {
            return .music
        }
        
        return self.mediaPlayURL.isSupportMusicFile(false) ? .music : .other
    }
    
    /// 是否为LRC文件
    public func isLRCFile() -> Bool {
        return self.mediaPlayURL.isLRCFile()
    }
    
    /// 是否有歌词
    public func isHaveLyric() -> Bool {
        guard let lyrics = self.lyricModel?.lyrics, lyrics.count > 0 else { return false }
        
        return true
    }
    
    /// 是否已收藏
    public func isFlagFavorite() -> Bool {
        if self.isLocalFile() {
            let fileName = self.mediaPlayURL.lastPathComponent
            let isLike = SandboxFileManager.shared.favoriteArray.contains(fileName)
            
            return isLike
        }else{
            return self.isFavorite
        }
        
    }
    
    /// 文件尺寸，字节为单位
    public func fileSize() -> Int64 {
        if let navSong = self.navidromeSong {
            return Int64(max(navSong.size, 0))
        }else if let webFileModel = self.webFileModel {
            return Int64(max(webFileModel.fileSize, 0))
        }else if let baiduFile = self.baiduFileModel {
            return Int64(max(baiduFile.size, 0))
        }else if let aliFileModel = self.aliFileModel {
            return Int64(max(aliFileModel.size ?? 0, 0))
        }else if let file115 = self.drive115Model {
            return Int64(max(file115.size, 0))
        }else if let googleFile = self.googleFile {
            return Int64(max(googleFile.size, 0))
        }else if let dropboxFile = self.dropboxFile {
            return Int64(max(dropboxFile.size ?? 0, 0))
        }else if let onedriveFile = self.onedriveFile {
            return Int64(max(onedriveFile.size, 0))
        }
        else{
            return Int64(self.mediaPlayURL.fileSize)
        }
    }
}



extension MusicItemModel {
    /// 拼接文件后缀
    public func addPathExtension() -> String {
        if let webFileModel = self.webFileModel {
            // 1️⃣webdav
            return "." + webFileModel.fileExtension
        }else if let navSong = self.navidromeSong {
            // 2️⃣navidrome
            return "." + navSong.suffix
        }else if let baiduFile = self.baiduFileModel {
            // 3️⃣百度网盘
            let name = baiduFile.fileExtension()
            return name.isEmpty ? name : "." + name
        }else if let aliFileModel = self.aliFileModel {
            // 3️⃣阿里云盘
            let name = aliFileModel.fileExtension()
            return name.isEmpty ? name : "." + name
        }else if let drive115Model = self.drive115Model {
            // 4️⃣115网盘
            let name = drive115Model.fileExtension()
            return name.isEmpty ? name : "." + name
        }else if let googleFile = self.googleFile {
            // 5️⃣谷歌网盘
            let name = googleFile.fileExtension()
            return name.isEmpty ? name : "." + name
        }else if let dropboxFile = self.dropboxFile {
            // 6️⃣Dropbox网盘
            let name = dropboxFile.fileExtension()
            return name.isEmpty ? name : "." + name
        }else if let onedriveFile = self.onedriveFile {
            // 7️⃣OneDrive网盘
            let name = onedriveFile.fileExtension()
            return name.isEmpty ? name : "." + name
        }else{
            // 本地文件
            let urlPath = "." + self.mediaPlayURL.pathExtension
            return self.isFolder() ? "" : urlPath
        }
    }
    
    /// 时间格式化
    public func durationTimeStr() -> String {
        
        if self.isLocalFile() {
            guard self.durationSeconds > 0 else {
                return ""
            }
            
            // 计算分钟和秒数
            let minutes = self.durationSeconds / 60
            let seconds = self.durationSeconds % 60
            
            // 格式化为 "mm:ss" 格式
            return String(format: "%02d:%02d", minutes, seconds)
        }else{
            if let navSong = self.navidromeSong {
                let minutes = navSong.duration / 60
                let seconds = navSong.duration % 60
                return navSong.duration > 0 ? String(format: "%02d:%02d", minutes, seconds) : ""
            }
            
            if let webFileModel = self.webFileModel, webFileModel.fileSize > 0 {
                return URL.formatFileSize(webFileModel.fileSize)
            }
            
            if let baiduFileModel = self.baiduFileModel {
                return baiduFileModel.isDirectory() ? "" : URL.formatFileSize(Int64(baiduFileModel.size))
            }
            
            if let aliFileModel = self.aliFileModel {
                return aliFileModel.isDirectory() ? "" : URL.formatFileSize(aliFileModel.size ?? 0)
            }
            
            if let drive115Model = self.drive115Model {
                return drive115Model.isDirectory() ? "" : URL.formatFileSize(Int64(drive115Model.size))
            }
            
            if let googleFile = self.googleFile {
                return googleFile.isDirectory() ? "" : URL.formatFileSize(Int64(googleFile.size))
            }
            
            if let dropboxFile = self.dropboxFile {
                return dropboxFile.isDirectory() ? "" : URL.formatFileSize(Int64(dropboxFile.size ?? 0))
            }
            
            if let onedriveFile = self.onedriveFile {
                return onedriveFile.isDirectory() ? "" : URL.formatFileSize(onedriveFile.size)
            }
            
            return ""
        }
        
    }
    
    /// 显示的音乐名称，没有后缀
    public func showTitleName() -> String {
        if self.isLocalFile() {
            if self.fileSourceType == .demoFile {
                return "7.1 Surround".localStr()
            }else{
                let fileName = self.mediaPlayURL.lastPathComponent.ocString.deletingPathExtension
                guard let title = self.title, !title.isEmpty else { return fileName }
                return title
            }
        }else{
            if let webFileModel = self.webFileModel {
                let fileName = self.webFileModel?.fileName.ocString.deletingPathExtension ?? self.mediaPlayURL.lastPathComponent.ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let navSong = self.navidromeSong {
                return navSong.title
            }else if let baiduFile = self.baiduFileModel {
                let fileName = baiduFile.server_filename.ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let aliFileModel = self.aliFileModel {
                let fileName = aliFileModel.name.ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let drive115Model = self.drive115Model {
                let fileName = drive115Model.fileName().ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let googleFile = self.googleFile {
                let fileName = googleFile.name.ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let dropboxFile = self.dropboxFile {
                let fileName = dropboxFile.name.ocString.deletingPathExtension
                return self.title ?? fileName
            }else if let onedriveFile = self.onedriveFile {
                let fileName = onedriveFile.name.ocString.deletingPathExtension
                return self.title ?? fileName
            }else{
                let fileName = self.mediaPlayURL.lastPathComponent.ocString.deletingPathExtension
                return fileName
            }
        }
    }
    
    /// 艺术家名称
    public func showArtistName() -> String {
        
        if self.isLocalFile() {
            if self.fileSourceType == .demoFile {
                return "Wakemusic".localStr()
            }else if self.isLRCFile() {
                return "LRC Lyrics File".localStr()
            }else{
                return self.artist ?? "Unknown Artist".localStr()
            }
        }else{
            if let navSong = self.navidromeSong {
                return self.artist ?? navSong.artist
            }else{
                return self.artist ?? "Unknown Artist".localStr()
            }
        }
        
    }
    
    
    // 搜索方法：歌曲名、歌手名、专辑名
    public func searchMatcheItem(_ queryKey: String) -> Bool {
        
        var fullSearchText = ""
        
        if let navSong = self.navidromeSong {
            fullSearchText = navSong.title + navSong.artist + navSong.album
        }else if let webFileModel = self.webFileModel {
            fullSearchText = webFileModel.fileName
        }else if let baiduFileModel = self.baiduFileModel {
            fullSearchText = baiduFileModel.server_filename
        }else if let aliFileModel = self.aliFileModel {
            fullSearchText = aliFileModel.name
        }else if let drive115Model = self.drive115Model {
            fullSearchText = drive115Model.fileName()
        }else if let googleFile = self.googleFile {
            fullSearchText = googleFile.name
        }else if let dropboxFile = self.dropboxFile {
            fullSearchText = dropboxFile.name
        }else if let onedriveFile = self.onedriveFile {
            fullSearchText = onedriveFile.name
        }else{
            fullSearchText = (self.title ?? "") + (self.artist ?? "") + (self.album ?? "")
        }
                
        let matched = fullSearchText.lowercased().contains(queryKey.lowercased())
        
        //debugPrint("搜索 = \(fullSearchText)，关键字 = \(queryKey)，是否匹配 = \(matched)")
        
        return matched
    }
    
    /// 分组首字母
    public func firstChar(_ groupType: GroupItemType) -> String {
        
        var title: String = "#"
        switch groupType {
        case .nonGroup:
            title = "#"
        case .musictagGroup:
            title = "#"
        case .titleGroup:
            title = self.showTitleName()
        case .artistGroup:
            title = self.showArtistName()
        }
        
        let firstChar = FirstCharHelper.shared.firstChar(title)
        
        return firstChar
    }
    
    /// 创建时间
    public func creationDate() -> Date {
        if let webFileModel = self.webFileModel {
            // 1️⃣webdav
            let date = webFileModel.modifiedDate ?? webFileModel.creationDate ?? 0
            return Date(timeIntervalSince1970: date.rounded())
        }else if let navSong = self.navidromeSong {
            // 2️⃣navidrome
            return Date.distantPast
        }else if let baiduFile = self.baiduFileModel {
            // 3️⃣百度网盘
            return Date(timeIntervalSince1970: TimeInterval(baiduFile.server_ctime).rounded())
        }else if let aliFileModel = self.aliFileModel {
            // 3️⃣阿里云盘
            return Date(timeIntervalSince1970: aliFileModel.created_at?.rounded() ?? 0)
        }else if let drive115Model = self.drive115Model {
            // 4️⃣115网盘
            return drive115Model.createDate()
        }else if let googleFile = self.googleFile {
            // 5️⃣谷歌网盘
            return googleFile.createdDate() ?? Date.distantFuture
        }else if let dropboxFile = self.dropboxFile {
            // 6️⃣Dropbox网盘
            return dropboxFile.createdDate() ?? Date.distantFuture
        }else{
            // 本地文件
            return self.mediaPlayURL.creationDate ?? Date.distantPast
        }
    }
    
    /// 修改时间
    public func modificationDate() -> Date {
        if let webFileModel = self.webFileModel {
            // 1️⃣webdav
            let date = webFileModel.modifiedDate ?? webFileModel.creationDate ?? 0
            return Date(timeIntervalSince1970: date.rounded())
        }else if let navSong = self.navidromeSong {
            // 2️⃣navidrome
            return Date.distantPast
        }else if let baiduFile = self.baiduFileModel {
            // 3️⃣百度网盘
            return Date(timeIntervalSince1970: TimeInterval(baiduFile.server_mtime).rounded())
        }else if let aliFileModel = self.aliFileModel {
            // 3️⃣阿里云盘
            return Date(timeIntervalSince1970: aliFileModel.updated_at?.rounded() ?? 0)
        }else if let drive115Model = self.drive115Model {
            // 4️⃣115网盘
            return drive115Model.modifyDate()
        }else if let googleFile = self.googleFile {
            // 5️⃣谷歌网盘
            return googleFile.modifiedDate() ?? Date.distantFuture
        }else if let dropboxFile = self.dropboxFile {
            // 6️⃣Dropbox网盘
            return dropboxFile.modifiedDate() ?? Date.distantFuture
        }else{
            // 本地文件
            return self.mediaPlayURL.modificationDate ?? Date.distantPast
        }
    }
    
    /// 排序使用的名称
    public func sortFileName() -> String {
        if let webFileModel = self.webFileModel {
            // 1️⃣webdav
            return webFileModel.fileName
        }else if let navSong = self.navidromeSong {
            // 2️⃣navidrome
            return self.filePathName()
        }else if let baiduFile = self.baiduFileModel {
            // 3️⃣百度网盘
            return baiduFile.server_filename
        }else if let aliFileModel = self.aliFileModel {
            // 3️⃣阿里云盘
            return aliFileModel.name
        }else if let drive115Model = self.drive115Model {
            // 4️⃣115网盘
            return drive115Model.fileName()
        }else if let googleFile = self.googleFile {
            // 5️⃣谷歌网盘
            return googleFile.name
        }else if let dropboxFile = self.dropboxFile {
            // 5️⃣Dropbox网盘
            return dropboxFile.name
        }else{
            // 本地文件
            return self.mediaPlayURL.lastPathComponent
        }
    }
    
    // 排序
    public func sortAnotherModel(model2: MusicItemModel, sortType: SortedbyType) -> Bool {
        let isAscending = MusicConfigManager.shared.isSortAscending
        
        switch sortType {
        case .createDate:
            // 1️⃣创建时间
            let date1 = self.creationDate()
            let date2 = model2.creationDate()
            return isAscending ? date1 > date2 : date1 < date2
            
        case .modifyDate:
            // 2️⃣修改时间
            let date1 = self.modificationDate()
            let date2 = model2.modificationDate()
            return isAscending ? date1 > date2 : date1 < date2
            
        case .fileSize:
            // 3️⃣文件尺寸
            let size1 = self.fileSize()
            let size2 = model2.fileSize()
            return isAscending ? size1 < size2 : size1 > size2
            
        case .fileName:
            // 4️⃣文件名称
            let name1 = self.sortFileName()
            let name2 = model2.sortFileName()

            let number1 = name1.extractFirstNumber()
            let number2 = name2.extractFirstNumber()

            switch (number1, number2) {
            case let (n1?, n2?):
                // 两者都提取出数字，按数字排序
                return isAscending ? n1 < n2 : n1 > n2
            case (nil, nil):
                // 都没有数字，使用稳定的本地化排序
                return isAscending
                    ? name1.localizedCompare(name2) == .orderedAscending
                    : name1.localizedCompare(name2) == .orderedDescending
            case (_?, nil):
                // name1 有数字，name2 没有 → 有数字的排前面
                return true
            case (nil, _?):
                // name2 有数字，name1 没有
                return false
            }
        }
    }
    
}
