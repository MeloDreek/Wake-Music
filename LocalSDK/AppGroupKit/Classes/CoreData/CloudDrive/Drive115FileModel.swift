//
//  Drive115FileModel.swift
//  AppGroupKit
//
//  Created by 张文 on 7/16/25.
//

import SmartCodable

/// 115网盘的文件结构
public struct Drive115FileModel: SmartCodableX, Hashable, Equatable {
    
    public init() {
        
    }
    
    /// 服务器信息
    public var drive115User: Drive115UserModel?
    
    /// 文件(夹)ID
    public var fid: String = ""
    
    /// 文件的状态，aid 的别名。1 正常，7 删除(回收站)，120 彻底删除
    public var aid: String = ""
    
    /// 父目录ID
    public var pid: String = ""
    
    /// 文件分类。0 文件夹，1 文件
    public var fc: Int?
    
    /// 文件(夹)名称
    public var fn: String = ""
    
    /// 文件扩展名
    public var ico: String = ""
    
    /// 文件夹封面
    public var fco: String = ""
    
    /// 是否星标，1：星标
    public var ism: Bool = false
    
    /// 是否加密；1：加密
    public var isp: Bool = false
    
    /// 文件提取码
    public var pc: String = ""
    
    /// 修改时间
    public var uet: TimeInterval = 0
    
    /// 上传时间
    public var uppt: TimeInterval = 0
    
    /// 文件备注
    public var fdesc: String = ""
    
    /// 文件大小
    public var fs: Int = 0
    
    /// 音视频时长
    public var play_long: Int = 0
    
    /// 视频封面地址
    public var v_img: String = ""
    
    /// 图片缩略图
    public var thumb: String = ""
    
    /// 原图地址
    public var uo: String = ""
    
    /// 音频长度
    public var fatr: String = ""
    
    /// 是否为视频
    public var isv: Bool = false
    
    /// 视频清晰度；1:标清 2:高清 3:超清 4:1080P 5:4k;100:原画
    public var def: Int?
    
    /// 视频清晰度；1:标清 2:高清 3:超清 4:1080P 5:4k;100:原画
    public var def2: Int?
    
    /// sh1值
    public var sha1: String = ""
    
    /* 以下信息是文件详情才有的 */
    
    /// 文件(夹)ID
    public var file_id: String?
    
    /// 包含文件总数量
    public var count: Int?
    
    /// 文件(夹)总大小
    public var size: Int64 = 0
    
    /// 上传时间
    public var ptime: TimeInterval?
    
    /// 修改时间
    public var utime: TimeInterval?
    
    /// 文件名称
    public var file_name: String?
    
    /// 文件(夹)最近打开时间
    public var open_time: TimeInterval?
    
    /// 文件提取码
    public var pick_code: String?
        
    /// 是否星标
    public var is_mark: String = ""
    
    /// 文件属性；0：文件夹，1；文件
    public var file_category: Int = 0
    
    /// 选中状态
    public var isSelected: Bool = false
    
    /// 文件(夹)所在的路径
    public var path: [Drive115PathsModel]?
    
    
    
    /// 提高查找效率
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fileID())
        hasher.combine(sha1)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: Drive115FileModel, rhs: Drive115FileModel) -> Bool {
        return lhs.fileID() == rhs.fileID() &&
                      lhs.sha1 == rhs.sha1
    }
    
}

extension Drive115FileModel {
    
    /// 文件(夹)ID
    public func fileID() -> String {
        return self.file_id ?? self.fid
    }
    
    /// 获取所有文件的完整路径列表
    public func pathTitle() -> String? {
        guard var paths = self.path, paths.count > 0 else { return nil }
        
        paths.removeFirst()
        
        if paths.count > 0 {
            paths.insert(Drive115PathsModel(name: "115 Drive".localStr()), at: 0)
            let pathTitle = paths.map { $0.name }.joined(separator: "/")
            return pathTitle
        }else{
            return nil
        }
        
    }
    
    /// 播放地址
    public func mediaPlayURL() -> URL {
        return SandboxFileManager.shared.basePublicFileURL()
    }
    
    // 是否为文件夹
    public func isDirectory() -> Bool {
        return (self.file_category == 0 || self.fc == 0) && self.fileExtension().isEmpty
    }
    
    /// 文件名称
    public func fileName() -> String {
        return self.file_name ?? self.fn
    }
    
    /// 文件扩展名
    public func fileExtension() -> String {
        let suffix = self.ico
        return suffix.lowercased()
    }
    
    /// 创建时间
    public func createDate() -> Date {
        let time = (self.ptime ?? self.uppt).rounded()
        
        return Date(timeIntervalSince1970: time)
    }
    
    /// 修改时间
    public func modifyDate() -> Date {
        let time = (self.utime ?? self.uet).rounded()
        
        return Date(timeIntervalSince1970: time)
    }
    
    /// 文件提取码
    public func filePickCode() -> String {
        return self.pick_code ?? self.pc
    }
    
    /// 是否为音乐
    public func isMusic() -> Bool {
        let suffix = self.fileExtension()
        return  AudioExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 是否为视频
    public func isVideo() -> Bool {
        let suffix = self.fileExtension()
        return VideoExtensionType.allCases.map({ $0.rawValue }).contains(suffix.lowercased())
    }
    
    /// 封面地址
    public func coverImgURL(_ isThumb: Bool = true) -> URL? {
        
        return URL(string: isThumb ? self.thumb : self.uo)
    }
    
    // 第一个文字
    public func firstChar(_ sortType: SortedbyType) -> String {
        let title: String = self.fileName()
        
        let collator =  UILocalizedIndexedCollation.current()
        let titleIndex = collator.section(for: title, collationStringSelector: #selector(NSObject.description))
        
        // sectionTitles = [A-Z+#]
        let firstChar = collator.sectionTitles[titleIndex]
        
        return firstChar
    }
    
}

/// 父目录树
public struct Drive115PathsModel: SmartCodableX {
    
    public init() {
        
    }

    public init(name: String, cid: String? = nil, aid: String? = nil, pid: String? = nil, p_cid: String? = nil, isp: String? = nil, iss: String? = nil, fv: String? = nil, fvs: String? = nil) {
        self.name = name
        self.cid = cid
        self.aid = aid
        self.pid = pid
        self.p_cid = p_cid
        self.isp = isp
        self.iss = iss
        self.fv = fv
        self.fvs = fvs
    }
    
    public var name: String = ""
    public var cid: String?
    public var aid: String?
    public var pid: String?
    public var p_cid: String?
    public var isp: String?
    public var iss: String?
    public var fv: String?
    public var fvs: String?
    
}
