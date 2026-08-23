//
//  NavidromeViewController+Action.swift
//  Mobie
//
//  Created by 张文 on 3/1/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer
import ProgressHUD
import Alamofire
import WebKit


extension NavidromeViewController: EmptyContentCellDelegate, ConnectSectionHeadViewDelegate {
    
    // 所有格式
    func emptyContentViewDidClickImport(cell: UIView) {
        let formatsVC = SupportTypeViewController()
        self.navigationController?.pushViewController(formatsVC, animated: true)
    }
    
    // 导入音乐
    func emptyContentViewDidClickFormats(cell: UIView) {
        self.reloginItemClick()
    }
    
    // 编辑配置/重新登录
    @objc func reloginItemClick() {
        
        let webVC = AuthNavidromeController(self.navUser)
        webVC.onLoginBlock = { [weak self] (navUser) in
            self?.navUser = navUser
            self?.refreshDataAction()
        }
        
        let navVC = KakaNavigationController(rootViewController: webVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .fullScreen
        self.present(navVC, animated: true)
    }

    // 导入页面
    func importMusicClick() {
        let importVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: importVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
    }
    
    // 点击头部按钮
    func connectSectionHeadViewDidClick(footView: ConnectSectionHeadView, sectionType: ConnectCellSection) {
        if sectionType == .starredSongs {
            // 更多
            if let songs = self.navsetModel.starred?.song, songs.count > 0 {
                let newSongs = songs.map({
                    var newSong = $0
                    newSong.starred = true
                    newSong.navUser = self.navUser
                    return newSong
                })
                let songVC = NavidromeSongListController(listType: .favorite, songs: (newSongs, nil))
                self.navigationController?.pushViewController(songVC, animated: true)
            }else{
                let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 1))
                cell?.kaka_playShakeAnim()
            }
        } else if sectionType == .myPlaylists {
            // 我的歌单
            self.newMusicFolder(footView)
        } else if sectionType == .todayRandom {
            // 随机音乐
            footView.startLoading()
            self.refreshRandomSongs { [weak self] () in
                footView.stopLoading()
                self?.tableView.reloadData()
            }
        }
    }
    
    // 新建歌单
    func newMusicFolder(_ footView: ConnectSectionHeadView? = nil) {
        let editAlertVC = UIAlertController(title: "New Playlist".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
                        
            footView?.startLoading()
            let params: [String: Any] = ["name": nameText]
            APIManager.shared.requestSubsonic(navUser: self?.navUser, endpoint: API.Subsonic.createPlaylist, method: .post, parameters: params) { response in
                if response.isSuccess() {
                    self?.refreshMyPlayLists({
                        footView?.stopLoading()
                        self?.tableView.reloadData()
                    })
                }else{
                    footView?.stopLoading()
                    self?.view.makeToast(response.toJSONString())
                }
            } fail: { error in
                footView?.stopLoading()
                self?.view.makeToast(error.localizedDescription)
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
}

extension NavidromeViewController: ConnectMyPlayListCellDelegate {
    
    // 点击歌单
    func connectMyPlayListCellDidClick(cell: ConnectMyPlayListCell, playlist: AppGroupKit.NavidromePlaylist) {
        let playlistVC = NavidromeSongListController(listType: .playlist, songs: ([], playlist))
        self.navigationController?.pushViewController(playlistVC, animated: true)
    }
    
    // 删除歌单
    func connectMyPlayListCellDidDelete(cell: ConnectMyPlayListCell, playlist: AppGroupKit.NavidromePlaylist) {
        
        self.showTwoAlert(message: "Are you sure to delete it?".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert, complete: {
            
            let param = ["id": playlist.id]
            APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: API.Subsonic.deletePlaylist, method: .delete, parameters: param) { [weak self] response in
                self?.refreshMyPlayLists({
                    self?.view.makeToast("Complete Deletion".localStr())
                    self?.tableView.reloadData()
                })
            } fail: { [weak self] error in
                self?.view.makeToast(error.localizedDescription)
            }
            
        })
        
    }
    
    // 重命名歌单
    func connectMyPlayListCellDidRename(cell: ConnectMyPlayListCell, playlist: AppGroupKit.NavidromePlaylist) {
        
        let editAlertVC = UIAlertController(title: "Rename".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
                        
            let param = ["playlistId": playlist.id, "name": nameText]
            
            APIManager.shared.requestSubsonic(navUser: self?.navUser, endpoint: API.Subsonic.updatePlaylist, parameters: param) { response in
                self?.refreshMyPlayLists({
                    self?.view.makeToast("Successful".localStr())
                    self?.tableView.reloadData()
                })
            } fail: { error in
                self?.view.makeToast(error.localizedDescription)
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
        
    }
    
}

extension NavidromeViewController: MusicTableViewCellDelegate {
    // 点击cell更多
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        
        guard let navSong = model.navidromeSong else { return }
        
        if action == .addFavirote || action == .removeFavirote {
            self.navidromeSearchDidAddLike(navSong: navSong)
        }
        
        if action == .addPlaylist {
            self.navidromeSearchDidAddPlaylist(navSong: navSong)
        }
        
        if action == .download {
            self.navidromeSearchDidDownload(cell: cell, navSong: navSong)
        }
        
        if action == .artistDetial {
            var navArtist = NavidromeArtist()
            navArtist.id = navSong.artistId ?? ""
            navArtist.name = navSong.artist
            navArtist.navUser = navSong.navUser
            let artistVC = NavidromeArtistDetialController(navUser: self.navUser, model: navArtist)
            self.navigationController?.pushViewController(artistVC, animated: true)
        }
        
        if action == .albumDetial {
            
        }
        
    }
    
    // 喜欢/不喜欢
    func navidromeSearchDidAddLike(navSong: AppGroupKit.NavidromeSong) {
        let params: [String: Any] = ["id": navSong.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: navSong.starred ? API.Subsonic.unstar : API.Subsonic.star, parameters: params) { [weak self] response in
            var newSong = navSong
            newSong.starred.toggle()
            
            let index = self?.navsetModel.starred?.song?.firstIndex { $0.id == newSong.id }
            guard let index = index else {
                // 加入喜欢
                self?.navsetModel.starred?.song?.insert(newSong, at: 0)
                self?.tableView.reloadData()
                self?.view.makeToast("Successful".localStr())
                return
            }
            
            // 取消喜欢
            self?.navsetModel.starred?.song?.remove(at: index)
            self?.tableView.reloadData()
            self?.view.makeToast("Successful".localStr())
            
        } fail: { [weak self] error in
            self?.view.makeToast(error.localizedDescription)
        }
    }
    
    // 加入歌单
    func navidromeSearchDidAddPlaylist(navSong: AppGroupKit.NavidromeSong) {
        let serverModel = ServerConfigModel(serverType: .fromNavidrome, navUser: self.navUser)
        let playlist = SelectPlaylistController(selectType: .navidromeList, serverModel: serverModel)
        playlist.onRemoteBlock = { [weak self] (playlist) in
            let params = ["playlistId": playlist.id, "songIdToAdd": navSong.id]
            APIManager.shared.requestSubsonic(navUser: self?.navUser, endpoint: API.Subsonic.updatePlaylist, parameters: params) { response in
                self?.view.makeToast("Successful".localStr())
                NotificationCenter.default.post(name: Notification.Name(kRemoteMusicChangedKey), object: nil)
            } fail: { error in
                self?.view.makeToast(error.localizedDescription)
            }

        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    // 下载Navidrme
    func navidromeSearchDidDownload(cell: MusicTableViewCell, navSong: AppGroupKit.NavidromeSong) {
                        
        let playlist = SelectPlaylistController(selectType: .downloadTask)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            
            var musicModel = MusicItemModel(navSong: navSong)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to Downloads".localStr())
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
        
    }
    
}


extension NavidromeViewController: MusicTopHeadViewDelegate {
    // 前往歌手详情页
    func musicTopHeadViewDidClickArtist(headView: UIView, navArtist: AppGroupKit.NavidromeArtist) {
        let artistVC = NavidromeArtistDetialController(navUser: self.navUser, model: navArtist)
        self.navigationController?.pushViewController(artistVC, animated: true)
    }
    
    // 点击navidrome歌手
    func musicTopHeadViewDidClickAdd(headView: UIView) {
        // 歌手列表
        let artistVC = NavidromeArtistListController(self.navUser)
        artistVC.onStarredBlock = { [weak self] () in
            self?.refreshStarredArtistsSongs({
                self?.tableView.reloadData()
            })
        }
        self.navigationController?.pushViewController(artistVC, animated: true)
    }
    
    func musicTopHeadViewDidClickLocal(headView: UIView, clickType: MusicTopHeadClickType, folder: URL) {
        
    }
    
    
}

extension NavidromeViewController {
    
    // 播放上一次缓存的歌曲
    func playLastMusicCache(_ music: MusicItemModel?) {
        guard let _ = music else { return }
        KakaMusicPlayer.shared.play()
    }
    
    // 定位到当前播放cell
    @objc func locationPlayingCell() {
        
    }
}
