//
//  SandboxFileManager+Like.swift
//  AppGroupKit
//
//  Created by 张文 on 12/22/24.
//

import Foundation

extension SandboxFileManager {
    
    // 添加喜欢
    public func addOrDeleteFavirote(_ fileURL: URL) {
        
        let fileName = fileURL.lastPathComponent
        let index = self.favoriteArray.firstIndex {
            $0 == fileName
        }
        
        if let index = index {
            // 取消收藏
            self.favoriteArray.remove(at: index)
        }else{
            // 添加收藏
            self.favoriteArray.append(fileName)
        }
        
        UserDefaults.standard.set(self.favoriteArray, forKey: "kFavoriteKey")
        
        UserDefaults.standard.synchronize()
        
    }
    
    // 获取喜欢的文件名
    func getFavorites() -> [String] {
        
        let cacheArray = self.old_readLocalMusics().filter { $0.isFavorite }.compactMap {
            $0.mediaPlayURL.lastPathComponent
        }
        
        if cacheArray.count > 0 {
            let jsonURL = self.basePublicFileURL().appendingPathComponent(SandboxType_AllJsons).path
            try? FileManager.default.removeItem(atPath: jsonURL )
        }
        
        let newArray = (UserDefaults.standard.array(forKey: "kFavoriteKey") as? [String]) ?? [String]()
        
        let allArray = newArray + cacheArray
        
        return allArray
    }
    
    /// 读取本地音乐模型
    @available(*, deprecated, renamed: "readLocalMusicFiles")
    public func old_readLocalMusics() -> [MusicItemModel] {
        let folderPath = self.basePublicFileURL().path + SandboxType_AllJsons

        let fileManager = FileManager.default
        var accountSubFiles = try? fileManager.contentsOfDirectory(atPath: folderPath)
        
        guard let accountFileArray = accountSubFiles, accountFileArray.count > 0 else {
            return []
        }

        var tempArray = [MusicItemModel]()
        
        // 遍历所有文件并输出文件名
        for accountName in accountFileArray {

            let accountFilePath = folderPath + accountName

            var jsonData = try? String(contentsOfFile: accountFilePath)
            jsonData = AESCryptoManager.decryptAES(string: jsonData ?? "", key: UserInfoManager.aesPassKey) ?? ""

            if var model = MusicItemModel.deserialize(from: jsonData) {
                tempArray.append(model)
            }

        }

       return tempArray
    }

}
