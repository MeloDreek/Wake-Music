//
//  LibraryLyricsViewController.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit
import UniformTypeIdentifiers
import GCDWebServer

enum MusicTopMode: Int {
    case coverLibrary = 0
    case lyricLibrary = 1
    
    func titleStr() -> String {
        switch self {
        case .coverLibrary:
            return "Cover Library".localStr()
        case .lyricLibrary:
            return "Lyric Library".localStr()
        }
    }
    
    func iconImage(_ color: UIColor = appMainColor) -> UIImage? {
        switch self {
        case .coverLibrary:
            if #available(iOS 16.0, *) {
                return Reasource.systemNamed("photo.stack", color: color)
            }else{
                return Reasource.systemNamed("photo.on.rectangle", color: color)
            }
        case .lyricLibrary:
            return Reasource.systemNamed("text.quote", color: color)
        }
    }
    
    func tintColor() -> UIColor {
        switch self {
        case .coverLibrary:
            return UIColor.systemBlue
        case .lyricLibrary:
            return UIColor.systemPink
        }
    }
    
}


/// 歌词库
class LibraryLyricsViewController: SuperViewController, UIDocumentPickerDelegate, DocumentFolderWatcherDelegate, GCDWebUploaderDelegate {
    
    deinit {
#if !targetEnvironment(macCatalyst)
        self.webServer.stop()
#endif
    }
    
    init(isSelect: Bool) {
        self.isSelect = isSelect
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
                
#warning("模拟mock数据")
//#if DEBUG
//        self.overrideUserInterfaceStyle = .light
//        self.navigationController?.overrideUserInterfaceStyle = .light
//        self.tableView.overrideUserInterfaceStyle = .light
//#endif
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = self.view.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = MusicTagType.lyrics.titleStr()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemsAction))
        self.configSearchBar()
        
        self.folderWatcher.startWatching()
        
#if !targetEnvironment(macCatalyst)
        self.webServer.start()
#endif
        
        self.refreshDataAction()
        self.navigationItem.rightBarButtonItem = self.importBarItem
    }
    
    @objc func cancelItemsAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    lazy var importBarItem: UIBarButtonItem = {
        var actionArray = [UIAction]()
        
        let subMenu1 = UIAction(title: "LRC" + " " + "File".localStr(), image: UIImage(systemName: "doc.badge.plus"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.importLocalFiles()
        })
        
        let subMenu2 = UIAction(title: "Folder".localStr(), image: UIImage(systemName: "folder.badge.plus"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.importLocalFolder()
        })
        
        let subMenu3 = UIAction(title: "WiFi".localStr(), image: UIImage(systemName: "wifi"), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            if let wifiCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? GCDURLTableViewCell {
                wifiCell.kaka_playShakeAnim()
            }
        })
        
        actionArray.append(subMenu1)
        actionArray.append(subMenu2)
        actionArray.append(subMenu3)
                
        let addMenu = UIMenu(title: "", children: actionArray)
        
        let importBarItem = UIBarButtonItem(image: UIImage(systemName: "plus"), menu: addMenu)
        return importBarItem
    }()
    
    @objc func importLocalFolder() {
        let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        documentVC.delegate = self
        documentVC.allowsMultipleSelection = false
        self.present(documentVC, animated: true)
    }
    
    @objc func importLocalFiles() {
        let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.text, UTType.data], asCopy: false)
        documentVC.delegate = self
        documentVC.shouldShowFileExtensions = true
        documentVC.allowsMultipleSelection = true
        self.present(documentVC, animated: true)
    }
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()

    // 处理文件选择的回调
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        var supportArray: [URL] = []
                
        if let folderURL = urls.first, folderURL.hasDirectoryPath {
            // 递归查找所有扩展名为 .lrc 的文件
            do {
                supportArray = try findLRCFiles(in: folderURL)
            } catch {
                self.view.makeToast(error.localizedDescription)
                return
            }
        }else{
            supportArray = urls
        }

        if supportArray.isEmpty {
            showOneAlert(title: "LRC files only".localStr(), message: "Please check your file format".localStr())
            return
        }

        self.viewModel.handleAudioURLs(handleType: .copy, sourceType: .localFile, musicURLs: supportArray) { result in
            
        } completion: { [weak self] models in
            self?.refreshDataAction()
        }
        
    }

    // 递归查找 LRC 文件
    private func findLRCFiles(in directory: URL) throws -> [URL] {
        var lrcFiles: [URL] = []
        
        let fileManager = FileManager.default
        var contents = [URL]()

        if FileManager.default.isReadableFile(atPath: directory.path) {
            contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } else if directory.startAccessingSecurityScopedResource() {
            defer {
                directory.stopAccessingSecurityScopedResource()
            }
            
            contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
        } else {
            contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        }
        
        for url in contents {
            if url.hasDirectoryPath {
                // 如果是文件夹，递归查找
                let subFiles = try findLRCFiles(in: url)
                lrcFiles.append(contentsOf: subFiles)
            } else if url.pathExtension.lowercased() == "lrc" {
                // 如果是 LRC 文件，添加到数组
                lrcFiles.append(url)
            }
        }
        
        return lrcFiles
    }
    
    func refreshDataAction() {
        self.dataArray = SandboxFileManager.shared.lyricsPathURL().readLocalSubFiles()
        
#warning("模拟mock数据")
        
        DispatchQueue.main.async { [weak self] () in
            self?.tableView.reloadData()
        }
    }
    
    // MARK:  GET && SET
    var isSelect: Bool!
    
    var onSelectCallback: ((URL)->Void)?
    
    // MARK:  懒加载
    lazy var dataArray: [URL] = {
        return [URL]()
    }()
    
    lazy var folderWatcher: DocumentFolderWatcher = {
        let baseFileURL = SandboxFileManager.shared.lyricsPathURL()
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
    lazy var viewModel: MusicViewModel = {
        let baseFileURL = SandboxFileManager.shared.lyricsPathURL()
        let vm = MusicViewModel(baseFileURL)
        return vm
    }()
    
#if !targetEnvironment(macCatalyst)
    lazy var webServer: GCDWebUploader = {
        var auduoTypes: [String] = ["lrc"]
        
        let appVersion = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let appBuildVersion = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        
        let server = GCDWebUploader(uploadDirectory: SandboxFileManager.shared.lyricsPathURL().path)
        server.delegate = self
        server.title = "🏷️" + Application.wakeMusic.appTitle()
        server.footer = "Waketag".localStr() + " \(appVersion) " + "(\(appBuildVersion ?? "99"))"
        server.prologue = "Please put the LRC lyrics file here, and do not close this page, let alone rest the screen, during transmission.".localStr()
        server.epilogue = "Please make sure the current device is connected to the same Wi-Fi as your computer or Android phone, and keep the screen on during transmission❗️".localStr()
        server.allowedFileExtensions = auduoTypes
        server.allowHiddenItems = true
        return server
    }()
#endif
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.register(LocalLyricsyHeadCell.self, forCellReuseIdentifier: "LocalLyricsyHeadCell")
        view.register(GCDURLTableViewCell.self, forCellReuseIdentifier: "GCDURLTableViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "LyricsTableViewCell")
        return view
    }()
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if kaka_IsMacOS() {
            return UITableView.automaticDimension
        }else{
            return indexPath.section == 1 ? 50.ckValue() : UITableView.automaticDimension
        }
    }
    
#if !targetEnvironment(macCatalyst)
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 1 ? "WiFi".localStr() : nil
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return "Please make sure the current device is connected to the same Wi-Fi as your computer or Android phone, and keep the screen on during transmission❗️".localStr()
        }else{
            return nil
        }
    }
    
    func webServerDidDisconnect(_ server: GCDWebServer) {
        debugPrint("链接断开")
        self.refreshDataAction()
    }
    
    func webServerDidConnect(_ server: GCDWebServer) {
        self.refreshDataAction()
    }
#endif
    
}

extension LibraryLyricsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return kaka_IsMacOS() ? 2 : 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if kaka_IsMacOS() {
            return section == 1 ? dataArray.count : 1
        }else{
            return section == 2 ? dataArray.count : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocalLyricsyHeadCell", for: indexPath)
            return cell
        }else{
            if !kaka_IsMacOS() && indexPath.section == 1 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "GCDURLTableViewCell", for: indexPath) as! GCDURLTableViewCell
#if !targetEnvironment(macCatalyst)
                cell.webUrl = self.webServer.serverURL
#endif
                return cell
            }else{
                let subURL = dataArray[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "LyricsTableViewCell", for: indexPath)
                var cellConfig = UIListContentConfiguration.cell()
                cellConfig.text = subURL.lastPathComponent
                cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
                cell.accessoryType = .disclosureIndicator
                cell.contentConfiguration = cellConfig
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 { return }
        
#if !targetEnvironment(macCatalyst)
        if indexPath.section == 1 {
            // 复制网址
            guard let curCell = tableView.cellForRow(at: indexPath) as? GCDURLTableViewCell else { return }
            guard let serverURL = self.webServer.serverURL else {
                curCell.kaka_playShakeAnim()
                return
            }
            
            curCell.webUrl = serverURL

            let shareVC = UIActivityViewController(activityItems: [serverURL], applicationActivities: nil)
            if !kaka_IsiPhone() {
                shareVC.popoverPresentationController?.sourceView = curCell.contentView
                curCell.copyButton.isSelected = true
            }
            self.present(shareVC, animated: true, completion: nil)
            
            UIPasteboard.general.string = serverURL.absoluteString
            shareVC.view.makeToast("Copied".localStr())
            return
        }
#endif
        
        let subURL = dataArray[indexPath.row]

        if self.isSelect {
            self.onSelectCallback?(subURL)
            self.cancelItemsAction()
        }else{
            self.readLRCFile(at: subURL)
        }
    }
    
    func readLRCFile(at subURL: URL) {
        
        // 检查是否成功读取内容
        guard let fileContent = subURL.readLRCContentStr(), fileContent.count > 1 else {
            self.view.makeToast("Unable to open document. Text encoding Unicode (UTF-8 and GBK) is not applicable.".localStr())
            return
        }
        
        if kaka_IsMacOS() {
            self.view.makeToast(fileContent)
        }else{
            showOneAlert(title: subURL.lastPathComponent, message: fileContent)
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if kaka_IsMacOS() {
            return indexPath.section == 1
        }else{
            return indexPath.section == 2
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if (kaka_IsMacOS() && indexPath.section == 1) || (!kaka_IsMacOS() && indexPath.section == 2) {
            // 删除
            let subURL = dataArray[indexPath.row]

            let deleteAction = UIContextualAction(style: .normal, title: nil) { action, view, finish in
                finish(true)
                try? FileManager.default.removeItem(at: subURL)
            }
            deleteAction.image = Reasource.systemNamed("trash", color: .white)
            deleteAction.backgroundColor = UIColor.systemPink
                    
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }else{
            return nil
        }
        
    }
    
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
        self.refreshDataAction()
    }
    
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        self.refreshDataAction()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
    
    
    
}

// MARK: 头部Cell
class LocalLyricsyHeadCell: UITableViewCell {
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
        let view = UIImageView(image: Reasource.systemNamed("text.quote"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = "Imported LRC lyrics files, if the music file does not have embedded lyrics, you can select these lyrics files to be embedded into the music file!".localStr()
        view.textAlignment = .center
        view.font = kaka_IsMacOS() ? UIFontLight(15) : UIFontBold(15.ckValue())
        view.textColor = kaka_IsMacOS() ? .label : .secondaryLabel
        return view
    }()
    
}

