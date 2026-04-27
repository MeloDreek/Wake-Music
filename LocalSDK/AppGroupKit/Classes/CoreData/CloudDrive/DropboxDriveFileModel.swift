//
//  DropboxDriveFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 10/27/25.
//

import SmartCodable

public enum DropboxFileType: Int, SmartCaseDefaultable {
    case file = 0
    case folder = 1
    case other = 2
}

public struct DropboxDriveFileModel: SmartCodableX, Equatable, Hashable {
    
    public init() { }
    
    public init(fileType: DropboxFileType = .file, name: String, id: String?, path_display: String? = nil, path_lower: String? = nil, size: UInt64?, is_downloadable: Bool, client_modified: TimeInterval?, server_modified: TimeInterval?, dropboxUser: DropboxDriveUserModel? = nil) {
        self.fileType = fileType
        self.name = name
        self.id = id
        self.path_display = path_display
        self.path_lower = path_lower
        self.size = size
        self.is_downloadable = is_downloadable
        self.client_modified = client_modified
        self.server_modified = server_modified
        self.dropboxUser = dropboxUser
    }
    
    /// 文件类型：file / folder
    public var fileType: DropboxFileType = .file
    
    /// 文件或文件夹名称
    public var name: String = ""
    
    /// 文件唯一 ID（Dropbox内部ID）
    public var id: String?
    
    /// 文件完整路径（区分大小写）
    public var path_display: String?
    
    /// 文件完整路径（小写）
    public var path_lower: String?
    
    /// 文件大小（仅文件有）
    public var size: UInt64?
    
    /// 是否可以下载
    public var is_downloadable: Bool = false
    
    /// 客户端修改时间（本地设备的时间）
    public var client_modified: TimeInterval?
    
    /// 服务器保存时间
    public var server_modified: TimeInterval?
    
    /// 配置信息
    public var dropboxUser: DropboxDriveUserModel?
    
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path_lower)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: DropboxDriveFileModel, rhs: DropboxDriveFileModel) -> Bool {
        return lhs.id == rhs.id && lhs.path_lower == rhs.path_lower
    }
    
}

//"Dropbox文件列表 = {\"entries\": [{\".tag\": \"folder\", \"name\": \"\\u97f3\\u4e50\", \"path_lower\": \"/\\u97f3\\u4e50\", \"path_display\": \"/\\u97f3\\u4e50\", \"id\": \"id:LhbMjeGx6MoAAAAAAAAABg\"}, {\".tag\": \"folder\", \"name\": \"\\u7167\\u7247\", \"path_lower\": \"/\\u7167\\u7247\", \"path_display\": \"/\\u7167\\u7247\", \"id\": \"id:LhbMjeGx6MoAAAAAAAAABw\"}], \"cursor\": \"AARCqP61QEBn7orv69ZPZEkpidLf5TE9EtOFlBYiAvhizNrTsMuCVhltrtHjCXvnLXASt6lIMRhFTGSdYCERCxOoNwrfHQzRl0dHAc_Rl4_gz1-pKlpZ-WZomH7MHpt0Lpi_ufsDN0I46PaDf1MiY0M9d_3wxyQxHgN4A3q-YBs7A6vAzlkKAg83U7jFpQJcEbc\", \"has_more\": false}"

extension DropboxDriveFileModel {
    
    
    /// 是否为文件夹
    public func isDirectory() -> Bool {
        return self.fileType == .folder
    }
    
    /// 播放地址
    public func mediaPlayURL() -> URL {
        return SandboxFileManager.shared.basePublicFileURL()
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = (self.name as NSString).pathExtension
        return suffix.lowercased()
    }

    /// 是否为音乐
    public func isMusic() -> Bool {
        let suffix = self.fileExtension()
        return AudioExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 是否为视频
    public func isVideo() -> Bool {
        let suffix = self.fileExtension()
        return VideoExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 创建时间
    public func createdDate() -> Date? {
        guard let client_modified = self.client_modified?.rounded(), client_modified > 0 else { return nil }
        
        let date = Date(timeIntervalSince1970: client_modified)
        return date
    }
    
    /// 修改时间
    public func modifiedDate() -> Date? {
        guard let server_modified = self.server_modified?.rounded(), server_modified > 0 else { return nil }
        
        let date = Date(timeIntervalSince1970: server_modified)
        return date
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
        return nil
    }
}


public struct DropboxFilePage: SmartCodableX {
    
    public init() { }
    
    public init(entries: [DropboxDriveFileModel]? = nil, cursor: String? = nil, hasMore: Bool, error: DropboxErrorModel? = nil, error_summary: String? = nil) {
        self.entries = entries
        self.cursor = cursor
        self.hasMore = hasMore
        self.error = error
        self.error_summary = error_summary
    }
    
    /// 文件数组
    public var entries: [DropboxDriveFileModel]?
    
    /// 下一页信息
    public var cursor: String?
    
    /// 还有更多？
    public var hasMore: Bool = false
    
    
    /// 错误字段（当出错时存在）
    public var error: DropboxErrorModel?
    
    /// 错误摘要描述（例如 "expired_access_token/"）
    public var error_summary: String?
    
    
    /// 是否正常
    public var isSuccess: Bool {
        return error == nil
    }
    
    /// 是否是 Token 过期
    public var isTokenExpired: Bool {
        return error?.tag == "expired_access_token"
    }
    
}

public struct DropboxErrorModel: SmartCodableX {
    
    public init() { }
    
    /// 错误类型，例如 expired_access_token
    public var tag: String?   // JSON中的 ".tag"
    
    public static func mappingForKey() -> [SmartKeyTransformer]? {
        return [
            CodingKeys.tag <--- ".tag"
        ]
    }
}

//"Dropbox文件列表 = {\"error\":{\".tag\":\"expired_access_token\"},\"error_summary\":\"expired_access_token/\"}"
