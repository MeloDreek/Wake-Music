//
//  AliyunpanFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 4/10/26.
//

import SmartCodable

/// 阿里云盘的文件  ==>  @AliyunpanFile
public struct AliyunpanFileModel: SmartCodable, Equatable, Hashable, Sendable {
    
    public init() { }
    
    public var drive_id: String = ""
    public var file_id: String = ""
    /// 根目录是 root
    public var parent_file_id: String = ""
    /// 文件名
    public var name: String = ""
    public var size: Int64?
    public var file_extension: String?
    /// 文件 hash
    public var content_hash: String?
    public var category: String?
    public var type: String?
    public var mime_type: String?
    
    /// 缩略图
    public var thumbnail: String?
    /// 图片预览图地址、小于 5MB 文件的下载地址。超过5MB 请使用 /getDownloadUrl
    public var url: String?
    public var created_at: TimeInterval?
    public var updated_at: TimeInterval?
    /// 播放进度
    public var play_cursor: String?
    
    /// 配置信息
    public var aliyunUser: AliyunpanUserModel?
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(drive_id)
        hasher.combine(parent_file_id)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: AliyunpanFileModel, rhs: AliyunpanFileModel) -> Bool {
        return lhs.drive_id == rhs.drive_id &&
         lhs.parent_file_id == rhs.parent_file_id
    }
    
}

extension AliyunpanFileModel {
    
    /// 是否为文件夹
    public func isDirectory() -> Bool {
        return self.type == "folder"
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = self.file_extension ?? ""
        return suffix.lowercased()
    }

    /// 是否为音乐
    public func isMusic() -> Bool {
        let suffix = self.fileExtension()
        return self.category == "audio" || AudioExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 是否为视频
    public func isVideo() -> Bool {
        let suffix = self.fileExtension()
        return self.category == "video" || VideoExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    // 第一个文字
    public func firstChar(_ sortType: SortedbyType) -> String {
        let title: String = self.name
        
        let collator =  UILocalizedIndexedCollation.current()
        let titleIndex = collator.section(for: title, collationStringSelector: #selector(NSObject.description))
        
        // sectionTitles = [A-Z+#]
        let firstChar = collator.sectionTitles[titleIndex]
        
        return firstChar
    }
    
    /// 封面地址
    public func coverImgURL() -> URL? {
        return URL(string: self.thumbnail ?? "")
    }
    
    /// 播放地址
    public func mediaPlayURL() -> URL {
        return URL(string: self.url ?? "") ?? SandboxFileManager.shared.basePublicFileURL()
    }
}
