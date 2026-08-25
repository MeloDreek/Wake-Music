//
//  LibraryCoverViewController.swift
//  Waketag
//
//  Created by Melo on 11/26/24.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit
import KakaPhotoBrowser
import PhotosUI
import ZLImageEditor

enum CoverGalleryStyle: Equatable {
    case preview   // 预览
    case select    // 选择
    case recommend(MusicItemModel) // 推荐封面
}

/// 封面库
class LibraryCoverViewController: SuperViewController, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
    
    struct SearchParameter {
        var title: String = ""
        var artist: String = ""
    }
    
    deinit {
        APIManager.shared.frontSession.cancelAllRequests()
    }
    
    init(editStyle: CoverGalleryStyle) {
        self.editStyle = editStyle
        switch editStyle {
        case .preview:
            break
        case .select:
            break
        case .recommend(let model):
            self.model = model
            break
        }
        
        super.init(nibName: nil, bundle: nil)
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
        
        self.configSearchBar()
                
        self.title = "Cover Library".localStr()
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        self.view.backgroundColor = self.tableView.backgroundColor
        
        self.localUrlArray = SandboxFileManager.shared.coverPathURL().readLocalSubFiles()
        self.tableView.reloadData()
        
        guard let model = self.model else { return }
        
        guard let title = model.title, !title.isEmpty, let artist = model.artist, !artist.isEmpty else {
            
            self.isRequesting = true
            self.tableView.reloadData()
            
            self.fetchMusicMeteData { result in
                switch result {
                case .success(let success):
                    self.refreshDataAction(title: success.title, artist: success.artist, album: model.album)
                    break
                case .failure(let failure):
                    self.isRequesting = false
                    self.tableView.reloadData()
                    self.showOneAlert(message: failure.errorDescription)
                    break
                }
            }
            return
        }
        
        // 直接搜索
        self.refreshDataAction(title: title, artist: artist, album: model.album)
    }
    
    
    func refreshDataAction(title: String, artist: String, album: String?) {
        
        self.isRequesting = true
        self.tableView.reloadData()
        
        self.requestCoverAction(title: title, artist: artist, album: album) {
            self.isRequesting = false
            self.tableView.reloadData()
        }
    }
    
    // 获取指纹信息
    func fetchMusicMeteData(completion: @escaping (Result<SearchParameter, KakaError>) -> Void) {
        guard let model = self.model else {
            completion(.failure(.custom("Please edit manually".localStr())))
            return
        }
        
        self.musicMatcher.matchLocalAudio(model: model, isRequestLyrics: false) { result in
            switch result {
            case .success(let success):
                guard let title = success.title, !title.isEmpty, let artist = success.artist, !artist.isEmpty else {
                    completion(.failure(.custom(self.normalError)))
                    return
                }
                
                let parameter = SearchParameter(title: title, artist: artist)
                completion(.success(parameter))
                break
            case .failure(let failure):
                completion(.failure(failure))
                break
            }
        }
    }
    
    // 首次加载封面
    func requestCoverAction(title: String, artist: String, album: String?, completion: (()->Void)? = nil) {
        MusicTagEditor.shared.requestITunesAlbumImages(title: title, artist: artist) { result in
            switch result {
            case .success(let models):
                self.remoteUrlArray = models
                if let coverArt = self.model?.coverArt {
                    var curModel = MusicReleaseModel()
                    curModel.tempImage = coverArt
                    curModel.title = artist
                    if let year = self.model?.year {
                        curModel.date = "\(year)"
                    }
                    self.remoteUrlArray.insert(curModel, at: 0)
                }
                completion?()
            case .failure(_):
                self.retryRefreshDataAction(album: album, artist: artist, completion: completion)
                break
            }
        }
    }
    
    // 再次加载封面
    func retryRefreshDataAction(album: String?, artist: String, completion: (()->Void)? = nil) {
        MusicTagEditor.shared.requestITunesAlbumImages(title: album ?? "", artist: artist) { result in
            switch result {
            case .success(let models):
                self.remoteUrlArray = models
                if let coverArt = self.model?.coverArt {
                    var curModel = MusicReleaseModel()
                    curModel.tempImage = coverArt
                    curModel.title = artist
                    if let year = self.model?.year {
                        curModel.date = "\(year)"
                    }
                    self.remoteUrlArray.insert(curModel, at: 0)
                }
                completion?()
            case .failure(_):
                self.isRequesting = false
                self.tableView.reloadData()
                self.showOneAlert(message: self.normalError)
                break
            }
        }
    }
    
    // MARK:  GET && SET
    
    var editStyle: CoverGalleryStyle = .preview
    
    var model: MusicItemModel?
    
    var onSelectCallback: ((MusicReleaseModel)->Void)?
    
    var isRequesting: Bool = true
    
    let normalError = "Audio fingerprint generated, but no matching track was found in global music databases. It may be an unreleased edit or remix, often related to unique waveform characteristics. Please edit manually.".localStr()
    
    // MARK:  懒加载
    
    lazy var musicMatcher: AudioFingerprintMatcher = {
        return AudioFingerprintMatcher()
    }()
    
    // 本地封面路径
    lazy var localUrlArray: [URL] = {
        return [URL]()
    }()
    
    lazy var remoteUrlArray: [MusicReleaseModel] = {
        return [MusicReleaseModel]()
    }()
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()
    
    lazy var dataArray: [CoverGalleryCellModel] = {
        let model1 = CoverGalleryCellModel(group: .headGroup, headTitle: nil, footTitle: nil)
        let model2 = CoverGalleryCellModel(group: .selectImage, headTitle: nil, footTitle: nil)
        let model3 = CoverGalleryCellModel(group: .audioFinger, headTitle: "🫆 "  + "Audio Fingerprint".localStr(), footTitle: nil)
        let model4 = CoverGalleryCellModel(group: .localGroup, headTitle: "Cached Files".localStr(), footTitle: nil)
        
        switch self.editStyle {
        case .preview:
            return [model1, model4]
        case .select:
            return [model1, model2, model4]
        case .recommend(let string):
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: Reasource.systemNamed("photo.on.rectangle"), style: .plain, target: self, action: #selector(cameraItemsAction))
            return [model1, model3, model4]
        }
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.register(CoverGalleryHeadCell.self, forCellReuseIdentifier: "CoverGalleryHeadCell")
        view.register(SelectCameraImageCell.self, forCellReuseIdentifier: "SelectCameraImageCell")
        view.register(GalleryEmptyViewCell.self, forCellReuseIdentifier: "GalleryEmptyViewCell")
        view.register(CoverGalleryTableCell.self, forCellReuseIdentifier: "CoverGalleryTableCell")
        return view
    }()
    
    @objc func cameraItemsAction() {
        
        if kaka_IsMacOS() {
            var imageArray = [UTType.png, UTType.jpeg, UTType.image, UTType.tiff, UTType.heif, UTType.heic, UTType.webP]
            if #available(iOS 18.0, *) {
                imageArray += [UTType.heics, UTType.exr]
            }
            
            let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: imageArray, asCopy: false)
            documentVC.delegate = self
            documentVC.allowsMultipleSelection = false
            documentVC.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            documentVC.shouldShowFileExtensions = true
            self.present(documentVC, animated: true)
        }else{
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited || kaka_IsMacOS() {
                        
                        var config = PHPickerConfiguration()
                        config.filter = .images
                        config.selectionLimit = 1
                        config.preferredAssetRepresentationMode = .current
                        
                        let picker = PHPickerViewController(configuration: config)
                        picker.delegate = self
                        self.present(picker, animated: true)
                    }else{
                        self.showOneAlert(message: "You have denied access to the album, please re-enable it.".localStr(), confirm: "Settings".localStr()) {
                            guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(vURL)
                        }
                    }
                }
            }
        }
        
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let imageURL = urls.first, let newImage = UIImage(contentsOfFile: imageURL.path) else { return }
        
        var model = MusicReleaseModel()
        model.tempImage = newImage
        
        self.onSelectCallback?(model)
        self.cancelButtonClick()
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let itemProvider = results.first?.itemProvider else { return }
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
                
        itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { object, error in
            guard let image = object as? UIImage else { return }
            
            DispatchQueue.main.async { [weak self] () in
                if kaka_IsMacOS() {
                    var model = MusicReleaseModel()
                    model.tempImage = image
                    
                    self?.onSelectCallback?(model)
                    self?.cancelButtonClick()
                    return
                }
                
                ZLImageEditorConfiguration.default()
                    .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                    .adjustTools([.brightness, .contrast, .saturation])
                    .clipRatios([.wh1x1, .wh4x3])
                    .showClipDirectlyIfOnlyHasClipTool(true)
                
                ZLEditImageViewController.showEditImageVC(parentVC: self, image: image) { [weak self] newImage, model in
                    var model = MusicReleaseModel()
                    model.tempImage = newImage
                    
                    self?.onSelectCallback?(model)
                    self?.cancelButtonClick()
                }
            }
            
        })
    }
    
}

extension LibraryCoverViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let groupModel = dataArray[section]
        if groupModel.group == .headGroup {
            return 1
        }else if groupModel.group == .selectImage {
            return 1
        } else if groupModel.group == .audioFinger {
            return remoteUrlArray.count > 0 ? remoteUrlArray.count : 1
        }else{
            return self.localUrlArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupModel = dataArray[indexPath.section]
        if groupModel.group == .headGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CoverGalleryHeadCell", for: indexPath) as! CoverGalleryHeadCell
            
            return cell
        }else if groupModel.group == .audioFinger {
            if remoteUrlArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CoverGalleryTableCell", for: indexPath) as! CoverGalleryTableCell
                cell.updateRemote(remoteModel: remoteUrlArray[indexPath.row], isSelect: false)
                cell.onClickBlock = { [weak self] (coverCell) in
                    guard let wSelf = self else { return }
                    let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
                    let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
                    photoBrowser.backgroundStyle = .blurPhoto
                    photoBrowser.show(from: wSelf)
                    
                    wSelf.removeLongGesture(photoBrowser)
                }
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "GalleryEmptyViewCell", for: indexPath) as! GalleryEmptyViewCell
                cell.isRequesting = self.isRequesting
                return cell
            }
        }else if groupModel.group == .selectImage {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectCameraImageCell", for: indexPath) as! SelectCameraImageCell
            
            return cell
        }else{
            let subURL = localUrlArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "CoverGalleryTableCell", for: indexPath) as! CoverGalleryTableCell
            cell.onClickBlock = { [weak self] (coverCell) in
                guard let wSelf = self else { return }
                let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
                let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
                photoBrowser.backgroundStyle = .blurPhoto
                photoBrowser.show(from: wSelf)
                
                wSelf.removeLongGesture(photoBrowser)
            }
            cell.coverURL = subURL
#warning("模拟mock数据")
//#if DEBUG
//            let name = "singer_\(indexPath.row)"
//            cell.coverImgView.image = Reasource.singerImage(name)
//            cell.nameLabel.text = "Singer 00\(indexPath.row + 1).png"
//#endif
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let groupModel = dataArray[indexPath.section]
        
        if groupModel.group == .selectImage {
            self.cameraItemsAction()
        }
        
        if groupModel.group == .localGroup || groupModel.group == .audioFinger {
            
            guard let imageCell = tableView.cellForRow(at: indexPath) as? CoverGalleryTableCell else { return }
            if self.editStyle != .preview {
                if !UserInfoManager.shared.isVIP() {
                    let message = "Say goodbye to tedious manual typing! Upgrade to Premium to automatically fix tags, fetch 4K artwork, and download lyrics via instant audio fingerprinting. Or, you can choose to continue editing manually.".localStr()
                    let action1 = AlertActionConfig(title: "Unlock Premium".localStr(), style: .destructive, actionType: .first)
                    let action2 = AlertActionConfig(title: "Manual Edit".localStr(), style: .default, actionType: .second)
                    self.showThreeAlert(message: message, btn1: action1, btn2: action2) { actionType in
                        if actionType == .first {
                            self.vipCenterClick()
                        }else{
                            self.cameraItemsAction()
                        }
                    }
                    return
                }
                
                guard let image = imageCell.coverImgView.image else {
                    imageCell.coverImgView.kaka_playAnimation()
                    return
                }
                
                var model = (groupModel.group == .localGroup) ? MusicReleaseModel() : remoteUrlArray[indexPath.row]
                model.tempImage = image
                
                self.onSelectCallback?(model)
                self.cancelButtonClick()
            }else{
                let photoItem = KakaPhotoItem(sourceView: imageCell.coverImgView, image: imageCell.coverImgView.image)
                let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
                photoBrowser.backgroundStyle = .blurPhoto
                photoBrowser.show(from: self)
                                
                self.removeLongGesture(photoBrowser)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.footTitle
    }
    
    func removeLongGesture(_ photoBrowser: KakaPhotoBrowser) {
        if UserInfoManager.shared.isVIP() {
            return
        }
        
        if let gestureRecognizers = photoBrowser.view.gestureRecognizers {
            for subGen in gestureRecognizers {
                if subGen is UILongPressGestureRecognizer {
                    photoBrowser.view.removeGestureRecognizer(subGen)
                }
            }
        }
    }
}

// MARK: 封面Cell
class CoverGalleryTableCell: UITableViewCell {
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
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
        
#warning("模拟mock数据")
//        coverImgView.addSubview(blurEffectView)
    }
    
    func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.leading.equalTo(kaka_IsMacOS() ? 10 : 18.ckValue())
            make.size.equalTo(kaka_IsMacOS() ? 40 : 50.ckValue())
            make.centerY.equalToSuperview()
            make.top.equalTo(kaka_IsMacOS() ? 8 : 15.ckValue())
        }
        
#warning("模拟mock数据")
//        blurEffectView.snp.makeConstraints { make in
//            make.edges.equalToSuperview()
//        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImgView.snp.trailing).offset(10.ckValue())
            make.trailing.equalToSuperview().offset(-5.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.centerY.equalTo(coverImgView.snp.centerY).offset(-descLabel.font.lineHeight / 2)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.height.greaterThanOrEqualTo(0)
            make.top.equalTo(nameLabel.snp.bottom)
        }
    }
    
    func preSetupHandleBuness() {
        self.selectionStyle = .default
        self.accessoryType = .disclosureIndicator
    }
    
    var onClickBlock: ((CoverGalleryTableCell)->Void)?
    
    var coverURL: URL? {
        didSet {
            guard let coverURL = self.coverURL else {
                return
            }
            
            coverImgView.kf.setImage(with: coverURL, placeholder: nil)
            nameLabel.text = coverURL.lastPathComponent
            descLabel.text = coverURL.fileSizeString
        }
    }
    
    func updateRemote(remoteModel: MusicReleaseModel, isSelect: Bool) {
        let placeImage = remoteModel.tempImage ?? MusicConfigManager.shared.musicPlaceImage
        coverImgView.kf.setImage(with: remoteModel.coverImageURL(), placeholder: placeImage)
        nameLabel.text = remoteModel.title
        if let year = remoteModel.releaseYear()?.year {
            descLabel.text = "\(year)"
        }else{
            descLabel.text = remoteModel.itunesModel?.primaryGenreName ?? "N/A"
        }
        
        self.accessoryType = isSelect ? .none : .disclosureIndicator
        self.accessoryView = isSelect ? self.selectIconView : .none
    }
    
    @objc func coverImgViewClick() {
        self.onClickBlock?(self)
    }
    
    func update(webImage:UIImage, title: String?) {
        coverImgView.image = webImage
        nameLabel.text = title
        descLabel.text = URL.formatFileSize(Int64(webImage.pngData()?.count ?? 0))
    }
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = .separator
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
#warning("模拟mock数据")
//#if DEBUG
//    lazy var blurEffectView: UIVisualEffectView = {
//        let blurEffect = UIBlurEffect(style: .extraLight)
//        let view = UIVisualEffectView(effect: blurEffect)
//        view.frame = self.coverImgView.bounds
//        view.alpha = 0.5
//        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        return view
//    }()
//#endif
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.numberOfLines = 1
        view.font = kaka_IsMacOS() ? UIListContentConfiguration.cell().textProperties.font : UIFontBold(15.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.font = kaka_IsMacOS() ? UIListContentConfiguration.cell().secondaryTextProperties.font : UIFontLight(12.ckValue())
        view.textAlignment = nameLabel.textAlignment
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var selectIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle.fill", color: .systemGreen))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        return view
    }()
    
}

// MARK: 头部Cell
class CoverGalleryHeadCell: UITableViewCell {
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
        var image: UIImage
        if #available(iOS 16.0, *) {
            image = Reasource.systemNamed("photo.stack")
        }else{
            image = Reasource.systemNamed("photo.on.rectangle")
        }
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = "Album covers after parsing of local music files, you can reuse these images to quickly fill music files with missing covers.".localStr()
        view.textAlignment = .center
        view.font = kaka_IsMacOS() ? UIFontLight(15) : UIFontBold(15.ckValue())
        view.textColor = kaka_IsMacOS() ? .label : .secondaryLabel
        return view
    }()
    
}

class SelectCameraImageCell: UITableViewCell {
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
        
    }
    
    func preSetupContains() {
        
    }
    
    func preSetupHandleBuness() {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.image = UIImage(systemName: "camera.fill")
        cellConfig.text = "Select Image".localStr()
        cellConfig.textProperties.color = .label
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
        self.contentConfiguration = cellConfig
        
        self.accessoryType = .disclosureIndicator
    }
   
}
