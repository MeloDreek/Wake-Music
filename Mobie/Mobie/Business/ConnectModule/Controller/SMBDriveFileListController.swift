//
//  SMBDriveFileListController.swift
//  Mobie
//
//  Read-only SMB browser using the existing cloud-drive interaction patterns.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import Combine
import NVActivityIndicatorView

/// SMB 文件浏览，沿用现有网盘的排序、选择和下载交互。
class SMBDriveFileListController: SuperViewController {

    /// SMB 共享目录文件列表
    /// - Parameters:
    ///   - loginModel: 服务器配置
    init(loginModel: SMBDriveUserModel, folderID: String = "", folderName: String? = nil) {
        super.init(nibName: nil, bundle: nil)

        self.loginModel = loginModel
        self.folderID = folderID
        self.folderName = folderName
    }

    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
        contentView.addSubview(emptyView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tableView.frame = contentView.bounds

        loadingView.snp.remakeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(loadingView.size.width)
        }

        let topInset = view.safeAreaInsets.top
        let bottomInset = max(view.safeAreaInsets.bottom + playingHeight, keyboardBottomInset)
        emptyView.frame = CGRect(x: 0, y: topInset, width: contentView.bounds.width,
                                 height: max(0, contentView.bounds.height - topInset - bottomInset))

        selectToolBar.frame = CGRectMake(0, self.view.height - 49.ckValue() - kaka_safeAreaInsets().bottom, contentView.width, 49.ckValue())
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()

        self.title = self.folderName ?? loginModel.title
        if kaka_safeAreaInsets().top > 15 || kaka_IsiPad() {
            self.navigationController?.navigationBar.prefersLargeTitles = true
            self.navigationItem.largeTitleDisplayMode = .automatic
        }else{
            self.navigationController?.navigationBar.prefersLargeTitles = false
            self.navigationItem.largeTitleDisplayMode = .never
        }

        self.configSearchBar()
        self.setRightBarbuttonItem()


        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)


        self.refreshDataAction()
    }

    @objc func refreshDataAction() {
        let requestID = UUID()
        loadRequestID = requestID
        isLoadingFolder = true
        emptyView.isHidden = true
        loadingView.startAnimating()
        SMBDriveService.shared.listFolder(user: loginModel, folderID: folderID) { [weak self] result in
            guard let self = self, self.loadRequestID == requestID else { return }
            self.isLoadingFolder = false
            self.stopLoadingAction()
            switch result {
            case .success(let files):
                self.lastLoadError = nil
                // Refresh replaces the snapshot; it must not duplicate files or keep deleted entries.
                self.allfileArray = files
                self.selectArray.removeAll()
                self.selectCountItem.title = "0"
                self.sortAllServerFiles(files)
            case .failure(let error):
                self.lastLoadError = error
                self.emptyView.isHidden = false
                self.tableView.isHidden = true
                self.emptyView.update(.failure(error.errorDescription))

            }
        }
    }

    // 分组、排序文件列表
    func sortAllServerFiles(_ snapshot: [MusicItemModel]) {

        // Search/cancel/sort must not turn a pending or failed request into a
        // misleading "Connected" empty-folder message.
        guard !isLoadingFolder else { return }
        if let error = lastLoadError {
            emptyView.isHidden = false
            tableView.isHidden = true
            emptyView.update(.failure(error.errorDescription))
            return
        }

        // Apply the same active query after refresh, grouping and sorting changes.
        let query = self.searchController.searchBar.text ?? ""
        let files = query.isEmpty ? snapshot : snapshot.filter { $0.searchMatcheItem(query) }

        let sortType = MusicConfigManager.shared.sortType

        var sortedDictionary = [ConnectFileType: [MusicItemModel]]()
        let folderKey = ConnectFileType.folder
        let musicKey = ConnectFileType.music
        let otherKey = ConnectFileType.other


        if self.isGrouping {
            // 分组文件夹、音乐、其他
            for index in 0..<files.count {
                let subFile = files[index]
                if subFile.fileType() == .folder {
                    // 文件夹
                    if sortedDictionary[folderKey] == nil {
                        sortedDictionary[folderKey] = [MusicItemModel]()
                    }
                    sortedDictionary[folderKey]?.append(subFile)
                } else if subFile.fileType() == .music {
                    // 音乐
                    if sortedDictionary[musicKey] == nil {
                        sortedDictionary[musicKey] = [MusicItemModel]()
                    }
                    sortedDictionary[musicKey]?.append(subFile)
                } else {
                    // 其他
                    if sortedDictionary[otherKey] == nil {
                        sortedDictionary[otherKey] = [MusicItemModel]()
                    }
                    sortedDictionary[otherKey]?.append(subFile)
                }
            }
        }else{
            // 不分组
            sortedDictionary[ConnectFileType.other] = files
        }

        // 内部排序
        for (key, value) in sortedDictionary {
            sortedDictionary[key] = value.sorted(by: { element1, element2 in
                return element1.sortAnotherModel(model2: element2, sortType: sortType)
            })
        }

        self.fileDict = sortedDictionary
        self.indexArray = sortedDictionary.keys.sorted(by: { return $0.rawValue < $1.rawValue })

        self.stopLoadingAction()
        self.tableView.reloadData()
        self.emptyView.isHidden = !files.isEmpty
        if files.isEmpty {
            self.emptyView.update(.empty(folderID: folderID, query: query))
        }
    }


    // MARK:  GET && SET

    var cancellables = Set<AnyCancellable>()

    /// 是否分组
    var isGrouping: Bool = true

    /// 登录信息
    var loginModel: SMBDriveUserModel!
    private var folderID: String = ""
    private var folderName: String?
    private var loadRequestID = UUID()
    private var isLoadingFolder = false
    private var lastLoadError: KakaError?
    private var keyboardBottomInset: CGFloat = 0

    /// 所有的文件列表
    var allfileArray: [MusicItemModel] = []

    /// 整理后的文件列表
    lazy var fileDict: [ConnectFileType: [MusicItemModel]] = {
        return [ConnectFileType: [MusicItemModel]]()
    }()

    /// 已排序的数组
    lazy var indexArray: [ConnectFileType] = {
        return [ConnectFileType]()
    }()


    // MARK:  懒加载

    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.tintColor = self.btnTincolor
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.rowHeight = UITableView.automaticDimension
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20.ckValue() + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()

    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 25.ckValue(), 25.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: .lineScalePulseOutRapid, color: appMainColor)
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

    lazy var emptyView: SMBFileListStatusView = {
        let view = SMBFileListStatusView()
        view.isHidden = true
        view.actionHandler = { [weak self] action in
            switch action {
            case .refresh: self?.refreshDataAction()
            case .clearSearch: self?.stopSearchAction(true)
            }
        }
        return view
    }()

    func cancelItem() -> UIBarButtonItem {
        let item = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(stopEditBarClick))
        item.tintColor = appMainColor
        return item
    }

    func moreBarItem() -> UIBarButtonItem {
        let selectAction = UIAction(title: "Select".localStr(), image: kaka_IsMacOS() ? nil : UIImage(systemName: "checkmark.circle"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.startEditBarClick()
        })

        let sortAction = UIAction(title: "Group".localStr(), image: kaka_IsMacOS() ? nil : (self.isGrouping ? UIImage(systemName: "checkmark") : nil), identifier: nil, discoverabilityTitle: nil, attributes: [], state: (kaka_IsMacOS() ? (self.isGrouping ? .on : .off) : .off), handler: { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.isGrouping = !wSelf.isGrouping
            wSelf.setRightBarbuttonItem()

            if let allfileArray = self?.allfileArray {
                self?.sortAllServerFiles(allfileArray)
            }
        })

        let refreshAction = UIAction(title: "Refresh".localStr(), image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.refreshDataAction()
        }
        let loginAction = UIAction(title: "Edit SMB Credentials".localStr(), image: UIImage(systemName: "person.crop.circle.badge.key")) { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(AuthSMBViewController(user: self.loginModel) { [weak self] user in
                self?.loginModel = user
                self?.refreshDataAction()
            }, animated: true)
        }
        let allItemMune = UIMenu(title: "", children: [loginAction, refreshAction, selectAction, sortAction, self.sorTypeMenu()])
        let mainItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: allItemMune)
        mainItem.accessibilityLabel = "More".localStr()
        return mainItem
    }

    // 排序方式
    func sorTypeMenu() -> UIMenu {
        let storageArray: [SortedbyType] = [.createDate, .modifyDate, .fileSize, .fileName]
        var actionArray: [UIAction] = [UIAction]()

        for subItem in storageArray {
            let isOn = subItem == MusicConfigManager.shared.sortType
            let subMenu = UIAction(title: subItem.formatStr(), image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: isOn ? .on : .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                if wSelf.indexArray.isEmpty {
                    wSelf.tableView.kaka_playShakeAnim()
                    return
                }

                MusicConfigManager.shared.sortType = subItem
                self?.setRightBarbuttonItem()
                if let allfileArray = self?.allfileArray {
                    self?.sortAllServerFiles(allfileArray)
                }
            })

            actionArray.append(subMenu)
        }

        let sortMenu = UIMenu(title: "", options: .displayInline, children: actionArray)

        // 升序
        let isSortAscending = MusicConfigManager.shared.isSortAscending
        let ascendingAction = UIAction(title: "Ascending".localStr(), image: kaka_IsMacOS() ? nil : (isSortAscending ? UIImage(systemName: "checkmark") : nil), identifier: nil, discoverabilityTitle: nil, attributes: [], state: kaka_IsMacOS() ? (isSortAscending ? .on : .off) : .off) { [weak self] action in
            MusicConfigManager.shared.isSortAscending = true
            self?.setRightBarbuttonItem()
            if let allfileArray = self?.allfileArray {
                self?.sortAllServerFiles(allfileArray)
            }
        }

        // 降序
        let deAscendingAction = UIAction(title: "Descending".localStr(), image: kaka_IsMacOS() ? nil : (isSortAscending ? nil : UIImage(systemName: "checkmark")), identifier: nil, discoverabilityTitle: nil, attributes: [], state: kaka_IsMacOS() ? (isSortAscending ? .off : .on) : .off) { [weak self] action in
            MusicConfigManager.shared.isSortAscending = false
            self?.setRightBarbuttonItem()
            if let allfileArray = self?.allfileArray {
                self?.sortAllServerFiles(allfileArray)
            }
        }

        let acendMenu = UIMenu(title: "", options: .displayInline, children: [ascendingAction, deAscendingAction])

        let mainMenu = UIMenu(title: "Sort By".localStr(), image: UIImage(systemName: "arrow.up.arrow.down"), children: [sortMenu, acendMenu])
        return mainMenu
    }

    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()

    // 选择工具栏
    lazy var selectToolBar: UIToolbar = {
        // 全选/全不选，已选择 88 项，完成
        let frame = CGRectMake(0, self.view.height - 49.ckValue() - kaka_safeAreaInsets().bottom, contentView.width, 49.ckValue())
        let view = UIToolbar(frame: frame)

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)

        let normalItems = [fixedSpace, self.selectAllItem,
                           fixedSpace, self.deSelectAllItem,
                           flexibleSpace, self.selectCountItem,
                           flexibleSpace, self.doneSelectItem,
                           fixedSpace]
        view.setItems(normalItems, animated: true)
        return view
    }()

    lazy var selectAllItem: UIBarButtonItem = {
        let item1 = UIBarButtonItem(title: "Select All".localStr(), style: .plain, target: self, action: #selector(selectAllBarClick))
        return item1
    }()

    lazy var deSelectAllItem: UIBarButtonItem = {
        let item1 = UIBarButtonItem(title: "Deselect All".localStr(), style: .plain, target: self, action: #selector(deselectAllBarClick))
        return item1
    }()

    lazy var doneSelectItem: UIBarButtonItem = {
        let doneItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(doneSelectItemAction))
        doneItem.tintColor = self.btnTincolor
        return doneItem
    }()

    lazy var selectCountItem: UIBarButtonItem = {
        let title = "\(self.selectArray.count)"
        let item = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
        item.tintColor = UIColor.label
        item.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        return item
    }()

    lazy var selectArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()

    var btnTincolor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }

}

extension SMBDriveFileListController {

    func stopLoadingAction() {
        self.emptyView.isHidden = true
        self.tableView.isHidden = false
        self.kaka_header.endRefreshing()
        self.loadingView.stopAnimating()
    }

    @objc func cancelBarClick() {

        (self.navigationController ?? self)?.dismiss(animated: true)
        self.navigationController?.popToRootViewController(animated: true)
    }

    @objc func playingMusicChanged() {
        self.tableView.reloadData()
    }

    func setRightBarbuttonItem() {

        if self.tableView.isEditing {
            self.navigationItem.rightBarButtonItem = self.cancelItem()
        }else{
            if self.isPresent() {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
            }

            self.navigationItem.rightBarButtonItem = self.moreBarItem()
        }
    }


    @objc func selectAllBarClick() {

        let audioArray = self.indexArray.flatMap { self.fileDict[$0] ?? [] }.filter { $0.fileType() == .music }

        if audioArray.count == 0 {
            self.tableView.kaka_playShakeAnim()
            self.showOneAlert(message: "No Audio Files".localStr())
            return
        }

        self.selectArray = audioArray.map({ subModel in
            var tempModel = subModel
            tempModel.isSelected = true
            return tempModel
        })

        for subIndexPath in self.getAllIndexPaths() {
            self.tableView.selectRow(at: subIndexPath, animated: false, scrollPosition: .none)
        }

        self.selectCountItem.title = "\(self.selectArray.count)"
    }

    @objc func deselectAllBarClick() {
        self.selectArray.removeAll()

        for subIndexPath in self.getAllIndexPaths() {
            self.tableView.deselectRow(at: subIndexPath, animated: false)
        }

        self.selectCountItem.title = "\(self.selectArray.count)"
    }

    // 开始编辑模式
    @objc func startEditBarClick() {

        if self.indexArray.count <= 0 {
            self.tableView.kaka_playShakeAnim()
            return
        }

        let audioArray = self.indexArray.flatMap { self.fileDict[$0] ?? [] }.filter { $0.fileType() == .music }

        if audioArray.count == 0 {
            self.tableView.kaka_playShakeAnim()
            self.showOneAlert(message: "No Audio Files".localStr())
            return
        }

        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
            tabbarVC.tabBar.isHidden = true
            tabbarVC.toolbarView.isHidden = true
            tabbarVC.floatingView.isHidden = true
            self.navigationItem.titleView = UIView()
        }

        if let splitVC = self.splitViewController as? MacTabbarViewController {
            splitVC.toolbarView.isHidden = true
            self.navigationItem.titleView = UIView()
        }

        self.tableView.setEditing(!self.tableView.isEditing, animated: true)

        self.setRightBarbuttonItem()
        self.view.addSubview(selectToolBar)
    }


    // 取消编辑模式
    @objc func stopEditBarClick() {
        self.selectArray.removeAll()
        self.tableView.setEditing(false, animated: true)

        self.setRightBarbuttonItem()

        for subIndexPath in (self.tableView.indexPathsForVisibleRows ?? []) {
            self.tableView.deselectRow(at: subIndexPath, animated: false)
        }

        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
            tabbarVC.tabBar.isHidden = false
            tabbarVC.localMusicCountChanged()
            self.navigationItem.titleView = nil
        }

        if let splitVC = self.splitViewController as? MacTabbarViewController {
            splitVC.toolbarView.isHidden = false
            self.navigationItem.titleView = nil
        }

        self.selectCountItem.title = "\(self.selectArray.count)"

        self.selectToolBar.removeFromSuperview()
    }


    @objc func doneSelectItemAction() {
        if self.selectArray.isEmpty {
            self.stopEditBarClick()
            return
        }

        let playlist = SelectPlaylistController(selectType: .downloadTask)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            guard let wSelf = self else { return }
            let tempArray = wSelf.selectArray.map {
                var newModel = $0
                newModel.downloadFolderName = folderURL.lastPathComponent
                return newModel
            }
            DownloadManager.shared.addMusicModel(tempArray)
            wSelf.stopEditBarClick()
            wSelf.view.makeToast("Added to Downloads".localStr())
        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }

    func getAllIndexPaths() -> [IndexPath] {
        var indexPaths: [IndexPath] = []

        let numberOfSections = tableView.numberOfSections
        for section in 0..<numberOfSections {
            let numberOfRows = tableView.numberOfRows(inSection: section)
            for row in 0..<numberOfRows {
                let fileType = self.indexArray[section]
                if self.fileDict[fileType]?[row].fileType() == .music {
                    let indexPath = IndexPath(row: row, section: section)
                    indexPaths.append(indexPath)
                }
            }
        }

        return indexPaths
    }

    // Paths are relative to this connection's selected SMB share.
    func pushDocumentPage(_ subFile: MusicItemModel) {
        guard let file = subFile.smbFile, file.isDirectory() else { return }
        let folderVC = SMBDriveFileListController(loginModel: loginModel, folderID: file.id, folderName: file.name)
        self.navigationController?.pushViewController(folderVC, animated: true)
    }
}

extension SMBDriveFileListController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.indexArray.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let fileType = self.indexArray[section]
        return self.fileDict[fileType]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let fileType = self.indexArray[indexPath.section]

        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
        if let musicModel = self.fileDict[fileType]?[indexPath.row] {
            cell.update(musicModel: musicModel, cellType: .cloudDrive)
            cell.delegate = self

            if tableView.isEditing {
                let isSelected = self.selectArray.contains(musicModel)
                if isSelected {
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                }else{
                    tableView.deselectRow(at: indexPath, animated: false)
                }
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let fileType = self.indexArray[indexPath.section]
        let dataArray = self.fileDict[fileType] ?? []
        let subModel = dataArray[indexPath.row]

        if !self.tableView.isEditing {

            tableView.deselectRow(at: indexPath, animated: true)

            if subModel.fileType() == .folder {
                self.pushDocumentPage(subModel)
            }else if subModel.fileType() == .music {

                self.playWithMusic(subModel)

            }else{

                self.view.makeToast("Unsupported Files".localStr())
            }

        }else{

            if subModel.fileType() != .music {
                self.view.makeToast("Unsupported Files".localStr())
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

            // 处理取消选择
            let fileType = self.indexArray[indexPath.section]
            var dataArray = self.fileDict[fileType] ?? []
            var model = dataArray[indexPath.row]

            // 确保模型的选择状态为 false
            model.isSelected = true

            // 更新数据源中的模型对象
            dataArray[indexPath.row] = model

            // 从选中数组中移除模型
            if !self.selectArray.contains(model) { self.selectArray.append(model) }

            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)

            self.selectCountItem.title = "\(self.selectArray.count)"

        }

    }

    // 取消选择
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {

        // 处理取消选择
        let fileType = self.indexArray[indexPath.section]
        var dataArray = self.fileDict[fileType] ?? []
        var model = dataArray[indexPath.row]

        // 确保模型的选择状态为 false
        model.isSelected = false

        // 更新数据源中的模型对象
        dataArray[indexPath.row] = model

        // 从选中数组中移除模型
        if let firstIndex = self.selectArray.firstIndex(where: { $0 == model }) {
            self.selectArray.remove(at: firstIndex)
        }

        // 更新当前单元格的选中状态
        if model.isSelected {
            self.tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }else{
            self.tableView.deselectRow(at: indexPath, animated: true)
        }

        let selectTitle = "\(self.selectArray.count)"
        self.selectCountItem.title = selectTitle
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let fileType = self.indexArray[indexPath.section]
        return self.fileDict[fileType]?[indexPath.row].fileType() == .music
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.isGrouping {
            let fileType = self.indexArray[section]
            return fileType.titleStr()
        }else{
            let config = MusicConfigManager.shared
            let arrowStr = (MusicConfigManager.shared.isSortAscending ? "<<" : ">>")
            return config.sortType.formatStr() + arrowStr
        }
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if self.isGrouping {
            return self.indexArray.map { subType in return subType.keyStr() }
        }else{
            return nil
        }
    }

}

extension SMBDriveFileListController {


}

extension SMBDriveFileListController: MusicTableViewCellDelegate {
    // 点击cell更多
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {

        if action == .play {
            self.playWithMusic(model)
        }


        if action == .download {
            self.downloadWithMusic(cell: cell, model: model)
        }
    }

    // 点击播放
    func playWithMusic(_ subModel: MusicItemModel) {

        let isPlaying = KakaMusicPlayer.shared.playingMusic == subModel

        if isPlaying {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            let sortType = MusicConfigManager.shared.sortType
            let musicArray = self.allfileArray.filter { $0.fileType() == .music }.sorted(by: { element1, element2 in
                return element1.sortAnotherModel(model2: element2, sortType: sortType)
            })

            guard let index = musicArray.firstIndex(where: { $0 == subModel }) else { return }

            ConnectConfigManager.shared.lastPlaylist = musicArray
            KakaMusicPlayer.shared.startPlayMusic(musics: musicArray, itemIndex: index)
        }
    }

    // 下载
    func downloadWithMusic(cell: MusicTableViewCell, model: MusicItemModel) {

        self.downloadWithMusic(model)
    }

    // 下载音乐
    func downloadWithMusic(_ model: MusicItemModel) {

        guard let smbFile = model.smbFile, smbFile.isMusic() else {
            return
        }

        let playlist = SelectPlaylistController(selectType: .downloadTask)
        playlist.onLocalBlock = { [weak self] (folderURL) in
            var musicModel = MusicItemModel(smbFile: smbFile)
            musicModel.downloadFolderName = folderURL.lastPathComponent
            DownloadManager.shared.addMusicModel([musicModel])
            self?.view.makeToast("Added to Downloads".localStr())
        }

        self.present(KakaNavigationController(rootViewController: playlist), animated: true)
    }

}


extension SMBDriveFileListController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty { self.sortAllServerFiles(self.allfileArray) }
        else { self.searchWithKey(searchText) }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }

        debugPrint("searchText = \(searchText)")


        self.searchWithKey(searchText)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        debugPrint("停止编辑 = \(searchBar.text ?? "")")
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }

    func searchWithKey(_ keyword: String) {
        self.sortAllServerFiles(self.allfileArray)
    }

    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }

    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366

        if let rect = rect {
            let keyboardFrame = view.convert(rect, from: nil)
            keyboardBottomInset = max(0, view.bounds.maxY - keyboardFrame.minY)
        }
        view.setNeedsLayout()

        self.tableView.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: keyboardH, right: 0)
    }

    @objc func keyboardWillHidden(_ notify: Notification) {
        keyboardBottomInset = 0
        view.setNeedsLayout()
        self.tableView.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: playingHeight, right: 0)
    }

    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.searchController.dismiss(animated: animation)

        self.sortAllServerFiles(self.allfileArray)
    }
}
