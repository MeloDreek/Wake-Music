//
//  NavidromeSection.swift
//  Mobie
//
//  Created by kaka on 2026/9/21.
//

import Foundation

enum NavidromeSection: Int, CaseIterable {
    case overview, recent, favorites, playlists, random, recentlyAdded

    var title: String? {
        switch self {
        case .overview: return nil
        case .recent: return "Recently Played".localStr()
        case .favorites: return "Favourite Songs".localStr()
        case .playlists: return "My Playlists".localStr()
        case .random: return "Discover Music".localStr()
        case .recentlyAdded: return "MusicServer.Home.RecentlyUploaded".localStr()
        }
    }

    var route: MusicServerRoute? {
        switch self {
        case .overview: return nil
        case .recent: return .recent
        case .favorites: return .favorites
        case .playlists: return .playlists
        case .random: return .random
        case .recentlyAdded: return .recentlyAdded
        }
    }

    var emptyMessage: String {
        switch self {
        case .recent: return "Play something to start your listening history.".localStr()
        case .favorites: return "Your favorite songs will appear here.".localStr()
        case .playlists: return "Your playlists will appear here.".localStr()
        case .overview, .random, .recentlyAdded: return "No music is available yet.".localStr()
        }
    }

    var isShelf: Bool { self == .recent || self == .favorites || self == .random }
    var previewLimit: Int {
        switch self {
        case .random: return 30
        case .recentlyAdded: return 20
        default: return 12
        }
    }

}
