//
//  MusicReleaseImage.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import SmartCodable

struct MusicReleaseImage: SmartCodableX, Equatable, Hashable {
    
    /// ID1
    var id: String = ""
    
    /// 前置图
    var image: String = ""
    
    /// 大小图
    var thumbnails: MusicReleaseThumbnail = .init()
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
        hasher.combine(self.image)
        hasher.combine(self.thumbnails)
    }
    
    
    public static func == (lhs: MusicReleaseImage, rhs: MusicReleaseImage) -> Bool {
        return lhs.id == rhs.id &&
             lhs.image == rhs.image &&
        lhs.thumbnails == rhs.thumbnails
    }
    
}

struct MusicReleaseThumbnail: SmartCodableX, Equatable, Hashable {
    
    /// 小图
    var large: String = ""
    
    /// 大图
    var small: String = ""
    
    /// 提高查找效率的方法
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.large)
        hasher.combine(self.small)
    }
    
    public static func == (lhs: MusicReleaseThumbnail, rhs: MusicReleaseThumbnail) -> Bool {
        return lhs.large == rhs.large &&
                 lhs.small == rhs.small
    }
}

/*
 "approved": true,
       "back": false,
       "comment": "",
       "edit": 65979017,
       "front": true,
       "id": 24888369614,
       "image": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614.jpg",
       "thumbnails": {
         "1200": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614-1200.jpg",
         "250": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614-250.jpg",
         "500": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614-500.jpg",
         "large": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614-500.jpg",
         "small": "http://coverartarchive.org/release/ce381ae4-ebff-4e90-a762-204a540bae4d/24888369614-250.jpg"
       },
       "types": [
         "Front"
       ]
 */

