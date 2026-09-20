//
//  NavidromeViewController+Data.swift
//  Mobie
//
//  Created by 张文 on 12/24/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KSPlayer
import ProgressHUD

extension NavidromeViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.navsetModel.randomSongs == nil ? 0 : self.sectionArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionType = self.sectionArray[section]
        if sectionType == .topSection {
            return 1
        }else if sectionType == .starredSongs {
            let count = self.navsetModel.starred?.song?.count ?? 1
            return count > 6 ? 6 : (count == 0 ? 1 : count)
        }else if sectionType == .myPlaylists {
            return 1
        }else{
            if self.navUser.isLargeServer {
                let count = self.navsetModel.randomSongs?.count ?? 1
                return count >= 21 ? 21 : count
            }else{
                return self.navsetModel.randomSongs?.count ?? 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionType = self.sectionArray[indexPath.section]
        if sectionType == .topSection {
            // 喜欢的歌手
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectNavidromeArtistCell", for: indexPath) as! ConnectNavidromeArtistCell
            cell.delegate = self
            cell.navModels = self.navsetModel.starred?.artist ?? []
            return cell
        }else if sectionType == .starredSongs {
            // 我喜欢的歌曲
            if let songs = self.navsetModel.starred?.song, songs.count > 0 {
                let musicModel = MusicItemModel(navSong: songs[indexPath.row])
                
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                cell.update(musicModel: musicModel, cellType: .navLargeServer)
                cell.delegate = self
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.updateMessage()
                return cell
            }
        }else if sectionType == .myPlaylists {
            // 我的歌单
            if let playlists = self.navsetModel.playlists, playlists.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectMyPlayListCell", for: indexPath) as! ConnectMyPlayListCell
                cell.playlistArray = playlists
                cell.delegate = self
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.updateMessage()
                return cell
            }
        }else{
            // 随机音乐
            if let songs = self.navsetModel.randomSongs, songs.count > 0 {
                let musicModel = MusicItemModel(navSong: songs[indexPath.row])
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                cell.update(musicModel: musicModel, cellType: .navLargeServer)
                cell.delegate = self
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.updateMessage()
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
                
        let sectionType = self.sectionArray[indexPath.section]
        var musicModel: MusicItemModel?
        var allMusics = [MusicItemModel]()
        
        if sectionType == .starredSongs {
            allMusics = (self.navsetModel.starred?.song ?? []).map({ return MusicItemModel(navSong: $0) })
            if allMusics.count == 0 {
                return
            }
            
            musicModel = allMusics[indexPath.row]
        }
        
        if sectionType == .todayRandom {
            allMusics = (self.navsetModel.randomSongs ?? []).map({ return MusicItemModel(navSong: $0) })
            musicModel = allMusics[indexPath.row]
        }

        guard let musicModel = musicModel else { return }
                
        if musicModel == KakaMusicPlayer.shared.playingMusic {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            let index = allMusics.firstIndex { $0 == musicModel } ?? 0
            ConnectConfigManager.shared.lastPlaylist = allMusics
            KakaMusicPlayer.shared.startPlayMusic(musics: allMusics, itemIndex: index)
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = self.sectionArray[indexPath.section]
        if sectionType == .topSection {
            return ConnectNavidromeArtistCell.cellSize().height
        }else if sectionType == .myPlaylists {
            if let playlists = self.navsetModel.playlists, playlists.count > 0 {
                return ConnectMyPlayListCell.headHeight()
            }else{
                return UITableView.automaticDimension
            }
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionType = self.sectionArray[section]
        let footView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ConnectSectionHeadView") as! ConnectSectionHeadView
        
        if sectionType == .topSection { return nil }

        if self.navUser.isLargeServer {
            footView.sectionType = sectionType
        }else{
            footView.titleLabel.text = sectionType.titleStr(self.navUser)
            footView.sectionType = nil
        }
        footView.delegate = self
        return footView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionType = self.sectionArray[section]
        if sectionType == .topSection || sectionType == .rootDic {
            return 0
        }else{
            return 40.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let sectionType = self.sectionArray[indexPath.section]
        if sectionType == .folders {
            return true
        }else{
            return false
        }
    }
        
}
