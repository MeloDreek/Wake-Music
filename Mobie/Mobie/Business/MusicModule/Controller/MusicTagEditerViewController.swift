//
//  MusicTagEditerViewController.swift
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
class MusicTagEditerViewController: SuperViewController {
    init(_ model: MusicItemModel? = nil) {
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
        
        if self.isPresent() {
            let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
            self.navigationItem.leftBarButtonItem = cancelItem
        }
        
        self.navigationItem.rightBarButtonItem = self.searchItem
        
        if (self.origialModel.mediaPlayURL as NSURL).isReadOnly() {
            (self.origialModel.mediaPlayURL as NSURL).setReadableAndWritable()
        }
        
        self.refreshDataAction()
                
    }
    
    func refreshDataAction() {
        
        if self.origialModel.fileSourceType == .demoFile {
            self.coverImage = self.origialModel.coverArt
            self.editModel = self.origialModel
            self.tableView.reloadData()
            return
        }
        
        let fileURL = self.origialModel.mediaPlayURL
        let metaModel = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
                
        self.fileSize = fileURL.fileSizeString
        self.coverImage = metaModel?.coverArt
        self.editModel = metaModel?.mergeTagLibInfo(self.origialModel) ?? self.origialModel
        
//        self.ffmpegGetMetadata(fileURL)
                
#warning("模拟mock数据")
//#if DEBUG
//        let language = PhoneSetManager.formatLanguage()
//        let isChinese = language == .chinese_simplified || language == .chinese_traditional || language == .japanese || language == .tailand || language == .malay || language == .yinni || language == .korean || language == .yuenan
//
//        self.coverImage = UIImage(named: isChinese ? "Genre_pusa" : "Genre_Jesus")
//        self.editModel?.title = isChinese ? "地藏菩萨本愿经" : "Holy Bible"
//        self.editModel?.artist = isChinese ? "Buddha" : "Jesus"
//        self.editModel?.album = isChinese ? "佛音" : "Holy Bible"
//        self.editModel?.year = 2000
//        self.editModel?.track = 1
//        self.editModel?.comment = "Wake Music".localStr()
//        self.editModel?.channel = .surround51
//        self.editModel?.genre = MusicGenreType.gospel.rawValue
//        
//        self.origialModel = self.editModel
//#endif
        
        self.tableView.reloadData()
    }
    
    @objc func cancelBarClick() {
        if self.isPresent() {
            (self.navigationController ?? self)?.dismiss(animated: true)
        }else{
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // 提取完整的音乐标签元数据
    func ffmpegGetMetadata(_ downloadURL: URL) {
        
        DispatchQueue.main.async {
            let currentOption = KSOptions()
            KSOptions.firstPlayerType = KSMEPlayer.self
            currentOption.playerTypes = [KSMEPlayer.self]
            
            DispatchQueue.global().async {
                do {
                    let metadata = try FFmpegUtility.getMetadata(for: downloadURL, options: currentOption)
                    debugPrint("ffmpeg元数据 = \(metadata.metadata), 封面宽 = \(metadata.coverImage?.width ?? 0)")
                    DispatchQueue.main.async {
                        self.handleAudioMetadata(metadata)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.fullFootStr = "❌" + error.localizedDescription
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    // 处理内嵌元数据
    @MainActor func handleAudioMetadata(_ infoModel: VideoInfo) {
        
        self.fullFootStr = infoModel.metadata
            .sorted { ($0.key + $0.value).count < ($1.key + $1.value).count }
            .map { "▶️\($0.key): \($0.value)" }
            .joined(separator: "\n")
        
        self.tableView.reloadData()
    }
    
    lazy var searchItem: UIBarButtonItem = {
        #if targetEnvironment(macCatalyst)
        let item = UIBarButtonItem(title: "AI", menu: self.aiMenu)
        return item
        #else
        let item = UIBarButtonItem(image: UIImage(systemName: "sparkle.magnifyingglass"), menu: self.aiMenu)
        return item
        #endif
    }()
    
    lazy var aiMenu: UIMenu = {

        var actionArray = [UIAction]()
        
        for subItem in AIType.allTypes() {
            let iconImage = subItem.iconImage()?.kaka_reSize(reSize: CGSizeMake(30.ckValue(), 30.ckValue()))
            let subMenu = UIAction(title: subItem.titleStr(), image: iconImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                
                self?.searchWithAIReminder(subItem)
            })
            
            actionArray.append(subMenu)
        }
                
        let addMenu = UIMenu(title: kaka_IsMacOS() ? "" : "AI", children: actionArray)
        return addMenu
    }()
    
    // 点击AI前往搜索，复制文本
    func searchWithAIReminder(_ aiType: AIType) {
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        guard let title = self.editModel?.title, !title.isEmpty, let artist = self.editModel?.artist, !artist.isEmpty else {
            self.showOneAlert(title: "Reminder".localStr(), message: "Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr())
            return
        }
        
        let searchContent = String(format: "Song: [%@], Artist: [%@]. Please send me the album name, release date, genre, track number, and most importantly, the full LRC lyrics. This is strictly for personal local music organization and tag editing. Thank you!".localStr(), title, artist)
        UIPasteboard.general.string = searchContent
        self.showOneAlert(title: "Reminder".localStr(), message: searchContent, confirm: "Copy Text".localStr()) {
            if kaka_IsMacOS() {
                if let vURL2 = aiType.websiteURL().1 {
                    UIApplication.shared.open(vURL2)
                }
                return
            }
            
            guard let vURL1 = aiType.websiteURL().0 else { return }
            
            UIApplication.shared.open(vURL1, options: [:]) { finish in
                if !finish {
                    if let vURL2 = aiType.websiteURL().1 {
                        UIApplication.shared.open(vURL2)
                    }
                }
            }
        }
    }
    
    @objc func shareAction() {
        
        let tempURL = self.origialModel.mediaPlayURL
                        
#if targetEnvironment(macCatalyst)
        let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL])
            documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true)
#else
        let shareVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if !kaka_IsiPhone() {
            if let exportCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: dataArray.count - 1)) {
                shareVC.popoverPresentationController?.sourceView = exportCell
            }
        }
        self.present(shareVC, animated: true, completion: nil)
#endif
        
    }
    
    
    

    
    /// 解析了标签元数据的模型
    var editModel: MusicItemModel!
    
    /// 原始模型
    var origialModel: MusicItemModel!
    
    /// 编辑后的回调
    var onEditCallback: ((MusicItemModel)->Void)?
    
    /// 解析的封面
    var coverImage: UIImage?
    
    /// 文件尺寸
    var fileSize: String = ""
    
    /// 全部音乐标签信息
    var fullFootStr: String = ""
    
    lazy var dataArray: [MeteDataGroupCellModel] = {
        let model1 = MeteDataGroupCellModel(group: .headGroup, headTitle: nil, itemArray: [.headerTag], footTitle: nil)
        let model2 = MeteDataGroupCellModel(group: .basicGroup, headTitle: "*" + "Basic".localStr(), itemArray: [.title, .artist, .album, .coverImage, .lyrics], footTitle: nil)
        
        let isChinese = PhoneSetManager.formatLanguage() == .chinese_simplified || PhoneSetManager.localPhoneCountry() == .chinese
        let baseAIArray: [AIType] = isChinese ? [.deepseek] : [.chatGPT, .Gemini]
        var allAIStr = baseAIArray.map({ $0.titleStr() })
        
        allAIStr.append("Apple Music API")
        if !isChinese {
            allAIStr.append("MusicBrainz")
        }
        var AIFooter = allAIStr.joined(separator: " & ")
        if UserInfoManager.shared.isVIP() {
            AIFooter = AIFooter + "\r" + "Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr()
        }
        
        let model3 = MeteDataGroupCellModel(group: .searchAI, headTitle: "Album Cover & Lyrics".localStr(), itemArray: [.searchAI], footTitle: nil)
        let model4 = MeteDataGroupCellModel(group: .otherGroup, headTitle: "Others".localStr(), itemArray: [.year, .genre, .track, .comment, .channel, .bitRate, .samples], footTitle: nil)
        
        var itemArray5: [MeteDataCellItemType] = [.fileName, .fileExtension, .fileSize, .fileDuration, .filePath]
        if self.origialModel.fileSourceType == .demoFile {
            itemArray5.removeLast()
        }
        let model5 = MeteDataGroupCellModel(group: .readonlyGroup, headTitle: "File".localStr(), itemArray: itemArray5, footTitle: nil)
        
        let model6 = MeteDataGroupCellModel(group: .exportGroup, headTitle: nil, itemArray: [.export], footTitle: self.fullFootStr)
        return kaka_IsMacOS() ? [model2, model3, model4, model5, model6] : [model1, model2, model3, model4, model5, model6]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 15 : 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.register(MusicTagHeadCell.self, forCellReuseIdentifier: "MusicTagHeadCell")
        view.register(MeteDataDetialViewCell.self, forCellReuseIdentifier: "MeteDataDetialViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ExportTableViewCell")
        return view
    }()
    
}

extension MusicTagEditerViewController: UITableViewDataSource, UITableViewDelegate {
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
        } else if groupModel.group == .exportGroup || groupModel.group == .searchAI {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            #if !targetEnvironment(macCatalyst)
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
            #endif
            cellConfig.textProperties.color = UIColor.deAccent
            cellConfig.textProperties.alignment = .center
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
            cell.backgroundColor = appMainColor
            cell.accessoryType = .none
            cell.contentConfiguration = cellConfig
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataDetialViewCell", for: indexPath) as! MeteDataDetialViewCell
            cell.update(model: self.editModel, itemType: itemType, coverImage: self.coverImage, fileSize: self.fileSize)
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        if itemType == .headerTag {
#warning("模拟mock数据")
//#if DEBUG
//            if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
//                tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//                tabbarVC.toolbarView.isHidden = !tabbarVC.toolbarView.isHidden
//            }
//#endif
        }
        
        if itemType == .lyrics {
            self.clickModifyLyricAction()
        }else{
            if self.origialModel.fileSourceType == .demoFile {
                self.tableView.kaka_playShakeAnim()
                self.view.makeToast("Demo audio is read-only and cannot be edited".localStr())
                return
            }
        }
                
        if itemType == .coverImage {
            self.clickModifyCover()
        }
        
        if itemType == .title {
            self.editSongTitleAction()
        }
        
        if itemType == .artist {
            self.editArtistAction()
        }
        
        if itemType == .album {
            self.editAlbumNameAction()
        }
        
        if itemType == .searchAI {
            self.musicRecognitionAction()
        }
        
        if itemType == .year {
            self.editYearAction()
        }
        
        if itemType == .track {
            self.editTrackAction()
        }
        
        if itemType == .comment {
            self.editCommentAction()
        }
        
        if itemType == .genre {
            self.editGenreAction()
        }
        
        if itemType == .filePath {
            var filePath: String?
            if #available(iOS 16.0, *) {
                filePath = self.editModel?.mediaPlayURL.path(percentEncoded: false)
            }else{
                filePath = self.editModel?.mediaPlayURL.path
            }
            
            guard let filePath = filePath else { return }
#if targetEnvironment(macCatalyst)
            KakaMusicPlayer.shared.showInFinderCatalyst(URL(fileURLWithPath: filePath))
#else
            UIPasteboard.general.string = filePath
            self.view.makeToast("Copied".localStr())
#endif
        }
        
        if itemType == .export {
            self.shareAction()
        }
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
        return groupModel.group == .exportGroup ? self.fullFootStr : groupModel.footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}


extension MusicTagEditerViewController: UIDocumentPickerDelegate {
    
    // 点击AI搜索
    func musicRecognitionAction() {
        
        guard var editModel = self.editModel else { return }
        
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        guard let title = editModel.title, !title.isEmpty else {
            let titleCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: kaka_IsMacOS() ? 0 : 1))
            titleCell?.kaka_playShakeAnim()
            self.view.makeToast("Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr())
            return
        }
        
        let searchVC = SearchTagViewController(model: editModel, isOnlyLyric: false)
        searchVC.onDoneBlock = { [weak self] (releaseModel, lyricModel) in
            
            var isSuccess: Bool = false
            let dispatchGroup = DispatchGroup()
            
            if let lyricModel = lyricModel, let lyricContent = lyricModel.toLyricString() {
                dispatchGroup.enter()
                let success = TaglibMetadataParser.setLyris(lyricContent, toFileURL: editModel.mediaPlayURL)
                if success {
                    editModel.lyricModel = lyricModel
                }
                
                isSuccess = success
                dispatchGroup.leave()
            }
            
            // 选择封面带来的其他信息
            if let releaseModel = releaseModel {
                
                if let coverImage = releaseModel.tempImage {
                    dispatchGroup.enter()
                    let success = TaglibMetadataParser.setCoverArt(coverImage, toFileURL: editModel.mediaPlayURL)
                    isSuccess = success
                    if success {
                        debugPrint("写入封面成功 = \(coverImage.pngData()?.count ?? 0)")
                        SandboxFileManager.shared.writeMusicthumbnailImage(model: editModel, image: coverImage) { vURL in
                            ImageCache.default.clearCache()
                            dispatchGroup.leave()
                        } fail: { error in
                            ImageCache.default.clearCache()
                            dispatchGroup.leave()
                        }
                    }else{
                        dispatchGroup.leave()
                    }
                }
                
                if let genre = releaseModel.itunesModel?.primaryGenreName, self?.editModel?.genre == nil {
                    dispatchGroup.enter()
                    let success = TaglibMetadataParser.setGenre(genre, toFileURL: editModel.mediaPlayURL)
                    if success {
                        editModel.genre = genre
                    }
                    dispatchGroup.leave()
                }
                
                if let year = releaseModel.releaseYear()?.year, self?.editModel?.year == nil {
                    dispatchGroup.enter()
                    let success = TaglibMetadataParser.setYear(Int32(year), toFileURL: editModel.mediaPlayURL)
                    if success {
                        editModel.year = year
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) { [weak self] () in
                
                if var editModel = self?.editModel {
                    editModel.lyricModel = lyricModel
                    editModel.coverArt = releaseModel?.tempImage

                    self?.coverImage = releaseModel?.tempImage ?? self?.coverImage
                    self?.editModel = editModel
                    self?.onEditCallback?(editModel)
                }
                
                if isSuccess {
                    self?.view.makeToast("Embedded Success".localStr())
                    self?.perform(#selector(self?.showFiveStarReview), with: nil, with: 2)
                    if editModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                        KakaMusicPlayer.shared.playingMusic = editModel
                    }
                }

                self?.tableView.reloadData()

            }
            
        }
        let navVC = KakaNavigationController(rootViewController: searchVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
        
    }
    
    @objc func showFiveStarReview() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    // 0️⃣ 修改封面图
    func clickModifyCover() {
        
        guard let editModel = self.editModel else { return }
                
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        let coverVC = CoverGalleryViewController(editStyle: .recommend(editModel))
        let navVC = KakaNavigationController(rootViewController: coverVC)
        coverVC.onSelectCallback = { [weak self] (releaseModel) in
            // 选择封面带来的其他信息
            if let genre = releaseModel.itunesModel?.primaryGenreName, self?.editModel?.genre == nil, let tempURL = self?.origialModel?.mediaPlayURL {
                TaglibMetadataParser.setGenre(genre, toFileURL: tempURL)
            }
            
            if let year = releaseModel.releaseYear()?.year, let tempURL = self?.origialModel?.mediaPlayURL, self?.editModel?.year == nil {
                TaglibMetadataParser.setYear(Int32(year), toFileURL: tempURL)
            }
            
            if let coverImage = releaseModel.tempImage {
                self?.editCoverImage(coverImage)
            }
        }
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    func editCoverImage(_ image: UIImage) {
        
        guard let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }
        
        let success = TaglibMetadataParser.setCoverArt(image, toFileURL: tempURL)
        debugPrint("标签元数据 = \(success)")

        if success {
            self.view.makeToast("Embedded Success".localStr())
            SandboxFileManager.shared.writeMusicthumbnailImage(model: editModel, image: image)
            if editModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                KakaMusicPlayer.shared.playingMusic = editModel
            }
            self.showFiveStarReview()
        }else{
            self.view.makeToast("Embedded Failed".localStr())
            return
        }
        
        
        ImageCache.default.clearCache()
        self.refreshDataAction()
        self.onEditCallback?(editModel)
        
    }
    
    // ✍️编辑歌曲名
    private func editSongTitleAction() {
        
        guard let oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.title.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.title?.count ?? 0 > 0) ? editModel.title : oldModel.showTitleName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            var editModel = oldModel
            editModel.title = nameText
            
            let success = SandboxFileManager.shared.updateTitleTag(oldModel: oldModel, newTitle: nameText)
            if success {
                
                self?.origialModel?.title = nameText
                self?.view.makeToast("Embedded Success".localStr())
                
                self?.refreshDataAction()
                self?.onEditCallback?(editModel)
                self?.showFiveStarReview()
                
                if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = self?.origialModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                
            }else{
                self?.origialModel?.title = oldModel.title
                self?.showEmbeddedFailed()
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑歌手名
    private func editArtistAction() {
        
        guard let oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.artist.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.artist?.count ?? 0 > 0) ? editModel.artist : oldModel.artist
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            var editModel = oldModel
            editModel.artist = nameText
            
            let success = SandboxFileManager.shared.updateArtistTag(oldModel: oldModel, newArtist: nameText)
            if success {
                
                self?.origialModel.artist = nameText
                self?.view.makeToast("Embedded Success".localStr())

                self?.refreshDataAction()
                self?.onEditCallback?(editModel)
                self?.showFiveStarReview()
                
                if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = self?.origialModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                
            }else{
                self?.origialModel?.artist = oldModel.artist
                self?.showEmbeddedFailed()
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑专辑名
    private func editAlbumNameAction() {
        
        guard let oldModel = self.origialModel, let tempURL = self.origialModel?.mediaPlayURL else { return }
        guard let editModel = self.editModel else { return }
        
        let editAlertVC = UIAlertController(title: MusicActionType.album.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.album?.count ?? 0 > 0) ? editModel.album : oldModel.album
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
                        
            let success = TaglibMetadataParser.setAlbum(nameText, toFileURL: tempURL)
            self?.origialModel.album = success ? nameText : oldModel.album
            
            if success {
                
                self?.view.makeToast("Embedded Success".localStr())
                self?.refreshDataAction()
                self?.onEditCallback?(editModel)
                self?.showFiveStarReview()
                
                // 如果当前编辑的封面是正在播放的歌曲，更新播放歌曲
                if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = self?.origialModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                
            }else{
                self?.showEmbeddedFailed()
            }
            
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑流派
    @objc func editGenreAction() {
        let genreVC = GenreTypeViewController(self.origialModel?.musicGenreType())
        genreVC.onSelectCallback = { [weak self] (subGenre) in
            guard let wSelf = self, let filePath = wSelf.origialModel?.mediaPlayURL else { return }
            
            wSelf.editModel.genre = subGenre.rawValue
            
            let success = TaglibMetadataParser.setGenre(subGenre.rawValue, toFileURL: filePath)
            
            self?.origialModel.genre = success ? subGenre.rawValue : self?.origialModel.genre

            if success {
                self?.view.makeToast("Embedded Success".localStr())
                self?.showFiveStarReview()
                
                // 如果当前编辑的封面是正在播放的歌曲，更新播放歌曲
                if self?.origialModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = self?.origialModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: wSelf.origialModel, oldFileName: wSelf.origialModel.filePathName())
                self?.refreshDataAction()
            }else{
                self?.showEmbeddedFailed()
            }
            
        }
        
        let navVC = KakaNavigationController(rootViewController: genreVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 编辑音轨号
    private func editTrackAction() {
        
        guard let oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: "Track Number".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let track = (editModel.track ?? 0 > 0) ? editModel.track : oldModel.track
            if let trackStr = track, trackStr > 0 {
                textView.text = "\(trackStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
                        
            let success = TaglibMetadataParser.setTrack(Int32(nameText), toFileURL: oldModel.mediaPlayURL)
            self?.origialModel.track = success ? Int(nameText) : oldModel.track
            
            if success {
                self?.view.makeToast("Embedded Success".localStr())
                self?.showFiveStarReview()
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                self?.refreshDataAction()
                
            }else{
                self?.showEmbeddedFailed()
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 编辑评论
    private func editCommentAction() {
        
        guard let oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: "Comment".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let comment = (editModel.comment?.count ?? 0 > 0) ? editModel.comment : oldModel.comment
            
            textView.text = comment
            
            textView.keyboardType = .default
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text else {
                return
            }
                        
            let success = TaglibMetadataParser.setComment(nameText, toFileURL: oldModel.mediaPlayURL)
            self?.origialModel.comment = success ? nameText : oldModel.comment
            
            if success {
                self?.view.makeToast("Embedded Success".localStr())
                self?.showFiveStarReview()
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                self?.refreshDataAction()
                
            }else{
                self?.showEmbeddedFailed()
            }
            
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑年代
    private func editYearAction() {

        guard let oldModel = self.origialModel else { return }
        guard let editModel = self.editModel else { return }
        
        let editAlertVC = UIAlertController(title: "Year".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let year = (editModel.year ?? 0 > 0) ? editModel.year : oldModel.year
            if let yearStr = year, yearStr > 0 {
                textView.text = "\(yearStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
            
            guard let wSelf = self else { return }
            
            let success = TaglibMetadataParser.setYear(Int32(nameText), toFileURL: wSelf.origialModel.mediaPlayURL)
            self?.origialModel.year = success ? nameText : oldModel.year
            
            if success {
                self?.view.makeToast("Embedded Success".localStr())
                self?.showFiveStarReview()
                
                // 如果当前编辑的封面是正在播放的歌曲，更新播放歌曲
                if oldModel.filePathName() == KakaMusicPlayer.shared.playingMusic?.filePathName() {
                    KakaMusicPlayer.shared.playingMusic = self?.origialModel
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.origialModel, oldFileName: oldModel.filePathName())
                self?.refreshDataAction()
            }else{
                self?.showEmbeddedFailed()
            }
                                    
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // 点击歌词Cell
    func clickModifyLyricAction() {
        let lyricVC = LyricDetialViewController(editModel: self.editModel)
        lyricVC.onEditCallback = { [weak self] (newModel) in
            self?.origialModel?.lyricModel = newModel.lyricModel
            self?.refreshDataAction()
            self?.onEditCallback?(newModel)
        }
        
        self.navigationController?.pushViewController(lyricVC, animated: true)
    }
    
    func showEmbeddedFailed() {
        self.showOneAlert(title: "Embedded Failed".localStr(), message: "This format does not have music tags. We recommend using mainstream music formats like FLAC, M4A, or MP3.".localStr(), confirm: "OK".localStr())
    }
    
}

// MARK:  邮箱联系
extension MusicTagEditerViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wake Music".localStr()) Feedback"
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
        
        let canOpenMailScheme = UIApplication.shared.canOpenURL(URL(string: "mailto:")!)
        let mailtoURL = URL(string: "mailto:\(companyEmail)?subject=\(subject)&body=\(messageBody)")!
        
        if !MFMailComposeViewController.canSendMail() {
            
            if canOpenMailScheme {
                // 2️⃣ 打开第三方邮件客户端
                UIApplication.shared.open(mailtoURL)
            }else{
                // 3️⃣ 用户没有任何邮件客户端
                let message = "No email app installed?".localStr()
                let action1 = AlertActionConfig(title: companyEmail, style: .destructive, actionType: .first)
                let action2 = AlertActionConfig(title: kaka_IsMacOS() ? "Gmail" : "App Store", style: .default, actionType: .second)
                
                self.showThreeAlert(message: message, btn1: action1, btn2: action2) { [weak self] type in
                    if type == .first {
                        UIPasteboard.general.string = companyEmail
                        self?.view?.makeToast("Copied".localStr())
                    }else{
                        guard let vURL = URL(string: emailAppURL) else { return }
                        UIApplication.shared.open(vURL)
                    }
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
        let allInfo = self.fullFootStr

        return """
        File Name: \(fileName)
        All Metadata: \(allInfo)
        App Name: \("Wake Music".localStr())
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
    
    
    func update(model: MusicItemModel?, itemType: MeteDataCellItemType, coverImage: UIImage?, fileSize: String) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.text = itemType.titleStr()
        
        switch itemType {
        case .headerTag: break
        case .searchAI: break
        case .coverImage:
            if !UserInfoManager.shared.isVIP() && (model?.fileSourceType != .demoFile) {
                cellConfig.text = nil
                cellConfig.attributedText = self.createAttributedString(withText: itemType.titleStr() ?? "", andImage: UIImage(named: "pro_crown")!)
            }
            coverImgView.image = coverImage ?? model?.placeImage()
            self.accessoryView = self.coverImgView
            self.accessoryType = .none
            break
        case .lyrics:
            if !UserInfoManager.shared.isVIP() && (model?.fileSourceType != .demoFile) {
                cellConfig.text = nil
                cellConfig.attributedText = self.createAttributedString(withText: itemType.titleStr() ?? "", andImage: UIImage(named: "pro_crown")!)
            }
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
        case .track:
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
            if #available(iOS 16.0, *) {
                cellConfig.secondaryText = model?.mediaPlayURL.path(percentEncoded: false)
            }else{
                cellConfig.secondaryText = model?.mediaPlayURL.path
            }
            self.accessoryView = nil
            self.accessoryType = kaka_IsMacOS() ? .disclosureIndicator : .none
            break
            
        case .bitRate:
            var bitrateStr: String = ""

            if let bitrate = model?.bitrate {
                if bitrate >= 1000000 {
                    // 大于等于 1 Mbps
                    let bitrateInMbps = Double(bitrate) / 1000000.0
                    bitrateStr = String(format: "%.1f Mbps", bitrateInMbps)
                }else if bitrate >= 1000 {
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
            if model?.addPathExtension().uppercased().contains("DTS") ?? false {
                cellConfig.secondaryText = AudioChannels.surround71.formatStr()
            }else{
                cellConfig.secondaryText = model?.channel?.formatStr()
            }
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
        case .export:
            break
        }
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: self.accessoryType == .disclosureIndicator ? 5 : 15)
        self.contentConfiguration = cellConfig
    }
    
    func createAttributedString(withText text: String, andImage image: UIImage) -> NSAttributedString {
        
        let spaceText = text + "  "
        let imageValue = image.size.height / image.size.width
        let textFont = UIListContentConfiguration.cell().textProperties.font
        
        // 创建一个可变的属性字符串
        let attributedString = NSMutableAttributedString(string: spaceText)

        // 设置文本的属性，例如字体和颜色
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.label
        ]
        attributedString.addAttributes(textAttributes, range: NSRange(location: 0, length: spaceText.count))

        // 创建一个 NSTextAttachment 来存放图片
        let textAttachment = NSTextAttachment()
        textAttachment.image = image

        // 设置图片的大小
        let imageSize = CGSize(width: textFont.lineHeight / imageValue, height: textFont.lineHeight)
        textAttachment.bounds = CGRect(x: 0, y: -3.ckValue(), width: imageSize.width, height: imageSize.height)

        // 将图片转换为 NSAttributedString
        let imageAttributedString = NSAttributedString(attachment: textAttachment)

        // 将图片添加到属性字符串的末尾
        attributedString.append(imageAttributedString)

        return attributedString
    }
    
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(frame: CGRectMake(0, 0, 60.ckValue(), 60.ckValue()))
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 6.ckValue()
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    func lyricIconView(_ isNoneLyric: Bool) -> UIImageView {
        let view = UIImageView(image: isNoneLyric ? Reasource.systemNamed("plus", color: UIColor.red) : Reasource.systemNamed("checkmark.circle.fill", color: UIColor.systemGreen))
        view.size = CGSize(width: 20.ckValue(), height: 20.ckValue())
        view.contentMode = .scaleAspectFit
        return view
    }
    
    @objc func coverImgViewClick() {
        if kaka_IsMacOS() { return }
        guard let curVC = self.currentViewController() else { return }
        let photoItem = KakaPhotoItem(sourceView: self.coverImgView, image: self.coverImgView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: curVC)
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
        self.addSubview(starImgView)
        self.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let value = starImgView.image!.size.width / starImgView.image!.size.height
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(height)
            make.width.equalTo(starImgView.snp.height).multipliedBy(value)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview()
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("tag.fill", color: appMainColor))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.text = MeteDataCellItemType.headerTag.titleStr()
        view.font = UIFontLight(15.ckValue())
        view.textAlignment = .center
        return view
    }()
    
}

