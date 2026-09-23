import UIKit
import AppGroupKit
import KakaFoundation
import KakaUIKit
import Combine
import NVActivityIndicatorView

/// Read-only FTP browser with the same grouped music/folder interactions as SMB.
final class FTPDriveFileListController: SuperViewController, UITableViewDataSource, UITableViewDelegate,
                                        MusicTableViewCellDelegate, UISearchBarDelegate {
    private var loginModel: FTPDriveUserModel
    private let folderPath: String
    private let folderName: String?
    private var loadRequestID = UUID()
    private var isLoading = false
    private var lastError: KakaError?
    private var isGrouping = true
    private var allFiles: [MusicItemModel] = []
    private var fileDict: [ConnectFileType: [MusicItemModel]] = [:]
    private var sections: [ConnectFileType] = []
    private var selected: [MusicItemModel] = []
    private var cancellables = Set<AnyCancellable>()

    init(loginModel: FTPDriveUserModel, folderPath: String = "", folderName: String? = nil) {
        self.loginModel = loginModel
        self.folderPath = folderPath
        self.folderName = folderName
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
            make.center.equalToSuperview()
            make.size.equalTo(loadingView.size.width)
        }
        emptyView.frame = contentView.bounds
        selectToolBar.frame = CGRect(x: 0, y: view.height - 49.ckValue() - kaka_safeAreaInsets().bottom,
                                     width: contentView.width, height: 49.ckValue())
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        title = folderName ?? loginModel.title
        navigationItem.largeTitleDisplayMode = .automatic
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        setRightBarbuttonItem()
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)
        refreshDataAction()
    }

    @objc private func refreshDataAction() {
        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        emptyView.isHidden = true
        loadingView.startAnimating()
        FTPDriveService.shared.listFolder(user: loginModel, folderPath: folderPath) { [weak self] result in
            guard let self, self.loadRequestID == requestID else { return }
            self.isLoading = false
            self.loadingView.stopAnimating()
            self.tableView.refreshControl?.endRefreshing()
            switch result {
            case .success(let files):
                self.lastError = nil
                self.allFiles = files
                self.selected.removeAll()
                self.selectCountItem.title = "0"
                self.rebuildSections()
            case .failure(let error):
                self.lastError = error
                self.tableView.isHidden = true
                self.emptyView.isHidden = false
                self.emptyView.update(.failure(error.errorDescription))
            }
        }
    }

    private func rebuildSections() {
        guard !isLoading else { return }
        if let lastError {
            tableView.isHidden = true
            emptyView.isHidden = false
            emptyView.update(.failure(lastError.errorDescription))
            return
        }
        let query = searchController.searchBar.text ?? ""
        let files = query.isEmpty ? allFiles : allFiles.filter { $0.searchMatcheItem(query) }
        let sort = MusicConfigManager.shared.sortType
        var groups: [ConnectFileType: [MusicItemModel]] = [:]
        for file in files { groups[isGrouping ? file.fileType() : .other, default: []].append(file) }
        for (type, items) in groups {
            groups[type] = items.sorted { $0.sortAnotherModel(model2: $1, sortType: sort) }
        }
        fileDict = groups
        sections = groups.keys.sorted { $0.rawValue < $1.rawValue }
        tableView.isHidden = false
        tableView.reloadData()
        emptyView.isHidden = !files.isEmpty
        if files.isEmpty { emptyView.update(.empty(folderID: folderPath, query: query)) }
    }

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.dataSource = self
        table.delegate = self
        table.tintColor = appMainColor
        table.rowHeight = UITableView.automaticDimension
        table.allowsMultipleSelectionDuringEditing = true
        table.contentInset.bottom = 20.ckValue() + playingHeight
        table.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
#if !targetEnvironment(macCatalyst)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        table.refreshControl = refresh
#endif
        return table
    }()

    private lazy var loadingView = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 25.ckValue(), height: 25.ckValue()),
                                                            type: .lineScalePulseOutRapid, color: appMainColor)

    private lazy var emptyView: SMBFileListStatusView = {
        let view = SMBFileListStatusView()
        view.isHidden = true
        view.actionHandler = { [weak self] action in
            switch action {
            case .refresh: self?.refreshDataAction()
            case .clearSearch:
                self?.searchController.searchBar.text = nil
                self?.rebuildSections()
            }
        }
        return view
    }()

    private lazy var searchController: UISearchController = {
        let controller = UISearchController()
        controller.searchBar.delegate = self
        return controller
    }()

    private func setRightBarbuttonItem() {
        if tableView.isEditing {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self,
                                                                action: #selector(stopEditBarClick))
            return
        }
        let edit = UIAction(title: "Select".localStr(), image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
            self?.startEditBarClick()
        }
        let refresh = UIAction(title: "Refresh".localStr(), image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.refreshDataAction()
        }
        let group = UIAction(title: "Group".localStr(), image: isGrouping ? UIImage(systemName: "checkmark") : nil) { [weak self] _ in
            guard let self else { return }
            self.isGrouping.toggle()
            self.setRightBarbuttonItem()
            self.rebuildSections()
        }
        let login = UIAction(title: "Edit FTP Credentials".localStr(), image: UIImage(systemName: "person.badge.key")) { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(AuthFTPViewController(user: self.loginModel) { [weak self] user in
                self?.loginModel = user
                self?.refreshDataAction()
            }, animated: true)
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                                              menu: UIMenu(children: [login, refresh, edit, group]))
    }

    private func startEditBarClick() {
        guard allFiles.contains(where: { $0.fileType() == .music }) else {
            showOneAlert(message: "No Audio Files".localStr())
            return
        }
        tableView.setEditing(true, animated: true)
        setRightBarbuttonItem()
        view.addSubview(selectToolBar)
    }

    @objc private func stopEditBarClick() {
        selected.removeAll()
        tableView.setEditing(false, animated: true)
        setRightBarbuttonItem()
        selectToolBar.removeFromSuperview()
        selectCountItem.title = "0"
    }

    private lazy var selectToolBar: UIToolbar = {
        let bar = UIToolbar()
        bar.items = [UIBarButtonItem(title: "Select All".localStr(), style: .plain, target: self, action: #selector(selectAllClick)),
                     UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                     selectCountItem,
                     UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                     UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain,
                                     target: self, action: #selector(downloadSelection))]
        return bar
    }()
    private lazy var selectCountItem = UIBarButtonItem(title: "0", style: .plain, target: nil, action: nil)

    @objc private func selectAllClick() {
        selected = sections.flatMap { fileDict[$0] ?? [] }.filter { $0.fileType() == .music }
        for (section, type) in sections.enumerated() {
            for (row, file) in (fileDict[type] ?? []).enumerated() where file.fileType() == .music {
                tableView.selectRow(at: IndexPath(row: row, section: section), animated: false, scrollPosition: .none)
            }
        }
        selectCountItem.title = "\(selected.count)"
    }

    @objc private func downloadSelection() {
        guard !selected.isEmpty else { stopEditBarClick(); return }
        let playlist = SelectPlaylistController(selectType: .downloadTask)
        playlist.onLocalBlock = { [weak self] folderURL in
            guard let self else { return }
            let files = self.selected.map { original -> MusicItemModel in
                var model = original
                model.downloadFolderName = folderURL.lastPathComponent
                return model
            }
            DownloadManager.shared.addMusicModel(files)
            self.stopEditBarClick()
            self.view.makeToast("Added to Downloads".localStr())
        }
        present(KakaNavigationController(rootViewController: playlist), animated: true)
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fileDict[sections[section]]?.count ?? 0
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        isGrouping ? sections[section].titleStr() : nil
    }
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        isGrouping ? sections.map { $0.keyStr() } : nil
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
        if let model = fileDict[sections[indexPath.section]]?[indexPath.row] {
            cell.update(musicModel: model, cellType: .cloudDrive)
            cell.delegate = self
            if tableView.isEditing, selected.contains(model) {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
        return cell
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        fileDict[sections[indexPath.section]]?[indexPath.row].fileType() == .music
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let model = fileDict[sections[indexPath.section]]?[indexPath.row] else { return }
        if tableView.isEditing {
            guard model.fileType() == .music else { tableView.deselectRow(at: indexPath, animated: true); return }
            if !selected.contains(model) { selected.append(model) }
            selectCountItem.title = "\(selected.count)"
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        switch model.fileType() {
        case .folder:
            guard let file = model.ftpFile else { return }
            navigationController?.pushViewController(FTPDriveFileListController(loginModel: loginModel,
                                                                                folderPath: file.path,
                                                                                folderName: file.name), animated: true)
        case .music: play(model)
        default: view.makeToast("Unsupported Files".localStr())
        }
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.isEditing, let model = fileDict[sections[indexPath.section]]?[indexPath.row] else { return }
        selected.removeAll { $0 == model }
        selectCountItem.title = "\(selected.count)"
    }

    private func play(_ model: MusicItemModel) {
        if KakaMusicPlayer.shared.playingMusic == model {
            KakaMusicPlayer.presentPlayController(fromVC: self)
            return
        }
        let sort = MusicConfigManager.shared.sortType
        let music = allFiles.filter { $0.fileType() == .music }.sorted {
            $0.sortAnotherModel(model2: $1, sortType: sort)
        }
        guard let index = music.firstIndex(of: model) else { return }
        ConnectConfigManager.shared.lastPlaylist = music
        KakaMusicPlayer.shared.startPlayMusic(musics: music, itemIndex: index)
    }

    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        if action == .play { play(model) }
        else if action == .download {
            guard model.ftpFile?.isMusic() == true else { return }
            let playlist = SelectPlaylistController(selectType: .downloadTask)
            playlist.onLocalBlock = { [weak self] folderURL in
                var item = model
                item.downloadFolderName = folderURL.lastPathComponent
                DownloadManager.shared.addMusicModel([item])
                self?.view.makeToast("Added to Downloads".localStr())
            }
            present(KakaNavigationController(rootViewController: playlist), animated: true)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { rebuildSections() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) { rebuildSections() }
}
