//
//  PlayCacheViewController.swift
//  Mobie
//
//  Created by 张文 on 4/1/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import Combine
import NVActivityIndicatorView
import SafariServices

/// 播放缓存
class PlayCacheViewController: SuperViewController, DocumentFolderWatcherDelegate {
    
    deinit {
        self.fileWatcher.stopWatching()
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
        let size = loadingView.size.width
        loadingView.frame = CGRectMake((contentView.width - size) / 2, (contentView.height - size) / 2, size, size)
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = SettingCellItemType.cacheConfig.titleStr()
        
        self.navigationItem.rightBarButtonItem = self.moreBarItem
        
        self.loadingView.startAnimating()
        self.refreshDataAction()
        
        self.fileWatcher.startWatching()
                
        // 预加载尺寸
        MusicConfigManager.shared.$preDownloadSize
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.preDownloadSizeChanged()
            }.store(in: &cancellables)
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.preDownloadSizeChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
    }
    
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
        self.refreshDataAction()
    }
    
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        self.refreshDataAction()
    }
    
    @objc func refreshDataAction() {
        
        let tempURLArray = baseFileURL.readLocalSubFiles()
        
        // 用于存储所有已处理的音乐模型
        var modelArray = [MusicItemModel]()

        // 创建一个串行队列来确保对 modelArray 的访问是线程安全的
        let modelArrayQueue = DispatchQueue(label: "com.predownload.modelArrayQueue")

        // 创建一个调度组，用于同步任务完成
        let dispatchGroup = DispatchGroup()

        for fileURL in tempURLArray {
            // 进入调度组
            dispatchGroup.enter()

            // 使用并发队列来执行每个文件的元数据解析任务
            let operationQueue = DispatchQueue(label: "com.predownload.operationQueue", attributes: .concurrent)

            operationQueue.async {
                
                if fileURL.hasDirectoryPath {
                    // 不写入文件夹
                    dispatchGroup.leave()
                    return
                }
                
                if fileURL.isLRCFile() {
                    SandboxFileManager.shared.saveLrcFileToDocument(lrcPath: fileURL, handleType: .move)
                    dispatchGroup.leave()
                    return
                }
                
                let metaData: MetadataTagModel?
                        
                if FileManager.default.isReadableFile(atPath: fileURL.path) {
                    metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
                } else if fileURL.startAccessingSecurityScopedResource() {
                    defer {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                    
                    metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
                    
                } else {
                    metaData = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
                }
                
                let musicModel = fileURL.createMusicModel(handleType: .link, sourceType: .localFile, targetURL: self.baseFileURL, metadata: metaData)
                
                if FileManager.default.fileExists(atPath: musicModel.coverThumbnailURL().path) {
                    // 使用串行队列来保证对 modelArray 的线程安全
                    modelArrayQueue.async {
                        if AudioExtension.audioSuffixs.contains(musicModel.mediaPlayURL.pathExtension) {
                            modelArray.append(musicModel)
                        }
                        dispatchGroup.leave()
                    }
                } else {
                    SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: metaData?.coverArt) { imageURL in
                        // 使用串行队列来保证对 modelArray 的线程安全
                        modelArrayQueue.async {
                            if AudioExtension.audioSuffixs.contains(musicModel.mediaPlayURL.pathExtension) {
                                modelArray.append(musicModel)
                            }
                            dispatchGroup.leave()
                        }
                    } fail: { error in
                        // 使用串行队列来保证对 modelArray 的线程安全
                        modelArrayQueue.async {
                            if AudioExtension.audioSuffixs.contains(musicModel.mediaPlayURL.pathExtension) {
                                modelArray.append(musicModel)
                            }
                            dispatchGroup.leave()
                        }
                    }
                }

            }
        }

        self.parserManager.addOperation {
            dispatchGroup.wait() // 等待所有任务完成
            // 所有任务完成后进行的处理
        }

        // 所有任务完成后调用 completion
        dispatchGroup.notify(queue: .main) { [weak self] () in
            guard let wSelf = self else { return }
            self?.cacheFolderSize = URL.formatFileSize(wSelf.baseFileURL.totalFileSize())
            self?.cacheArray = modelArray.sorted { model1, model2 in
                // 获取文件属性
                let attributes1 = try? FileManager.default.attributesOfItem(atPath: model1.mediaPlayURL.path)
                let attributes2 = try? FileManager.default.attributesOfItem(atPath: model2.mediaPlayURL.path)

                // 提取创建时间
                let creationDate1 = attributes1?[.creationDate] as? Date ?? Date.distantPast
                let creationDate2 = attributes2?[.creationDate] as? Date ?? Date.distantPast

                // 根据创建时间排序
                return creationDate1 > creationDate2
            }
            
            self?.loadingView.stopAnimating()
            self?.tableView.isHidden = false
            self?.tableView.reloadData()
        }
        
    }
    
    @objc func preDownloadSizeChanged() {
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    lazy var dataArray: [CacheGroupCellModel] = {
        let model1 = CacheGroupCellModel(group: .header, headTitle: nil, itemArray: [.header], footTitle: nil)
        let model2 = CacheGroupCellModel(group: .config, headTitle: nil, itemArray: [.cacheSwitch, .cacheSize, .cachePath], footTitle: nil)
        let model3 = CacheGroupCellModel(group: .caches, headTitle: "Cached Music".localStr(), itemArray: [], footTitle: nil)
        return [model1, model2, model3]
    }()
    
    var cancellables = Set<AnyCancellable>()
    
    lazy var cacheArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    lazy var parserManager: OperationQueue = {
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let manager = OperationQueue()
        manager.name = "com.predownload.operationQueue"
        manager.qualityOfService = .userInteractive
        manager.maxConcurrentOperationCount = Int(ceil(Double(cpuCount) / 2.0))
        
        return manager
    }()
    
    // MARK:  懒加载
    let baseFileURL = SandboxFileManager.shared.preDownloadURL()
    
    var cacheFolderSize: String = ""
    
    
    lazy var moreBarItem: UIBarButtonItem = {
        
        let moveAction = UIAction(title: "Move to Local".localStr(), image: UIImage(systemName: "move.3d"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] action in
            self?.moveToLocalAction()
        }
        let clearAction = UIAction(title: "Clear Cache".localStr(), image: UIImage(systemName: "trash"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] action in
            self?.clearCacheAction()
        }
        let libraryMenu = UIMenu(title: "", options: .displayInline, children: [moveAction, clearAction])
        
        let mainItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: libraryMenu)
        mainItem.accessibilityLabel = "More".localStr()
        return mainItem
    }()
    
    func clearCacheAction() {
        KakaCacheTools.finishCacheCompletion { [weak self] () in
            self?.cacheArray.removeAll()
            self?.tableView.reloadData()
            self?.refreshDataAction()
        }
    }
    
    // 将文件移动到本地库
    @objc func moveToLocalAction() {
        guard !cacheArray.isEmpty else {
            tableView.kaka_playShakeAnim()
            return
        }

        let tempArray = cacheArray
        let dispatchGroup = DispatchGroup()
        var movedItems: [MusicItemModel] = []

        for subModel in tempArray {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                do {
                    var targetURL = SandboxFileManager.shared.basePublicFileURL()
                    targetURL = targetURL.appendingPathComponent(subModel.mediaPlayURL.lastPathComponent)

                    try FileManager.default.moveItem(at: subModel.mediaPlayURL, to: targetURL)
                    DispatchQueue.main.async {
                        movedItems.append(subModel)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.view.makeToast(error.localizedDescription)
                    }
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            // 移除成功移动的项（通过对象而非索引）
            self.cacheArray.removeAll { model in
                movedItems.contains(model)
            }
            
            self.tableView.reloadData()
            
            self.navigationController?.popToRootViewController(animated: true)
            
        }
    }

        
    
    

    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.isHidden = true
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(CacheConfigHeadCell.self, forCellReuseIdentifier: "CacheConfigHeadCell")
        view.register(CacheConfigTableCell.self, forCellReuseIdentifier: "CacheConfigTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var fileWatcher: DocumentFolderWatcher = {
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
}

extension PlayCacheViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cellModel = dataArray[section]
        if cellModel.group == .header {
            return cellModel.itemArray.count
        }else if cellModel.group == .config {
            return cellModel.itemArray.count
        } else {
            return self.cacheArray.count > 0 ? self.cacheArray.count : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .header {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CacheConfigHeadCell", for: indexPath) as! CacheConfigHeadCell
            
            return cell
        }else if cellModel.group == .config {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CacheConfigTableCell", for: indexPath) as! CacheConfigTableCell
            cell.itemType = cellModel.itemArray[indexPath.row]
            return cell
        }else{
            if cacheArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                cell.delegate = self
                let model = self.cacheArray[indexPath.row]
                cell.update(musicModel: model, cellType: .none)
                cell.nameLabel.text = model.mediaPlayURL.lastPathComponent
                cell.descLabel.text = model.mediaPlayURL.fileSizeString
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
        let cellModel = dataArray[indexPath.section]
        
        if cellModel.group == .config {
            let itemType = cellModel.itemArray[indexPath.row]
            
            if itemType == .cachePath {
                UIPasteboard.general.string = SandboxFileManager.shared.preDownloadURL().path
                self.view.makeToast("Copied".localStr())
            }
        }
        
        if cellModel.group == .caches && self.cacheArray.count > 0 {
            
            if !UserInfoManager.shared.isVIP() {
                self.vipCenterClick()
                return
            }
            
            let musicModel = self.cacheArray[indexPath.row]
            if KakaMusicPlayer.shared.playingMusic == musicModel {
                KakaMusicPlayer.presentPlayController(fromVC: self)
            }else{
                KakaMusicPlayer.shared.startPlayMusic(musics: self.cacheArray, itemIndex: indexPath.row)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        if cellModel.group == .caches {
            return (cellModel.headTitle ?? "") + " - \(self.cacheFolderSize)"
        }else{
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return dataArray[section].footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .header {
            return UITableView.automaticDimension
        }else if cellModel.group == .config {
            return UITableView.automaticDimension
        } else {
            return self.cacheArray.count > 0 ? UITableView.automaticDimension : 150.ckValue()
        }
    }
    
}

extension PlayCacheViewController: MusicTableViewCellDelegate {
    // 点击更多
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        if action == .deleteItem {
            self.tableView.setEditing(false, animated: true)
            self.deleteMusicModel([model])
        }
        
        if action == .musictag {
            let tagVC = MusicTagEditorController(model)
            tagVC.onEditCallback = { [weak self] (editModel) in
                self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
            }
            self.navigationController?.pushViewController(tagVC, animated: true)
        }
        
        if action == .addPlaylist {
            let playlist = SelectPlaylistController(selectType: .navidromeList)
            playlist.onLocalBlock = { [weak self] (folderURL) in
                guard let wSelf = self else { return }
                do {
                    let downloadName = model.filePathName() + model.addPathExtension()
                    
                    let targetURL = folderURL.appendingPathComponent(downloadName)
                    try FileManager.default.moveItem(at: model.mediaPlayURL, to: targetURL)
                } catch {
                    wSelf.view.makeToast(error.localizedDescription)
                }
            }
            
            self.present(KakaNavigationController(rootViewController: playlist), animated: true)
        }
    }
    
    /// 3️⃣ 删除歌曲
    func deleteMusicModel(_ models: [MusicItemModel]) {
        
        self.showTwoAlert(message: "Files cannot be recovered after deletion.".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) {
            SandboxFileManager.shared.deleteMusicModels(models: models) { [weak self] result in
                switch result {
                case .success(let success):
                    for subModel in success {
                        if KakaMusicPlayer.shared.playingMusic == subModel {
                            KakaMusicPlayer.shared.playingMusic = nil
                            KakaMusicPlayer.shared.pause()
                            KakaMusicPlayer.shared.stop()
                        }
                        
                        KakaMusicPlayer.shared.removeOneMusicModel(subModel)
                    }
                    break
                case .failure(let failure):
                    self?.view.makeToast(failure.errorDescription)
                    break
                }
            }
        }
    }
}

// MARK: 配置信息
class CacheConfigTableCell: UITableViewCell {
    var itemType: CacheGroupCellItem? {
        didSet {
            guard let itemType = itemType else { return }
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            cellConfig.textProperties.color = .label
            cellConfig.secondaryTextProperties.color = .secondaryLabel
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            
            switch itemType {
            case .header:
                self.accessoryType = .none
                self.accessoryView = nil
            case .cacheSwitch:
                self.accessoryType = .none
                self.accessoryView = self.cacheSwitchView
            case .cacheSize:
                self.accessoryType = .none
                self.accessoryView = self.preDownloadView()
            case .cachePath:
                cellConfig.secondaryTextProperties.numberOfLines = 1
                cellConfig.secondaryTextProperties.lineBreakMode = .byTruncatingMiddle
                cellConfig.secondaryText = SandboxFileManager.shared.preDownloadURL().path(percentEncoded: false)
                self.accessoryType = .none
                self.accessoryView = nil
            }
            
            self.contentConfiguration = cellConfig
        }
    }
    
    lazy var cacheSwitchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.isOn = MusicConfigManager.shared.isPreDownload
        view.addTarget(self, action: #selector(switchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func switchViewClick(_ sender: UISwitch) {
        MusicConfigManager.shared.isPreDownload = sender.isOn
    }
    
    func preDownloadView() -> UIView {
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.preDownloadMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = MusicConfigManager.shared.preDownloadSize.formatStr()
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    
    func preDownloadMenu() -> UIMenu {
        let appearArray: [PreDownloadSize] = [.GB2, .GB4, .GB8, .GB16, .GB32, .GB64]
        var actionArray = [UIAction]()
        for subType in appearArray {
            let isOne = MusicConfigManager.shared.preDownloadSize == subType
            let action = UIAction(title: subType.formatStr(), image: nil, state: isOne ? .on : .off, handler: { _ in
                MusicConfigManager.shared.preDownloadSize = subType
            })
            actionArray.append(action)
        }
        
        let menu = UIMenu(title: CacheGroupCellItem.cacheSize.titleStr(), children: actionArray)
        return menu
    }
    
}

// MARK: 头部Cell
class CacheConfigHeadCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(starImgView)
        contentView.addSubview(descLabel)
    }
    
    func preSetupContains() {
        var height = 180.ckValue()
        switch kaka_osType() {
        case .iOS: height = 100
        case .iPadOS: height = 200
        case .macOS: height = 100
        }
        
        let value = starImgView.image!.size.width / starImgView.image!.size.height
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(height)
            make.width.equalTo(starImgView.snp.height).multipliedBy(value)
        }
        
        descLabel.snp.makeConstraints { make in
            make.top.equalTo(starImgView.snp.bottom).offset(10.ckValue())
            make.leading.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-10.ckValue())
        }
    }
    
    func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
        
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: SettingCellItemType.cacheConfig.cellImage())
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.text = CacheGroupCellItem.header.titleStr()
        view.font = kaka_IsMacOS() ? UIFontLight(15) : UIFontBold(15.ckValue())
        view.textColor = kaka_IsMacOS() ? .label : .secondaryLabel
        return view
    }()
    
}
