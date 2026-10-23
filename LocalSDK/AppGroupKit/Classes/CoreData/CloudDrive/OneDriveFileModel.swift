//
//  OneDriveFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 11/5/25.
//

import SmartCodable

/// OneDrive网盘文件模型
public struct OneDriveFileModel: SmartCodableX, Hashable, Equatable {
    
    public init() { }
    
    public var id: String = ""
    public var name: String = ""
    public var size: Int64 = 0
    public var webUrl: String?
    public var downloadUrl: String?
    public var eTag: String?
    public var cTag: String?
    
    public var createdDateTime: String?
    public var lastModifiedDateTime: String?
    
    public var createdBy: OneDriveUserInfo?
    public var lastModifiedBy: OneDriveUserInfo?
    public var parentReference: OneDriveParentReference?
    public var fileSystemInfo: OneDriveFileSystemInfo?
    
    public var file: OneDriveFileInfo?
    public var folder: OneDriveFolderInfo?
    public var specialFolder: OneDriveSpecialFolder?
    public var remoteItem: OneDriveRemoteItem?
    
    /// 配置信息
    public var onedriveUser: OneDriveUserModel?
    
    public static func mappingForKey() -> [SmartKeyTransformer]? {
        return [
            CodingKeys.downloadUrl <--- "@microsoft.graph.downloadUrl"
        ]
    }
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: OneDriveFileModel, rhs: OneDriveFileModel) -> Bool {
        return lhs.id == rhs.id
    }
}
extension OneDriveFileModel {
    
    /// 是否为文件夹
    public func isDirectory() -> Bool {
        return self.folder != nil
    }
    
    /// 播放地址
    public func mediaPlayURL() -> URL {
        if let downloadUrl = self.downloadUrl, let vURL = URL(string: downloadUrl) {
            return vURL
        }else{
            return SandboxFileManager.shared.basePublicFileURL()
        }
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = (self.name as NSString).pathExtension
        return suffix.lowercased()
    }

    /// 是否为音乐
    public func isMusic() -> Bool {
        let suffix = self.fileExtension()
        return AudioExtension.isPlayableAudioExtension(suffix)
    }
    
    /// 是否为视频
    public func isVideo() -> Bool {
        let suffix = self.fileExtension()
        return VideoExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 创建时间
    public func createdDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // 含毫秒
        let date = formatter.date(from: self.createdDateTime ?? "")
        return date
    }
    
    /// 修改时间
    public func modifiedDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // 含毫秒
        let date = formatter.date(from: self.lastModifiedDateTime ?? "")
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











// MARK: - 子结构体定义

public struct OneDriveFilePage: SmartCodableX {
    
    public init() { }
    
    /// 文件
    public var value: [OneDriveFileModel]?
    
    /// 下一页
    public var nextLink: String?
    
    /// 上下文
    public var context: String?
    
    /// 错误信息
    public var error: OneDriveErrorDetail?
    
    ///  判断是否过期
    public func isTokenExpired() -> Bool {
        if let error = self.error, let code = error.code {
            return code.lowercased().contains("token") || code.lowercased().contains("expired")
        }else{
            return false
        }
    }
    
    public static func mappingForKey() -> [SmartKeyTransformer]? {
        return [
            CodingKeys.nextLink <--- "@odata.nextLink",
            CodingKeys.context <--- "@odata.context"
        ]
    }
}

public struct OneDriveUserInfo: SmartCodableX {
    
    public init() { }
    
    public var application: OneDriveAppInfo?
    public var user: OneDriveUserDetail?
}

public struct OneDriveAppInfo: SmartCodableX {
    
    public init() { }
    
    public var id: String = ""
    public var displayName: String = ""
}

public struct OneDriveUserDetail: SmartCodableX {
    
    public init() { }
    
    public var id: String = ""
    public var displayName: String = ""
    public var email: String?
}

public struct OneDriveParentReference: SmartCodableX {
    
    public init() { }
    
    public var id: String = ""
    public var driveId: String = ""
    public var driveType: String?
    public var name: String?
    public var path: String?
    public var siteId: String?
}

public struct OneDriveFileSystemInfo: SmartCodableX {
    
    public init() { }
    
    public var createdDateTime: String?
    public var lastModifiedDateTime: String?
}

public struct OneDriveFileInfo: SmartCodableX {
    
    public init() { }
    
    public var mimeType: String = ""
    public var hashes: OneDriveFileHashes?
}

public struct OneDriveFileHashes: SmartCodableX {
    
    public init() { }
    
    public var quickXorHash: String?
}

public struct OneDriveFolderInfo: SmartCodableX {
    
    public init() { }
    
    public var childCount: Int = 0
    public var view: OneDriveFolderView?
}

public struct OneDriveFolderView: SmartCodableX {
    
    public init() { }
    
    public var sortBy: String?
    public var sortOrder: String?
    public var viewType: String?
}

public struct OneDriveSpecialFolder: SmartCodableX {
    
    public init() { }
    
    public var name: String?
}

public struct OneDriveRemoteItem: SmartCodableX {
    
    public init() { }
    
    
    public var id: String = ""
    public var size: Int64 = 0
    public var folder: OneDriveFolderInfo?
    public var parentReference: OneDriveParentReference?
    public var sharepointIds: OneDriveSharepointIds?
}

public struct OneDriveSharepointIds: SmartCodableX {
    
    public init() { }
    
    public var listId: String = ""
    public var listItemUniqueId: String = ""
    public var siteId: String = ""
    public var siteUrl: String?
    public var webId: String = ""
}


// MARK: 错误模型
//public struct OneDriveErrorResponse: SmartCodableX {
//    
//    public init() { }
//    
//    public var error: OneDriveErrorDetail?
//    
//    public func isTokenExpired() -> Bool {
//        return self.error?.code == "InvalidAuthenticationToken"
//    }
//}

public struct OneDriveErrorDetail: SmartCodableX {
    
    public init() { }
    
    public var code: String?
    public var message: String?
    public var innerError: OneDriveInnerError?
}

public struct OneDriveInnerError: SmartCodableX {
    
    public init() { }
    
    public var date: String?
    public var requestId: String?
    public var clientRequestId: String?

    public static func mappingForKey() -> [SmartKeyTransformer]? {
        return [
            CodingKeys.requestId <--- "request-id",
            CodingKeys.clientRequestId <--- "client-request-id"
        ]
    }
}
