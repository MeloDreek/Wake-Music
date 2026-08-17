//
//  NavidromeViewController+Request.swift
//  Mobie
//
//  Created by 张文 on 2/27/25.
//

import KakaFoundation
import AppGroupKit
import Alamofire

extension NavidromeViewController {
    
    // 喜欢的歌，我的歌单，随便听听
    @objc func refreshDataAction() {
         
        if !self.tableView.isDragging {
            loadingView.startAnimating()
        }
        
        let taskGroup = DispatchGroup()
        self.isAuthenticated = true
        
        // 1、我喜欢的歌手和歌曲
        taskGroup.enter()
        self.refreshStarredArtistsSongs {
            taskGroup.leave()
        }
                
        // 2、我的歌单
        if self.navUser.isLargeServer {
            taskGroup.enter()
            self.refreshMyPlayLists {
                taskGroup.leave()
            }
        }
        
        // 3、随机一组歌曲 && 全部歌曲
        taskGroup.enter()
        self.refreshRandomSongs {
            taskGroup.leave()
        }
        
        taskGroup.notify(queue: .main) { [weak self] () in
            guard let wSelf = self else { return }
                                    
            if let navUser = wSelf.navUser, !wSelf.isAuthenticated, !wSelf.isRetryLogin {
                // 重新自动登录
                self?.reloginNavidrome(navUser)
            }else{
                if let navModel = self?.navsetModel, let randomSongs = navModel.randomSongs, randomSongs.count > 0 {
                    wSelf.navsetModel = navModel
                }
                
                wSelf.loadingView.stopAnimating()
                wSelf.isRetryLogin = false
                wSelf.kaka_header.endRefreshing()
                wSelf.tableView.reloadData()
            }
        }
        
    }
    
    // 页面数据变动的通知
    @objc func refreshMyNavidrome() {
        // 1、我喜欢的歌手和歌曲
        self.refreshStarredArtistsSongs {
            self.tableView.reloadData()
        }
                
        // 2、我的歌单
        self.refreshMyPlayLists {
            self.tableView.reloadData()
        }
    }
    
    // 重新登录Navidrome
    private func reloginNavidrome(_ serverModel: NavidromeUserModel) {
        
        APIManager.shared.loginNavidrome(serverUrl: serverModel.hostUrl, isLargeServer: serverModel.isLargeServer, username: serverModel.username, password: serverModel.password) { [weak self] result in
            guard let wSelf = self else { return }
            
            wSelf.isRetryLogin = true
            
            switch result {
            case .success(let navModel):
                
                let serverModel = ServerConfigModel(serverType: .fromNavidrome, navUser: navModel)
                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: serverModel) {
                    self?.refreshDataAction()
                }
                                
                break
            case .failure(let failure):
                self?.view.makeToast(failure.errorDescription)
                break
            }
        }
    }
    
    // 1、我喜欢的歌手和歌曲
    func refreshStarredArtistsSongs(_ complection: (()->Void)? = nil) {
        
        // 大型服，加载喜欢的歌手
        let params1: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC", "_sort": "play_count"]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.getStarred, method: .get, parameters: params1) { subsonicModel in
            var starredModel = subsonicModel.starred ?? NaviArAlSongModel()
            let songs = (starredModel.song ?? []).map {
                var newModel = $0
                newModel.starred = true
                newModel.navUser = self.navUser
                return newModel
            }
            starredModel.song = songs
            
            let tempArtists = starredModel.artist ?? []
            let artistArray = tempArtists.map {
                var newModel = $0
                newModel.starred = true
                newModel.navUser = self.navUser
                return newModel
            }
            
            starredModel.artist = artistArray
            
            self.navsetModel.starred = starredModel
            complection?()
        } fail: { error in
            self.navsetModel.starred = nil
            self.view.makeToast(error.errorDescription)
            complection?()
        }
        
    }
    
    // 2、我的歌单
    func refreshMyPlayLists(_ completion: (()->Void)? = nil) {
        let params: [String: Any] = ["_start": 0, "_end": 0]
        APIManager.shared.requestNavidrome(navUser: self.navUser, endpoint: API.Navidrome.getPlaylists, method: .get, parameters: params) { data in
            let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]]
            if jsonArray == nil {
                let jsonStr = String(data: data, encoding: .utf8) ?? ""
                debugPrint("jsonStr = \(jsonStr)")
                self.isAuthenticated = !jsonStr.contains("Authentication Failed")
            }else{
                let tempArray = [NavidromePlaylist].deserialize(from: jsonArray) ?? []
                let playlistArray = tempArray.map({
                    var newModel = $0
                    newModel.navUser = self.navUser
                    return newModel
                })
                
                self.navsetModel.playlists = playlistArray
                ConnectConfigManager.shared.playlists = playlistArray
            }
                        
            completion?()
        } fail: { error in
            self.navsetModel.playlists = nil
            self.view.makeToast(error.localizedDescription)
            completion?()
            
        }
    }
    
    // 3、随机获取一组歌曲
    func refreshRandomSongs(_ completion: (()->Void)? = nil) {
        
        if self.navUser.isLargeServer {
            let params: [String: Any] = ["size": 21]
            APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.randomSongs, method: .get, parameters: params) { subsonicModel in
                let tempArray = subsonicModel.randomSongs?.song ?? []
                let songArray = tempArray.map({
                    var newModel = $0
                    newModel.navUser = self.navUser
                    return newModel
                })
                self.navsetModel.randomSongs = songArray
                completion?()
            } fail: { error in
                self.navsetModel.randomSongs = nil
                self.view.makeToast(error.localizedDescription)
                completion?()
            }
        }else{
            // 所有歌曲
            let params3: [String: Any] = ["_start": 0, "_end": 0]
            APIManager.shared.requestNavidrome(navUser: self.navUser, endpoint: API.Navidrome.getSong, parameters: params3) { data in
                guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]], jsonArray.count > 0 else {
                    let jsonStr = String(data: data, encoding: .utf8) ?? ""
                    debugPrint("jsonStr = \(jsonStr)")
                    self.isAuthenticated = !jsonStr.contains("Authentication Failed")
                    completion?()
                    return
                }
                
                let tempArray = [NavidromeSong].deserialize(from: jsonArray) ?? []
                let songArray = tempArray.map({
                    var newModel = $0
                    newModel.navUser = self.navUser
                    return newModel
                })
                self.navsetModel.randomSongs = songArray
                completion?()
                
            } fail: { error in
                self.navsetModel.randomSongs = nil
                self.view.makeToast(error.localizedDescription)
                completion?()
            }
            
           
        }
    }
    
}
