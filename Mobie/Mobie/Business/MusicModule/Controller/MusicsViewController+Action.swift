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
            let alertController = UIAlertController(title: fileExtension.uppercased(), message: "This is a proprietary encrypted audio file. Please use a third-party tool to convert it to another format.".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
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
        
        let alertController: UIAlertController = UIAlertController(title: "Reminder".localStr(), message: "File not found. Would you like to delete it?".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
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
    
    // 预览歌词库
    func previewLyricLibrary() {
        let lyricVC = LibraryLyricsViewController(isSelect: false)
        let navVC = KakaNavigationController(rootViewController: lyricVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 预览封面库
    func previewArtworkLibrary() {
        let coverVC = LibraryCoverViewController(editStyle: .preview)
        let navVC = KakaNavigationController(rootViewController: coverVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    /// 3️⃣ 删除歌曲
    func deleteMusicModel(_ models: [MusicItemModel]) {
        self.showTwoAlert(title: "Reminder".localStr(), message: "Files cannot be recovered after deletion.".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) {
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
