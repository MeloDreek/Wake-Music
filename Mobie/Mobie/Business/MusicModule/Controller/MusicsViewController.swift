//
//  MusicsViewController.swift
//  AppLock
//
//  Created by Kaka Inc. on 2024/1/2.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Kingfisher
import StoreKit
import KSPlayer
import Combine
import SafariServices

/// 图库 && 文件夹
class MusicsViewController: SuperViewController {
    
    deinit {
        if !self.viewModel.isBaseDoc {
            self.folderWatcher.stopWatching()
        }
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kLocalMusicChangedKey), object: nil)
    }
    
    public init(_ baseFilePath: URL) {
        super.init(nibName: nil, bundle: nil)
        self.baseFileURL = baseFilePath
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.title = self.viewModel.isBaseDoc ? (self.tabBarItem.title ?? KakaTabbarType.musics.formatStr()) : self.baseFileURL.lastPathComponent

        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        deleteToolBar.frame = CGRectMake(0, self.view.height - 49.ckValue() - kaka_safeAreaInsets().bottom, self.view.width, 49.ckValue())
        tableView.frame = contentView.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
                
        self.configSearchBar()
        self.addNotificationEvent()
        self.refreshDataAction()
        self.perform(#selector(setupNavigationItem), with: nil, afterDelay: 1)
                
        self.folderWatcher.startWatching()
    }
    
    @objc func refreshDataAction() {
        
        if self.isNoneMusic && !self.tableView.isDragging && (KakaMusicPlayer.shared.playingMusic?.fileSourceType != .demoFile) {
            self.tableView.tableHeaderView = nil
            self.tableView.tableFooterView = nil
            if let emptyCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EmptyTableViewCell {
                emptyCell.startRefreshData()
            }
        }
        
        self.viewModel.refreshMusicDataAction { [weak self] models in
            guard let self = self else { return }
            self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.isNoneMusic ? 0 : playingHeight, right: 0)
            self.tableView.tableHeaderView = self.isShowHeadView ? self.headView : nil
            self.tableView.tableFooterView = self.isNoneMusic ? nil : self.footView
            
            if self.viewModel.isBaseDoc {
                self.headView.updateLocal(folders: self.viewModel.folderArray)
            }
            
            self.footView.update(self.viewModel.baseFileURL)

            self.tableView.separatorStyle = self.isNoneMusic ? .none : .singleLine
            self.tableView.reloadData()
            
            if let lastModel = KakaMusicPlayer.shared.playingMusic, lastModel.isLocalFile() {
                if lastModel.isLocalFile() {
                    if self.viewModel.isBaseDoc && !KakaMusicPlayer.shared.isPlaying {
                        // 仅仅是为了程序首次进来后可以有播放列表和当前音乐
                        KakaMusicPlayer.shared.playingMusic = models.first(where: { $0 == lastModel }) ?? MusicItemModel.demoMusicModel()
                        let sortedArray = models.filter({ $0.mediaPlayURL.isSupportMusicFile(false) }).sorted(by: { element1, element2 in
                            return element1.sortAnotherModel(model2: element2, sortType: MusicConfigManager.shared.sortType)
                        })
                        
                        KakaMusicPlayer.shared.musicArray = sortedArray
                        KakaMusicPlayer.shared.tempMusicArray = sortedArray
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] () in
                if let emptyCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EmptyTableViewCell {
                    emptyCell.stopRefreshData()
                }
                
                self?.kaka_header.endRefreshing()
            }
        } fail: { [weak self] errorMsg in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] () in
                if let emptyCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EmptyTableViewCell {
                    emptyCell.stopRefreshData()
                }
                
                self?.kaka_header.endRefreshing()
            }
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
        
        self.setupNavigationItem()
    }
    
    // MARK:  GET && SET
    var baseFileURL: URL!
    
    var cancellables = Set<AnyCancellable>()
            
    // MARK:  懒加载
        
    lazy var viewModel: MusicViewModel = {
        let vm = MusicViewModel(self.baseFileURL)
        return vm
    }()
    
    lazy var folderWatcher: DocumentFolderWatcher = {
        let watcher = DocumentFolderWatcher(self.baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.tableHeaderView = self.headView
        view.tableFooterView = self.footView
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(EmptyTableViewCell.self, forCellReuseIdentifier: "EmptyTableViewCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var headView: MusicTopHeadView = {
        let view = MusicTopHeadView(frame: CGRectMake(0, 0, contentView.width, MusicTopHeadView.cellSize().height))
        view.delegate = self
        return view
    }()
    
    lazy var footView: MusicsFootView = {
        let view = MusicsFootView(frame: CGRectMake(0, 0, self.view.width, 98.ckValue()))
        view.onCallback = { [weak self] (unSupportUrls) in
            let unsupportVC = UnsupportViewController(unSupportUrls)
            self?.navigationController?.pushViewController(unsupportVC, animated: true)
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
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()
    
    var isNoneMusic: Bool {
        get {
            let dataArray = self.viewModel.allMusicArray
            let isNone = dataArray.count == 0
            
            return isNone
        }
    }
    
    var isShowHeadView: Bool {
        get {
            // 列表有数据、首页
            let folderArray = self.viewModel.folderArray
            return folderArray.count > 0 && self.viewModel.isBaseDoc
        }
    }
    
    
    lazy var premiumBarItem: UIBarButtonItem = {
        let timerView = PremiumTimerView(frame: CGRectMake(0, 0, PremiumTimerView.maxWidth(), 30.ckValue()))
        timerView.onStopCallback = { [weak self] () in
            self?.navigationItem.leftBarButtonItems = nil
        }
        timerView.addTarget(self, action: #selector(vipCenterClick), for: .touchUpInside)
        
        let item = UIBarButtonItem(customView: timerView)
        item.style = .done
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        item.width = PremiumTimerView.maxWidth()
        return item
    }()
    
    
    

    
    func moreBarItem() -> UIBarButtonItem {
        // 选择
        let selectAction = UIAction(title: "Select".localStr(), image: kaka_IsMacOS() ? nil : UIImage(systemName: "checkmark.circle"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.startEditBarClick()
        })
        
        // 新建歌单
        let playlistAction = UIAction(title: "New Playlist".localStr(), image: UIImage(systemName: "folder.badge.plus"), identifier: nil, discoverabilityTitle: nil, attributes: [.destructive], state: .off, handler: { [weak self] _ in
            self?.newMusicFolder()
        })
        
        let playlistMenu = UIMenu(title: "", options: .displayInline, children: [playlistAction])
        
        // 封面库、歌词库
        let lyricAction = UIAction(title: MusicTopMode.lyricLibrary.titleStr(), image: MusicTopMode.lyricLibrary.iconImage(.label), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] action in
            self?.previewLyricLibrary()
        }
        let coverAction = UIAction(title: MusicTopMode.coverLibrary.titleStr(), image: MusicTopMode.coverLibrary.iconImage(.label), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] action in
            self?.previewArtworkLibrary()
        }
        let libraryMenu = UIMenu(title: "", options: .displayInline, children: [coverAction, lyricAction])
        
        let childrenArr = self.viewModel.isBaseDoc ? [selectAction, self.groupTypeMenu(), self.sorTypeMenu(), libraryMenu, playlistMenu] : [selectAction, self.groupTypeMenu(), self.sorTypeMenu(), libraryMenu]
        
        let allItemMune = UIMenu(title: "", children: childrenArr)
        let mainItem = UIBarButtonItem(image: Reasource.systemNamed("ellipsis.circle"), menu: allItemMune)
        mainItem.accessibilityLabel = "More".localStr()
        return mainItem
    }
    
    // 分组
    func groupTypeMenu() -> UIMenu {
        let groupArray: [GroupItemType] = GroupItemType.allCases
        var actionArray: [UIAction] = [UIAction]()
        
        for subGroup in groupArray {
            let isOn = subGroup == MusicConfigManager.shared.groupType
            let subMenu = UIAction(title: subGroup.formatStr(), image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: isOn ? .on : .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                if wSelf.isNoneMusic {
                    wSelf.tableView.kaka_playShakeAnim()
                    return
                }
                
                if subGroup != .nonGroup && wSelf.viewModel.allMusicArray.count > 300 {
                    wSelf.showTwoAlert(message: "Too many files! Building the index for grouped sorting may take a while.".localStr(), confirm: "Continue".localStr()) {
                        self?.viewModel.groupType = subGroup
                        MusicConfigManager.shared.groupType = subGroup
                        self?.setupNavigationItem()
                        self?.refreshDataAction()
                    }
                    return
                }
                
                self?.viewModel.groupType = subGroup
                MusicConfigManager.shared.groupType = subGroup
                self?.setupNavigationItem()
                self?.refreshDataAction()
            })
            
            actionArray.append(subMenu)
        }
                
        let sortMenu = UIMenu(title: "Group".localStr(), image: UIImage(systemName: "list.bullet"), children: actionArray)
        
        return sortMenu
    }
    
    // 排序方式
    func sorTypeMenu() -> UIMenu {
        let storageArray: [SortedbyType] = [.createDate, .modifyDate, .fileSize, .fileName]
        var actionArray: [UIAction] = [UIAction]()
        
        for subItem in storageArray {
            let isOn = subItem == MusicConfigManager.shared.sortType
            let subMenu = UIAction(title: subItem.formatStr(), image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: isOn ? .on : .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                if wSelf.isNoneMusic {
                    wSelf.tableView.kaka_playShakeAnim()
                    return
                }
                
                self?.viewModel.sortType = subItem
                MusicConfigManager.shared.sortType = subItem
                self?.setupNavigationItem()
                self?.refreshDataAction()
            })
            
            actionArray.append(subMenu)
        }
                
        let sortMenu = UIMenu(title: "", options: .displayInline, children: actionArray)
        
        let isSortAscending = MusicConfigManager.shared.isSortAscending
        let ascendingAction = UIAction(title: "Ascending".localStr(), image: kaka_IsMacOS() ? nil : (isSortAscending ? UIImage(systemName: "checkmark") : nil), identifier: nil, discoverabilityTitle: nil, attributes: [], state: kaka_IsMacOS() ? (isSortAscending ? .on : .off) : .off) { [weak self] action in
            MusicConfigManager.shared.isSortAscending = true
            self?.setupNavigationItem()
            self?.refreshDataAction()
        }
        
        let deAscendingAction = UIAction(title: "Descending".localStr(), image: kaka_IsMacOS() ? nil : (isSortAscending ? nil : UIImage(systemName: "checkmark")), identifier: nil, discoverabilityTitle: nil, attributes: [], state: kaka_IsMacOS() ? (isSortAscending ? .off : .on) : .off) { [weak self] action in
            MusicConfigManager.shared.isSortAscending = false
            self?.setupNavigationItem()
            self?.refreshDataAction()
        }
        
        let acendMenu = UIMenu(title: "", options: .displayInline, children: [ascendingAction, deAscendingAction])

        let mainMenu = UIMenu(title: "Sort By".localStr(), image: UIImage(systemName: "arrow.up.arrow.down"), children: [sortMenu, acendMenu])
        return mainMenu
    }
    
    // 导入方式
    func importBarItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(image: Reasource.systemNamed("plus"), style: .plain, target: self, action: #selector(importMusicClick))
        item.accessibilityLabel = "Import Music".localStr()
        return item
    }
    
    lazy var deleteToolBar: UIToolbar = {
        // 分享，已选择 88 项，更多
        let frame = CGRectMake(0, self.view.height - 49.ckValue() - kaka_safeAreaInsets().bottom, self.view.width, 49.ckValue())
        let view = UIToolbar(frame: frame)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        let shareItem = UIBarButtonItem(title: "Export".localStr(), style: .plain, target: self, action: #selector(shareItemsAction))
        let selectItem = self.selectCountItem
        let moreItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: self.editMoreMenu())
        
        let normalItems = [fixedSpace, shareItem,
                           flexibleSpace, selectItem,
                           flexibleSpace, moreItem,
                           fixedSpace]
        view.setItems(normalItems, animated: true)
        return view
    }()
    
    lazy var selectCountItem: UIBarButtonItem = {
        let title = "\(self.viewModel.selectArray.count)"
        let item = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
        item.tintColor = UIColor.label
        item.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        return item
    }()
    
    // 移动到歌单、删除
    func editMoreMenu() -> UIMenu {
        let editTypes: [MusicActionType] = [.addPlaylist, .deleteItem]
        var editArray = [UIAction]()

        for subItem in editTypes {
            let isDelete = subItem == .deleteItem
            let subMenu = UIAction(title: subItem.titleStr(), image: subItem.iconImage(), identifier: nil, discoverabilityTitle: nil, attributes: isDelete ? [.destructive] : [], state: .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                if wSelf.viewModel.selectArray.count == 0 {
                    wSelf.tableView.kaka_playShakeAnim()
                    return
                }
                
                if subItem == .addPlaylist {
                    self?.moveToOtherPlaylist(wSelf.viewModel.selectArray)
                }
                
                if subItem == .deleteItem {
                    wSelf.deleteMusicModel(wSelf.viewModel.selectArray)
                }
            })

            editArray.append(subMenu)
        }
        
        let batchAction = UIAction(title: "Batch Auto-Embed".localStr(), image: UIImage(systemName: "touchid"), attributes: []) { [weak self] (_) in
            self?.batchAutoEditAction()
        }
        
        let editMenu = UIMenu(title: "", options: .displayInline, children: editArray)
                
        return UIMenu(children: [batchAction, editMenu])
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearCache()
    }
    
}
