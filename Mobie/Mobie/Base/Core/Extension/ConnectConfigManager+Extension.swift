//
//  ConnectConfigManager.swift
//  Mobie
//
//  Created by 张文 on 12/29/24.
//

import SmartCodable
import AppGroupKit
import KakaFoundation
import FilesProvider


extension ConnectConfigManager {
    // 添加或更新一个服务器
    public func addOrUpdateRemoteServer(serverModel: ServerConfigModel?, completion: (()->Void)? = nil) {
        
        guard let serverModel = serverModel else {
            completion?()
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        // 1️⃣服务器
        var tempArray = self.connectedModels.map {
            var model = $0
            model.isSelected = false
            return model
        }
        
        // 首先检查是否已经存在该模型
        var newModel = serverModel
        newModel.isSelected = true
        
        if let index = tempArray.firstIndex(of: newModel) {
            tempArray.remove(at: index)
            tempArray.insert(newModel, at: 0)
        } else {
            tempArray.insert(newModel, at: 0)
        }
        
        self.connectedModels = tempArray
        dispatchGroup.leave()
        
        // 2️⃣更新已收藏的文件夹
        dispatchGroup.enter()
        let folders = self.getFavoriteFolders(serverModel)
        let folderArray = folders.map {
            var subFolder = $0
            if let webdavUser = serverModel.webdavUser, let _ = subFolder.webFileModel {
                subFolder.webFileModel?.webdavUser = webdavUser
            }
            if let baiduUser = serverModel.baiduUser, let _ = subFolder.baiduFileModel {
                subFolder.baiduFileModel?.baiduUser = baiduUser
            }
            if let aliyunUser = serverModel.aliyunUser, let _ = subFolder.aliFileModel {
                subFolder.aliFileModel?.aliyunUser = aliyunUser
            }
            if let drive115User = serverModel.drive115User, let _ = subFolder.drive115Model {
                subFolder.drive115Model?.drive115User = drive115User
            }
            if let googleUser = serverModel.googleUser, let _ = subFolder.googleFile {
                subFolder.googleFile?.googleUser = googleUser
            }
            if let dropboxUser = serverModel.dropboxUser, let _ = subFolder.dropboxFile {
                subFolder.dropboxFile?.dropboxUser = dropboxUser
            }
            if let user = serverModel.smbUser, subFolder.smbFile != nil {
                subFolder.smbFile?.smbUser = user
            }
            if let user = serverModel.megaUser, subFolder.megaFile != nil {
                subFolder.megaFile?.megaUser = user
            }
            if let user = serverModel.boxUser, subFolder.boxFile != nil {
                subFolder.boxFile?.boxUser = user
            }
            if let user = serverModel.pcloudUser, subFolder.pcloudFile != nil {
                subFolder.pcloudFile?.pcloudUser = user
            }
            if let onedriveUser = serverModel.onedriveUser, let _ = subFolder.onedriveFile {
                subFolder.onedriveFile?.onedriveUser = onedriveUser
            }
            return subFolder
        }
        
        self.addOrUpdateFavoriteFolders(folders: folderArray) {
            dispatchGroup.leave()
        }
        
        // 3️⃣更新已收藏的歌曲
        dispatchGroup.enter()
        let musics = self.getFavoriteSongs(serverModel)
        let musicArray = musics.map {
            var subMusic = $0
            if let webdavUser = serverModel.webdavUser, let _ = subMusic.webFileModel {
                subMusic.webFileModel?.webdavUser = webdavUser
            }
            if let baiduUser = serverModel.baiduUser, let _ = subMusic.baiduFileModel {
                subMusic.baiduFileModel?.baiduUser = baiduUser
            }
            if let aliyunUser = serverModel.aliyunUser, let _ = subMusic.aliFileModel {
                subMusic.aliFileModel?.aliyunUser = aliyunUser
            }
            if let drive115User = serverModel.drive115User, let _ = subMusic.drive115Model {
                subMusic.drive115Model?.drive115User = drive115User
            }
            if let googleUser = serverModel.googleUser, let _ = subMusic.googleFile {
                subMusic.googleFile?.googleUser = googleUser
            }
            if let dropboxUser = serverModel.dropboxUser, let _ = subMusic.dropboxFile {
                subMusic.dropboxFile?.dropboxUser = dropboxUser
            }
            if let user = serverModel.smbUser, subMusic.smbFile != nil {
                subMusic.smbFile?.smbUser = user
            }
            if let user = serverModel.megaUser, subMusic.megaFile != nil {
                subMusic.megaFile?.megaUser = user
            }
            if let user = serverModel.boxUser, subMusic.boxFile != nil {
                subMusic.boxFile?.boxUser = user
            }
            if let user = serverModel.pcloudUser, subMusic.pcloudFile != nil {
                subMusic.pcloudFile?.pcloudUser = user
            }
            if let onedriveUser = serverModel.onedriveUser, let _ = subMusic.onedriveFile {
                subMusic.onedriveFile?.onedriveUser = onedriveUser
            }
            return subMusic
        }
                                    
        self.addOrUpdateFavoriteMusics(musics: musicArray) {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion?()
        }
    }
    
    // 删除一个服务器
    @MainActor
    public func deleteOneServer(_ serverModel: ServerConfigModel) {
        
        // 1️⃣删除服务器
        var serverArray = self.connectedModels
        if let index = serverArray.firstIndex(of: serverModel) {
            serverArray.remove(at: index)
        }
        
        self.connectedModels = serverArray
        
        // 2️⃣删除收藏文件夹
        var folderArray = self.selectFolderArray
        let folders = Set(self.getFavoriteFolders(serverModel))
        folderArray.removeAll { folders.contains($0) }
        
        self.selectFolderArray = folderArray

        // 3️⃣删除收藏的歌曲
        var musicArray = self.favoriteMusicArray
        let musics = Set(self.getFavoriteSongs(serverModel))
        musicArray.removeAll { musics.contains($0) }
        
        self.favoriteMusicArray = musicArray

        if let user = serverModel.smbUser {
            SMBDriveService.shared.unlink(user)
            self.lastPlaylist = self.lastPlaylist.filter { $0.smbFile?.smbUser != user }
            let player = KakaMusicPlayer.shared
            player.musicArray = player.musicArray.filter { $0.smbFile?.smbUser != user }
            player.tempMusicArray = player.tempMusicArray.filter { $0.smbFile?.smbUser != user }
            if player.nextPlayMusic?.smbFile?.smbUser == user { player.nextPlayMusic = nil }
            if player.playingMusic?.smbFile?.smbUser == user {
                player.stop()
                player.playingMusic = nil
                MusicConfigManager.shared.lastPlayModel = nil
            }
        }
        if let user = serverModel.megaUser {
            MEGADriveService.shared.unlink(user)
            self.lastPlaylist = self.lastPlaylist.filter { $0.megaFile?.megaUser != user }
            let player = KakaMusicPlayer.shared
            player.musicArray = player.musicArray.filter { $0.megaFile?.megaUser != user }
            player.tempMusicArray = player.tempMusicArray.filter { $0.megaFile?.megaUser != user }
            if player.nextPlayMusic?.megaFile?.megaUser == user { player.nextPlayMusic = nil }
            if player.playingMusic?.megaFile?.megaUser == user {
                player.stop()
                player.playingMusic = nil
                MusicConfigManager.shared.lastPlayModel = nil
            }
        }
        if let user = serverModel.boxUser {
            BoxDriveService.shared.unlink(user)
            self.lastPlaylist = self.lastPlaylist.filter { $0.boxFile?.boxUser != user }
            let player = KakaMusicPlayer.shared
            player.musicArray = player.musicArray.filter { $0.boxFile?.boxUser != user }
            player.tempMusicArray = player.tempMusicArray.filter { $0.boxFile?.boxUser != user }
            if player.nextPlayMusic?.boxFile?.boxUser == user { player.nextPlayMusic = nil }
            if player.playingMusic?.boxFile?.boxUser == user {
                player.stop()
                player.playingMusic = nil
                MusicConfigManager.shared.lastPlayModel = nil
            }
        }
        if let user = serverModel.pcloudUser {
            PCloudDriveService.shared.unlink(user)
            self.lastPlaylist = self.lastPlaylist.filter { $0.pcloudFile?.pcloudUser != user }
            let player = KakaMusicPlayer.shared
            player.musicArray = player.musicArray.filter { $0.pcloudFile?.pcloudUser != user }
            player.tempMusicArray = player.tempMusicArray.filter { $0.pcloudFile?.pcloudUser != user }
            if player.nextPlayMusic?.pcloudFile?.pcloudUser == user { player.nextPlayMusic = nil }
            if player.playingMusic?.pcloudFile?.pcloudUser == user {
                player.stop()
                player.playingMusic = nil
                MusicConfigManager.shared.lastPlayModel = nil
            }
        }
        
        KakaMusicPlayer.shared.deleteAllM3uCache()
        
    }
    
    // 喜欢或不喜欢的一首歌
    public func likeOrDislikeOneMusic(_ model: MusicItemModel) {
        
        var tempArray = self.favoriteMusicArray
        
        // 首先检查是否已经存在该模型
        var newModel = model
        if model.pcloudFile != nil || model.megaFile != nil || model.boxFile != nil {
            newModel.isFavorite = !tempArray.contains(model)
        } else {
            newModel.isFavorite.toggle()
        }
        
        if let index = tempArray.firstIndex(of: newModel) {
            tempArray.remove(at: index)
            if newModel.isFavorite {
                tempArray.insert(newModel, at: 0)
            }
        } else {
            tempArray.insert(newModel, at: 0)
        }
        
        self.favoriteMusicArray = tempArray
                
    }
    
    /// 新增或更新远程的播放列表
    public func addOrUpdateRemotePlaylist(musics: [MusicItemModel], completion: (() -> Void)? = nil) {
        
        var musicSet = Set(self.lastPlaylist)  // 转换为 Set 集合
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 遍历要新增或更新的音乐
            for subModel in musics {
                // 移除已有的该模型
                musicSet.remove(subModel)
                
                // 如果 webFileModel 存在，添加到集合中
                if let _ = subModel.webFileModel {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.baiduFileModel {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.aliFileModel {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.drive115Model {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.googleFile {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.dropboxFile {
                    musicSet.insert(subModel)
                }
                if subModel.pcloudFile != nil || subModel.megaFile != nil || subModel.boxFile != nil {
                    musicSet.insert(subModel)
                }
                
                if let _ = subModel.onedriveFile {
                    musicSet.insert(subModel)
                }
            }
            
            let sortedArray = Array(musicSet).sorted(by: { element1, element2 in
                return element1.sortAnotherModel(model2: element2, sortType: MusicConfigManager.shared.sortType)
            })
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.webFileModel {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.baiduFileModel {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.aliFileModel {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.drive115Model {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.googleFile {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.onedriveFile {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            if let _ = KakaMusicPlayer.shared.playingMusic?.dropboxFile {
                KakaMusicPlayer.shared.musicArray = sortedArray
            }
            
            self.lastPlaylist = sortedArray
            KakaMusicPlayer.shared.musicArray = sortedArray
            KakaMusicPlayer.shared.tempMusicArray = sortedArray
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                completion?()
            }
        }
            
    }
    
    // 批量删除收藏的文件夹
    public func deleteFavoriteFolders(folders: [MusicItemModel], completion: (([MusicItemModel]) -> Void)? = nil) {
        
        var tempArray = self.selectFolderArray

        if folders.count == tempArray.count {
            tempArray.removeAll()
            
            // 处理播放模型
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                self.selectFolderArray = tempArray
                completion?(tempArray)
            }
            return
        }
        
        // 将 models 转换为 Set，以提高查找效率
        let modelsToRemoveSet = Set(folders)
        
        // 使用全局并发队列进行异步操作
        DispatchQueue.global(qos: .userInitiated).async {
            // 直接在原数组上进行操作，避免拷贝
            tempArray.removeAll { modelsToRemoveSet.contains($0) }
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                self.selectFolderArray = tempArray
                completion?(tempArray)
            }
            
        }
    }

}

extension ConnectConfigManager {
    
    // 获取当前服务器下收藏的文件夹
    public func getFavoriteFolders(_ serverModel: ServerConfigModel?) -> [MusicItemModel] {
        let resultArray = self.selectFolderArray.filter({ subModel in
            
            if let webFile = subModel.webFileModel {
                return webFile.webdavUser == serverModel?.webdavUser
            }
            
            if let baiduFile = subModel.baiduFileModel {
                return baiduFile.baiduUser == serverModel?.baiduUser
            }
            
            if let aliFileModel = subModel.aliFileModel {
                return aliFileModel.aliyunUser == serverModel?.aliyunUser
            }
            
            if let drive115Model = subModel.drive115Model {
                return drive115Model.drive115User == serverModel?.drive115User
            }
            
            if let googleFile = subModel.googleFile {
                return googleFile.googleUser == serverModel?.googleUser
            }
            
            if let dropboxFile = subModel.dropboxFile {
                return dropboxFile.dropboxUser == serverModel?.dropboxUser
            }
            if let file = subModel.smbFile, let user = serverModel?.smbUser {
                return file.smbUser == user
            }
            if let file = subModel.megaFile, let user = serverModel?.megaUser {
                return file.megaUser == user
            }
            if let file = subModel.boxFile, let user = serverModel?.boxUser {
                return file.boxUser == user
            }
            if let file = subModel.pcloudFile, let user = serverModel?.pcloudUser {
                return file.pcloudUser == user
            }
            
            if let onedriveFile = subModel.onedriveFile {
                return onedriveFile.onedriveUser == serverModel?.onedriveUser
            }
            
            
            return false
        })
        
        return resultArray
    }
    
    // 获取当前服务器下喜欢的歌曲
    public func getFavoriteSongs(_ serverModel: ServerConfigModel?) -> [MusicItemModel] {
        let resultArray = self.favoriteMusicArray.filter({ subModel in
            
            if let webFile = subModel.webFileModel {
                return webFile.webdavUser == serverModel?.webdavUser
            }
            
            if let baiduFile = subModel.baiduFileModel {
                return baiduFile.baiduUser == serverModel?.baiduUser
            }
            
            if let aliFileModel = subModel.aliFileModel {
                return aliFileModel.aliyunUser == serverModel?.aliyunUser
            }
            
            if let drive115Model = subModel.drive115Model {
                return drive115Model.drive115User == serverModel?.drive115User
            }
            
            if let googleFile = subModel.googleFile {
                return googleFile.googleUser == serverModel?.googleUser
            }
            
            if let dropboxFile = subModel.dropboxFile {
                return dropboxFile.dropboxUser == serverModel?.dropboxUser
            }
            if let file = subModel.smbFile, let user = serverModel?.smbUser {
                return file.smbUser == user
            }
            if let file = subModel.megaFile, let user = serverModel?.megaUser {
                return file.megaUser == user
            }
            if let file = subModel.boxFile, let user = serverModel?.boxUser {
                return file.boxUser == user
            }
            if let file = subModel.pcloudFile, let user = serverModel?.pcloudUser {
                return file.pcloudUser == user
            }
            
            if let onedriveFile = subModel.onedriveFile {
                return onedriveFile.onedriveUser == serverModel?.onedriveUser
            }
            
            return false
        })
        
        return resultArray
    }
    
    /// 新增或更新喜欢的文件夹
    public func addOrUpdateFavoriteFolders(folders: [MusicItemModel], completion: (() -> Void)? = nil) {
        
        var selectedFolders = self.selectFolderArray.filter { $0.isFolder() }
        
        // 遍历要新增或更新的音乐
        for subModel in folders {
            
            // 如果 webFileModel 存在，添加到集合中
            if let _ = subModel.webFileModel {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.baiduFileModel {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.aliFileModel {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.drive115Model {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.googleFile {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.dropboxFile {
                selectedFolders.insert(subModel, at: 0)
            }
            if subModel.pcloudFile != nil || subModel.megaFile != nil || subModel.boxFile != nil {
                selectedFolders.insert(subModel, at: 0)
            }
            
            if let _ = subModel.onedriveFile {
                selectedFolders.insert(subModel, at: 0)
            }
        }
        
        let newArray = Array(Set(selectedFolders))
        self.selectFolderArray = newArray
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
            completion?()
        }
        
    }
    
    /// 新增或更新喜欢的歌曲信息
    public func addOrUpdateFavoriteMusics(musics: [MusicItemModel], completion: (() -> Void)? = nil) {
        
        var selectedMusics = self.favoriteMusicArray.filter { $0.fileType() == .music }
        
        // 遍历要新增或更新的音乐
        for subModel in musics {
            
            // 如果 webFileModel 存在，添加到集合中
            if let _ = subModel.webFileModel {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.baiduFileModel {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.aliFileModel {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.drive115Model {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.googleFile {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.dropboxFile {
                selectedMusics.insert(subModel, at: 0)
            }
            if subModel.pcloudFile != nil || subModel.megaFile != nil || subModel.boxFile != nil {
                selectedMusics.insert(subModel, at: 0)
            }
            
            if let _ = subModel.onedriveFile {
                selectedMusics.insert(subModel, at: 0)
            }
        }
        
        let newArray = Array(Set(selectedMusics))
        self.favoriteMusicArray = newArray
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
            completion?()
        }
        
    }
}
