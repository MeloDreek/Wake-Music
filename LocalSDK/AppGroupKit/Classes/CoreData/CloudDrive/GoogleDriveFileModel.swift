//
//  GoogleDriveFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 10/22/25.
//

import SmartCodable


/// 谷歌文件列表
public struct GoogleDriveFileModel: SmartCodableX, Equatable, Hashable {
    
    public init() {}
    
    /// 文件ID
    public var id: String = ""
    
    /// 类型：1️⃣drive#file，2️⃣drive#fileList
    public var kind: String = ""
    
    /// 名称
    public var name: String = ""
    
    /// 媒体类型
    public var mimeType: String = ""
    
    /// 文件尺寸
    public var size: Int64 = 0
    
    /// 下载地址
    public var webContentLink: String = ""
    
    /// 创建时间
    public var createdTime: String = ""
    
    /// 修改时间
    public var modifiedTime: String = ""
    
    /// 未完成的搜索
    public var incompleteSearch: Bool = false
    
    /// 父文件夹
    public var parents: [String]?
    
    /// 登录信息
    public var googleUser: GoogleDriveUserModel?
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: GoogleDriveFileModel, rhs: GoogleDriveFileModel) -> Bool {
        return lhs.id == rhs.id
    }
    
}

extension GoogleDriveFileModel {
    /// 是否为文件夹
    public func isDirectory() -> Bool {
        return self.kind == "drive#fileList" || self.mimeType == "application/vnd.google-apps.folder"
    }
    
    /// 播放地址
    public func mediaPlayURL() -> URL {
        let url = "https://www.googleapis.com/drive/v3/files/\(self.id)?alt=media"
        return URL(string: url) ?? SandboxFileManager.shared.basePublicFileURL()
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = self.name.ocString.pathExtension
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
    
    /// 是否为图片
    public func isImage() -> Bool {
        let suffix = self.fileExtension()
        return ImageExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 创建时间
    public func createdDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // 含毫秒
        let date = formatter.date(from: self.createdTime)
        return date
    }
    
    /// 修改时间
    public func modifiedDate() -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // 含毫秒
        let date = formatter.date(from: self.modifiedTime)
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

/*
 我拿到了原属字符串数据，请使用SmartCodable帮我进行定义swift结构体。

 "谷歌文件列表 = {\n  \"files\": [\n    {\n      \"id\": \"1q4XxNfChAqSVU3PtXVIXdDCi_tWpqm8L\",\n      \"name\": \"高桥洋子 - 暂し空に祈りて.flac\",\n      \"mimeType\": \"audio/flac\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1q4XxNfChAqSVU3PtXVIXdDCi_tWpqm8L&export=download\",\n      \"modifiedTime\": \"2025-07-21T16:14:34.000Z\",\n      \"size\": \"36316458\"\n    },\n    {\n      \"id\": \"1_NwWyWDM-rEBD12GP3Z3MU7uOwxL1uJS\",\n      \"name\": \"Lady Gaga & Bruno Mars - Die With A Smile.flac\",\n      \"mimeType\": \"audio/flac\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1_NwWyWDM-rEBD12GP3Z3MU7uOwxL1uJS&export=download\",\n      \"modifiedTime\": \"2025-06-20T08:56:10.000Z\",\n      \"size\": \"50300936\"\n    },\n    {\n      \"id\": \"11hEPhSmeI5pJIbN-gxoXoM8wcnwlhk6S\",\n      \"name\": \"Michael Jackson - Childhood .flac\",\n      \"mimeType\": \"audio/flac\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=11hEPhSmeI5pJIbN-gxoXoM8wcnwlhk6S&export=download\",\n      \"modifiedTime\": \"2025-06-09T03:16:35.000Z\",\n      \"size\": \"92621972\"\n    },\n    {\n      \"id\": \"1BDXV2Ot-wuvtTqCNc4sWH82v6099lMjL\",\n      \"name\": \"04 - 涟漪.dff\",\n      \"mimeType\": \"audio/x-dff\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1BDXV2Ot-wuvtTqCNc4sWH82v6099lMjL&export=download\",\n      \"modifiedTime\": \"2025-05-17T06:46:35.000Z\",\n      \"size\": \"133247930\"\n    },\n    {\n      \"id\": \"1XpCO7cTRh2Wo_wLiQ4eSxcA3KgPCKQSy\",\n      \"name\": \"GEM邓紫棋 - AINY (爱你).ape\",\n      \"mimeType\": \"audio/x-ape\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1XpCO7cTRh2Wo_wLiQ4eSxcA3KgPCKQSy&export=download\",\n      \"modifiedTime\": \"2025-05-17T06:40:14.000Z\",\n      \"size\": \"26959471\"\n    },\n    {\n      \"id\": \"14WTJm6_RSu07XM4ONuj-jmD2HLLBjqIW\",\n      \"name\": \"GEM邓紫棋 - AINY (爱你).ape\",\n      \"mimeType\": \"audio/x-ape\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=14WTJm6_RSu07XM4ONuj-jmD2HLLBjqIW&export=download\",\n      \"modifiedTime\": \"2025-05-17T06:40:14.000Z\",\n      \"size\": \"26959471\"\n    },\n    {\n      \"id\": \"1Uj-LrPebBbcdlUMt53R-rZyRfWcXpJmJ\",\n      \"name\": \"张杰 - 树呢.mp3\",\n      \"mimeType\": \"audio/mpeg\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1Uj-LrPebBbcdlUMt53R-rZyRfWcXpJmJ&export=download\",\n      \"modifiedTime\": \"2025-01-24T03:25:59.000Z\",\n      \"size\": \"12958397\"\n    },\n    {\n      \"id\": \"1QS4ZZwvLkcPWYe65psb25qi5J3fSpyb2\",\n      \"name\": \"周传雄-黄昏.mp3\",\n      \"mimeType\": \"audio/mpeg\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1QS4ZZwvLkcPWYe65psb25qi5J3fSpyb2&export=download\",\n      \"modifiedTime\": \"2025-01-07T09:32:36.000Z\",\n      \"size\": \"13995438\"\n    },\n    {\n      \"id\": \"1XL6jvS2zk_Y8ihCzcyDU48T8ag0ON_lH\",\n      \"name\": \"Hotel California.lrc\",\n      \"mimeType\": \"application/octet-stream\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1XL6jvS2zk_Y8ihCzcyDU48T8ag0ON_lH&export=download\",\n      \"modifiedTime\": \"2024-12-01T13:49:01.000Z\",\n      \"size\": \"2264\"\n    },\n    {\n      \"id\": \"10os6CdxT4NPDtyiLF8iLkHo_8cWkUcY_\",\n      \"name\": \"林志炫- 输了你赢了世界又如何.ogg\",\n      \"mimeType\": \"audio/ogg\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=10os6CdxT4NPDtyiLF8iLkHo_8cWkUcY_&export=download\",\n      \"modifiedTime\": \"2024-11-19T10:41:46.000Z\",\n      \"size\": \"14934542\"\n    },\n    {\n      \"id\": \"176eljAqemk-3i7Ws4f54RDIXIg0bCrzr\",\n      \"name\": \"未知艺术家 - 未知标题.dts\",\n      \"mimeType\": \"application/octet-stream\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=176eljAqemk-3i7Ws4f54RDIXIg0bCrzr&export=download\",\n      \"modifiedTime\": \"2024-10-11T05:12:29.000Z\",\n      \"size\": \"28643328\"\n    },\n    {\n      \"id\": \"1L0rctnU1bHBel_KVvLCw1d0uQR-bjOEk\",\n      \"name\": \"Hotel California-The Eagles.wav\",\n      \"mimeType\": \"audio/wav\",\n      \"webContentLink\": \"https://drive.google.com/uc?id=1L0rctnU1bHBel_KVvLCw1d0uQR-bjOEk&export=download\",\n      \"modifiedTime\": \"2012-10-17T05:40:21.000Z\",\n      \"size\": \"1328947481\"\n    }\n  ]\n}\n"
 */
