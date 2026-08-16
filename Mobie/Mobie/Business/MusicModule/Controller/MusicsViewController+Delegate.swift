//
//  MusicsViewController+Delegate.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/25.
//

import KakaFoundation
import AppGroupKit
import StoreKit
import MediaPlayer
import KSPlayer
import Kingfisher
import KakaTaglibKit
import MessageUI
import ProgressHUD

extension MusicsViewController: DocumentFolderWatcherDelegate, MusicTopHeadViewDelegate {
    
    // 新增了文件
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
                
        self.viewModel.addNewMusics(newUrls: addFiles) { models in
            let time: TimeInterval = addFiles[0].hasDirectoryPath ? 1 : 1
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + time) { [weak self] () in
                guard let wSelf = self else { return }
                wSelf.tableView.tableFooterView = wSelf.footView
                wSelf.tableView.tableHeaderView = wSelf.isShowHeadView ? wSelf.headView : nil
                wSelf.footView.update(wSelf.viewModel.baseFileURL)
                self?.tableView.reloadData()
            }
        }
        
        if !self.viewModel.isBaseDoc { return }
        DispatchQueue.main.async { [weak self] () in
            guard let wSelf = self else { return }
            
            wSelf.headView.updateLocal(folders: wSelf.viewModel.folderArray)
        }
    }
    
    // 删除了文件
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        self.viewModel.deleteMusics(newUrls: deleteFiles) { [weak self] models in
            guard let wSelf = self else { return }
            let fileCount = wSelf.baseFileURL.totalFileCount()
            wSelf.tableView.tableFooterView = fileCount == 0 ? nil : wSelf.footView
            wSelf.tableView.tableHeaderView = wSelf.isShowHeadView ? wSelf.headView : nil
            wSelf.footView.update(wSelf.viewModel.baseFileURL)
            self?.tableView.reloadData()
        }
        
        if !self.viewModel.isBaseDoc { return }
        DispatchQueue.main.async { [weak self] () in
            guard let wSelf = self else { return }
            
            wSelf.headView.updateLocal(folders: wSelf.viewModel.folderArray)
        }
        
    }
    
    // 点击头部
    func musicTopHeadViewDidClickLocal(headView: UIView, clickType: MusicTopHeadClickType, folder: URL) {
        self.stopEditBarClick()
        switch clickType {
        case .clickFolder:
            // 歌单事件：点击文件夹
            let folderVC = MusicsViewController(folder)
            self.navigationController?.pushViewController(folderVC, animated: true)
        case .clickRename:
            // 歌单事件：重命名
            self.renameFolderURL(folder)
        case .clickExport:
            // 歌单事件：导出
            let tempModel = MusicItemModel(fileURL: folder, sourceType: .localFile)
            self.shareMusicModel([tempModel])
        case .clickDelete:
            // 歌单事件：删除
            let tempModel = MusicItemModel(fileURL: folder, sourceType: .localFile)
            self.deleteMusicModel([tempModel])
        }
    }
    
    func musicTopHeadViewDidClickAdd(headView: UIView) {
        
    }
    
    func musicTopHeadViewDidClickArtist(headView: UIView, navArtist: NavidromeArtist) {
        
    }
    
}

extension MusicsViewController: MusicTableViewCellDelegate {
    // 点击更多
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        
        if action == .musictag {
            self.editMusicTagsAction(model)
        }
        
        if action == .audioFinger {
            self.audioFingerprintRecognzer(model)
        }
        
        if action == .addPlaylist {
            self.moveToPlaylistAction(cell: cell, model: model)
        }
        
        if action == .addFavirote {
            self.addOrDeleteFavirote(model)
        }
        
        if action == .showInFinder {
            KakaMusicPlayer.shared.showInFinderCatalyst(model.mediaPlayURL)
        }
        
        if action == .deleteItem {
            self.deleteMusicModel([model])
        }
    }
    
    // 音频指纹识别
    func audioFingerprintRecognzer(_ model: MusicItemModel) {
        let recognizerVC = AudioMatchTagViewController(model)
        recognizerVC.onEditCallback = { [weak self] (newModel) in
            self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
        }
        let navVC = KakaNavigationController(rootViewController: recognizerVC)
#if DEBUG
        navVC.modalPresentationStyle = .automatic
#endif
        self.present(navVC, animated: true)
    }
    
    // 编辑音乐标签
    func editMusicTagsAction(_ model: MusicItemModel) {
        
        self.tableView.setEditing(false, animated: true)
        
        let tagVC = MusicTagEditorController(model)
        tagVC.onEditCallback = { [weak self] (editModel) in
            self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
        }
        self.navigationController?.pushViewController(tagVC, animated: true)
    }
    
    // 收藏或不收藏
    func addOrDeleteFavirote(_ model: MusicItemModel) {
        self.tableView.setEditing(false, animated: true)
        SandboxFileManager.shared.addOrDeleteFavirote(model.mediaPlayURL)
        self.refreshDataAction()
    }
    
    // 移动到其他文件夹
    func moveToPlaylistAction(cell: MusicTableViewCell, model: MusicItemModel) {
        let playlist = SelectPlaylistController(isLocal: true, serverModel: nil)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            guard let wSelf = self else { return }
            do {
                let downloadName = model.filePathName() + model.addPathExtension()
                
                let targetURL = folderURL.appendingPathComponent(downloadName)
                try FileManager.default.moveItem(at: model.mediaPlayURL, to: targetURL)
                wSelf.headView.updateLocal(folders: wSelf.viewModel.folderArray)
                wSelf.refreshDataAction()
                wSelf.guideFiveStarRating()
            } catch {
                wSelf.view.makeToast(error.localizedDescription)
            }
        }
        
        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    @objc func guideFiveStarRating() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: windowScene)
        } else {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

extension MusicsViewController: EmptyContentCellDelegate {
    
    // 导入音乐
    func emptyContentViewDidClickImport(cell: UIView) {
        if kaka_IsMacOS() {
            self.importFromFolder()
        }else{
            self.importMusicClick()
        }
    }
    
    // 所有格式
    func emptyContentViewDidClickFormats(cell: UIView) {
        let formatsVC = SupportTypeViewController()
        self.navigationController?.pushViewController(formatsVC, animated: true)
    }
    
    // 导入页面
    @objc func importMusicClick() {
        let importVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: importVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
        

    }
    
    // 导入方式
    func importTypeClick(_ importType: ImportFileType) {
        
        if importType == .fromFile {
            self.importFromFiles()
        }
        
        if importType == .fromFolder {
            self.importFromFolder()
        }
        
        if importType == .fromVideos {
            self.importFromVideo()
        }
        
        if importType == .fromApple {
            self.importfromApple()
        }
        
        if importType == .fromUSB {
            self.scanDocumentFiles()
        }
        
        if importType == .fromWiFi {
            self.importfromWiFi()
        }
    }
    
    // 新建歌单
    func newMusicFolder() {
        let editAlertVC = UIAlertController(title: "New Playlist".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: " ")
            
            SandboxFileManager.shared.addOrUpdateFolder(folderName: nameText) { result in
                switch result {
                case .success(_):
                    self?.refreshDataAction()
                case .failure(let kakaError):
                    self?.view.makeToast(kakaError.errorDescription)
                }
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
        
    }
    
    // 文件夹重新命名
    func renameFolderURL(_ folderURL: URL) {
        let editAlertVC = UIAlertController(title: MusicActionType.title.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = folderURL.lastPathComponent
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
                        
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            
            let fileManager = FileManager.default
                
            // 获取父目录的 URL
            let parentDirectory = folderURL.deletingLastPathComponent()
            
            // 构建新文件夹的完整路径
            let newFolderURL = parentDirectory.appendingPathComponent(nameText)
            
            do {
                // 检查新文件夹是否已存在
                if fileManager.fileExists(atPath: newFolderURL.path) {
                    debugPrint("新文件夹名称已存在")
                    self?.view.makeToast(KakaError.duplicateNames.errorDescription)
                    return
                }
                
                // 执行重命名
                try fileManager.moveItem(at: folderURL, to: newFolderURL)
                self?.refreshDataAction()
                
            } catch {
                self?.view.makeToast(error.localizedDescription)
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 扫描Apple Music里的本地音乐
    func importfromApple() {
        let appleVC = AppleMusicListController()
        self.navigationController?.pushViewController(appleVC, animated: true)
    }
    
    func showEmbeddedFailed() {
        self.showOneAlert(title: "Embedded Failed".localStr(), message: "This format does not support embedded music metadata. We recommend using common audio formats such as MP3, FLAC, M4A, or WAV.".localStr(), confirm: "OK".localStr())
    }
}

