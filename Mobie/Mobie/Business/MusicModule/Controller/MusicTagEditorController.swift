//
//  MusicTagEditorController.swift
//  Mobie
//
//  Created by 张文 on 11/3/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import KSPlayer
import KakaTaglibKit
import KakaPhotoBrowser
import PhotosUI
import KakaObjcKit
import Kingfisher
import UniformTypeIdentifiers
import ZLImageEditor
import MessageUI
import StoreKit
import SafariServices


// 封面，歌名、歌手、专辑，文件名、文件大小、文件格式、比特率、码率、声道。
class MusicTagEditorController: SuperViewController {
    private var metadataTask: Task<Void, Never>?

    deinit { metadataTask?.cancel() }

    init(_ model: MusicItemModel) {
        super.init(nibName: nil, bundle: nil)
        self.origialModel = model
        self.editModel = model
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = "Music Tag Editor".localStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = self.exportBarItem
        
        if let fileURL = self.origialModel?.mediaPlayURL, !fileURL.isSupportMusicFile(false) {
            self.showOneAlert(message: "Unsupported Files".localStr()) {
                self.navigationController?.popViewController(animated: true)
            }
            return
        }
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
//#if DEBUG
//        if let origialModel = self.origialModel {
//            let fileURL = origialModel.mediaPlayURL
//            TaglibMetadataParser.setLyris("", toFileURL: fileURL)
//            TaglibMetadataParser.setCoverArt(nil, toFileURL: fileURL)
//            try? FileManager.default.removeItem(at: origialModel.coverThumbnailURL())
//            ImageCache.default.clearMemoryCache()
//        }
//#endif
                
        self.refreshDataAction()
    }
    
    @objc func refreshDataAction() {
        guard let origialModel = self.origialModel else { return }
        
        let metaModel = TaglibMetadataParser.readMetadata(withFileURL: origialModel.mediaPlayURL, read: .all)
                
        self.fileSize = origialModel.mediaPlayURL.fileSizeString
        self.coverImage = metaModel?.coverArt
        self.editModel = metaModel?.mergeTagLibInfo(origialModel) ?? self.origialModel
                
        self.tableView.reloadData()
        
        self.handleAudioMetadata()

#warning("模拟mock数据")
        
//#if DEBUG
//        let musicGenre = MusicGenreType.pop
//        self.coverImage = musicGenre.iconImage()
//        self.editModel?.title = musicGenre.formatStr()
//        self.editModel?.artist = Application.wakeMusic.appTitle()
//        self.editModel?.year = Date().year
//        self.editModel?.track = 1
//        self.editModel?.channel = .surround51
//        self.editModel?.genre = musicGenre.rawValue
//        self.editModel?.album = musicGenre.formatStr() + "1999"
//        self.tableView.reloadData()
//#endif
        
    }
    
    
    // 处理内嵌元数据
    @MainActor func handleAudioMetadata() {
        guard let playingMusic = self.origialModel else { return }
        
        let currentOption = KakaMusicPlayer.shared.audioOption(playingMusic)
        KSOptions.firstPlayerType = KSMEPlayer.self
        currentOption.playerTypes = [KSMEPlayer.self]
        
        metadataTask?.cancel()
        metadataTask = Task { @MainActor [weak self] in
            do {
                let metadata = try await FFmpegUtility.getMetadata(for: playingMusic.mediaPlayURL, options: currentOption)
                guard !Task.isCancelled, let self,
                      self.origialModel?.uniqueID() == playingMusic.uniqueID() else { return }
                debugPrint("ffmpeg元数据 = \(metadata.metadata), 封面宽 = \(metadata.coverImage?.width ?? 0)")
                self.footStr = metadata.metadata
                    .sorted { ($0.key + $0.value).count < ($1.key + $1.value).count }
                    .map { "▶️\($0.key): \($0.value)" }
                    .joined(separator: "\n")
                self.tableView.reloadData()
            } catch {
                guard !Task.isCancelled else { return }
                debugPrint("解析内嵌元数据失败 = \(error.localizedDescription)")
            }
        }
        
    }
    
    lazy var exportBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Export".localStr(), style: .plain, target: self, action: #selector(exportAction))
        return item
    }()
        
    func showInFinderCatalyst(_ fileURL: URL) {
        
        // Finder 的行为是选中这个文件，所以我们传它所在的目录
        let folderURL = fileURL.deletingLastPathComponent()
        
        // 如果是文件夹就直接打开，否则打开其所在目录
        let targetURL = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: nil) && fileURL.path.hasSuffix("/") ? fileURL : folderURL

        UIApplication.shared.open(targetURL, options: [:]) { success in
            if !success {
                debugPrint("无法在 Finder 中打开路径: \(targetURL.path)")
                UIPasteboard.general.string = fileURL.path
                appKeyWindow?.makeToast("Copied".localStr())
            }
        }
    }
    
    // 导出文件
    @objc func exportAction() {
        
        guard let tempURL = self.origialModel?.mediaPlayURL else { return }
                        
        if kaka_IsMacOS() {
            let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL])
                documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true)
        }else{
            let shareVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if !kaka_IsiPhone() {
                if let exportCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: dataArray.count - 1)) {
                    shareVC.popoverPresentationController?.sourceView = exportCell
                }
            }
            self.present(shareVC, animated: true, completion: nil)
        }
    }
    
    func refreshMusicModel(_ model: MusicItemModel) {
        self.origialModel = model
        self.editModel = model
        self.refreshDataAction()
    }
    
    /// 解析了标签元数据的模型
    var editModel: MusicItemModel?
    
    /// 原始模型
    var origialModel: MusicItemModel!
    
    /// 编辑后的回调
    var onEditCallback: ((MusicItemModel)->Void)?
    
    /// 解析的封面
    var coverImage: UIImage?
    
    /// 文件尺寸
    var fileSize: String = ""
    
    /// 全部元数据
    var footStr: String?
            
    lazy var dataArray: [MeteDataGroupCellModel] = {
        let model1 = MeteDataGroupCellModel(group: .headGroup, headTitle: nil, itemArray: [.headerTag], footTitle: nil)
        let model2 = MeteDataGroupCellModel(group: .basicGroup, headTitle: "*" + "Basic".localStr(), itemArray: [.title, .artist, .album, .coverImage, .lyrics], footTitle: nil)
        
        let autoModel = MeteDataGroupCellModel(group: .audioFinger, headTitle: nil, itemArray: [.audioFinger], footTitle: nil)
        
        let model3 = MeteDataGroupCellModel(group: .otherGroup, headTitle: "Others".localStr(), itemArray: [.year, .genre, .trackNumber, .comment, .channel, .bitRate, .samples], footTitle: nil)
        let model4 = MeteDataGroupCellModel(group: .readonlyGroup, headTitle: "File".localStr(), itemArray: [.fileName, .fileExtension, .fileSize, .fileDuration, .filePath], footTitle: nil)
        return [model1, model2, autoModel, model3, model4]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInset = kaka_IsMacOS() ? UIEdgeInsets(top: 20, left: 0, bottom: playingHeight + 50.ckValue(), right: 0) : UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight + 30.ckValue(), right: 0)
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(MusicTagHeadCell.self, forCellReuseIdentifier: "MusicTagHeadCell")
        view.register(AudioFingerTableViewCell.self, forCellReuseIdentifier: "AudioFingerTableViewCell")
        view.register(MeteDataDetialViewCell.self, forCellReuseIdentifier: "MeteDataDetialViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ExportTableViewCell")
        return view
    }()
        
}

extension MusicTagEditorController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        if groupModel.group == .headGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTagHeadCell", for: indexPath) as! MusicTagHeadCell
            return cell
        } else if groupModel.group == .audioFinger {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AudioFingerTableViewCell", for: indexPath) as! AudioFingerTableViewCell
            cell.title = itemType.titleStr()
            return cell
        }
        else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataDetialViewCell", for: indexPath) as! MeteDataDetialViewCell
#warning("模拟mock数据")
//#if DEBUG
//            cell.update(model: self.editModel, itemType: itemType, coverImage: MusicGenreType.punk.iconImage(), fileSize: self.fileSize)
//#else
            cell.update(model: self.editModel, itemType: itemType, coverImage: self.coverImage, fileSize: self.fileSize)
//#endif
            return cell
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        let clickArray: [MeteDataCellItemType] = [.title, .artist, .album, .genre, .trackNumber, .year]
        if clickArray.contains(itemType) {
            
            let alertController = UIAlertController(title: itemType.titleStr(), message: nil, preferredStyle: .alert)
            let action1 = UIAlertAction(title: "Auto-Match".localStr(), style: .destructive) { (sender) in
                self.audioMatchByAudioID()
            }
            
            let action2 = UIAlertAction(title: "Manual Edit".localStr(), style: .default) { (sender) in
                
                if itemType == .title {
                    self.editTitleAction()
                }
                
                if itemType == .artist {
                    self.editArtistAction()
                }
                
                if itemType == .album {
                    self.editAlbumAction()
                }
                
                if itemType == .genre {
                    self.editGenreAction()
                }
                
                if itemType == .trackNumber {
                    self.editTrackNumberAction()
                }
                
                if itemType == .year {
                    self.editYearAction()
                }
            }
            
            let action3 = UIAlertAction(title: "Cancel".localStr(), style: .cancel) { (sender) in
                
            }
            
            alertController.addAction(action1)
            alertController.addAction(action2)
            alertController.addAction(action3)
            
            self.present(alertController, animated: true, completion: nil)
        }
        
        if itemType == .coverImage {
            self.editArtworkAction()
        }
        
        if itemType == .lyrics {
            self.editLyricsAction()
        }
        
        if itemType == .audioFinger {
            self.audioMatchByAudioID()
        }
        
        if itemType == .comment {
            self.editCommentAction()
        }
        
        if itemType == .filePath {
            self.clickFilePathAction()
        }
        
#warning("模拟mock数据")
//#if DEBUG
//        if itemType == .headerTag {
//            if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
//                tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//                tabbarVC.toolbarView.isHidden = !tabbarVC.toolbarView.isHidden
//                return
//            }
//        }
//#endif
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        return itemType == .coverImage ? 100.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        if groupModel.group == .readonlyGroup {
            return self.footStr
        }else{
            return groupModel.footTitle
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}


extension MusicTagEditorController {
    
    // 0️⃣ 修改封面图
    func editArtworkAction() {
        
        if !UserInfoManager.shared.isVIP() {
            let title = "🫆" + "Auto-Match".localStr()
            let message = "HD 4K cover art and lyrics are Premium metadata features. The free version supports manually editing basic metadata like Title, Artist, and Album. Upgrade to Premium to take your music collection to the next level!".localStr()
            self.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                self.vipCenterClick()
            }
            return
        }
        
        guard let editModel = self.editModel else { return }

        let coverVC = LibraryCoverViewController(editStyle: .recommend(editModel))
        let navVC = KakaNavigationController(rootViewController: coverVC)
        coverVC.onSelectCallback = { [weak self] (releaseModel) in
            if let coverImage = releaseModel.tempImage {
                self?.setNewCoverImage(coverImage)
            }
        }
        
#warning("模拟mock数据")
//#if DEBUG
//        navVC.modalPresentationStyle = .fullScreen
//#endif
        
        self.present(navVC, animated: true)
    }
    
    func setNewCoverImage(_ image: UIImage) {
        
        guard let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }
        
        let success = TaglibMetadataParser.setCoverArt(image, toFileURL: tempURL)
        debugPrint("标签元数据 = \(success)")

        if success {
            SandboxFileManager.shared.writeMusicthumbnailImage(model: editModel, image: image)
            ImageCache.default.clearCache()
            self.refreshDataAction()
            self.onEditCallback?(editModel)
            appKeyWindow?.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideEmmbedFailed()
        }
        
    }
    
    // ✍️编辑歌曲名
    private func editTitleAction() {
        
        guard let oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.title.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.title?.count ?? 0 > 0) ? editModel.title : oldModel.showTitleName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
            
            let baseFileURL: URL = tempURL.deletingLastPathComponent()
            var editModel = oldModel
            editModel.title = nameText
            
            let isSuccess = SandboxFileManager.shared.updateTitleTag(oldModel: oldModel, newTitle: nameText)
            if isSuccess {
                self?.onEditCallback?(editModel)
                self?.origialModel?.title = nameText
                if editModel.handleType != .link  {
                    let mediaPlayStr = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                    self?.origialModel?.mediaPlayURL = URL(fileURLWithPath: mediaPlayStr)
                }
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }

        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑歌手名
    private func editArtistAction() {
        
        guard let oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.artist.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.artist?.count ?? 0 > 0) ? editModel.artist : oldModel.artist
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
            
            let baseFileURL: URL = tempURL.deletingLastPathComponent()
            
            var editModel = oldModel
            editModel.artist = nameText
            
            let isSuccess = SandboxFileManager.shared.updateArtistTag(oldModel: oldModel, newArtist: nameText)
            if isSuccess {
                self?.onEditCallback?(editModel)
                self?.origialModel?.artist = nameText
                if editModel.handleType != .link {
                    let mediaPlayStr = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                    self?.origialModel?.mediaPlayURL = URL(fileURLWithPath: mediaPlayStr)
                }
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
            
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑专辑名
    private func editAlbumAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.album.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.album?.count ?? 0 > 0) ? editModel.album : oldModel.album
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            oldModel.album = nameText
            
            let success = TaglibMetadataParser.setAlbum(nameText, toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
            
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑年代
    private func editYearAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicTagType.year.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let year = (editModel.year ?? 0 > 0) ? editModel.year : oldModel.year
            if let yearStr = year, yearStr > 0 {
                textView.text = "\(yearStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
            
            oldModel.year = nameText
            
            let success = TaglibMetadataParser.setYear(Int32(nameText), toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
            
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 编辑流派
    private func editGenreAction() {
        let genreVC = GenreTypeViewController(self.editModel?.genre)
        genreVC.onSelectCallback = { [weak self] (subGenre) in
            guard let wSelf = self, let filePath = wSelf.origialModel?.mediaPlayURL else { return }
            let success = TaglibMetadataParser.setGenre(subGenre, toFileURL: filePath)
            if success {
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
        }
        
        let navVC = KakaNavigationController(rootViewController: genreVC)
        self.present(navVC, animated: true)
    }
    
    // 写入歌词
    func setLyricContent(_ content: String) {
        
        guard var origialModel = self.editModel else { return }
        
        let success = TaglibMetadataParser.setLyris(content, toFileURL: origialModel.mediaPlayURL)
        if success {
            origialModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content)?.convertSwiftModel()
            self.editModel = origialModel
            self.tableView.reloadData()
            self.onEditCallback?(origialModel)
            
            if content.count > 3 {
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self.guideEmmbedFailed()
            }
        }
        
        debugPrint("写入歌词 = \(success)")
    }
    
    // 编辑音轨号
    private func editTrackNumberAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicTagType.trackNumber.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let track = (editModel.track ?? 0 > 0) ? editModel.track : oldModel.track
            if let trackStr = track, trackStr > 0 {
                textView.text = "\(trackStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
            
            oldModel.track = nameText
            
            let success = TaglibMetadataParser.setTrack(Int32(nameText), toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
            
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 编辑注释
    private func editCommentAction() {
        
        guard var oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicTagType.comment.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = editModel.comment
            
            textView.keyboardType = .default
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text else {
                return
            }
            
            oldModel.comment = nameText
            
            let success = TaglibMetadataParser.setComment(nameText, toFileURL: oldModel.mediaPlayURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                appKeyWindow?.makeToast("Embedded Success".localStr())
                self?.perform(#selector(self?.guideFiveStarRating), with: nil, afterDelay: 2)
            }else{
                self?.guideEmmbedFailed()
            }
            
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 编辑歌词
    func editLyricsAction() {
        guard let editModel = self.editModel else {
            return
        }
        
        if !editModel.isHaveLyric() && !UserInfoManager.shared.isVIP() {
            let title = "🫆" + "Auto-Match".localStr()
            let message = "HD 4K cover art and lyrics are Premium metadata features. The free version supports manually editing basic metadata like Title, Artist, and Album. Upgrade to Premium to take your music collection to the next level!".localStr()
            self.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                self.vipCenterClick()
            }
            return
        }
        
#warning("模拟mock数据")
//#if DEBUG
//        let editVC = SelectLyricViewController(music: editModel, result: nil)
//        let navVC = KakaNavigationController(rootViewController: editVC)
//        navVC.modalPresentationStyle = .automatic
//        self.present(navVC, animated: true)
//#else
        let lyricVC = LyricDetialViewController(editModel: editModel)
        lyricVC.onEditCallback = { [weak self] (newModel) in
            self?.origialModel?.lyricModel = newModel.lyricModel
            self?.refreshDataAction()
            self?.onEditCallback?(newModel)
        }
        
        self.navigationController?.pushViewController(lyricVC, animated: true)
//#endif
        
    }
    
    // 点击文件地址
    func clickFilePathAction() {
        let filePath = self.editModel?.mediaPlayURL.path(percentEncoded: false)
        
        guard let filePath = filePath else { return }
#if targetEnvironment(macCatalyst)
        self.showInFinderCatalyst(URL(fileURLWithPath: filePath))
#else
        UIPasteboard.general.string = filePath
        appKeyWindow?.makeToast("Copied".localStr())
#endif
    }
    
    // 音频指纹识别元数据
    @objc func audioMatchByAudioID() {
        
        if !UserInfoManager.shared.isVIP() {
            let title = "🫆" + "Auto-Match".localStr()
            let message = "No manual editing required! AI Acoustic Fingerprinting analyzes the audio waveform to instantly fetch accurate metadata, 4K artwork, lyrics, and more.".localStr()
            self.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                self.vipCenterClick()
            }
            return
        }
        
        guard let origialModel = self.origialModel else { return }
        
        let recognizerVC = AudioMatchTagViewController(origialModel)
        recognizerVC.onEditCallback = { [weak self] (newModel) in
            self?.origialModel = newModel
            self?.onEditCallback?(newModel)
            self?.refreshDataAction()
        }
        let navVC = KakaNavigationController(rootViewController: recognizerVC)
#warning("模拟mock数据")
//#if DEBUG
//        navVC.modalPresentationStyle = .fullScreen
//#endif
        self.present(navVC, animated: true)
    }
    
    /// 弹出好评
    @objc func guideFiveStarRating() {
#if !DEBUG
        if AppLocalManager.shared.isGuideFiveStar {
            return
        }
        
        AppLocalManager.shared.isGuideFiveStar = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        AppStore.requestReview(in: windowScene)
#endif
    }
    
    /// 内嵌失败的处理
    func guideEmmbedFailed() {
        let title = "Unable to Save".localStr()
        let message = "The file may be corrupted or in an unsupported format. We suggest replacing it with standard MP3, Flac, M4A, or WAV files. You can check the FAQs or send a report to our support.".localStr()
        let action1 = AlertActionConfig(title: "FAQ".localStr(), style: .destructive, actionType: .first)
        let action2 = AlertActionConfig(title: "Send Report".localStr(), style: .default, actionType: .second)
        
        self.showThreeAlert(title: title, message: message, btn1: action1, btn2: action2) { [weak self] type in
            if type == .first {
                let faqVC = FAQsViewController()
                self?.navigationController?.pushViewController(faqVC, animated: true)
            }else{
                self?.handleWithEmail()
            }
        }
    }
    
}

extension MusicTagEditorController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wakemusic".localStr()) Feedback"
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
        
        let canOpenMailScheme = UIApplication.shared.canOpenURL(URL(string: "mailto:")!)
        let mailtoURL = URL(string: "mailto:\(companyEmail)?subject=\(subject)&body=\(messageBody)")!
        
        if !MFMailComposeViewController.canSendMail() {
            
            if canOpenMailScheme {
                // 2️⃣ 打开第三方邮件客户端
                UIApplication.shared.open(mailtoURL)
            }else{
                // 3️⃣ 用户没有任何邮件客户端
                if kaka_IsMacOS() {
                    UIApplication.shared.open(FeedbackURL)
                }else{
                    let feedbackVC = SFSafariViewController(url: FeedbackURL)
                    self.present(feedbackVC, animated: true)
                }
            }
            return
        }
        
        // 1️⃣ 优先使用Apple的邮件客户端
        if canOpenMailScheme && kaka_IsMacOS() {
            UIApplication.shared.open(mailtoURL)
        }else{
            let emailVC = MFMailComposeViewController()
            emailVC.mailComposeDelegate = self
            emailVC.setToRecipients([companyEmail])
            emailVC.setSubject(subject)
            emailVC.setMessageBody(messageBody, isHTML: false)
            self.present(emailVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        if result == .sent {
            self.view.makeToast("Thank you for your feedback".localStr())
        }
        
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
    func getDeviceInformation() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = kaka_IsMacOS() ? "macOS" : device.model
        let appVersion = ((Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "") + "_" + "\(UserInfoManager.shared.isVIP() ? "1" : "0")"
        let fileName = self.origialModel.mediaPlayURL.lastPathComponent
        let allInfo = self.footStr ?? "❌"

        return """
        File Name: \(fileName)
        All Metadata: \(allInfo)
        App Name: \("Wakemusic".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}


// MARK:  其他信息
class MeteDataDetialViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(model: MusicItemModel?, itemType: MeteDataCellItemType, coverImage: UIImage?, fileSize: String?) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        if UserInfoManager.shared.isVIP() || (itemType != .coverImage && itemType != .lyrics) {
            cellConfig.text = itemType.titleStr()
        }else{
            let titleStr = itemType.titleStr() ?? ""

            // 1. 设置基础文字样式（使用系统默认字体或主色调）
            let font = cellConfig.textProperties.font
            let attributedTitle = NSMutableAttributedString(string: titleStr + " ", attributes: [.font: font, .foregroundColor: UIColor.label])
            
            // 2. 创建并配置 Pro 图标附件
            let crownImage = UIImage(named: "pro_crown")!
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = crownImage
            
            // 3. 计算图标尺寸与垂直居中偏移量（Y offset）
            let iconHeight: CGFloat = 14
            let iconWidth: CGFloat = crownImage.size.width * (iconHeight / crownImage.size.height)
            let yOffset = (font.capHeight - iconHeight) / 2.0 // 精准与文字对齐
            
            imageAttachment.bounds = CGRect(x: 0, y: yOffset, width: iconWidth, height: iconHeight)
            
            // 4. 将图标拼接在文案末尾
            let iconString = NSAttributedString(attachment: imageAttachment)
            attributedTitle.append(iconString)
            
            cellConfig.attributedText = attributedTitle
        }
        
        switch itemType {
        case .headerTag: break
        case .coverImage:
            self.accessoryView = self.coverImgView(coverImage)
            self.accessoryType = .none
            break
        case .lyrics:
            let isNoneLyrics = (model?.lyricModel?.lyrics == nil) || (model?.lyricModel?.lyrics?.count == 0)
            self.accessoryView = self.lyricIconView(isNoneLyrics)
            self.accessoryType = .none
            break
        case .title:
            cellConfig.secondaryText = model?.title ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .artist:
            cellConfig.secondaryText = model?.artist ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .album:
            cellConfig.secondaryText = model?.album ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
            
        case .audioFinger:
            cellConfig.secondaryText = nil
            self.accessoryView = nil
            self.accessoryType = .none
            break
            
        case .trackNumber:
            cellConfig.secondaryText = (model?.track ?? 0) > 0 ? "\(model?.track ?? 0)" : ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .comment:
            cellConfig.secondaryText = model?.comment ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .fileName:
            cellConfig.secondaryText = model?.mediaPlayURL.lastPathComponent
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .fileSize:
            cellConfig.secondaryText = fileSize
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .fileDuration:
            if let durationSeconds = model?.durationSeconds, durationSeconds > 0, let durationStr = model?.durationTimeStr() {
                cellConfig.secondaryText = "\(durationSeconds)s" + " = " + durationStr
            }else{
                cellConfig.secondaryText = ""
            }
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .fileExtension:
            cellConfig.secondaryText = model?.mediaPlayURL.pathExtension.uppercased()
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .filePath:
            cellConfig.secondaryText = model?.mediaPlayURL.path(percentEncoded: false)
            self.accessoryView = nil
            self.accessoryType = kaka_IsMacOS() ? .disclosureIndicator : .none
            break
            
        case .bitRate:
            var bitrateStr: String = ""

            if let bitrate = model?.bitrate {
                if bitrate >= 1000 {
                    let bitrateInKbps = Double(bitrate) / 1000.0

                    if bitrateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                        // 整数时去掉小数点
                        bitrateStr = String(format: "%.0f kbps", bitrateInKbps)
                    } else {
                        // 非整数时保留小数点后1位
                        bitrateStr = String(format: "%.1f kbps", bitrateInKbps)
                    }

                }else{
                    bitrateStr = String(format: "%.0f bps", Double(bitrate))
                }
            }else{
                bitrateStr = String(format: "%.0f bps", Double(model?.bitrate ?? 0))
            }
            
            cellConfig.secondaryText = bitrateStr
            
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .samples:
            var sampleRateStr: String = ""
            if let sampleRate = model?.sampleRate {
                if sampleRate >= 1000000 {
                    // 处理 MHz
                    let sampleRateInMHz = Double(sampleRate) / 1000000.0
                    if sampleRateInMHz.truncatingRemainder(dividingBy: 1) == 0 {
                        sampleRateStr = String(format: "%.0f MHz", sampleRateInMHz)
                    } else {
                        sampleRateStr = String(format: "%.1f MHz", sampleRateInMHz)
                    }
                } else if sampleRate >= 1000 {
                    // 处理 kHz
                    let sampleRateInKbps = Double(sampleRate) / 1000.0
                    if sampleRateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                        sampleRateStr = String(format: "%.0f kHz", sampleRateInKbps)
                    } else {
                        sampleRateStr = String(format: "%.1f kHz", sampleRateInKbps)
                    }
                } else {
                    // 处理 Hz 和 mHz
                    if sampleRate < 1000 {
                        // 处理 mHz
                        let sampleRateInMHz = Double(sampleRate) * 1000.0
                        sampleRateStr = String(format: "%.0f mHz", sampleRateInMHz)
                    } else {
                        // 处理 Hz
                        sampleRateStr = String(format: "%.0f Hz", Double(sampleRate))
                    }
                }
            }
            
            cellConfig.secondaryText = sampleRateStr
            
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .channel:
            cellConfig.secondaryText = model?.channel?.formatStr()
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .genre:
            if let genreType = model?.musicGenreType() {
                cellConfig.secondaryText = genreType.formatStr()
            }else{
                cellConfig.secondaryText = model?.genre ?? ""
            }
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .year:
            cellConfig.secondaryText = ((model?.year ?? 0) > 1) ? "\(model?.year ?? 0)" : ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        }
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: self.accessoryType == .disclosureIndicator ? 5 : 15)
        self.contentConfiguration = cellConfig
    }
    
    func createAttributedString(withText text: String, andImage image: UIImage) -> NSAttributedString {
        
        let spaceText = text + "  "
        
        // 创建一个可变的属性字符串
        let attributedString = NSMutableAttributedString(string: spaceText)

        // 设置文本的属性，例如字体和颜色
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIListContentConfiguration.cell().textProperties.font,
            .foregroundColor: UIColor.label
        ]
        attributedString.addAttributes(textAttributes, range: NSRange(location: 0, length: spaceText.count))

        // 创建一个 NSTextAttachment 来存放图片
        let textAttachment = NSTextAttachment()
        textAttachment.image = image

        // 设置图片的大小
        let imageSize = CGSize(width: 30, height: 18) // 根据需要调整图片大小
        textAttachment.bounds = CGRect(x: 0, y: -3.ckValue(), width: imageSize.width, height: imageSize.height)

        // 将图片转换为 NSAttributedString
        let imageAttributedString = NSAttributedString(attachment: textAttachment)

        // 将图片添加到属性字符串的末尾
        attributedString.append(imageAttributedString)

        return attributedString
    }
    
    func coverImgView(_ image: UIImage?) -> UIImageView {
        let isNoneImage = image == nil
        let view = UIImageView(frame: CGRectMake(0, 0, isNoneImage ? 20.ckValue() : 60.ckValue(), isNoneImage ? 20.ckValue() : 60.ckValue()))
        view.image = image ?? Reasource.systemNamed("plus", color: UIColor.red)
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 6.ckValue()
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        if !isNoneImage {
            let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick(_:)))
            view.addGestureRecognizer(clickTap)
        }
        
#if DEBUG
        let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        effectView.frame = view.bounds
        effectView.alpha = 0.58
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(effectView)
#endif
        
        return view
    }
    
    @objc func coverImgViewClick(_ sender: UITapGestureRecognizer) {
        
        guard let coverImgView = sender.view as? UIImageView else { return }
        
        guard let curVC = self.currentViewController() else { return }
        let photoItem = KakaPhotoItem(sourceView: coverImgView, image: coverImgView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: curVC)
    }
    
    func lyricIconView(_ isNoneLyric: Bool) -> UIImageView {
        let view = UIImageView(image: isNoneLyric ? Reasource.systemNamed("exclamationmark.circle.fill", color: UIColor.red) : Reasource.systemNamed("checkmark.circle.fill", color: UIColor.systemGreen))
        view.size = CGSize(width: 20.ckValue(), height: 20.ckValue())
        view.contentMode = .scaleAspectFit
        return view
    }
    
}


class MusicTagHeadCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(starImgView)
        contentView.addSubview(titleLabel)
    }
    
    private func preSetupContains() {
        
        let value = starImgView.image!.size.width / starImgView.image!.size.height
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(self.starSize)
            make.width.equalTo(starImgView.snp.height).multipliedBy(value)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(starImgView.snp.bottom).offset(10.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalTo(5.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview().offset(-5.ckValue())
        }
    }
    
    var starSize: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 120
            case .iPadOS: return 200
            case .macOS: return 120
            }
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("tag.fill"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = MeteDataCellItemType.headerTag.titleStr()
        view.numberOfLines = 0
        view.font = UIFontLight(15.ckValue())
        view.textColor = .secondaryLabel
        view.textAlignment = .center
        return view
    }()
}
