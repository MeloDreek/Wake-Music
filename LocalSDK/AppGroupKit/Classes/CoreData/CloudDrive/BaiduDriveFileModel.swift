//
//  BaiduDriveFileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 7/3/25.
//

import SmartCodable

/// 百度网盘的文件模型
public struct BaiduDriveFileModel: SmartCodableX, Equatable, Hashable {
    
    public init() { }
    
    public init(fs_id: Int, path: String, server_filename: String, size: Int, isdir: Int, category: Int, dir_empty: Bool, server_mtime: Int, server_ctime: Int, local_mtime: Int, local_ctime: Int, thumbs: [String], dlink: String? = nil, filename: String? = nil, isSelected: Bool, baiduUser: BaiduDriveUserModel? = nil) {
        self.fs_id = fs_id
        self.path = path
        self.server_filename = server_filename
        self.size = size
        self.isdir = isdir
        self.category = category
        self.dir_empty = dir_empty
        self.server_mtime = server_mtime
        self.server_ctime = server_ctime
        self.local_mtime = local_mtime
        self.local_ctime = local_ctime
        self.thumbs = thumbs
        self.dlink = dlink
        self.filename = filename
        self.isSelected = isSelected
        self.baiduUser = baiduUser
    }
    
    /// 文件在云端的唯一标识ID
    public var fs_id: Int = 0
    
    /// 文件的绝对路径
    public var path: String = ""
    
    /// 文件名称
    public var server_filename: String = ""
    
    /// 文件大小，单位B
    public var size: Int = 0
    
    /// 是否为目录，0 文件、1 目录
    public var isdir: Int = 0
    
    /// 文件类型，1 视频、2 音频、3 图片、4 文档、5 应用、6 其他、7 种子
    public var category: Int = 0
    
    /// 该目录是否存在子目录，只有请求参数web=1且该条目为目录时，该字段才存在， 0为存在， 1为不存在
    public var dir_empty: Bool = false
    
    /// 文件在服务器修改时间
    public var server_mtime: Int = 0
    
    /// 文件在服务器创建时间
    public var server_ctime: Int = 0
    
    /// 文件在客户端修改时间
    public var local_mtime: Int = 0
    
    /// 文件在客户端创建时间
    public var local_ctime: Int = 0
    
    /// 只有请求参数web=1且该条目分类为图片时，该字段才存在，包含三个尺寸的缩略图URL
    public var thumbs: [String] = []
    
    /// 文件下载地址
    public var dlink: String?
    public var filename: String?
    
    /// 选中状态
    public var isSelected: Bool = false
    
    /// 配置信息
    public var baiduUser: BaiduDriveUserModel?
    
    /// 方便查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fs_id)
        hasher.combine(path)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: BaiduDriveFileModel, rhs: BaiduDriveFileModel) -> Bool {
        return lhs.fs_id == rhs.fs_id &&
                  lhs.path == rhs.path
    }
    
    /// 是否为文件夹
    public func isDirectory() -> Bool {
        return self.isdir == 1
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = (self.path as NSString).pathExtension
        return suffix.lowercased()
    }

    /// 是否为音乐
    public func isMusic() -> Bool {
        let suffix = self.fileExtension()
        return self.category == 2 || AudioExtension.isPlayableAudioExtension(suffix)
    }
    
    /// 是否为视频
    public func isVideo() -> Bool {
        let suffix = self.fileExtension()
        return self.category == 1 || VideoExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    // 第一个文字
    public func firstChar(_ sortType: SortedbyType) -> String {
        let title: String = self.server_filename
        
        let collator =  UILocalizedIndexedCollation.current()
        let titleIndex = collator.section(for: title, collationStringSelector: #selector(NSObject.description))
        
        // sectionTitles = [A-Z+#]
        let firstChar = collator.sectionTitles[titleIndex]
        
        return firstChar
    }
    
    /// 封面地址
    public func coverImgURL() -> URL? {
        return URL(string: self.thumbs.first ?? "")
    }
    
    /// 已缓存的m3u地址
    public func m3uCacheURL() -> URL {
        let tempDir = SandboxFileManager.shared.preDownloadURL()
        let fileName = self.server_filename.ocString.deletingPathExtension + ".m3u"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        return fileURL
    }
    
}
