//
//  DownloadViewController.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import AppGroupKit
import Combine

/// 下载列表
class DownloadViewController: SuperViewController {
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
        self.title = "Download".localStr()
        DownloadManager.shared.activateDownloads()
        DownloadManager.shared.downloadUpdates
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.updateRightBarItem()
                self?.tableView.reloadData()
            }.store(in: &cancellables)
        
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.refreshDataAction()
            }.store(in: &cancellables)
        
        self.updateRightBarItem()
        self.refreshDataAction()
        
#warning("模拟mock数据")
//#if DEBUG
//        var testArray = [MusicItemModel]()
//        for i in 0..<66 {
//            let subGenre = MusicGenreType.allGenreArray().randomElement() ?? MusicGenreType.pop
//            let subExtension = AudioExtension.audioSuffixs.randomElement()?.lowercased() ?? "dsf"
//            
//            var model = MusicItemModel(fileURL: SandboxFileManager.shared.basePublicFileURL().appendingPathComponent("\(subGenre.formatStr()).\(subExtension)"), sourceType: .localFile)
//            model.title = "Wakemusic".localStr() + " \(i)." + subExtension
//            model.artist = "From".localStr() + " " + ImportFileType.fromGoogleDrive.titleStr()
//            model.coverArt = subGenre.iconImage()
//            testArray.append(model)
//        }
//        
//        DownloadManager.shared.taskArray = testArray
//#endif
    }
    
    @objc func dismissItemAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    func updateRightBarItem() {
        if self.isPresent() && !kaka_IsMacOS() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissItemAction))
        }
        
        self.navigationItem.rightBarButtonItem = DownloadManager.shared.downloadsRunning ? self.stopDownloadItem : self.downloadBarItem
    }
    
    @objc func stopDownloadAction() {
        DownloadManager.shared.pauseDownloads()
        self.updateRightBarItem()
    }
    
    @objc func refreshDataAction() {
        self.dataArray = DownloadManager.shared.taskArray
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
            self.kaka_header.endRefreshing()
            self.tableView.tableHeaderView = (self.dataArray.isEmpty || !kaka_IsMacOS()) ? nil : self.headView
            self.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                        
        let scrollEdgeAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        scrollEdgeAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
        self.navigationController?.navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        
        let compactAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        compactAppearance.configureWithOpaqueBackground() // 不透明，纯色
        self.navigationController?.navigationBar.compactAppearance = compactAppearance
        
        let standardAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        standardAppearance.configureWithDefaultBackground()  // 默认透明色
        self.navigationController?.navigationBar.standardAppearance = standardAppearance
        
        // 配合contentInsetAdjustmentBehavior实现完成透明
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.navigationBar.barTintColor = .clear
        
        if kaka_safeAreaInsets().top > 20 || kaka_IsiPad() {
            self.navigationController?.navigationBar.prefersLargeTitles = true
            self.navigationItem.largeTitleDisplayMode = .automatic
        }else{
            self.navigationController?.navigationBar.prefersLargeTitles = false
            self.navigationItem.largeTitleDisplayMode = .never
        }
        
        self.refreshDataAction()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
            tabbarVC.updateDownloadCount()
        }
    }
    
    // MARK:  GET && SET
    
    
    var cancellables = Set<AnyCancellable>()
    
    
    lazy var dataArray: [MusicItemModel] = {
        return DownloadManager.shared.taskArray
    }()
    
    lazy var selectArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.tableHeaderView = (self.dataArray.isEmpty || !kaka_IsMacOS()) ? nil : self.headView
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(EmptyTableViewCell.self, forCellReuseIdentifier: "EmptyTableViewCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        let iconImage = UIImage(systemName: "arrow.down.circle")
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 100
        }
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height * 1.5))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: iconImage)
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(height)
        }
        return view
    }()
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var downloadBarItem: UIBarButtonItem = {
        let selectItem = UIBarButtonItem(title: "Download".localStr(), style: .plain, target: self, action: #selector(startDownloadClick))
        return selectItem
    }()
    
    lazy var stopDownloadItem: UIBarButtonItem = {
        let selectItem = UIBarButtonItem(image: UIImage(systemName: "stop.circle.fill"), style: .plain, target: self, action: #selector(stopDownloadAction))
        return selectItem
    }()
    
}

extension DownloadViewController: UITableViewDataSource, UITableViewDelegate, EmptyContentCellDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count == 0 ? 1 : dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard dataArray.count > 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyTableViewCell", for: indexPath) as! EmptyTableViewCell
            cell.delegate = self
            cell.messaleLabel.text = "Download music from your cloud drive or server for the best offline listening experience.".localStr()
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
        let model = dataArray[indexPath.row]
        cell.update(musicModel: model, cellType: .download)
        cell.delegate = self
        if let progress = DownloadManager.shared.downloadProgress(for: model) {
            let indicator = CircleProgressView(frame: CGRect(x: 0, y: 0, width: 30.ckValue(), height: 30.ckValue()))
            indicator.progress = progress
            cell.accessoryView = indicator
        } else if let error = DownloadManager.shared.downloadError(for: model) {
            let indicator = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))
            indicator.tintColor = .systemOrange
            indicator.accessibilityLabel = error
            cell.accessoryView = indicator
        }
#warning("模拟mock数据")
//        #if DEBUG
//        cell.loadingBgView.isHidden = true
//        
//        var allGenre = MusicGenreType.allCases
//        allGenre.removeLast()
//        let genreType = allGenre.reversed()[indexPath.row]
//        cell.coverImgView.image = genreType.iconImage()
//        cell.nameLabel.text = genreType.formatStr() + "." +  AudioFormatEnum.allCases.randomElement()!.rawValue.lowercased()
//        cell.descLabel.text = PhoneSetManager.formatLanguage() == .chinese_simplified ? ImportFileType.fromBaiduDrive.titleStr() : ImportFileType.fromGoogleDrive.titleStr()
//        #endif
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
#warning("模拟mock数据")
//        #if DEBUG
//        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
//            tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//        }
//        return
//        #endif
        
        guard self.dataArray.indices.contains(indexPath.row) else {
            return
        }
        
        let model = dataArray[indexPath.row]
        guard requireRemoteConnectionAccess() else { return }
        if let error = DownloadManager.shared.downloadError(for: model) {
            showTwoAlert(message: error, confirm: "Retry".localStr()) {
                DownloadManager.shared.prioritizeDownload(model)
            }
        } else {
            DownloadManager.shared.prioritizeDownload(model)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard dataArray.count > 0 else {
            let navHeight = app_navHeight
            let tabHeight = self.tabBarController?.tabBar.bounds.height ?? 0
            
            let cellHeight = self.view.height - navHeight - kStatusBarHeight - tabHeight - 70.ckValue()
            return cellHeight
        }
        
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let totalSize = self.dataArray.map { $0.fileSize() }.reduce(0, +)
        let countStr = String(format: "%d songs".localStr(), self.dataArray.count)
        
        let headStr = countStr + " " + URL.formatFileSize(totalSize)
        
        return self.dataArray.count > 0 ? headStr : nil
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if dataArray.count == 0 { return nil }
        
        let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            guard let wSelf = self, wSelf.dataArray.indices.contains(indexPath.row) else {
                finish(false)
                return
            }
            // The automatic queue may finish/remove rows while this alert is open.
            let selectedModel = wSelf.dataArray[indexPath.row]
            
            let alertController = UIAlertController(title: "Reminder".localStr(), message: "Are you sure to delete it?".localStr(), preferredStyle: .alert)
            let action1 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { (sender) in
                self?.deleteDownloadItem(selectedModel)
                finish(true)
            }
            let action2 = UIAlertAction(title: "Delete All".localStr(), style: .destructive) { (sender) in
                DownloadManager.shared.taskArray = []
                self?.dataArray.removeAll()
                self?.tableView.reloadData()
                self?.stopDownloadAction()
                finish(true)
            }
            let action3 = UIAlertAction(title: "Cancel".localStr(), style: .cancel) { _ in finish(false) }
            
            alertController.addAction(action1)
            alertController.addAction(action2)
            alertController.addAction(action3)
            
            action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
            action2.setValue(UIColor.systemRed, forKey: "_titleTextColor")
            action3.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
            
            wSelf.present(alertController, animated: true, completion: nil)
            
        }
        deleteAction.image = Reasource.systemNamed("trash", color: .white)
        deleteAction.backgroundColor = UIColor.systemPink
                
        let actions = [deleteAction]
        return UISwipeActionsConfiguration(actions: actions)
    }
    
    func deleteDownloadItem(_ model: MusicItemModel) {
        self.dataArray = DownloadManager.shared.removeFromDownloads(model)
        self.tableView.tableHeaderView = (self.dataArray.isEmpty || !kaka_IsMacOS()) ? nil : self.headView
        self.tableView.reloadData()
    }
    
    // EmptyContentCellDelegate
    func emptyContentViewDidClickImport(cell: UIView) {
        self.importMusicClick()
    }
    
    func emptyContentViewDidClickFormats(cell: UIView) {
        let formatsVC = SupportTypeViewController()
        self.navigationController?.pushViewController(formatsVC, animated: true)
    }
    
    func importMusicClick() {
        let importVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: importVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
    }
    
}
