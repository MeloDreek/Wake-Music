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


/*
 "OneDrive文件列表✅ = {\"@odata.context\":\"https://graph.microsoft.com/v1.0/$metadata#users(\'melodreek%40gmail.com\')/drive/root/children\",\"value\":[{\"createdDateTime\":\"2025-11-04T14:56:33Z\",\"eTag\":\"\\\"{ADD24504-303B-453D-B2C7-5F7C5CF81A10},1\\\"\",\"id\":\"B3DB63EC4E5B22A9!sadd24504303b453db2c75f7c5cf81a10\",\"lastModifiedDateTime\":\"2025-11-04T14:56:33Z\",\"name\":\"Music\",\"webUrl\":\"https://onedrive.live.com?cid=b3db63ec4e5b22a9&id=B3DB63EC4E5B22A9!sadd24504303b453db2c75f7c5cf81a10\",\"cTag\":\"\\\"c:{ADD24504-303B-453D-B2C7-5F7C5CF81A10},0\\\"\",\"size\":227889812,\"createdBy\":{\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"lastModifiedBy\":{\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b3db63ec4e5b22a9\",\"id\":\"B3DB63EC4E5B22A9!sea8cc6beffdb43d7976fbc7da445c639\",\"name\":\"Documents\",\"path\":\"/drive/root:\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\"},\"fileSystemInfo\":{\"createdDateTime\":\"2025-11-04T14:56:33Z\",\"lastModifiedDateTime\":\"2025-11-04T14:56:33Z\"},\"folder\":{\"childCount\":6,\"view\":{\"sortBy\":\"name\",\"sortOrder\":\"ascending\",\"viewType\":\"thumbnails\"}}},{\"createdDateTime\":\"2025-11-04T14:56:21Z\",\"eTag\":\"\\\"{45D7C0B0-0ECF-4758-88E8-4B1545B20557},1\\\"\",\"id\":\"B3DB63EC4E5B22A9!s45d7c0b00ecf475888e84b1545b20557\",\"lastModifiedDateTime\":\"2025-11-04T14:56:21Z\",\"name\":\"Personal Vault\",\"cTag\":\"\\\"c:{45D7C0B0-0ECF-4758-88E8-4B1545B20557},1\\\"\",\"size\":0,\"createdBy\":{\"user\":{\"displayName\":\"System Account\"}},\"lastModifiedBy\":{\"user\":{\"displayName\":\"System Account\"}},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b3db63ec4e5b22a9\",\"id\":\"B3DB63EC4E5B22A9!sea8cc6beffdb43d7976fbc7da445c639\",\"name\":\"Documents\",\"path\":\"/drive/root:\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\"},\"fileSystemInfo\":{\"createdDateTime\":\"2025-11-04T14:56:21Z\",\"lastModifiedDateTime\":\"2025-11-04T14:56:21Z\"},\"remoteItem\":{\"id\":\"01VNWBWHN6Y2GOVW7725BZO354PWSELRRZ\",\"size\":0,\"folder\":{\"childCount\":0},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b!iJ8W1Y5S0UCDCXqEySwiDzbSgdnF7v1DkWDYyS-wYqwKUEuQGL80Tpi3IsWEzt4j\"},\"sharepointIds\":{\"listId\":\"904b500a-bf18-4e34-98b7-22c584cede23\",\"listItemUniqueId\":\"8ce731e1-9c0a-4b83-a182-c97fd115a855\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\",\"siteUrl\":\"https://my.microsoftpersonalcontent.com/personal/b3db63ec4e5b22a9\",\"webId\":\"d981d236-eec5-43fd-9160-d8c92fb062ac\"}}},{\"createdDateTime\":\"2025-11-04T14:56:24Z\",\"eTag\":\"\\\"{13375EFA-387D-4BDE-8467-B3AD6EF89465},1\\\"\",\"id\":\"B3DB63EC4E5B22A9!s13375efa387d4bde8467b3ad6ef89465\",\"lastModifiedDateTime\":\"2025-11-04T14:56:24Z\",\"name\":\"图片\",\"webUrl\":\"https://onedrive.live.com?cid=b3db63ec4e5b22a9&id=B3DB63EC4E5B22A9!s13375efa387d4bde8467b3ad6ef89465\",\"cTag\":\"\\\"c:{13375EFA-387D-4BDE-8467-B3AD6EF89465},0\\\"\",\"size\":0,\"createdBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"lastModifiedBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b3db63ec4e5b22a9\",\"id\":\"B3DB63EC4E5B22A9!sea8cc6beffdb43d7976fbc7da445c639\",\"name\":\"Documents\",\"path\":\"/drive/root:\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\"},\"fileSystemInfo\":{\"createdDateTime\":\"2025-11-04T14:56:24Z\",\"lastModifiedDateTime\":\"2025-11-04T14:56:24Z\"},\"folder\":{\"childCount\":0,\"view\":{\"sortBy\":\"name\",\"sortOrder\":\"ascending\",\"viewType\":\"thumbnails\"}},\"specialFolder\":{\"name\":\"photos\"}},{\"createdDateTime\":\"2025-11-04T14:56:23Z\",\"eTag\":\"\\\"{82BD7912-3DBE-43D4-8A00-BD1D71C49E47},1\\\"\",\"id\":\"B3DB63EC4E5B22A9!s82bd79123dbe43d48a00bd1d71c49e47\",\"lastModifiedDateTime\":\"2025-11-04T14:56:23Z\",\"name\":\"文档\",\"webUrl\":\"https://onedrive.live.com?cid=b3db63ec4e5b22a9&id=B3DB63EC4E5B22A9!s82bd79123dbe43d48a00bd1d71c49e47\",\"cTag\":\"\\\"c:{82BD7912-3DBE-43D4-8A00-BD1D71C49E47},0\\\"\",\"size\":0,\"createdBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"lastModifiedBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b3db63ec4e5b22a9\",\"id\":\"B3DB63EC4E5B22A9!sea8cc6beffdb43d7976fbc7da445c639\",\"name\":\"Documents\",\"path\":\"/drive/root:\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\"},\"fileSystemInfo\":{\"createdDateTime\":\"2025-11-04T14:56:23Z\",\"lastModifiedDateTime\":\"2025-11-04T14:56:23Z\"},\"folder\":{\"childCount\":0,\"view\":{\"sortBy\":\"name\",\"sortOrder\":\"ascending\",\"viewType\":\"thumbnails\"}},\"specialFolder\":{\"name\":\"documents\"}},{\"@microsoft.graph.downloadUrl\":\"https://my.microsoftpersonalcontent.com/personal/b3db63ec4e5b22a9/_layouts/15/download.aspx?UniqueId=5f4b1e02-a153-40cb-b9d4-6d2b277ee894&Translate=false&tempauth=v1e.eyJzaXRlaWQiOiJkNTE2OWY4OC01MjhlLTQwZDEtODMwOS03YTg0YzkyYzIyMGYiLCJhcHBfZGlzcGxheW5hbWUiOiJXYWtlIE11c2ljIiwiYXBwaWQiOiJlNDk0MTM2OS1jZDczLTRmM2MtOGU0OC1jMTQwNGUzNzM3MTkiLCJhdWQiOiIwMDAwMDAwMy0wMDAwLTBmZjEtY2UwMC0wMDAwMDAwMDAwMDAvbXkubWljcm9zb2Z0cGVyc29uYWxjb250ZW50LmNvbUA5MTg4MDQwZC02YzY3LTRjNWItYjExMi0zNmEzMDRiNjZkYWQiLCJleHAiOiIxNzYyNDQxMDAzIn0.M50EW1FHVekYumC3wlOYKeVPm10Ki4RJfnNLfGNox6-ShHXV9Cg-SP_aI90J7wxSFrNPRrA6ZQbs_wylQZgqUASENVbWfzUT_lgveGrQAACw0kzlYLoatQL8_Y5c-y4YOzMaagjLUe6eYCO1d6w0cwCHvRNhwnVLaHTaHuh7qR-iEGz7zHfusM_CDvg35P4xxvCgKgcIl5MT3V7TrfNhUEe36j0Q_jnjhSiO4louthrVnY4fvBsQgWOGCGexcGWGAGCvEHZkN5DCZi4Ve4KbTE8XvdVSAfiDyJF7yQ4_x65qlXX0stR4A_3UawCshaP4i1ibm6wZDK93DF17s6w_ULlzcq2-WV_4hpzaRD3xHs-3Nme7HD6Uih03nk9PCTK0-Nb5NxWLHCtt8yFGpn1vDmKiUl9YeBGkoViM8Efo0HCZFoTyUxhTN-q1_-ZjZYsN.g91JU3CG-O-L01Lxwzf_8yCP5tgb1wkBbEoj8TWgLuM&ApiVersion=2.0\",\"createdDateTime\":\"2025-11-04T14:56:24Z\",\"eTag\":\"\\\"{5F4B1E02-A153-40CB-B9D4-6D2B277EE894},1\\\"\",\"id\":\"B3DB63EC4E5B22A9!s5f4b1e02a15340cbb9d46d2b277ee894\",\"lastModifiedDateTime\":\"2025-11-04T14:56:24Z\",\"name\":\"OneDrive 入门.pdf\",\"webUrl\":\"https://onedrive.live.com?cid=b3db63ec4e5b22a9&id=B3DB63EC4E5B22A9!s5f4b1e02a15340cbb9d46d2b277ee894\",\"cTag\":\"\\\"c:{5F4B1E02-A153-40CB-B9D4-6D2B277EE894},1\\\"\",\"size\":1247350,\"createdBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"lastModifiedBy\":{\"application\":{\"id\":\"00000000-0000-0000-0000-000000048beb\",\"displayName\":\"i:0i.t|ms.sp.ext|00000000-0000-0000-0000-000000048beb@9188040d-6c67-4c5b-b112-36a304b66dad\"},\"user\":{\"email\":\"melodreek@gmail.com\",\"id\":\"b3db63ec4e5b22a9\",\"displayName\":\"Melo Dreek\"}},\"parentReference\":{\"driveType\":\"personal\",\"driveId\":\"b3db63ec4e5b22a9\",\"id\":\"B3DB63EC4E5B22A9!sea8cc6beffdb43d7976fbc7da445c639\",\"name\":\"Documents\",\"path\":\"/drive/root:\",\"siteId\":\"d5169f88-528e-40d1-8309-7a84c92c220f\"},\"file\":{\"mimeType\":\"application/pdf\",\"hashes\":{\"quickXorHash\":\"NKj4+h7+hwesn2J0OfGN9MbTCZY=\"}},\"fileSystemInfo\":{\"createdDateTime\":\"2025-11-04T14:56:24Z\",\"lastModifiedDateTime\":\"2025-11-04T14:56:24Z\"}}]}"
 */
