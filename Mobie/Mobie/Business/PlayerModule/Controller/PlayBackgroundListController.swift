//
//  PlayBackgroundListController.swift
//  Mobie
//
//  Created by 张文 on 5/20/25.
//

import KakaFoundation
import SmartCodable
import AppGroupKit
import PanModal
import KakaPhotoBrowser
import StoreKit
import KakaObjcKit
import Kingfisher
import SafariServices

/// 选择播放器背景。设置组、默认、
class PlayBackgroundListController: SuperViewController {
    
    deinit {
        
        ImageCache.default.clearMemoryCache()

#if !DEBUG
        if self.isChanged && self.currentViewController() is MusicPlayerViewController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
#endif
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = "Player background".localStr()
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cancelButtonClick))
        }
        
        self.navigationItem.rightBarButtonItem = self.addItem
        
        self.perform(#selector(refreshDataAction), with: nil, afterDelay: 0.1)
        
        self.perform(#selector(showAirPlayTips), with: nil, afterDelay: 1)
    }
    
    @objc func refreshDataAction() {
        self.modelArray.removeAll()

                        
        self.modelArray.append(contentsOf: self.customArray())
        self.modelArray.append(contentsOf: self.systemArray())
        
        self.tableView.reloadData()
    }
   
    
    

    
    @objc func showAirPlayTips() {
        
        if AppLocalManager.shared.isShowCustomBg {
            return
        }
                
        let popView = CMPopTipView(message: "Customize wallpaper".localStr())
        popView?.hasShadow = true
        popView?.has3DStyle = false
        popView?.borderColor = UIColor.white
        popView?.dismissTapAnywhere = true
        popView?.backgroundColor = appMainColor
        popView?.textColor = UIColor.deAccent
        popView?.presentPointing(at: self.addItem, animated: true)
        
        AppLocalManager.shared.isShowCustomBg = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { [weak self] context in
            self?.tableView.reloadData()
        } completion: {  context in
            
        }
    }
    
    // MARK:  GET && SET
    var isChanged: Bool = false
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PlayBackDefaultTableCell.self, forCellReuseIdentifier: "PlayBackDefaultTableCell")
        view.register(PlayBackCoverTableCell.self, forCellReuseIdentifier: "PlayBackCoverTableCell")
        return view
    }()
    
    lazy var addItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .done, target: self, action: #selector(uploadCustomBackground))
        return item
    }()
    
    lazy var settingArray: [PlayBackgroundEffect] = {
        return [.gaussianBlur, .coverAssetColor, .translucencyMask, .showAlphaMask]
    }()
    
    let defaultModel = PlayBackgroundModel(backgroundType: .defaultType, backgroundName: "", backgroundConfig: .coverAssetColor, isShowAlphaMask: false)
    
    lazy var modelArray: [PlayBackgroundModel] = {
        return [PlayBackgroundModel]()
    }()
    
    func customArray() -> [PlayBackgroundModel] {
        let subFiles = SandboxFileManager.shared.customPlayerbackURL().readLocalSubFiles()
        var tempArray = [PlayBackgroundModel]()
        for subFile in subFiles {
            let subModel = PlayBackgroundModel(backgroundType: .customType, backgroundName: subFile.lastPathComponent, backgroundConfig: .translucencyMask, isShowAlphaMask: false)
            tempArray.append(subModel)
        }
        return tempArray
    }
    
    func systemArray() -> [PlayBackgroundModel] {
        let subFiles: [PlayBackgroundSystem] = [.style1, .style2, .style3, .style4, .style5, .style6, .style7, .style8, .style9, .style10, .style11, .style12, .style13, .style14]
        var tempArray = [PlayBackgroundModel]()
        for subFile in subFiles {
            let subModel = PlayBackgroundModel(backgroundType: .systemType, backgroundName: subFile.systemImageName(), backgroundConfig: .translucencyMask, isShowAlphaMask: false)
            tempArray.append(subModel)
        }
        return tempArray
    }
}

extension PlayBackgroundListController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? settingArray.count : 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlayBackDefaultTableCell", for: indexPath) as! PlayBackDefaultTableCell
            cell.playBackConfig = settingArray[indexPath.row]
            return cell
        }else{
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "PlayBackDefaultTableCell", for: indexPath) as! PlayBackDefaultTableCell
                cell.backgroundModel = self.defaultModel
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "PlayBackCoverTableCell", for: indexPath) as! PlayBackCoverTableCell
                cell.modelArray = self.modelArray
                cell.onClickCallback = { [weak self] (curModel) in
                    self?.selectbackground(curModel)
                }
                cell.onDeleteCallback = { [weak self] (curModel) in
                    self?.deleteCustomWallpaper(curModel)
                }
                cell.onPreviewCallback = { [weak self] (curModel, coverCell) in
                    guard let wSelf = self else { return }
                    let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
                    let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
                    photoBrowser.backgroundStyle = .blurPhoto
                    photoBrowser.show(from: wSelf)
                }
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            let subEffect = settingArray[indexPath.row]
            if subEffect == .showAlphaMask { return }
            
            if subEffect != .gaussianBlur && !UserInfoManager.shared.isVIP() {
                self.vipCenterClick()
                return
            }
            
            var curModel = MusicConfigManager.shared.playbackModel
            curModel.backgroundConfig = subEffect
            if curModel.backgroundConfig == .coverAssetColor {
                curModel.backgroundType = .defaultType
                curModel.backgroundName = nil
            }
            
            MusicConfigManager.shared.playbackModel = curModel
            
            self.isChanged = true
            self.tableView.reloadData()
        }
        
        if indexPath.section == 1 && indexPath.row == 0 {
            self.selectbackground(self.defaultModel)
        }
    }
    
    // 选中
    func selectbackground(_ model: PlayBackgroundModel) {
        
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        let oldConfig = MusicConfigManager.shared.playbackModel.backgroundConfig
        var newModel = model
        newModel.isShowAlphaMask = MusicConfigManager.shared.playbackModel.isShowAlphaMask
        newModel.backgroundConfig = model.backgroundType == .customType ? .translucencyMask : oldConfig
        MusicConfigManager.shared.playbackModel = newModel
        self.isChanged = true
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Preferences".localStr() : "Customize wallpaper".localStr()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return UITableView.automaticDimension
        }else{
            if indexPath.row == 0 {
                return UITableView.automaticDimension
            }else{
                let itemSpace = PlayBackCoverTableCell.itemSpace
                let totalWidth = contentView.bounds.width - 40 - itemSpace * 3
                let cellWidth = (totalWidth / 2) - 1
                let cellHeight = kaka_IsMacOS() ? cellWidth * 0.5625 : cellWidth / 0.75

                let itemCount = CGFloat(self.modelArray.count)
                let rowCount = (itemCount + 1) / 2 + (itemCount.truncatingRemainder(dividingBy: 2) == 0 ? 0 : 1) // 判断是否整除

                return rowCount * cellHeight + itemSpace
            }
        }
    }
    
    // 删除自定义壁纸
    func deleteCustomWallpaper(_ model: PlayBackgroundModel) {
        self.showTwoAlert(title: "Reminder".localStr(), message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) { [weak self] () in
            let filePathURL = SandboxFileManager.shared.customPlayerbackURL().appendingPathComponent(model.backgroundName ?? "")
            do {
#if targetEnvironment(macCatalyst)
                try? FileManager.default.trashItem(at: filePathURL, resultingItemURL: nil)
#else
                try? FileManager.default.removeItem(at: filePathURL)
#endif
                if model.backgroundName == MusicConfigManager.shared.playbackModel.backgroundName {
                    var newModel = MusicConfigManager.shared.playbackModel
                    newModel.backgroundType = .defaultType
                    
                    MusicConfigManager.shared.playbackModel = newModel
                }
                self?.refreshDataAction()
            } catch {
                self?.view.makeToast(error.localizedDescription)
            }
        }
    }
    
}
