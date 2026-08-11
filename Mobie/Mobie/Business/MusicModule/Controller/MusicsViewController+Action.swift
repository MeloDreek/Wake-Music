//
//  MusicsViewController+Action.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/2/3.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import ProgressHUD
import KakaTaglibKit
import Kingfisher


extension MusicsViewController {
    
    // 设置左右元素
    @objc func setupNavigationItem() {
                           
        if self.tableView.isEditing {
            self.navigationItem.rightBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(stopEditBarClick))]
            let item1 = UIBarButtonItem(title: "Select All".localStr(), style: .plain, target: self, action: #selector(selectAllBarClick))
            let item2 = UIBarButtonItem(title: "Deselect All".localStr(), style: .plain, target: self, action: #selector(deSelectAllBarClick))
            self.navigationItem.leftBarButtonItems = [item1, item2]
        }else{
            if kaka_IsMacOS() {
                self.navigationItem.leftBarButtonItems = nil
                self.navigationItem.rightBarButtonItems = [self.moreBarItem(), self.importBarItem()]
            }else{
                let isBaseDoc = !self.viewModel.isBaseDoc
                let isVIP = UserInfoManager.shared.isVIP()
                let isOffer = DiscountIAPManager.shared.isShowDiscount()
                if isBaseDoc || isVIP {
                    self.navigationItem.leftBarButtonItems = nil
                }else{
                    self.navigationItem.leftBarButtonItems = isOffer ? [self.premiumBarItem] : nil
                }
                
                self.navigationItem.rightBarButtonItems = [self.moreBarItem(), self.importBarItem()]
            }
        }

        self.selectCountItem.title = "\(self.viewModel.selectArray.count)"
    }
    
    // 开始编辑模式
    @objc func startEditBarClick() {
        if self.isNoneMusic {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.viewModel.selectArray.removeAll()
        self.tableView.setEditing(true, animated: !kaka_IsMacOS())
        
        self.perform(#selector(setupNavigationItem), with: nil, afterDelay: 0.5)

        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
            tabbarVC.tabBar.isHidden = true
            tabbarVC.toolbarView.isHidden = true
            tabbarVC.floatingView.isHidden = true
            self.navigationItem.titleView = UIView()
        }
        
        if let splitVC = self.splitViewController as? MacTabbarViewController {
            splitVC.toolbarView.isHidden = true
            self.navigationItem.titleView = UIView()
            self.navigationItem.searchController = nil
        }
        
        self.view.addSubview(deleteToolBar)
    }
    
    // 结束编辑模型
    @objc func stopEditBarClick() {
        self.viewModel.selectArray.removeAll()
        self.tableView.setEditing(false, animated: !kaka_IsMacOS())
        
        self.perform(#selector(setupNavigationItem), with: nil, afterDelay: 0.5)
                
        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
            tabbarVC.tabBar.isHidden = false
            tabbarVC.localMusicCountChanged()
            self.navigationItem.titleView = nil
        }
        
        if let splitVC = self.splitViewController as? MacTabbarViewController {
            splitVC.toolbarView.isHidden = false
            self.navigationItem.titleView = nil
            self.navigationItem.searchController = self.searchController
        }
        
        self.deleteToolBar.removeFromSuperview()
    }
    
    @objc func selectAllBarClick() {
        self.viewModel.selectArray = self.viewModel.allMusicArray.map({ subModel in
            var tempModel = subModel
            tempModel.isSelected = true
            return tempModel
        })
        
        for subIndexPath in self.getAllIndexPaths() {
            self.tableView.selectRow(at: subIndexPath, animated: false, scrollPosition: .none)
        }
                
        let selectTitle = "\(self.viewModel.selectArray.count)"
        self.selectCountItem.title = selectTitle
        
    }
    
    @objc func deSelectAllBarClick() {
        self.viewModel.selectArray.removeAll()
        
        for subIndexPath in self.getAllIndexPaths() {
            self.tableView.deselectRow(at: subIndexPath, animated: false)
        }
        
        let selectTitle = "\(self.viewModel.selectArray.count)"
        self.selectCountItem.title = selectTitle
        
    }
    
    func getAllIndexPaths() -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        
        let numberOfSections = tableView.numberOfSections
        for section in 0..<numberOfSections {
            let numberOfRows = tableView.numberOfRows(inSection: section)
            for row in 0..<numberOfRows {
                let indexPath = IndexPath(row: row, section: section)
                indexPaths.append(indexPath)
            }
        }
        
        return indexPaths
    }
    
    // 从电脑端传输
    @objc func importfromWiFi() {
        
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "PC"])
        
        let scanVC = GCDWebServerController(self.viewModel)
        let navVC = KakaNavigationController(rootViewController: scanVC)
        navVC.modalPresentationStyle = .fullScreen
        self.present(navVC, animated: true)
    }
    
    // 视频转音乐
    @objc func importFromVideo() {
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "Conveter_App"])
        
        let convertVC = VideoConverterViewController(viewModel: self.viewModel)
        let nacVC = KakaNavigationController(rootViewController: convertVC)
        nacVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .fullScreen
        self.present(nacVC, animated: true)
    }
    
    // 扫描本地iTunes文件
    func scanDocumentFiles() {
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "Import_iTunes"])
        let scanVC = ScanUSBViewController(viewModel)
        let navVC = KakaNavigationController(rootViewController: scanVC)
        navVC.modalPresentationStyle = .fullScreen
        self.present(navVC, animated: true)
    }
    
    // 点击播放音乐
    func clickMusicItem(_ index: Int) {
        
        let allArray = self.viewModel.allMusicArray
        if allArray.count <= index { return }
        
        let clickModel = allArray[index]
        
        if !self.checkFileExist(clickModel) { return }
        
        let fileExtension = clickModel.mediaPlayURL.pathExtension.lowercased()
        if AudioExtension.forbiddenExtensions.contains(fileExtension) {
            let alertController = UIAlertController(title: fileExtension.uppercased(), message: "The current file is an exclusive encrypted audio, please use a third party tool to convert the format.".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
            let action1 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { (sender) in
                SandboxFileManager.shared.deleteMusicModels(models: [clickModel]) { [weak self] models in
                    self?.refreshDataAction()
                } fail: { [weak self] errorMsg in
                    self?.refreshDataAction()
                }

            }
            let action2 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
            
            alertController.addAction(action1)
            alertController.addAction(action2)
            
            action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
            action2.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
            
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        
        KakaMusicPlayer.shared.startPlayMusic(musics: allArray, itemIndex: index)
                
    }
    
    func checkFileExist(_ model: MusicItemModel) -> Bool {
        if FileManager.default.fileExists(atPath: model.mediaPlayURL.path) {
            return true
        }
        
        let alertController: UIAlertController = UIAlertController(title: "Reminder".localStr(), message: "File doesn't exist, do you delete it?".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { (sender) in
            SandboxFileManager.shared.deleteMusicModels(models: [model]) { [weak self] models in
                self?.refreshDataAction()
            } fail: { [weak self] errorMsg in
                self?.refreshDataAction()
            }

        }
        let action2 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        
        action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.present(alertController, animated: true, completion: nil)
        return false
    }
    
    // 分享
    @objc func shareItemsAction() {
        if self.viewModel.selectArray.count == 0 {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.shareMusicModel(self.viewModel.selectArray)
    }
    
    // 定位到当前播放cell
    @objc func locationPlayingCell() {
        guard let model = KakaMusicPlayer.shared.playingMusic else { return }
        guard let playingIndex = self.viewModel.findMusicIndexPath(model) else { return }
        
        self.tableView.scrollToRow(at: playingIndex, at: .middle, animated: true)
    }
}

extension MusicsViewController {
    
    // 处理音乐编辑
    func handleEditMusic(_ actionType: MusicActionType) {
        
        if actionType == .coverArt {
            self.modifyCoverImageAction(editStyle: .select)
        }
        
        if actionType == .title {
            if self.viewModel.selectArray.count > 1 {
                self.view.makeToast("The title is unique and does not support batch editing".localStr())
                return
            }
            
            if let firstModel = self.viewModel.selectArray.first {
                self.editSongTitleAction(oldModel: firstModel)
            }
        }
        
        if actionType == .artist {
            self.editArtistAction(models: self.viewModel.selectArray)
        }
        
        if actionType == .album {
            self.editAlbumNameAction(models: self.viewModel.selectArray)
        }
        
    }
    
    // 预览歌词库
    func previewLyricLibrary() {
        let lyricVC = LyricListViewController(isSelect: false)
        let navVC = KakaNavigationController(rootViewController: lyricVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 0️⃣ 修改封面图
    func modifyCoverImageAction(editStyle: CoverGalleryStyle) {
        
        if !UserInfoManager.shared.isVIP() && editStyle != .preview {
            self.vipCenterClick()
            return
        }
        
        let coverVC = CoverGalleryViewController(editStyle: editStyle)
        let navVC = KakaNavigationController(rootViewController: coverVC)
        coverVC.onSelectCallback = { [weak self] (releaseModel) in
            if let coverImage = releaseModel.tempImage {
                self?.editCoverImage(coverImage)
            }
        }
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
        
    }

    
    // 1️⃣ 修改歌名
    func editSongTitleAction(oldModel: MusicItemModel) {
        
        var editModel = oldModel
        
        let editAlertVC = UIAlertController(title: MusicActionType.title.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = oldModel.showTitleName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            
            let success = SandboxFileManager.shared.updateTitleTag(oldModel: oldModel, newTitle: nameText)
            if success {
                
                editModel.title = nameText
                
                self?.view.makeToast("Embedded Success".localStr())
                self?.stopEditBarClick()
                
                if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = editModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: editModel, oldFileName: oldModel.filePathName())
                
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 2️⃣ 编辑歌手名
    func editArtistAction(models: [MusicItemModel]) {
        
        let editAlertVC = UIAlertController(title: MusicActionType.artist.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = models.count == 1 ? models.first?.showArtistName() : nil
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            let operationQueue = OperationQueue() // 创建一个操作队列
            operationQueue.maxConcurrentOperationCount = 1 // 设置为串行队列，只有一个任务可以同时执行

            ProgressHUD.animate("Processing...".localStr())

            nameText = nameText.replaceChar(oldChar: "/", newChar: " ")

            for oldModel in models {
                // 使用 BlockOperation 包装每个操作
                let operation = BlockOperation {
                    var editModel = oldModel
                    editModel.artist = nameText
                    
                    let success = SandboxFileManager.shared.updateArtistTag(oldModel: oldModel, newArtist: nameText)
                    if success {
                        if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                            KakaMusicPlayer.shared.playingMusic = editModel
                        }
                        
                        KakaMusicPlayer.shared.updateOneMusicModel(newModel: editModel, oldFileName: oldModel.filePathName())
                    }
                    
                }
                
                // 这个操作完成时的回调
                operation.completionBlock = {
                    // 可以在这里执行一些收尾操作，例如离开 group、更新 UI 等
                    if operationQueue.operations.allSatisfy({ $0.isFinished }) {
                        DispatchQueue.main.async { [weak self] in
                            guard let wSelf = self else { return }
                            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
                            wSelf.stopEditBarClick()
                            ProgressHUD.succeed("Embedded Success".localStr())
                        }
                    }
                }
                
                operationQueue.addOperation(operation) // 将操作加入队列
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 3️⃣ 编辑专辑名
    func editAlbumNameAction(models: [MusicItemModel]) {
        
        let editAlertVC = UIAlertController(title: MusicActionType.album.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = models.count == 1 ? models.first?.album : nil
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            guard let wSelf = self else { return }
            var editArray = [MusicItemModel]()

            // 创建一个串行队列来同步访问 metadataParser
            ProgressHUD.animate("Processing...".localStr())
            let serialQueue = DispatchQueue(label: "com.album.metadataQueue")

            // 使用队列处理模型，确保 metadataParser 操作是串行的
            for oldModel in models {
                var editModel = oldModel
                editModel.album = nameText
                
                // 将 metadataParser 操作放入串行队列中，确保线程安全
                serialQueue.async {
                    let success = TaglibMetadataParser.setAlbum(nameText, toFileURL: oldModel.mediaPlayURL)
                    editModel.album = success ? nameText : oldModel.album
                    debugPrint("标签元数据 = \(success)")

                    if success {
                        KakaMusicPlayer.shared.updateOneMusicModel(newModel: editModel, oldFileName: oldModel.filePathName())
                    }
                    // 在串行队列中修改完 metadata 后，将 editModel 添加到编辑数组
                    DispatchQueue.main.async {
                        editArray.append(editModel)
                    }
                }
            }
            
            NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            wSelf.stopEditBarClick()
            ProgressHUD.succeed("Embedded Success".localStr())
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    
    /// 3️⃣ 删除歌曲
    func deleteMusicModel(_ models: [MusicItemModel]) {
        self.tableView.setEditing(false, animated: true)
        self.showTwoAlert(title: "Reminder".localStr(), message: "Unable to recover after deletion".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) {
            SandboxFileManager.shared.deleteMusicModels(models: models) { [weak self] models in
                guard let wSelf = self else { return }
                for subModel in models {
                    if KakaMusicPlayer.shared.playingMusic == subModel {
                        KakaMusicPlayer.shared.stop()
                        KakaMusicPlayer.shared.playingMusic = nil
                        
                        KakaMusicPlayer.shared.playingMusic = MusicItemModel.demoMusicModel()
                    }
                    
                    KakaMusicPlayer.shared.removeOneMusicModel(subModel)
                }
                self?.refreshDataAction()
                wSelf.stopEditBarClick()
            } fail: { [weak self] errorMsg in
                self?.view.makeToast(errorMsg)
            }
        }
    }
    
    // 4️⃣ 分享歌曲
    func shareMusicModel(_ models: [MusicItemModel]) {
                
        let urlArray = models.map { $0.mediaPlayURL }
                        
        let shareVC = UIActivityViewController(activityItems: urlArray, applicationActivities: nil)
        shareVC.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
            if completed {
                if let activityType = activityType {
                    AnalyticsManager.shared.logEvent("share_music", parameters: ["shareType": activityType.rawValue, "musics": models.count])
                }
            } else {
                AnalyticsManager.shared.logEvent("musics_cancel_share")
            }
                        
        }
        if !kaka_IsiPhone() {
            shareVC.popoverPresentationController?.sourceView = self.navigationController?.navigationBar
        }
        self.present(shareVC, animated: true, completion: nil)
    }
    
        
}
