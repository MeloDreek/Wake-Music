//
//  LyricInfoModel.swift
//  AppGroupKit
//
//  Created by 张文 on 11/5/24.
//

import SmartCodable

/// 歌词完整模型
public struct LyricInfoModel: SmartCodableX, Equatable, Hashable {
    
    public init() {
        
    }
        
    /// 没有时间属性
    public var isNoneTime: Bool = true
    
    /// 歌名
    public var title: String?
    
    /// 歌手
    public var artist: String?
    
    /// 专辑
    public var album: String?
    
    /// 创建歌词的人
    public var creater: String?
    
    /// 总时长（毫秒）
    public var totalTime: TimeInterval?
    
    /// 时间补偿值（毫秒），正值表示整体提前，负值相反。这是用于总体调整显示快慢的
    public var offset: Int = 0
    
    /// 每一行的歌词
    public var lyrics: [LyricModel]?
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.title)
        hasher.combine(self.artist)
        hasher.combine(self.lyrics)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: LyricInfoModel, rhs: LyricInfoModel) -> Bool {
        return lhs.title == rhs.title &&
               lhs.artist == rhs.artist &&
               lhs.lyrics == rhs.lyrics
    }
    
    /// 构造成 [00:03.00]
    public func toLyricString(_ isShow: Bool = false) -> String? {
        guard let lyrics = self.lyrics, lyrics.count > 0 else { return nil }
        
        var fullLyric = ""
        
        if let title = self.title, title.count > 1 {
            fullLyric.append("[ti:\(title)]")
            fullLyric.append("\r")
            if isShow {
                fullLyric.append("\r")
            }
        }
        if let artist = self.artist, artist.count > 1 {
            fullLyric.append("[ar:\(artist)]")
            fullLyric.append("\r")
            if isShow {
                fullLyric.append("\r")
            }
        }
        if let album = self.album, album.count > 1 {
            fullLyric.append("[al:\(album)]")
            fullLyric.append("\r")
            if isShow {
                fullLyric.append("\r")
            }
        }
        if let creater = self.creater, creater.count > 1 {
            fullLyric.append("[by:\(creater)]")
            fullLyric.append("\r")
            if isShow {
                fullLyric.append("\r")
            }
        }
        if let totalTime = self.totalTime, totalTime > 1 {
            fullLyric.append("[t_time:\(totalTime)]")
            fullLyric.append("\r")
            if isShow {
                fullLyric.append("\r")
            }
        }
        
        let offset = self.offset
        fullLyric.append("[offset:\(offset)]")
        fullLyric.append("\r")
        if isShow {
            fullLyric.append("\r")
        }
        
        
        for i in (0..<lyrics.count) {
            let subLyric = lyrics[i]
            let isLast = lyrics.count - 1 == i
            
            if self.isNoneTime {
                fullLyric.append(subLyric.fullLyric ?? "")
                if !isLast {
                    fullLyric.append("\r")
                    if isShow {
                        fullLyric.append("\r")
                    }
                }
            }else{
                guard let startTimestamp = subLyric.startTimestamp else { return nil }
                
                let minutes = Int(startTimestamp / 1000) / 60
                let seconds = Int(startTimestamp / 1000) % 60
                let hundredths = Int(startTimestamp.truncatingRemainder(dividingBy: 1000))  //毫秒

                let formatStr = String(format: "[%02d:%02d.%03d] %@", minutes, seconds, hundredths, subLyric.fullLyric ?? "")
                
                if seconds > 1 {
                    debugPrint("歌词 = \(formatStr), startTimestamp = \(startTimestamp), minutes = \(minutes), seconds = \(seconds), hundredths = \(hundredths)")
                }
                
                fullLyric.append(formatStr)
                if !isLast {
                    fullLyric.append("\r")
                    if isShow {
                        fullLyric.append("\r")
                    }
                }
            }
        }
        
        return fullLyric
    }
    
    // 没有标签的纯歌词文本
    public func noneTagLyricString() -> String? {
        guard let lyrics = self.lyrics, lyrics.count > 0 else { return nil }
        
        var fullLyric = ""
        for i in (0..<lyrics.count) {
            let subLyric = lyrics[i]
            let isLast = lyrics.count - 1 == i
            
            if self.isNoneTime {
                fullLyric.append(subLyric.fullLyric ?? "")
                if !isLast {
                    fullLyric.append("\r")
                }
            }else{
                guard let startTimestamp = subLyric.startTimestamp else { return nil }
                
                let minutes = Int(startTimestamp / 1000) / 60
                let seconds = Int(startTimestamp / 1000) % 60
                let hundredths = Int((startTimestamp - floor(startTimestamp)) * 100) // 百分之一秒

                let formatStr = String(format: "[%02d:%02d.%02d] %@", minutes, seconds, hundredths, subLyric.fullLyric ?? "")
                fullLyric.append(formatStr)
                if !isLast {
                    fullLyric.append("\r")
                }
            }
        }
        
        return fullLyric
    }
}

public struct LyricModel: SmartCodableX, Equatable, Hashable {
    
    public init() {
        
    }
    
    public init(startTimestamp: TimeInterval? = nil, endTimestamp: TimeInterval? = nil, fullLyric: String? = nil, realLyric: String? = nil, translatLyric: String? = nil) {
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.fullLyric = fullLyric
        self.realLyric = realLyric
        self.translatLyric = translatLyric
    }
    
    /// 开始时间（毫秒）
    public var startTimestamp: TimeInterval?
    
    /// 结束时间（毫秒）
    public var endTimestamp: TimeInterval?
    
    /// 完整对歌词
    public var fullLyric: String?
    
    /// 真正的歌词
    public var realLyric: String?
    
    /// 译文
    public var translatLyric: String?
    
    /// 构造一句LRC歌词
    public func formatLyricStr(_ isNoneTime: Bool) -> String? {
                
        guard let startTimestamp = self.startTimestamp, !isNoneTime else {
            return self.fullLyric
        }
        
        let minutes = Int(startTimestamp / 1000) / 60
        let seconds = Int(startTimestamp / 1000) % 60
        let hundredths = Int(startTimestamp.truncatingRemainder(dividingBy: 1000))  //毫秒

        let formatStr = String(format: "[%02d:%02d.%03d] %@", minutes, seconds, hundredths, self.fullLyric ?? "")
        
        return formatStr
    }
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.startTimestamp)
        hasher.combine(self.fullLyric)
    }
    
    /// 判断两个模型的值是否一致
    public static func == (lhs: LyricModel, rhs: LyricModel) -> Bool {
        return lhs.startTimestamp == rhs.startTimestamp &&
                       lhs.fullLyric == rhs.fullLyric
    }
    
    
}
