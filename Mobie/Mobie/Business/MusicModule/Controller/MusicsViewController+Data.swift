//
//  MusicsViewController+Data.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser
import PhotosUI
import StoreKit
import PanModal
import ZLImageEditor
import KSPlayer
import ProgressHUD


extension MusicsViewController: UITableViewDataSource, UITableViewDelegate {
        
    func numberOfSections(in tableView: UITableView) -> Int {
        return isNoneMusic ? 1 : viewModel.musicIndexArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isNoneMusic {
            return 1
        }else{
            let dataArray = self.viewModel.homeSectionArray(section)
            return dataArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.isNoneMusic {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyTableViewCell", for: indexPath) as! EmptyTableViewCell
            cell.appearanceChanged()
            cell.delegate = self
            return cell
        }else{
            let dataArray = self.viewModel.homeSectionArray(indexPath.section)
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
            
            if dataArray.count > indexPath.row {
                let model = dataArray[indexPath.row]
                cell.update(musicModel: model, cellType: .local)
                cell.delegate = self
                if tableView.isEditing {
                    let isSelected = self.viewModel.selectArray.map { $0.filePathName() }.contains(model.filePathName())
                    if isSelected {
                        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    }else{
                        tableView.deselectRow(at: indexPath, animated: false)
                    }
                }
            }else{
                debugPrint("❌数组越界")
            }

#warning("模拟mock数据")
//#if DEBUG
//            let musicGenre = MusicGenreType.allCases.randomElement()!
//            
//            cell.nameLabel.text = musicGenre.formatStr() + "." + AudioExtensionType.allCases.randomElement()!.rawValue
//            cell.descLabel.text = "Wake Music".localStr()
//            cell.coverImgView.image = musicGenre.iconImage()
//#endif
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
#warning("模拟mock数据")
//#if DEBUG
//        tableView.deselectRow(at: indexPath, animated: true)
//        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
//            tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//            tabbarVC.toolbarView.isHidden = !tabbarVC.toolbarView.isHidden
//            return
//        }
//#endif
        
        if isNoneMusic {
            tableView.deselectRow(at: indexPath, animated: true)
#if !DEBUG
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
#endif
            return
        }
        
        if !self.tableView.isEditing {
            let dataArray = self.viewModel.homeSectionArray(indexPath.section)
            let model = dataArray[indexPath.row]
            
            if model.isFolder() {
                if !self.checkFileExist(model) {
                    return
                }
                
                let musicVC = MusicsViewController(model.mediaPlayURL)
                self.navigationController?.pushViewController(musicVC, animated: true)
            }else{
                let isPlaying: Bool = KakaMusicPlayer.shared.playingMusic == model
                let playingIndex = viewModel.playingMusicIndex(model)
                
                if isPlaying {
                    KakaMusicPlayer.presentPlayController(fromVC: self)
                }else{
                    self.clickMusicItem(playingIndex)
                }
            }
            
            tableView.deselectRow(at: indexPath, animated: true)
        }else{
            // 直接从数据源获取模型对象
            var dataArray = self.viewModel.homeSectionArray(indexPath.section)
            var model = dataArray[indexPath.row]
            
            // 切换选择状态
            model.isSelected.toggle()
            
            // 更新数据源中的模型对象
            dataArray[indexPath.row] = model
            
            // 更新选中数组
            if model.isSelected {
                // 如果模型被选中且不在 selectArray 中，则添加
                if !self.viewModel.selectArray.contains(where: { $0.filePathName() == model.filePathName() }) {
                    self.viewModel.selectArray.append(model)
                }
            } else {
                // 如果模型未被选中且在 selectArray 中，则移除
                if let firstIndex = self.viewModel.selectArray.firstIndex(where: { $0.filePathName() == model.filePathName() }) {
                    self.viewModel.selectArray.remove(at: firstIndex)
                }
            }
            
            let selectTitle = "\(self.viewModel.selectArray.count)"
            self.selectCountItem.title = selectTitle
            
            // 更新当前单元格的选中状态
            if model.isSelected {
                self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }else{
                self.tableView.deselectRow(at: indexPath, animated: true)
            }
            
            if model.isFlagFavorite() {
                self.tableView.reloadData()
            }
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        // 处理取消选择
        var dataArray = self.viewModel.homeSectionArray(indexPath.section)
        var model = dataArray[indexPath.row]
        
        // 确保模型的选择状态为 false
        model.isSelected = false
        
        // 更新数据源中的模型对象
        dataArray[indexPath.row] = model
        
        // 从选中数组中移除模型
        if let firstIndex = self.viewModel.selectArray.firstIndex(where: { $0.filePathName() == model.filePathName() }) {
            self.viewModel.selectArray.remove(at: firstIndex)
        }
        
        // 更新当前单元格的选中状态
        if model.isSelected {
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }else{
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        
        if model.isFlagFavorite() {
            self.tableView.reloadData()
        }
        
        self.selectCountItem.title = "\(self.viewModel.selectArray.count)"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isNoneMusic {
            let navHeight = app_navHeight
            let tabHeight = self.tabBarController?.tabBar.bounds.height ?? 0
            
            let cellHeight = self.view.height - navHeight - kStatusBarHeight - tabHeight - 70.ckValue()
            return cellHeight
        }else{
            return UITableView.automaticDimension
        }
                        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isNoneMusic {
            return nil
        }else{
            if viewModel.musicIndexArray.count <= section {
                return nil
            }else {
                
                let header = viewModel.musicIndexArray[section]
                if self.viewModel.groupType == .nonGroup || self.viewModel.searchKey != nil {
                    if header == .likedSongs {
                        return header.titleStr()
                    }else{
                        if let searchKey = self.viewModel.searchKey {
                            let searchStr = self.searchController.searchBar.placeholder ?? ""
                            return searchStr + " " + searchKey
                        }else{
                            let arrowStr = (MusicConfigManager.shared.isSortAscending ? "<<" : ">>")
                            return viewModel.sortType.formatStr() + arrowStr
                        }
                    }
                }else{
                    return header.titleStr()
                }
            }
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isNoneMusic {
            return nil
        }else{
            if viewModel.groupType == .nonGroup || viewModel.searchKey != nil {
                return nil
            }else{
                return viewModel.musicIndexArray.map { $0.keyStr() }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return isNoneMusic ? false : true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let dataArray = self.viewModel.homeSectionArray(indexPath.section)
        
        if dataArray.count > indexPath.row {
            let model = dataArray[indexPath.row]
            
            // 音乐标签
            let musictagAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
                self?.editMusicTagsAction(model)
                finish(true)
            }
            musictagAction.image = Reasource.systemNamed("touchid", color: .white)
            musictagAction.backgroundColor = UIColor.systemBlue
            
            // 移动到歌单
            let moveAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
                guard let cell = self?.tableView.cellForRow(at: indexPath) as? MusicTableViewCell else { return }
                self?.moveToPlaylistAction(cell: cell, model: model)
                finish(true)
            }
            moveAction.image = Reasource.systemNamed("music.note.list", color: .white)
            moveAction.backgroundColor = UIColor.systemGreen
            
            // 收藏
            let likeAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
                self?.addOrDeleteFavirote(model)
                finish(true)
            }
            likeAction.image = Reasource.systemNamed(model.isFlagFavorite() ? "heart.fill" : "heart", color: .white)
            likeAction.backgroundColor = UIColor.systemOrange
            
            // 删除
            let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
                self?.deleteMusicModel([model])
                finish(true)
            }
            deleteAction.image = Reasource.systemNamed("trash", color: .white)
            deleteAction.backgroundColor = UIColor.systemPink
                    
            let actions = [musictagAction, moveAction, likeAction, deleteAction]
            return UISwipeActionsConfiguration(actions: actions)
        }else{
            return nil
        }
        
    }
    
    // 选择、添加收藏/取消收藏、编辑标签，删除
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        if tableView.isEditing { return nil }
        
        let dataArray = self.viewModel.homeSectionArray(indexPath.section)
        if dataArray.count <= indexPath.row { return nil }
        
        let model = dataArray[indexPath.row]
                        
        // 音频指纹识别
        let audiofingerAction = UIAction(title: MusicActionType.audioFinger.titleStr(), image: MusicActionType.audioFinger.iconImage()) { [weak self] _ in
            self?.editMusicTagsAction(model)
        }
        
        let musictagMenu = UIMenu(title: "", options: .displayInline, children: [audiofingerAction])
        
        // 喜欢/不喜欢
        let likeType = model.isFlagFavorite() ? MusicActionType.removeFavirote : MusicActionType.addFavirote
        let likeItem = UIAction(title: likeType.titleStr(), image: likeType.iconImage()) { [weak self] (_) in
            SandboxFileManager.shared.addOrDeleteFavirote(model.mediaPlayURL)
            self?.refreshDataAction()
        }
        
        // 移动到歌单
        let playlistAction = UIAction(title: MusicActionType.addPlaylist.titleStr(), image: MusicActionType.addPlaylist.iconImage()) { [weak self] _ in
            self?.tableView.setEditing(false, animated: true)
            guard let cell = self?.tableView.cellForRow(at: indexPath) as? MusicTableViewCell else { return }
            self?.moveToPlaylistAction(cell: cell, model: model)
        }
        
        let otherMenu = UIMenu(title: "", options: .displayInline, children: [likeItem, playlistAction])
        
        // 删除
        let deleteAction = UIAction(title: MusicActionType.deleteItem.titleStr(), image: MusicActionType.deleteItem.iconImage(), attributes: .destructive) { [weak self] (_) in
            self?.deleteMusicModel([model])
        }
        
        let deleteMenu = UIMenu(title: "", options: .displayInline, children: [deleteAction])
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: .none, actionProvider: { _ in
            return UIMenu(title: model.mediaPlayURL.lastPathComponent, children: [musictagMenu, otherMenu, deleteMenu])
        })
    }
    
}


