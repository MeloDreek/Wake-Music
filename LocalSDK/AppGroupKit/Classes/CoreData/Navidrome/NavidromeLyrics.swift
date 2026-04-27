//
//  NavidromeLyrics.swift
//  AppGroupKit
//
//  Created by 张文 on 3/13/25.
//

import SmartCodable

public struct NavidromeLyrics: SmartCodableX {
    
    public init(artist: String, title: String, value: String? = nil) {
        self.artist = artist
        self.title = title
        self.value = value
    }
    
    public init() {
        
    }
    
    /// 艺术家
    public var artist: String = ""
    
    /// 标题
    public var title: String = ""
    
    /// 歌词
    public var value: String?
}
