//
//  MusicItemModel.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/24.
//

import KakaFoundation
import SmartCodable
import Photos
import CloudKit
import MediaPlayer

/// 音乐模型
public struct MusicItemModel: SmartCodableX, Equatable, Hashable, Sendable {
    
    public init() {}
    
    // 本地音乐的构造方法
    public init(fileURL: URL, sourceType: ImportFileType) {
        self.fileSourceType = sourceType
        self.mediaPlayURL = fileURL
    }
    
    // 构造Apple Music本地音乐
    public init(appleMusic: MPMediaItem) {
        self.fileSourceType = .fromApple
        self.mediaPlayURL = appleMusic.assetURL!
        self.title = appleMusic.title
        self.artist = appleMusic.artist
        self.album = appleMusic.albumTitle
        self.genre = appleMusic.genre
        self.year = appleMusic.releaseDate?.year
        self.track = appleMusic.albumTrackNumber
        self.comment = appleMusic.comments
        self.durationSeconds = Int(appleMusic.playbackDuration)
        
        if let coverImage = appleMusic.artwork?.image(at: CGSize(width: 100, height: 100)) {
            SandboxFileManager.shared.writeMusicthumbnailImage(model: self, image: coverImage)
        }
    }
    
    // Webdav文件的构造方法
    public init(webFileModel: WebdavFileModel) {
        self.fileSourceType = .fromWebDav
        self.mediaPlayURL = webFileModel.mediaPlayURL ?? SandboxFileManager.shared.basePublicFileURL()
        self.webFileModel = webFileModel
    }
    
    // Navidrome的构造方法
    public init(navSong: NavidromeSong) {
        self.fileSourceType = .fromNavidrome
        self.mediaPlayURL = navSong.mediaPlayURL() ?? SandboxFileManager.shared.basePublicFileURL()
        self.navidromeSong = navSong
        self.isFavorite = navSong.starred
        self.title = navSong.title
        self.durationSeconds = navSong.duration
        self.genre = navSong.genre
        self.album = navSong.album
        self.artist = navSong.artist
        self.year = navSong.year
        self.channel = AudioChannels(channel: navSong.channelCount)
        self.track = navSong.trackNumber
        self.bitrate = navSong.bitRate
        self.sampleRate = navSong.samplingRate
    }
    
    // 百度网盘的构造方法
    public init(baiduFile: BaiduDriveFileModel) {
        self.fileSourceType = .fromBaiduDrive
        self.mediaPlayURL = baiduFile.m3uCacheURL()
        self.baiduFileModel = baiduFile
    }
    
    // 百度网盘的构造方法
    public init(aliFile: AliyunpanFileModel) {
        self.fileSourceType = .fromAliyunDrive
        self.mediaPlayURL = aliFile.mediaPlayURL()
        self.aliFileModel = aliFile
    }
    
    /// 115网盘的构造方法
    public init(file115: Drive115FileModel) {
        self.fileSourceType = .from115Drive
        self.mediaPlayURL = file115.mediaPlayURL()
        self.drive115Model = file115
    }
    
    /// 谷歌网盘的构造方法
    public init(googleFile: GoogleDriveFileModel) {
        self.fileSourceType = .fromGoogleDrive
        self.mediaPlayURL = googleFile.mediaPlayURL()
        self.googleFile = googleFile
    }
    
    /// Dropbox的构造方法
    public init(dropboxFile: DropboxDriveFileModel) {
        self.fileSourceType = .fromDropboxDrive
        self.mediaPlayURL = dropboxFile.mediaPlayURL()
        self.dropboxFile = dropboxFile
    }
    
    public init(smbFile: SMBDriveFileModel) {
        self.fileSourceType = .fromSMB
        self.mediaPlayURL = smbFile.mediaPlayURL()
        self.smbFile = smbFile
    }
    public init(yandexFile: YandexDriveFileModel) {
        self.fileSourceType = .fromYandexDrive
        self.mediaPlayURL = yandexFile.mediaPlayURL()
        self.yandexFile = yandexFile
    }
    public init(boxFile: BoxDriveFileModel) {
        self.fileSourceType = .fromBoxDrive
        self.mediaPlayURL = boxFile.mediaPlayURL()
        self.boxFile = boxFile
    }
    public init(megaFile: MEGADriveFileModel) {
        self.fileSourceType = .fromMEGADrive
        self.mediaPlayURL = megaFile.mediaPlayURL()
        self.megaFile = megaFile
    }
    public init(pcloudFile: PCloudDriveFileModel) {
        self.fileSourceType = .fromePCloud
        self.mediaPlayURL = pcloudFile.mediaPlayURL()
        self.pcloudFile = pcloudFile
    }

    /// OneDrive的构造方法
    public init(onedriveFile: OneDriveFileModel) {
        self.fileSourceType = .fromOneDrive
        self.mediaPlayURL = onedriveFile.mediaPlayURL()
        self.onedriveFile = onedriveFile
    }
    
    /// 是否为复制的文件，如果不是，那就是link连接
    public var handleType = FileHandleType.copy
    
    /// 文件来源
    public var fileSourceType = ImportFileType.localFile
    
    /// Web文件模型
    public var webFileModel: WebdavFileModel?
    
    /// Navidrome歌曲模型
    public var navidromeSong: NavidromeSong?
    
    /// 百度网盘的文件
    public var baiduFileModel: BaiduDriveFileModel?
    
    /// 阿里云盘的文件
    public var aliFileModel: AliyunpanFileModel?
    
    /// 115网盘的文件
    public var drive115Model: Drive115FileModel?
    
    /// 谷歌网盘的文件
    public var googleFile: GoogleDriveFileModel?
    
    /// Dropbox的文件
    public var dropboxFile: DropboxDriveFileModel?
    
    /// OneDrive的文件
    public var onedriveFile: OneDriveFileModel?
    
    public var smbFile: SMBDriveFileModel?
    public var yandexFile: YandexDriveFileModel?
    public var boxFile: BoxDriveFileModel?
    public var megaFile: MEGADriveFileModel?
    public var pcloudFile: PCloudDriveFileModel?

    /// 媒体播放路径
    public var mediaPlayURL = SandboxFileManager.shared.basePublicFileURL()
    
    /// 歌曲名称
    public var title: String?
    
    /// 艺术家
    public var artist: String?
    
    /// 专辑名称
    public var album: String?
    
    /// 下载的歌单名称，需要拼接跟路径->SandboxFileManager.share.basePublicFileURL
    public var downloadFolderName: String?
    
    /// 是否收藏，仅用于远程资源
    public var isFavorite: Bool = false
    
    /// 时间（秒）
    public var durationSeconds: Int = 0
    
    /// 音轨号
    public var track: Int?
    
    /// 音频比特率：比特每秒（kbps）
    public var bitrate: Int?
    
    /// 位深度
    public var bitDepth: Int?
    
    /// 音频采样率：赫兹（Hz）
    public var sampleRate: Int?
    
    /// 音乐流派
    public var genre: String?
    
    /// 音频通道数（int）
    public var channel: AudioChannels?
    
    /// 元数据上的评论
    public var comment: String?
    
    /// 发布年代
    public var year: Int?
    
    /// 歌词
    public var lyricModel: LyricInfoModel?
    
    /// 封面
    @SmartIgnored
    public var coverArt: KakaImage?
    
    /// 仅本地需要
    @SmartIgnored
    public var isSelected: Bool = false
    
    /// 定义一个主键
    public func uniqueID() -> String {
        if let file = smbFile { return file.identity }
        if let file = megaFile { return file.identity }
        if let file = yandexFile { return file.identity }
        if let file = boxFile { return file.identity }
        if let file = pcloudFile { return file.identity }
        
        if let filePath = self.webFileModel?.filePath { return "webdav-\(filePath)" }
        if let id = self.navidromeSong?.id { return "navidrome-\(id)" }
        if let id = self.googleFile?.id { return "google-\(id)" }
        if let id = self.dropboxFile?.id { return "dropbox-\(id)" }
        if let id = self.onedriveFile?.id { return "onedrive-\(id)" }
        if let id = self.drive115Model?.fileID() { return "115-\(id)" }
        if let id = self.baiduFileModel?.fs_id { return "baidu-\(id)" }
        
        // 本地文件 fallback
        return "local-\(self.filePathName())"
    }
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
//        hasher.combine(self.filePathName())
//        hasher.combine(self.navidromeSong?.id)
//        hasher.combine(self.webFileModel?.filePath)
//        hasher.combine(self.baiduFileModel?.fs_id)
//        hasher.combine(self.drive115Model?.fileID())
//        hasher.combine(self.googleFile?.id)
//        hasher.combine(self.dropboxFile?.id)
//        hasher.combine(self.onedriveFile?.id)
        
        hasher.combine(self.uniqueID())
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: MusicItemModel, rhs: MusicItemModel) -> Bool {
//        return lhs.filePathName() == rhs.filePathName() &&
//        lhs.drive115Model?.fileID() == rhs.drive115Model?.fileID() &&
//        lhs.webFileModel?.filePath == rhs.webFileModel?.filePath &&
//        lhs.baiduFileModel?.fs_id == rhs.baiduFileModel?.fs_id &&
//            lhs.navidromeSong?.id == rhs.navidromeSong?.id &&
//                 lhs.googleFile?.id == rhs.googleFile?.id &&
//                lhs.dropboxFile?.id == rhs.dropboxFile?.id &&
//               lhs.onedriveFile?.id == rhs.onedriveFile?.id
        
        return lhs.uniqueID() == rhs.uniqueID()
    }
    
}
