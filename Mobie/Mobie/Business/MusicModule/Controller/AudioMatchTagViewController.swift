//
//  AudioMatchTagViewController.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import StoreKit
import Kingfisher
import MessageUI
import SafariServices
import KSPlayer
import ProgressHUD

protocol AudioMatchTagDelete: AnyObject {
    
    // 封面
    func audioMatchArtworkClickCover(coverView: AudioMatchCoverFootView, artwork: UIImage)
    
    // 其他标签
    func audioMatchTagClickType(cellType: MeteDataCellItemType, model: AudioFingerprintModel)
}

/// 自动识别页面
class AudioMatchTagViewController: SuperViewController {
    
    init(_ model: MusicItemModel) {
        super.init(nibName: nil, bundle: nil)
        self.model = model
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupSubViews()
        self.viewDidLayoutSubviews()
        self.handleBuness()
    }
    
    func setupSubViews() {
        contentView.addSubview(tableView)
        contentView.addSubview(embeddedButton)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
        
        let bottomSpace = kaka_IsMacOS() ? 25.ckValue() : 12.ckValue()
                    
        contentView.addSubview(embeddedButton)
        embeddedButton.snp.remakeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide.snp.centerX)
            make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(20.ckValue())
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-bottomSpace)
            make.height.equalTo(embeddedButton.layer.cornerRadius * 2)
        }
    }
    
    func handleBuness() {
        self.title = "Auto-Match".localStr()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        
        self.refreshDataAction()
        
        self.handleAudioMetadata()
    }
    
    func refreshDataAction() {
        
        let metaModel = TaglibMetadataParser.readMetadata(withFileURL: self.model.mediaPlayURL, read: .all)
        self.coverImage = metaModel?.coverArt
        self.tableView.reloadData()
        
        self.musicMatcher.matchLocalAudio(model: model) { result in
            switch result {
            case .success(let model):
                self.isAutoMatched = true
                self.embeddedButton.isHidden = false
                self.tagsModel = model
                self.tableView.reloadData()
                break
            case .failure(let failure):
                self.isAutoMatched = false
                self.embeddedButton.isHidden = true
                self.tableView.reloadData()
                self.showOneAlert(message: failure.errorDescription)
                break
            }
        }
    }
    
    // 处理内嵌元数据
    @MainActor func handleAudioMetadata() {
        guard let playingMusic = self.model else { return }
        
        let currentOption = KakaMusicPlayer.shared.audioOption(playingMusic)
        KSOptions.firstPlayerType = KSMEPlayer.self
        currentOption.playerTypes = [KSMEPlayer.self]
        
        DispatchQueue.global().async {
            do {
                let metadata = try FFmpegUtility.getMetadata(for: playingMusic.mediaPlayURL, options: currentOption)
                debugPrint("ffmpeg元数据 = \(metadata.metadata), 封面宽 = \(metadata.coverImage?.width ?? 0)")
                DispatchQueue.main.async {
                    self.footStr = metadata.metadata
                        .sorted { ($0.key + $0.value).count < ($1.key + $1.value).count }
                        .map { "▶️\($0.key): \($0.value)" }
                        .joined(separator: "\n")
                }
            } catch {
                debugPrint("解析内嵌元数据失败 = \(error.localizedDescription)")
            }
        }
        
    }
    
    
    // MARK: GET && SET
    var model: MusicItemModel!
    
    var isAutoMatched: Bool?
    var tagsModel: AudioFingerprintModel?
    
    /// 编辑后的回调
    var onEditCallback: ((MusicItemModel)->Void)?
    
    /// 解析的封面
    var coverImage: UIImage?
    
    /// 全部内嵌的信息
    var footStr: String?
    
    // MARK: 懒加载
    lazy var musicMatcher: AudioFingerprintMatcher = {
        return AudioFingerprintMatcher()
    }()
    
    lazy var tagEditor: MusicTagEditor = {
        return MusicTagEditor()
    }()
                
    lazy var dataArray: [MeteDataCellItemType] = {
        return [.coverImage, .title, .artist, .album, .year, .genre, .trackNumber, .lyrics]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInset = kaka_IsMacOS() ? UIEdgeInsets(top: 20, left: 0, bottom: playingHeight + 50.ckValue(), right: 0) : UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight + 30.ckValue(), right: 0)
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(MeteDataDetialViewCell.self, forCellReuseIdentifier: "MeteDataDetialViewCell")
        view.register(AudioMatchCoverFootView.self, forHeaderFooterViewReuseIdentifier: "AudioMatchCoverFootView")
        view.register(AudioMatchTagFootView.self, forHeaderFooterViewReuseIdentifier: "AudioMatchTagFootView")
        view.register(AudioMatchLyricsFootView.self, forHeaderFooterViewReuseIdentifier: "AudioMatchLyricsFootView")
        return view
    }()
    
    lazy var embeddedButton: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = appMainColor
        view.layer.cornerRadius = 25.ckValue()
        
        // 1. 创建内部排列的栈视图
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6.ckValue() // 完美的间距控制
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.isUserInteractionEnabled = false // 让事件穿透到父视图
        
        // 2. 内部组件
        let imgView = UIImageView(image: UIImage(systemName: "touchid"))
        imgView.tintColor = .white
        
        let label = UILabel()
        label.text = "Embed All".localStr()
        label.textColor = .white
        label.font = UIFontBold(17.ckValue())
        
        stackView.addArrangedSubview(imgView)
        stackView.addArrangedSubview(label)
        
        // 3. 布局堆栈
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // 4. 阴影
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 5, height: 5)
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 6
        
        // 5. 点击手势
        let tap = UITapGestureRecognizer(target: self, action: #selector(embeddedAllMetadata))
        view.addGestureRecognizer(tap)
        
        return view
    }()
    
}

extension AudioMatchTagViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellType = dataArray[indexPath.section]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataDetialViewCell", for: indexPath) as! MeteDataDetialViewCell
#warning("模拟mock数据")
//#if DEBUG
//        cell.update(model: self.model, itemType: cellType, coverImage: nil, fileSize: nil)
//#else
        cell.update(model: self.model, itemType: cellType, coverImage: self.coverImage, fileSize: nil)
//#endif
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cellType = dataArray[indexPath.section]
                
        if cellType == .coverImage {
            self.manual_editArtworkAction()
        }
        
        if cellType == .title {
            self.manual_editTitleAction()
        }
        
        if cellType == .artist {
            self.manual_editArtistAction()
        }
        
        if cellType == .album {
            self.manual_editAlbumAction()
        }
        
        if cellType == .trackNumber {
            self.manual_editTrackNumberAction()
        }
        
        if cellType == .year {
            self.manual_editYearAction()
        }
        
        if cellType == .genre {
            self.manual_editGenreAction()
        }
        
        if cellType == .lyrics {
            self.manual_editLyricAction()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellType = dataArray[indexPath.section]
        
        return cellType == .coverImage ? 100.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let cellType = dataArray[section]
        if cellType == .coverImage {
            return kaka_IsMacOS() ? 66 : 80.ckValue()
        }else if cellType == .lyrics {
            return 120.ckValue()
        }else{
            return kaka_IsMacOS() ? 35 : 45.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let cellType = dataArray[section]
        if cellType == .coverImage {
            let footView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "AudioMatchCoverFootView") as! AudioMatchCoverFootView
            footView.delegate = self
            if let isAutoMatched = self.isAutoMatched, !isAutoMatched {
                footView.setupFailedStatus()
            }else{
                footView.update(cellType: cellType, model: self.tagsModel)
            }
            return footView
        }else if cellType == .lyrics {
            let footView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "AudioMatchLyricsFootView") as! AudioMatchLyricsFootView
            footView.delegate = self
            if let isAutoMatched = self.isAutoMatched, !isAutoMatched {
                footView.setupFailedStatus()
            }else{
                footView.update(cellType: cellType, model: self.tagsModel)
            }
            return footView
        }else{
            let footView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "AudioMatchTagFootView") as! AudioMatchTagFootView
            footView.delegate = self
            if let isAutoMatched = self.isAutoMatched, !isAutoMatched {
                footView.setupFailedStatus()
            }else{
                footView.update(cellType: cellType, model: self.tagsModel)
            }
            return footView
        }
    }
}

extension AudioMatchTagViewController: AudioMatchTagDelete {
    
    // 封面
    func audioMatchArtworkClickCover(coverView: AudioMatchCoverFootView, artwork: UIImage) {
        self.auto_editArtworkAction(artwork)
    }
    
    // 内嵌回调
    func audioMatchTagClickType(cellType: MeteDataCellItemType, model: AudioFingerprintModel) {
        
        if cellType == .title, let title = model.title, !title.isEmpty {
            self.auto_editTitleAction(title)
        }
        
        if cellType == .artist, let artist = model.artist, !artist.isEmpty {
            self.auto_editArtistAction(artist)
        }
        
        if cellType == .album, let album = model.album, !album.isEmpty {
            self.auto_editAlbumAction(album)
        }
        
        if cellType == .genre, let genres = model.genres, !genres.isEmpty {
            self.auto_editGenreAction(genres)
        }
        
        if cellType == .year, let year = model.year, year > 0 {
            self.auto_editYearAction(year)
        }
        
        if cellType == .trackNumber, let track = model.trackNumber, track > 0 {
            self.auto_editTrackNumberAction(track)
        }
        
        if cellType == .lyrics {
            self.auto_editLyricAction(model)
        }
        
    }
    
}

extension AudioMatchTagViewController {
    
    /// 填充全部元数据
    @objc func embeddedAllMetadata() {
        
        guard let _ = self.tagsModel else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
//#if DEBUG
//        let fileURL = self.model.mediaPlayURL
//        TaglibMetadataParser.setTitle("", toFileURL: fileURL)
//        TaglibMetadataParser.setArtist("", toFileURL: fileURL)
//        TaglibMetadataParser.setAlbum("", toFileURL: fileURL)
//        TaglibMetadataParser.setLyris("", toFileURL: fileURL)
//        TaglibMetadataParser.setCoverArt(nil, toFileURL: fileURL)
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            self.refreshDataAction()
//        }
//
//        return
//#endif
        
        if !UserInfoManager.shared.isVIP() {
            let message = "Say goodbye to tedious manual typing! Upgrade to Premium to automatically fix tags, fetch 4K artwork, and download lyrics via instant audio fingerprinting. Or, you can choose to continue editing manually.".localStr()
            let action1 = AlertActionConfig(title: "Unlock Premium".localStr(), style: .destructive, actionType: .first)
            let action2 = AlertActionConfig(title: "Manual Edit".localStr(), style: .default, actionType: .second)
            self.showThreeAlert(message: message, btn1: action1, btn2: action2) { [weak self] actionType in
                if actionType == .first {
                    self?.vipCenterClick()
                }
            }
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        let configVC = AutoEditConfigViewController()
        configVC.onSelectBlock = { [weak self] (config) in
            self?.startEditBarClick(config)
        }
        configVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .overFullScreen
        self.present(configVC, animated: false)
    }
    
    func startEditBarClick(_ config: AutoEditConfig) {
        guard let tagsModel = self.tagsModel, let model = self.model else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        // 1. 禁用交互并显示 HUD
        self.view.isUserInteractionEnabled = false
        ProgressHUD.animate("Processing...".localStr())
        
        // 2. 使用 Task 开启异步上下文
        Task { [weak self] in
            guard let self = self else { return }
            
            // 核心异步调用：顺序等待后台写入标签 + 文件重命名完成
            let (newModel, errorTags) = await self.tagEditor.embeddedAllMetadata(
                model: model,
                tagsModel: tagsModel,
                config: config
            )
            
            // 3. 恢复 UI 状态（确保回到主线程）
            await MainActor.run {
                self.view.isUserInteractionEnabled = true
                ProgressHUD.dismiss()
                
                // 4. 处理错误或成功提示
                if let errorTags = errorTags, !errorTags.isEmpty {
                    let tagErrMsg = errorTags.map { $0.titleStr() }.joined(separator: ", ")
                    let message = tagErrMsg + "\r\n" + "Failed to embed some tags. The file might be corrupted. Try editing manually or replacing it with a new file.".localStr()
                    self.showOneAlert(message: message)
                } else {
                    var autoEditFileCount = UserInfoManager.shared.autoEditFileCount
                    autoEditFileCount += 1
                    UserInfoManager.shared.autoEditFileCount = autoEditFileCount
                    
                    self.view.makeToast("Embedded Success".localStr())
                    self.perform(#selector(self.guideFiveStarRating), with: nil, afterDelay: 2)
                }
                
                // 5. 更新本地模型与回调刷新
                self.model = newModel
                self.onEditCallback?(newModel)
                self.refreshDataAction()
            }
        }
    }
    
    // 1️⃣ 手动编辑封面
    func manual_editArtworkAction() {
        guard var editModel = self.model else { return }
        editModel.title = self.tagsModel?.title ?? editModel.title
        editModel.artist = self.tagsModel?.artist ?? editModel.artist
        
        let coverVC = LibraryCoverViewController(editStyle: .recommend(editModel))
        coverVC.onSelectCallback = { [weak self] (releaseModel) in
            if let coverImage = releaseModel.tempImage {
                self?.auto_editArtworkAction(coverImage)
            }
        }
        self.navigationController?.pushViewController(coverVC, animated: true)
    }
    
    // 自动写入封面
    func auto_editArtworkAction(_ image: UIImage) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        guard let model = self.model else { return }

        let success = TaglibMetadataParser.setCoverArt(image, toFileURL: model.mediaPlayURL)
        debugPrint("标签元数据 = \(success)")

        if success {
            self.view.makeToast("Embedded Success".localStr())
            self.coverImage = image
            SandboxFileManager.shared.writeMusicthumbnailImage(model: model, image: image)
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
            return
        }
        
        ImageCache.default.clearCache()
        self.onEditCallback?(model)
        self.tableView.reloadData()
    }
    
    // 2️⃣ 手动编辑标题
    private func manual_editTitleAction() {
        
        let editAlertVC = UIAlertController(title: MusicActionType.title.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (self.model.title?.count ?? 0 > 0) ? self.model.title : self.model.showTitleName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            self?.auto_editTitleAction(nameText)
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    /// 自动编辑标题
    private func auto_editTitleAction(_ newName: String) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        let baseFileURL: URL = self.model.mediaPlayURL.deletingLastPathComponent()

        guard var editModel = self.model else { return }
        editModel.title = newName
        
        let isSuccess = SandboxFileManager.shared.updateTitleTag(oldModel: self.model, newTitle: newName)
        if isSuccess {
            self.onEditCallback?(editModel)
            self.model?.title = newName
            if editModel.handleType != .link  {
                let mediaPlayStr = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                self.model?.mediaPlayURL = URL(fileURLWithPath: mediaPlayStr)
            }
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }

    }
    
    /// 3️⃣ 手动编辑艺术家
    private func manual_editArtistAction() {
        
        let editAlertVC = UIAlertController(title: MusicActionType.artist.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (self.model.artist?.count ?? 0 > 0) ? self.model.artist : self.model.showArtistName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            self?.auto_editArtistAction(nameText)
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    /// 自动编辑艺术家
    private func auto_editArtistAction(_ newName: String) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        let baseFileURL: URL = self.model.mediaPlayURL.deletingLastPathComponent()

        guard var editModel = self.model else { return }
        editModel.artist = newName
        
        let isSuccess = SandboxFileManager.shared.updateArtistTag(oldModel: self.model, newArtist: newName)
        if isSuccess {
            self.onEditCallback?(editModel)
            self.model?.artist = newName
            if editModel.handleType != .link  {
                let mediaPlayStr = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                self.model?.mediaPlayURL = URL(fileURLWithPath: mediaPlayStr)
            }
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }

    }
    
    /// 4️⃣ 手动编辑专辑
    private func manual_editAlbumAction() {
        
        let editAlertVC = UIAlertController(title: MusicActionType.album.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = self.model.album
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            self?.auto_editAlbumAction(nameText)
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    /// 自动编辑专辑
    private func auto_editAlbumAction(_ newName: String) {

        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        guard var editModel = self.model else { return }
        editModel.album = newName
        
        let isSuccess = TaglibMetadataParser.setAlbum(newName, toFileURL: self.model.mediaPlayURL)
        if isSuccess {
            self.onEditCallback?(editModel)
            self.model?.album = newName
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }

    }
    
    /// 5️⃣ 手动编辑年代
    private func manual_editYearAction() {
        
        let editAlertVC = UIAlertController(title: MusicTagType.year.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let year = self.model.year
            if let yearStr = year, yearStr > 0 {
                textView.text = "\(yearStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let yearInt = nameField.text?.ocString.integerValue, yearInt > 0 else {
                return
            }
            
            self?.auto_editYearAction(yearInt)
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    /// 自动编辑年代
    private func auto_editYearAction(_ year: Int) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        guard var editModel = self.model else { return }
        editModel.year = year
        
        let isSuccess = TaglibMetadataParser.setYear(Int32(year), toFileURL: self.model.mediaPlayURL)
        if isSuccess {
            self.onEditCallback?(editModel)
            self.model?.year = year
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }

    }
    
    /// 5️⃣ 手动编辑流派
    func manual_editGenreAction() {
        let genreVC = GenreTypeViewController(self.model.genre)
        genreVC.onSelectCallback = { [weak self] (subGenre) in
            self?.auto_editGenreAction(subGenre)
        }
        
        self.navigationController?.pushViewController(genreVC, animated: true)
    }
    
    /// 自动编辑流派
    func auto_editGenreAction(_ genre: String) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        guard var editModel = self.model else { return }
        editModel.genre = genre
        
        let success = TaglibMetadataParser.setGenre(genre, toFileURL: self.model.mediaPlayURL)
        if success {
            self.onEditCallback?(editModel)
            self.model.genre = genre
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }
    }
    
    /// 6️⃣ 手动编辑音轨号
    private func manual_editTrackNumberAction() {
        
        let editAlertVC = UIAlertController(title: MusicTagType.trackNumber.titleStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let track = self.model.track
            if let trackStr = track, trackStr > 0 {
                textView.text = "\(trackStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let yearInt = nameField.text?.ocString.integerValue, yearInt > 0 else {
                return
            }
            
            self?.auto_editTrackNumberAction(yearInt)
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    /// 自动编辑音轨号
    private func auto_editTrackNumberAction(_ trackNumber: Int) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        guard var editModel = self.model else { return }
        editModel.track = trackNumber
        
        let isSuccess = TaglibMetadataParser.setTrack(Int32(trackNumber), toFileURL: self.model.mediaPlayURL)
        if isSuccess {
            self.onEditCallback?(editModel)
            self.model?.track = trackNumber
            self.refreshDataAction()
            self.view.makeToast("Embedded Success".localStr())
            self.perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)
        }else{
            self.guideFiveStarRating()
        }

    }
    
    /// 7️⃣ 自动选择歌词
    func auto_editLyricAction(_ result: AudioFingerprintModel) {
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if UserInfoManager.shared.isFreeTrail {
            if UserInfoManager.shared.autoEditFileCount >= 10 {
                let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr(), cancle: "Manual Edit".localStr()) {
                    self.vipCenterClick()
                }
                return
            }
        }
        
        let lyricVC = SelectLyricViewController(music: self.model, result: result)
        lyricVC.onSelectBlock = { [weak self] (lyricModel) in
            guard let wSelf = self else { return }
            let isSuccess = TaglibMetadataParser.setLyris(lyricModel.toLyricString(), toFileURL: wSelf.model.mediaPlayURL)
            if isSuccess {
                wSelf.view.makeToast("Embedded Success".localStr())
                wSelf.model.lyricModel = lyricModel
                wSelf.onEditCallback?(wSelf.model)
                wSelf.tableView.reloadData()
            }else{
                wSelf.guideFiveStarRating()
            }
        }
        self.navigationController?.pushViewController(lyricVC, animated: true)
    }
    
    // 手动编辑歌词
    func manual_editLyricAction() {
        let editVC = LyricEditorViewController(musicModel: self.model)
        editVC.title = self.model.filePathName()
        editVC.editCallBack = { [weak self] (lyricModel) in
            guard let wSelf = self else { return }
            let isSuccess = TaglibMetadataParser.setLyris(lyricModel.toLyricString(), toFileURL: wSelf.model.mediaPlayURL)
            if isSuccess {
                wSelf.view.makeToast("Embedded Success".localStr())
                wSelf.model.lyricModel = lyricModel
                wSelf.onEditCallback?(wSelf.model)
                wSelf.tableView.reloadData()
            }else{
                wSelf.guideEmmbedFailed()
            }
        }
        self.navigationController?.pushViewController(editVC, animated: true)
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

extension AudioMatchTagViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
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
        let fileName = self.model.mediaPlayURL.lastPathComponent
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
