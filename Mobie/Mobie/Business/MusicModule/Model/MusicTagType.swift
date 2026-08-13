//
//  MusicTagType.swift
//  Mobie
//
//  Created by kaka on 2026/8/12.
//

import Foundation

enum MusicTagType {
    case artWork
    case title
    case artist
    case album
    case lyrics
    
    case year
    case genre
    case trackNumber
    case comment
    
    func titleStr() -> String {
        switch self {
        case .artWork:
            return "Artwork".localStr()
        case .title:
            return "Title".localStr()
        case .artist:
            return "Artist".localStr()
        case .album:
            return "Album".localStr()
        case .lyrics:
            return "Lyrics".localStr()
            
        case .year:
            return "Year".localStr()
        case .genre:
            return "Genre".localStr()
        case .trackNumber:
            return "Track Number".localStr()
        case .comment:
            return "Comment".localStr()
        }
    }
}

