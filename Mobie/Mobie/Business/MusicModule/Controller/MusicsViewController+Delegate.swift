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
        if self.headMusictagView.state == .matching {
            return
        }
        
        self.viewModel.addNewMusics(newUrls: addFiles) { models in
            let time: TimeInterval = addFiles[0].hasDirectoryPath ? 1 : 1
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + time) { [weak self] () in
                guard let wSelf = self else { return }
                wSelf.tableView.tableFooterView = wSelf.footView
                wSelf.tableView.tableHeaderView = wSelf.showHeadView
                wSelf.footView.update(wSelf.viewModel.baseFileURL)
                self?.tableView.reloadData()
            }
        }
        
        if !self.viewModel.isBaseDoc { return }
        DispatchQueue.main.async { [weak self] () in
            guard let wSelf = self else { return }
            
            wSelf.headFolderView.updateLocal(folders: wSelf.viewModel.folderArray)
        }
    }
    
    // 删除了文件
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        
        if self.headMusictagView.state == .matching {
            return
        }
        
        self.viewModel.deleteMusics(newUrls: deleteFiles) { [weak self] models in
            guard let wSelf = self else { return }
            let fileCount = wSelf.baseFileURL.totalFileCount()
            wSelf.tableView.tableFooterView = fileCount == 0 ? nil : wSelf.footView
            wSelf.tableView.tableHeaderView = wSelf.showHeadView
            wSelf.footView.update(wSelf.viewModel.baseFileURL)
            self?.tableView.reloadData()
        }
        
        if !self.viewModel.isBaseDoc { return }
        DispatchQueue.main.async { [weak self] () in
            guard let wSelf = self else { return }
            
            wSelf.headFolderView.updateLocal(folders: wSelf.viewModel.folderArray)
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

extension MusicsViewController: MusicTopBatchEditHeadViewDelegate {
    
    // 批量自动编辑
    func musicTopHeadViewDidStartEditing(topView: MusicTopBatchEditHeadView) {
        self.stopEditBarClick()
        
        let allModels = self.viewModel.allMusicArray
        
        guard allModels.count > 0 else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
#warning("模拟mock数据")
//#if DEBUG
//        self.headMusictagView.state = .matching
//        var cureModel = allModels.last
//        cureModel?.mediaPlayURL = SandboxFileManager.shared.basePublicFileURL().appendingPathComponent("Michael Jackson - Dangerous.flac")
//        self.headMusictagView.updateProgress(curModel: cureModel, completed: allModels.count / 2, total: allModels.count)
//        return
//#endif
        
        if !UserInfoManager.shared.isVIP() {
            let message = "Say goodbye to tedious manual typing! Upgrade to Premium to automatically fix tags, fetch 4K artwork, and download lyrics via instant audio fingerprinting. Or, you can choose to continue editing manually.".localStr()
            let action1 = AlertActionConfig(title: "Unlock Premium".localStr(), style: .destructive, actionType: .first)
            let action2 = AlertActionConfig(title: "Manual Edit".localStr(), style: .default, actionType: .second)
            self.showThreeAlert(message: message, btn1: action1, btn2: action2) { [weak self] actionType in
                if actionType == .first {
                    self?.vipCenterClick()
                }else{
                    guard let wSelf = self else { return }
                    wSelf.tableView(wSelf.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                }
            }
            return
        }
        
        let configVC = AutoEditConfigViewController()
        configVC.onSelectBlock = { [weak self] (config) in
            self?.starBatchAutoEdit(config)
        }
        configVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .overFullScreen
        self.present(configVC, animated: false)
        
    }
    
    func starBatchAutoEdit(_ config: AutoEditConfig) {
        var allModels = self.viewModel.allMusicArray
        if UserInfoManager.shared.isFreeTrail {
            // 免费试用期间只处理10个文件
            allModels = Array(allModels.prefix(10))
        }
        
        guard allModels.count > 0 else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.isBatchEditing = true
        self.headMusictagView.state = .matching
        self.headMusictagView.updateProgress(curModel: allModels.first, completed: 1, total: allModels.count)
        let startTime = Date()
        
        self.tagEditor.batchEmbeddedMetadata(models: allModels, config: config) { [weak self] curModel, completed, total in
            self?.headMusictagView.updateProgress(curModel: curModel, completed: completed, total: total)
        } completion: { [weak self] completedModels, missingTagModels in
            
            let spentTime = Date().timeIntervalSince(startTime)
            let missTagModels = missingTagModels ?? []
            
            guard let wSelf = self else { return }
            
            // 更新头部和列表
            let totalCount = allModels.count
            let completeTagCount = totalCount - missTagModels.count
            
            wSelf.isBatchEditing = false
            wSelf.headMusictagView.state = .completed
            wSelf.headMusictagView.updateComplete(time: spentTime, completeTagCount: completeTagCount, misstagCount: missTagModels.count)
            wSelf.refreshDataAction()
            
            var autoEditFileCount = UserInfoManager.shared.autoEditFileCount
            autoEditFileCount += allModels.count
            UserInfoManager.shared.autoEditFileCount = autoEditFileCount
            
            // 进入完成页面
            let successVC = BatchEditSuccessController(spentTime: spentTime, totalCount: allModels.count, missingTagCount: missTagModels.count)
            successVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .overFullScreen
            self?.present(successVC, animated: false)
        }
    }
    
    // 取消队列
    func musicTopHeadViewDidClickCancel(topView: MusicTopBatchEditHeadView) {
        self.showTwoAlert(message: "Are you sure you want to cancel?".localStr()) { [weak self] () in
            self?.tagEditor.cancelBatchEmbeddedQueue()
            self?.headMusictagView.state = .normal
            self?.isBatchEditing = false
            self?.headMusictagView.matchingView.progressView.update(current: 0, total: 0)
            self?.view.makeToast(KakaError.youhaveCanceled.errorDescription)
        }
    }
    
    // 已完成，用户点击重置
    func musicTopHeadViewDidCompletReset(topView: MusicTopBatchEditHeadView) {
        self.headMusictagView.state = .normal
        self.isBatchEditing = false
        self.headMusictagView.matchingView.progressView.update(current: 0, total: 0)
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
        let tagVC = MusicTagEditorController(model)
        tagVC.onEditCallback = { [weak self] (newModel) in
            self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
        }
        self.navigationController?.pushViewController(tagVC, animated: true)
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
        self.moveToOtherPlaylist([model])
    }
    
    // 批量移动到其他文件夹
    func moveToOtherPlaylist(_ models: [MusicItemModel]) {
        guard !models.isEmpty else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        let playlist = SelectPlaylistController(selectType: .selectPlaylist)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            guard let wSelf = self else { return }
            
            let fileManager = FileManager.default
            
            // 遍历批量处理所有模型
            for model in models {
                do {
                    let downloadName = model.filePathName() + model.addPathExtension()
                    let targetURL = folderURL.appendingPathComponent(downloadName)
                    
                    try fileManager.moveItem(at: model.mediaPlayURL, to: targetURL)
                } catch {
                    debugPrint("❌移动文件失败: \(model.mediaPlayURL), error: \(error)")
                }
            }
            
            wSelf.stopEditBarClick()
            wSelf.headFolderView.updateLocal(folders: wSelf.viewModel.folderArray)
            wSelf.refreshDataAction()
        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }
    
    // 引导好评
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
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
                        
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
        let editAlertVC = UIAlertController(title: MusicActionType.title.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = folderURL.lastPathComponent
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
                                    
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

