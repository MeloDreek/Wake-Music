//
//  MusicViewModel.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/24.
//

import KakaFoundation
import AppGroupKit


/// VM
class MusicViewModel {
    
    public init(_ baseFileURL: URL) {
        self.baseFileURL = baseFileURL
        let isSame = baseFileURL == SandboxFileManager.shared.basePublicFileURL()
        
        if !isSame {
            self.groupType = .nonGroup
            self.sortType = MusicConfigManager.shared.sortType
        }
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 当前文件夹
    var baseFileURL: URL!
    
    /// 分组方式
    public var groupType = MusicConfigManager.shared.groupType
    
    /// 排序方式
    public var sortType = MusicConfigManager.shared.sortType
    
    /// 搜索关键词
    public var searchKey: String?
    
    /// 选中的数据
    public lazy var selectArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    /// 是否为Documents文件夹
    var isBaseDoc: Bool {
        get {
            let isSame = self.baseFileURL == SandboxFileManager.shared.basePublicFileURL()
            
            return isSame
        }
    }
    
    /// 获取歌单
    var folderArray: [URL] {
        get {
            let baseURL = SandboxFileManager.shared.basePublicFileURL()
            let folderArr = baseURL.readLocalSubFiles().filter { $0.hasDirectoryPath }.filter { subFolder in
                debugPrint("文件名称 = \(subFolder.lastPathComponent.lowercased())")
                return subFolder.lastPathComponent.lowercased() != "revenuecat"
            }
            
            return folderArr
        }
    }
    
}
