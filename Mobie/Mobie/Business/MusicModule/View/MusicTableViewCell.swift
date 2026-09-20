//
//  MusicTableViewCell.swift
//  Wakemusic
//
//  Created by Melo on 7/26/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import FilesProvider
import Kingfisher

protocol MusicTableViewCellDelegate: AnyObject {
    // cell操作
    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType)
}

// MARK:  文件cell
class MusicTableViewCell: UITableViewCell {
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: kAppThemeColorChangedKey), object: nil)
        NotificationCenter.default.removeObserver(self, name: .playbackArtworkCached, object: nil)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.hanldeBessness()
        NotificationCenter.default.addObserver(self, selector: #selector(playbackArtworkCached(_:)), name: .playbackArtworkCached, object: nil)
    }

    @objc private func playbackArtworkCached(_ notification: Notification) {
        guard let model = musicModel, let key = notification.object as? String,
              key == model.artworkCacheKey() else { return }
        // Refresh badges/accessory too: a successful write resolves a missing tag.
        update(musicModel: model, cellType: cellType)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImgView.kf.cancelDownloadTask()
        coverImgView.image = nil
        musicModel = nil
        isPlaying = false
        loadingBgView.isHidden = true
    }

    private static let artworkCache: ImageCache = {
        let cache = ImageCache(name: "MusicListThumbnails.v2")
        cache.memoryStorage.config.totalCostLimit = 24 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 200
        return cache
    }()

    private func loadArtwork(_ model: MusicItemModel, url: URL? = nil, modifier: AnyModifier? = nil) {
        coverImgView.kf.cancelDownloadTask()
        let url = url ?? model.coverThumbnailURL()
        let side: CGFloat = kaka_IsMacOS() ? 35 : 44.ckValue()
        var options: KingfisherOptionsInfo = [
            .processor(DownsamplingImageProcessor(size: CGSize(width: side, height: side))),
            .scaleFactor(traitCollection.displayScale),
            .targetCache(Self.artworkCache)
        ]
        if let modifier { options.append(.requestModifier(modifier)) }
        // Never synchronously load an original cover as a placeholder. Local
        // JPEGs already live on disk; only their small decoded thumbnails need RAM.
        let placeholder = model.placeImage()
        if url.isFileURL {
            guard FileManager.default.fileExists(atPath: url.path) else {
                coverImgView.image = placeholder
                return
            }
            let revision = MusicArtworkCache.revision(at: url)
            let provider = LocalFileImageDataProvider(fileURL: url, cacheKey: model.artworkCacheKey() + ":" + revision)
            options.append(.cacheMemoryOnly)
            coverImgView.kf.setImage(with: .provider(provider), placeholder: placeholder, options: options)
        } else {
            coverImgView.kf.setImage(with: url, placeholder: placeholder, options: options)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(taglistView)
        
        #if targetEnvironment(macCatalyst)
        contentView.addSubview(timeLabel)
        #endif
        
        coverImgView.addSubview(loadingBgView)
        coverImgView.addSubview(blurEffectView)
        if let loadingView = loadingView {
            loadingBgView.addSubview(loadingView)
        }
    }
    
    private func preSetupContains() {
        
        coverImgView.snp.makeConstraints { make in
            make.top.equalTo(kaka_IsMacOS() ? 8 : 12.ckValue())
            make.leading.equalTo(kaka_IsMacOS() ? 8 : 15.ckValue())
            make.size.equalTo(kaka_IsMacOS() ? 35 : 44.ckValue())
            make.centerY.equalToSuperview()
        }
        
#if targetEnvironment(macCatalyst)
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(5.ckValue())
            make.size.greaterThanOrEqualTo(0)
            make.centerY.equalToSuperview()
        }
#endif
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImgView.snp.trailing).offset(10.ckValue())
#if targetEnvironment(macCatalyst)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-5.ckValue())
#else
            make.trailing.equalToSuperview().offset(-5.ckValue())
#endif
            make.height.greaterThanOrEqualTo(nameLabel.font.lineHeight)
            make.centerY.equalTo(coverImgView.snp.centerY).offset(-descLabel.font.lineHeight / 2)
        }
        
        taglistView.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(self)
            make.height.lessThanOrEqualTo(descLabel.font.lineHeight * 1.2)
            make.top.equalTo(nameLabel.snp.bottom).offset(3.ckValue())
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.height.greaterThanOrEqualTo(descLabel.font.lineHeight)
            make.top.equalTo(nameLabel.snp.bottom)
        }
        
        loadingBgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if let loadingView = self.loadingView {
            loadingView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(loadingView.size)
            }
        }
        
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
    }
    
    func hanldeBessness() {
        self.accessoryType = .none
        self.selectionStyle = .default
        
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        let isPause = KakaMusicPlayer.shared.playbackStatus == .paused
        
        self.loadingView?.stopAnimating()
        self.loadingView = nil
        self.loadingView = NVActivityIndicatorView(frame: CGRectMake(0, 0, 22.ckValue(), 22.ckValue()), type: AppLocalManager.shared.playAnimation.nvType(), color: .white)
        if let loadingView = self.loadingView {
            loadingBgView.addSubview(loadingView)
            loadingView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(loadingView.size)
            }
            loadingView.startAnimating()
        }
                        
        if let model = self.musicModel, self.isPlaying, !isPause {
            self.update(musicModel: model, cellType: self.cellType)
            
            self.nameLabel.textColor = appMainColor
            self.descLabel.textColor = appMainColor
        }
        
    }
    
    // MARK:  GET && SET
    weak var delegate: MusicTableViewCellDelegate?
    
    private(set) var isPlaying: Bool = false
    private(set) var cellType: MusicCellType = .local
    private(set) var musicModel: MusicItemModel!
    
    var appMainColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    
    func update(musicModel: MusicItemModel, cellType: MusicCellType) {
                
        self.isPlaying = KakaMusicPlayer.shared.playingMusic == musicModel
        self.musicModel = musicModel
        self.cellType = cellType

        var isSupportType = musicModel.mediaPlayURL.isSupportMusicFile(false)
        if let navSong = musicModel.navidromeSong, !navSong.id.isEmpty {
            isSupportType = true
        }
        
        if let baiduFile = musicModel.baiduFileModel {
            let isSupport = AudioExtension.audioSuffixs.contains(baiduFile.fileExtension())
            isSupportType = !baiduFile.isDirectory() && isSupport
        }
        
        if let aliFileModel = musicModel.aliFileModel {
            let isSupport = AudioExtension.audioSuffixs.contains(aliFileModel.fileExtension())
            isSupportType = !aliFileModel.isDirectory() && isSupport
        }
        
        if let drive115Model = musicModel.drive115Model {
            isSupportType = drive115Model.isMusic()
        }
        
        if let googleFile = musicModel.googleFile {
            let isSupport = AudioExtension.audioSuffixs.contains(googleFile.fileExtension())
            isSupportType = !googleFile.isDirectory() && isSupport
        }
        
        if let dropboxFile = musicModel.dropboxFile {
            let isSupport = AudioExtension.audioSuffixs.contains(dropboxFile.fileExtension())
            isSupportType = !dropboxFile.isDirectory() && isSupport
        }
        if let smbFile = musicModel.smbFile {
            let isSupport = AudioExtension.audioSuffixs.contains(smbFile.fileExtension())
            isSupportType = !smbFile.isDirectory() && isSupport
        }
        if let megaFile = musicModel.megaFile {
            let isSupport = AudioExtension.audioSuffixs.contains(megaFile.fileExtension())
            isSupportType = !megaFile.isDirectory() && isSupport
        }
        if let yandexFile = musicModel.yandexFile {
            let isSupport = AudioExtension.audioSuffixs.contains(yandexFile.fileExtension())
            isSupportType = !yandexFile.isDirectory() && isSupport
        }
        if let pan123File = musicModel.pan123File {
            let isSupport = AudioExtension.audioSuffixs.contains(pan123File.fileExtension())
            isSupportType = !pan123File.isDirectory() && isSupport
        }
        if let guangyaFile = musicModel.guangyaFile {
            let isSupport = AudioExtension.audioSuffixs.contains(guangyaFile.fileExtension())
            isSupportType = !guangyaFile.isDirectory() && isSupport
        }
        if let boxFile = musicModel.boxFile {
            let isSupport = AudioExtension.audioSuffixs.contains(boxFile.fileExtension())
            isSupportType = !boxFile.isDirectory() && isSupport
        }
        if let pcloudFile = musicModel.pcloudFile {
            let isSupport = AudioExtension.audioSuffixs.contains(pcloudFile.fileExtension())
            isSupportType = !pcloudFile.isDirectory() && isSupport
        }
        
        if let onedriveFile = musicModel.onedriveFile {
            let isSupport = AudioExtension.audioSuffixs.contains(onedriveFile.fileExtension())
            isSupportType = !onedriveFile.isDirectory() && isSupport
        }
        
        self.updateSupportExtension(isSupportType)
        
#if targetEnvironment(macCatalyst)
        self.timeLabel.text = cellType == .download ? URL.formatFileSize(musicModel.fileSize()) : musicModel.durationTimeStr()
#endif
        
        let playStatus = KakaMusicPlayer.shared.playbackStatus
        let isPause = playStatus == .paused || playStatus == .initialized || playStatus == .error
                                                
        if self.isPlaying && !isPause {
            loadingBgView.isHidden = false
            nameLabel.textColor = appMainColor
            descLabel.textColor = appMainColor.withAlphaComponent(0.8)
        }else{
            loadingBgView.isHidden = true
            nameLabel.textColor = .label
            descLabel.textColor = .secondaryLabel
        }
        
        var isShowTag = MusicConfigManager.shared.isShowMissTag && !musicModel.isFullMusicTag() && cellType == .local
        if musicModel.isFolder() {
            isShowTag = false
        }
        
        descLabel.isHidden = isShowTag
        taglistView.isHidden = !isShowTag
        taglistView.removeAllTags()
        self.updateMusicTags(musicModel)

        if let webFileModel = musicModel.webFileModel {
            // 1️⃣Webdav
            if musicModel.mediaPlayURL.isSupportMusicFile(false) {
                self.loadArtwork(musicModel)
            }else{
                self.loadArtwork(musicModel, url: webFileModel.mediaPlayURL)
            }
            
            self.nameLabel.text = webFileModel.fileName
            self.descLabel.text = self.secondWebdavStr(webFileModel)
        }else if let baiduFileModel = musicModel.baiduFileModel {
            // 2️⃣百度网盘
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.secondBaiduStr(baiduFileModel)
        }else if let aliFileModel = musicModel.aliFileModel {
            // 3️⃣阿里云盘
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.secondAliyunStr(aliFileModel)
        }else if let drive115Model = musicModel.drive115Model {
            // 4️⃣115网盘
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.second115Str(drive115Model)
        }else if let googleFile = musicModel.googleFile {
            // 5️⃣谷歌网盘
            if googleFile.isImage() {
                let accessToken = googleFile.googleUser?.accessToken ?? ""
                let modifier = AnyModifier { request in
                    var r = request
                    r.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    return r
                }
                
                loadArtwork(musicModel, url: musicModel.mediaPlayURL, modifier: modifier)
            }else{
                loadArtwork(musicModel)
            }
            
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.secondGoogleStr(googleFile)
            
        }else if let dropboxFile = musicModel.dropboxFile {
            // 6️⃣Dropbox网盘
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.secondDropboxStr(dropboxFile)
        }else if let file = musicModel.smbFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "SMB" : musicModel.durationTimeStr()
        }else if let file = musicModel.megaFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "MEGA" : musicModel.durationTimeStr()
        }else if let file = musicModel.yandexFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "Yandex Disk" : musicModel.durationTimeStr()
        }else if let file = musicModel.pan123File {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "Pan123.Name".localStr() : musicModel.durationTimeStr()
        }else if let file = musicModel.guangyaFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "Guangya.Name".localStr() : musicModel.durationTimeStr()
        }else if let file = musicModel.boxFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "Box" : musicModel.durationTimeStr()
        }else if let file = musicModel.pcloudFile {
            loadArtwork(musicModel)
            nameLabel.text = file.name
            self.descLabel.text = file.isDirectory() ? "pCloud" : musicModel.durationTimeStr()
        }else if let onedriveFile = musicModel.onedriveFile {
            // 7️⃣OneDrive网盘
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + musicModel.addPathExtension()
            self.descLabel.text = self.secondOnedriveStr(onedriveFile)
        }
        else{
            // 本地音乐
            loadArtwork(musicModel)
            nameLabel.text = musicModel.showTitleName() + (MusicConfigManager.shared.isShowExtension ? musicModel.addPathExtension() : "")
            self.descLabel.text = self.secondLocalStr(musicModel)
        }
        
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        return view
    }()
    
    lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .extraLight)
        let view = UIVisualEffectView(effect: blurEffect)
//#if !DEBUG
        view.isHidden = true
//#endif
        view.frame = self.coverImgView.bounds
        view.alpha = 0.58
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
    
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
        view.textColor = UIColor.secondaryLabel
        return view
    }()
    
    lazy var timeLabel: UILabel = {
        let view = UILabel()
        view.font = kaka_IsMacOS() ? UIListContentConfiguration.cell().secondaryTextProperties.font : UIFontLight(12.ckValue())
        view.textColor = .secondaryLabel
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .left : .right
        return view
    }()
    
    lazy var loadingBgView: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView? = {
        let frame = CGRectMake(0, 0, 22.ckValue(), 22.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: .white)
        view.startAnimating()
        return view
    }()
    
    lazy var taglistView: TagListView = {
        let view = TagListView()
        return view
    }()
    
    func createTagView(_ titleStr: String) -> TagView {
        
        let fontSize = UIListContentConfiguration.cell().secondaryTextProperties.font.pointSize * 0.8
        let textFont = UIFontLight(fontSize)
        
        let view = TagView(title: titleStr)
        view.textColor = .white
        view.textFont = textFont
        view.paddingX = 6.ckValue()
        view.paddingY = 2.ckValue()
        view.tag_cornerRadius = (textFont.lineHeight + view.paddingY * 2) / 2
        return view
    }
    
}

extension MusicTableViewCell {
    
    // 本地音乐
    private func secondLocalStr(_ musicModel: MusicItemModel) -> String {
        if musicModel.isFolder() {
            return String(format: "%d songs".localStr(), musicModel.mediaPlayURL.totalFileCount())
        }else{
            let artistStr = musicModel.showArtistName()
            if cellType == .download && !kaka_IsMacOS() {
                return (URL.formatFileSize(musicModel.fileSize()) + " " + artistStr)
            }else{
                let sortType = MusicConfigManager.shared.sortType
                switch sortType {
                case .createDate:
                    return artistStr
                case .modifyDate:
                    return artistStr
                case .fileSize:
                    return artistStr + " " + musicModel.mediaPlayURL.fileSizeString
                case .fileName:
                    return artistStr
                }
            }
        }
    }
    
    // webdav
    private func secondWebdavStr(_ fileModel: WebdavFileModel) -> String {
        let dateTime = fileModel.modifiedDate ?? fileModel.creationDate ?? 0
        let dateStr = (Date(timeIntervalSince1970: dateTime.rounded())).dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory {
            return dateStr
        }else{
            return kaka_IsMacOS() ? dateStr : URL.formatFileSize(fileModel.fileSize) + "  " + dateStr
        }
    }
    
    // 百度网盘
    private func secondBaiduStr(_ fileModel: BaiduDriveFileModel) -> String {
        let dateStr = (Date(timeIntervalSince1970: TimeInterval(fileModel.server_ctime))).dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory() {
            return dateStr
        }else{
            return kaka_IsMacOS() ? dateStr : URL.formatFileSize(Int64(fileModel.size)) + "  " + dateStr
        }
    }
    
    // 阿里云盘
    private func secondAliyunStr(_ fileModel: AliyunpanFileModel) -> String {
        let dateStr = (Date(timeIntervalSince1970: TimeInterval(fileModel.created_at ?? 0))).dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory() {
            return dateStr
        }else{
            return kaka_IsMacOS() ? dateStr : URL.formatFileSize(fileModel.size ?? 0) + "  " + dateStr
        }
    }
    
    // 115网盘
    private func second115Str(_ fileModel: Drive115FileModel) -> String {
        let dateStr = fileModel.createDate().dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory() {
            if let count = fileModel.count, count > 0 {
                return dateStr + "  " + String(format: "%d subfiles".localStr(), count)
            }else{
                return dateStr
            }
        }else{
            return kaka_IsMacOS() ? dateStr : URL.formatFileSize(fileModel.size) + "  " + dateStr
        }
    }
    
    // 谷歌网盘
    private func secondGoogleStr(_ fileModel: GoogleDriveFileModel) -> String {
        let dateStr = fileModel.createdDate()?.dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory() {
            return dateStr ?? URL.formatFileSize(fileModel.size)
        }else{
            return kaka_IsMacOS() ? (dateStr ?? "") : URL.formatFileSize(fileModel.size) + "  " + (dateStr ?? "")
        }
    }
    
    // Dropbox网盘
    private func secondDropboxStr(_ fileModel: DropboxDriveFileModel) -> String {
        let dateStr = fileModel.createdDate()?.dateTimeString(ofStyle: .medium)
        if fileModel.isDirectory() {
            return dateStr ?? (fileModel.path_display ?? URL.formatFileSize(fileModel.size ?? 0))
        }else{
            return kaka_IsMacOS() ? (dateStr ?? "") : URL.formatFileSize(fileModel.size ?? 0) + "  " + (dateStr ?? "")
        }
    }
    
    // OneDrive网盘
    private func secondOnedriveStr(_ fileModel: OneDriveFileModel) -> String {
        let dateStr = fileModel.createdDate()?.dateTimeString(ofStyle: .medium)
        let subFileStr = String(format: "%d subfiles".localStr(), fileModel.folder?.childCount ?? 0)

        if fileModel.isDirectory() {
            return subFileStr
        }else{
            return kaka_IsMacOS() ? (dateStr ?? "") : URL.formatFileSize(fileModel.size) + "  " + (dateStr ?? "")
        }
    }
    
    // 更新音乐标签
    private func updateMusicTags(_ musicModel: MusicItemModel) {
                
        if musicModel.isFullMusicTag() { return }
        
        if !musicModel.hasCachedArtwork() {
            let tagView = self.createTagView(MusicActionType.coverArt.titleStr())
            tagView.tagBackgroundColor = .systemRed
            taglistView.addTagView(tagView)
        }
        
        if let title = musicModel.title, title.count > 0 {
        }else{
            let tagView = self.createTagView(MusicActionType.title.titleStr())
            tagView.tagBackgroundColor = .systemRed
            taglistView.addTagView(tagView)
        }
        
        if let artist = musicModel.artist, artist.count > 0 {
        }else{
            let tagView = self.createTagView(MusicActionType.artist.titleStr())
            tagView.tagBackgroundColor = .systemRed
            taglistView.addTagView(tagView)
        }
        
        if let lyrics = musicModel.lyricModel?.lyrics, lyrics.count > 0 {
        }else{
            let tagView = self.createTagView("Lyrics".localStr())
            tagView.tagBackgroundColor = .systemRed
            taglistView.addTagView(tagView)
        }
    }
    
    // 判断音乐格式
    private func updateSupportExtension(_ isSupportType: Bool) {
        if isSupportType {
            switch cellType {
            case .none:
                self.accessoryView = nil
                self.accessoryType = .disclosureIndicator
                break
                
            case .local:
                let isFullTag = self.musicModel.isFullMusicTag()

                self.accessoryView = isFullTag ? self.localButton() : self.autoTagButton()
                self.accessoryType = .none
                break
                
            case .download:
                self.accessoryView = self.downloadButton()
                self.accessoryType = .none
                break
                
            case .cloudDrive:
                self.accessoryView = self.cloudDriveButton()
                self.accessoryType = .none
                break
            
            case .navLargeServer:
                self.accessoryView = self.largenavBUtton()
                self.accessoryType = .none
                break
                
            case .navArtistDetial:
                self.accessoryView = self.navartistBUtton()
                self.accessoryType = .none
                break
                
            case .navPlaylistDetial:
                self.accessoryView = self.navplaylistBUtton()
                self.accessoryType = .none
                break
                
            }
        } else {
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
        }
    }
    
    
}
