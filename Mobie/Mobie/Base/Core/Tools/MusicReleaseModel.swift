//
//  MusicReleaseModel.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import SmartCodable

/// 聚合的音乐标签数据
struct MusicReleaseModel: SmartCodable, Equatable, Hashable {
    
    /// MBID
    var id: String = ""
    
    /// 名称
    var title: String = ""
    
    /// 日期
    var date: String?
    
    /// 国家
    var country: String = ""
    
    /// 时长
    var length: TimeInterval?
        
    /// MusicBranz的封面信息
    var branzImages: MusicReleaseImage?
    
    /// iTunes的信息
    var itunesModel: ITunesSongModel?
    
    @SmartIgnored
    var tempImage: UIImage?
    
    public static func == (lhs: MusicReleaseModel, rhs: MusicReleaseModel) -> Bool {
        return lhs.id == rhs.id &&
        lhs.branzImages == rhs.branzImages &&
        lhs.itunesModel == rhs.itunesModel
    }
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
        hasher.combine(self.branzImages)
        hasher.combine(self.itunesModel)
    }
    
    /// 封面图
    func coverImageURL() -> URL? {
        if let itunesModel = self.itunesModel {
            let coverStr = itunesModel.artworkUrl100.replaceChar(oldChar: "100x100", newChar: "600x600")
            return URL(string: coverStr)
        }else if let branzImages = self.branzImages {
            return URL(string: branzImages.thumbnails.small)
        }else{
            return nil
        }
    }
    
    /// 发布年代和日期
    func releaseYear() -> Date? {
        
        guard let dateStr = self.date ?? self.itunesModel?.releaseDate else { return nil }
        
        let iso8601Formatter = ISO8601DateFormatter()
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy" // 设置年份格式
        
        // 尝试解析 ISO 8601 格式
        if let date = iso8601Formatter.date(from: dateStr) {
            return date
        }
        // 尝试解析仅包含年份的格式
        else if let date = yearFormatter.date(from: dateStr) {
            return date
        } else {
            return nil
        }
        
    }
    
}


