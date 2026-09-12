//
//  MusicItemModel+Kaka.swift
//  Wakemusic
//
//  Created by Melo on 7/29/24.
//

import KakaFoundation
import AppGroupKit
import KSPlayer
import KakaTaglibKit
import FFmpegKit
import AVFoundation
import Kingfisher

extension MusicItemModel {
    
    /// 封面占位图
    func placeImage() -> KakaImage {
        if self.fileSourceType == .demoFile {
            return self.coverArt ?? KakaImage(named: "demo_art")!
        } else if self.fileSourceType == .fromNavidrome {
            if let navSong = self.navidromeSong {
                return KakaImage(named: "\(navSong.suffix)_icon") ?? KakaImage(named: "music_place")!
            }else{
                return KakaImage(named: "music_place")!
            }
        }else if self.fileSourceType == .fromBaiduDrive {
            if let baiduFile = self.baiduFileModel {
                let fileExtension = baiduFile.fileExtension()
                if baiduFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if baiduFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if baiduFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromAliyunDrive {
            if let aliFileModel = self.aliFileModel {
                let fileExtension = aliFileModel.fileExtension()
                if aliFileModel.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if aliFileModel.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if aliFileModel.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .from115Drive {
            if let drive115Model = self.drive115Model {
                let fileExtension = drive115Model.fileExtension()
                if drive115Model.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if drive115Model.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if drive115Model.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromGoogleDrive {
            if let googleFile = self.googleFile {
                let fileExtension = googleFile.fileExtension()
                if googleFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if googleFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if googleFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromDropboxDrive {
            if let dropboxFile = self.dropboxFile {
                let fileExtension = dropboxFile.fileExtension()
                if dropboxFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if dropboxFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if dropboxFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if let file = self.smbFile {
            if file.isDirectory() { return KakaImage(named: "folder_icon")! }
            return KakaImage(named: "\(file.fileExtension())_icon") ?? KakaImage(named: "music_place")!
        }else if self.fileSourceType == .fromMEGADrive {
            if let megaFile = self.megaFile {
                let fileExtension = megaFile.fileExtension()
                if megaFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if megaFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if megaFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromYandexDrive {
            if let yandexFile = self.yandexFile {
                let fileExtension = yandexFile.fileExtension()
                if yandexFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if yandexFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if yandexFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromBoxDrive {
            if let boxFile = self.boxFile {
                let fileExtension = boxFile.fileExtension()
                if boxFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if boxFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if boxFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromePCloud {
            if let pcloudFile = self.pcloudFile {
                let fileExtension = pcloudFile.fileExtension()
                if pcloudFile.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if pcloudFile.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if pcloudFile.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else if self.fileSourceType == .fromOneDrive {
            if let fromOneDrive = self.onedriveFile {
                let fileExtension = fromOneDrive.fileExtension()
                if fromOneDrive.isDirectory() {
                    return KakaImage(named: "folder_icon")!
                }else if fromOneDrive.isMusic() {
                    return KakaImage(named: "\(fileExtension)_icon") ?? KakaImage(named: "music_place")!
                }else if fromOneDrive.isVideo() {
                    return UIImage(named: "video_place")!
                }else{
                    return KakaImage(named: "file_place")!
                }
            }else{
                return KakaImage(named: "file_place")!
            }
        }else{
            if AudioExtensionType.allCases.map({ $0.rawValue }).contains(self.mediaPlayURL.pathExtension.lowercased()) {
                return KakaImage(named: "\(self.mediaPlayURL.pathExtension.lowercased())_icon") ?? UIImage(named: "video_place")!
            }else if VideoExtensionType.allCases.map({ $0.rawValue }).contains(self.mediaPlayURL.pathExtension.lowercased()) {
                return UIImage(named: "video_place")!
            } else{
                if let webFileModel = self.webFileModel {
                    if webFileModel.isDirectory {
                        return KakaImage(named: "folder_icon")!
                    }else{
                        return KakaImage(named: "file_place")!
                    }
                }else{
                    if self.isFolder() {
                        return KakaImage(named: "folder_icon")!
                    }else if self.isLRCFile() {
                        return KakaImage(named: "lyric_place")!
                    }else{
                        return KakaImage(named: "music_place")!
                    }
                }
            }
        }
    }
    
    /// 获取Webdav同名文件夹下的LRC歌词文件路径
    public func lrcFileInSameFolderURL() -> URL? {
        let lastName = self.mediaPlayURL.lastPathComponent
        let extensionStr = self.mediaPlayURL.pathExtension
        
        let lrcFileName = lastName.replaceChar(oldChar: extensionStr, newChar: "lrc")
        
        let folderURL = self.mediaPlayURL.deletingLastPathComponent()
        
        // 构造 LRC 文件的完整路径
        let lrcFileURL = folderURL.appendingPathComponent(lrcFileName)
        
        return lrcFileURL
    }
    
    /// 音乐流派
    public func musicGenreType() -> MusicGenreType? {
        guard let genre = self.genre, genre.count > 0, let genreType = MusicGenreType.initGenre(genre) else { return nil }
        
        return genreType
    }
    
    /// 音乐标签是否齐全
    public func isFullMusicTag() -> Bool {
        let isTitle = (self.title?.count ?? 0) > 0
        let isArtist = (self.artist?.count ?? 0) > 0
        
        let isCover = self.coverArt != nil || FileManager.default.fileExists(atPath: self.coverThumbnailURL().path)
        let isLyric = (self.lyricModel?.lyrics?.count ?? 0) > 0
        
        return isTitle && isArtist && isCover && isLyric
    }
    
    /// 文件缩略图地址
    public func coverThumbnailURL() -> URL {
        
        let fileName = self.filePathName() + ".jpg"
        var cacheCoverURL: URL
        if #available(iOS 16.0, *) {
            cacheCoverURL = SandboxFileManager.shared.coverPathURL().appending(path: fileName, directoryHint: .notDirectory)
        } else {
            cacheCoverURL = SandboxFileManager.shared.coverPathURL().appendingPathComponent(fileName)
        }
        
        if FileManager.default.fileExists(atPath: cacheCoverURL.path) { return cacheCoverURL }
        if let navSong = self.navidromeSong {
            return navSong.coverImgURL() ?? cacheCoverURL
        }else if let baiduFile = self.baiduFileModel {
            return baiduFile.coverImgURL() ?? cacheCoverURL
        }else if let drive115Model = self.drive115Model {
            return drive115Model.coverImgURL() ?? cacheCoverURL
        }
        else{
            return cacheCoverURL
        }
    }
    
    /// 音乐封面
    public func musicCoverImage() -> KakaImage? {
        let localURL = SandboxFileManager.shared.coverPathURL().appendingPathComponent(filePathName() + ".jpg")
        if let cached = UIImage(contentsOfFile: localURL.path) { return cached }
        if let navSong = self.navidromeSong, let imageURL = navSong.coverImgURL() {
            return imageURL.getCachedImage()
        }else if let baiduFile = self.baiduFileModel, let imageURL = baiduFile.coverImgURL() {
            return imageURL.getCachedImage()
        }else{
            if fileSourceType == .demoFile {
                return self.coverArt
            } else{
                let filePathStr = self.coverThumbnailURL().path
                return UIImage(contentsOfFile: filePathStr)
            }
        }
    }

    /// UI may display cached cloud artwork in any engine, but must never initiate tag parsing.
    func playbackCoverImage() -> UIImage {
        if let image = musicCoverImage() { return image }
        if isLocalFile(), mediaPlayURL.isFileURL, let image = TaglibMetadataParser.extractCoverArt(from: mediaPlayURL) {
            return image
        }
        return placeImage()
    }
    
    /// 构造一个试听音乐模型
    static func demoMusicModel() -> MusicItemModel {
        let fileURL = URL(fileURLWithPath: Reasource.fullFilePath("Wakemusic.dts"))
        
        let placeArtist = "Wakemusic".localStr()
        let lyricStr = "[00:00.000] \(placeArtist)\r[00:03.662] ⚡️⚡️⚡️\r[00:05.663] ☁️☁️☁️\r[00:07.664] 🌩️🌩️🌩️\r[00:09.665] 🌧️🌧️🌧️\r[00:11.666] ☂️☂️☂️\r[00:13.667] ☔️☔️☔️\r[00:15.668] 🌊🌊🌊\r[00:17.669] ❄️❄️❄️\r[00:19.660] ⛄️⛄️⛄️\r[00:21.661] ☃️☃️☃️\r[00:23.662] 💧💧💧\r[00:25.663] 🌈🌈🌈\r[00:27.664] 🌥️🌥️🌥️\r[00:29.665] ⛅️⛅️⛅️\r[00:31.666] 🌤️🌤️🌤️\r[00:32.666] ☀️☀️☀️\r[00:33.000] \(placeArtist)"
        
        let metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
        
        var newModel = MusicItemModel(fileURL: fileURL, sourceType: .demoFile)
        newModel.fileSourceType = .demoFile
        newModel.coverArt = metaData?.coverArt ?? UIImage(named: "demo_art")
        newModel.title = metaData?.title ?? "7.1 Surround".localStr()
        newModel.artist = metaData?.artist ?? "Wakemusic".localStr()
        newModel.album = metaData?.album ?? "Wakemusic".localStr()
        newModel.year = Int(metaData?.year ?? UInt(Date().year))
        newModel.durationSeconds = Int(metaData?.durationSeconds ?? 35)
        newModel.track = Int(metaData?.track ?? 1)
        newModel.bitrate = 1500000
        newModel.sampleRate = 2800000
        newModel.channel = AudioChannels.surround71
        newModel.genre = metaData?.genre ?? MusicGenreType.pop.rawValue
        newModel.comment = metaData?.comment ?? "This is a demo music"
        newModel.lyricModel = metaData?.lyricModel?.convertSwiftModel() ?? TaglibMetadataParser.parseSynchronizedLyrics(lyricStr).convertSwiftModel()
        return newModel
    }
    
}

extension MetadataTagModel {
    
    // 合并TagLib的元数据
    func mergeTagLibInfo(_ model: MusicItemModel) -> MusicItemModel {
        var newModel = model
        newModel.title = self.title
        newModel.artist = self.artist
        newModel.album = self.album
        newModel.year = Int(self.year)
        newModel.durationSeconds = Int(self.durationSeconds)
        newModel.track = Int(self.track)
        newModel.bitrate = Int(self.bitrate)
        newModel.sampleRate = Int(self.sampleRate)
        newModel.channel = AudioChannels(channel: Int(self.channel))
        newModel.genre = self.genre
        newModel.comment = self.comment
        newModel.lyricModel = self.lyricModel?.convertSwiftModel()
        
        return newModel
    }
    
}

extension URL {
    
    func getCachedImage() -> UIImage? {
        if FileManager.default.fileExists(atPath: self.path) {
            return UIImage(contentsOfFile: self.path)
        }else{
            let image = ImageCache.default.retrieveImageInMemoryCache(forKey: self.absoluteString)
            if let cgImage = image?.cgImage {
                return UIImage(cgImage: cgImage)
            }else{
                return nil
            }
        }
    }
    
}
