//
//  SearchTagViewController.swift
//  Mobie
//
//  Created by 张文 on 5/11/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import KakaPhotoBrowser

/// 搜索封面和歌词: 2组内容
class SearchTagViewController: SuperViewController {
    
    /// 搜索封面和歌词页面
    /// - Parameters:
    ///   - model: 模型
    ///   - isOnlyLyric: 是否只有歌词
    init(model: MusicItemModel, isOnlyLyric: Bool) {
        super.init(nibName: nil, bundle: nil)
        self.model = model
        self.oldModel = model
        self.isOnlyLyric = isOnlyLyric
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        
        contentView.addSubview(loadingView)
        contentView.addSubview(loadingLabel)
        contentView.addSubview(copyButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        loadingView.frame = CGRectMake((self.view.width - loadingView.size.width) / 2, (self.view.height - loadingView.size.height) / 2, loadingView.size.width, loadingView.size.height)
        loadingLabel.frame = CGRectMake(0, CGRectGetMaxY(loadingView.frame) + 12.ckValue(), self.view.width, loadingLabel.font.lineHeight * 1.5)
        
        tableView.frame = contentView.bounds
        copyButton.frame = CGRectMake(25.ckValue(), contentView.height - 70.ckValue(), contentView.width - 50.ckValue(), 50.ckValue())
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        if self.isOnlyLyric {
            self.title = "Lyrics".localStr()
        }else{
            self.title = "Album Cover & Lyrics".localStr()
        }
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarItemClick))
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneBarItenClick))
        
        self.refreshDataAction()
    }
    
    @objc func refreshDataAction() {
        
        guard let musicModel = self.model else { return }
        
        guard let title = musicModel.title, !title.isEmpty, let artist = musicModel.artist, !artist.isEmpty else {
            self.showOneAlert(title: "Reminder".localStr(), message: "Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr())
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.loadingView.isHidden = true
            self.loadingLabel.isHidden = true
            self.copyButton.isHidden = true
            
            self.tableView.reloadData()
            return
        }
        
        if !self.tableView.isDragging {
            self.loadingView.startAnimating()
            self.tableView.isHidden = true
            self.copyButton.isHidden = true
            self.loadingView.isHidden = false
            self.loadingLabel.isHidden = false
        }
        
        let fetchDataGroup = DispatchGroup()
        
        if !self.isOnlyLyric {
            // 获取封面
            fetchDataGroup.enter()
            self.requestCoverAction(title: title, artist: artist, album: musicModel.album) {
                fetchDataGroup.leave()
            }
        }
        
        // 获取歌词
        fetchDataGroup.enter()
//#warning("模拟mock数据")
//        #if DEBUG
//        title = "white"
//        artist = ""
//        #endif
        self.requestLyricAction(title: title, artist: artist, album: musicModel.album) {
            fetchDataGroup.leave()
        }
        
        fetchDataGroup.notify(queue: .main) {
            self.loadingView.stopAnimating()
            self.tableView.isHidden = false
            self.copyButton.isHidden = false
            self.loadingView.isHidden = true
            self.loadingLabel.isHidden = true
            
            self.tableView.reloadData()
        }
    }
    
    // 首次加载封面
    func requestCoverAction(title: String, artist: String, album: String?, completion: (()->Void)? = nil) {
        MusicTagEditor.shared.requestITunesAlbumImages(title: title, artist: artist) { result in
            switch result {
            case .success(let models):
                self.coverArray = models
                if let coverArt = self.model.coverArt {
                    var curModel = MusicReleaseModel()
                    curModel.tempImage = coverArt
                    curModel.title = title
                    if let year = self.model.year {
                        curModel.date = "\(year)"
                    }
                    self.coverArray.insert(curModel, at: 0)
                }
                
                self.selectCoverModel = self.coverArray.first
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
                self.coverArray = models
                if let coverArt = self.model.coverArt {
                    var curModel = MusicReleaseModel()
                    curModel.tempImage = coverArt
                    curModel.title = artist
                    if let year = self.model.year {
                        curModel.date = "\(year)"
                    }
                    self.coverArray.insert(curModel, at: 0)
                }
                self.selectCoverModel = self.coverArray.first
                completion?()
            case .failure(_):
                completion?()
                self.showOneAlert(title: "Reminder".localStr(), message: "Search failed! You can try to modify the title, artist or album name and try again!".localStr())
                break
            }
        }
    }
    
    // 搜索歌词
    func requestLyricAction(title: String, artist: String, album: String?, completion: (()->Void)? = nil) {
        
        MusicTagEditor.shared.requestAccurateLyric(title: title, artist: artist, album: album, duration: Int(self.model.durationSeconds)) { result in
            
            switch result {
            case .success(let models):
                self.lyricArray = models
                if let lyricModel = self.model.lyricModel, let lyrics = lyricModel.lyrics, !lyrics.isEmpty {
                    self.lyricArray.insert(lyricModel, at: 0)
                    if models.isEmpty {
                        self.uploadOneLyric(lyricModel)
                    }
                }
                self.selectLyricModel = self.lyricArray.first
                break
            case .failure(_):
                if let lyricModel = self.model.lyricModel, let lyrics = lyricModel.lyrics, !lyrics.isEmpty {
                    self.lyricArray.insert(lyricModel, at: 0)
                    self.selectLyricModel = self.lyricArray.first
                    self.uploadOneLyric(lyricModel)
                }
                break
            }
            
            completion?()
        }
    }
    
    // 上传歌词
    func uploadOneLyric(_ lyricModel: LyricInfoModel) {
        MusicTagEditor.shared.publishNewLyric(musicModel: self.model, lyricModel: lyricModel)
    }
    
    // MARK:  GET && SET
    var onDoneBlock: ((MusicReleaseModel?, LyricInfoModel?)->Void)?
    
    var oldModel: MusicItemModel!
    var model: MusicItemModel!
    
    var isOnlyLyric: Bool = false
    
    var selectLyricIndex: Int = 0
    
    var selectCoverModel: MusicReleaseModel?
    var selectLyricModel: LyricInfoModel?
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.isHidden = true
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80.ckValue() + kaka_safeAreaInsets().bottom, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(SearchTagTipsViewCell.self, forCellReuseIdentifier: "SearchTagTipsViewCell")
        view.register(CoverGalleryHeadCell.self, forCellReuseIdentifier: "CoverGalleryHeadCell")
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(CoverGalleryTableCell.self, forCellReuseIdentifier: "CoverGalleryTableCell")
        view.register(LRCLyricTableViewCell.self, forCellReuseIdentifier: "LRCLyricTableViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "BasicAiTypeViewCell")
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
    lazy var loadingLabel: UILabel = {
        let view = UILabel()
        
        view.font = UIFontLight(16.ckValue())
        view.textAlignment = .center
        view.textColor = .secondaryLabel
        view.text = "Processing...".localStr()
        return view
    }()
    
    lazy var dataArray: [SearchTagCellModel] = {
        let model1 = SearchTagCellModel(group: .tipsGroup, headTitle: nil, footTitle: nil)
        let model2 = SearchTagCellModel(group: .coverGroup, headTitle: MusicActionType.coverArt.formatStr(), footTitle: nil)
        var headTitle = "Lyrics".localStr() + "（" + self.model.durationTimeStr() + "）"
        let model3 = SearchTagCellModel(group: .lyricGroup, headTitle: headTitle, footTitle: nil)
        return isOnlyLyric ? [model1, model3] : [model1, model2, model3]
    }()
    
    lazy var coverArray: [MusicReleaseModel] = {
        return [MusicReleaseModel]()
    }()
    
    lazy var lyricArray: [LyricInfoModel] = {
        return [LyricInfoModel]()
    }()
    
    lazy var aitypeArray: [AIType] = {
        return AIType.allTypes()
    }()
    
    lazy var copyButton: UIButton = {
        let view = UIButton(type: .custom)
        view.isHidden = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.setTitle("Manually paste the lyrics".localStr(), for: .normal)
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor.deAccent, for: .normal)
        view.addTarget(self, action: #selector(copyButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    @objc func copyButtonClick(_ sender: UIButton) {
        let editVC = LyricEditorViewController(musicModel: self.model)
        editVC.title = self.model.filePathName()
        editVC.editCallBack = { [weak self] (newLyric) in
            self?.selectLyricModel = newLyric
            self?.doneBarItenClick()
        }
        self.navigationController?.pushViewController(editVC, animated: true)
    }
    
    @objc func cancelBarItemClick() {
        self.navigationController?.dismiss(animated: true)
    }
    
    @objc func doneBarItenClick() {
        if self.selectCoverModel?.tempImage == nil {
            let imageCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? CoverGalleryTableCell
            self.selectCoverModel?.tempImage = imageCell?.coverImgView.image
        }
        
        self.onDoneBlock?(self.selectCoverModel, self.selectLyricModel)
        self.cancelBarItemClick()
    }
    
}

extension SearchTagViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cellModel = dataArray[section]
        if cellModel.group == .tipsGroup {
            return 1
        }else if cellModel.group == .coverGroup {
            return self.coverArray.isEmpty ? 1 : self.coverArray.count
        }else if cellModel.group == .lyricGroup {
            return self.lyricArray.isEmpty ? 1 : self.lyricArray.count
        }else{
            return self.aitypeArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = dataArray[indexPath.section]
        
        if cellModel.group == .tipsGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchTagTipsViewCell", for: indexPath) as! SearchTagTipsViewCell
            cell.model = self.model
            cell.onClickBlock = { [weak self] (tipsCell) in
                guard let title = tipsCell.titleField.text, !title.isEmpty else {
                    tipsCell.titleField.kaka_playShakeAnim()
                    return
                }
                guard let artist = tipsCell.artistField.text, !artist.isEmpty else {
                    tipsCell.artistField.kaka_playShakeAnim()
                    return
                }
                
                self?.model.title = title
                self?.model.artist = artist
                self?.view.endEditing(true)
                
                self?.refreshDataAction()
            }
            return cell
        }else if cellModel.group == .coverGroup {
            if self.coverArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CoverGalleryTableCell", for: indexPath) as! CoverGalleryTableCell
                let remoteModel = self.coverArray[indexPath.row]
                cell.updateRemote(remoteModel: remoteModel, isSelect: self.selectCoverModel == remoteModel)
                cell.onClickBlock = { [weak self] (coverCell) in
                    guard let wSelf = self else { return }
                    let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
                    let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
                    photoBrowser.backgroundStyle = .blurPhoto
                    photoBrowser.show(from: wSelf)
                }
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                return cell
            }
        }else if cellModel.group == .lyricGroup {
            if self.lyricArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "LRCLyricTableViewCell", for: indexPath) as! LRCLyricTableViewCell
                let lyricModel = self.lyricArray[indexPath.row]
//                cell.updateLyric(lyricModel: lyricModel, isSelect: self.selectLyricModel == lyricModel)
                cell.updateLyric(lyricModel: lyricModel, isSelect: selectLyricIndex == indexPath.row)
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                
                return cell
            }
        }else{
            let aiType = self.aitypeArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicAiTypeViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.image = aiType.iconImage()
            cellConfig.text = aiType.titleStr()
            cellConfig.image = aiType.iconImage()
            cellConfig.imageProperties.maximumSize = CGSizeMake(30.ckValue(), 30.ckValue())
            cell.contentConfiguration = cellConfig
            cell.accessoryType = .disclosureIndicator
            cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 25, leading: 15, bottom: 25, trailing: 15)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cellModel = dataArray[indexPath.section]
        
        if cellModel.group == .coverGroup {
            let imageCell = self.tableView.cellForRow(at: indexPath) as? CoverGalleryTableCell
            guard let image = imageCell?.coverImgView.image else {
                imageCell?.coverImgView.kaka_playAnimation()
                return
            }
            
            self.selectCoverModel = self.coverArray[indexPath.row]
            self.selectCoverModel?.tempImage = image
            self.tableView.reloadData()
            
            self.selectCoverModel?.title = self.oldModel.title ?? ""
            self.selectCoverModel?.itunesModel?.trackName = self.oldModel.artist ?? ""
            self.selectCoverModel?.itunesModel?.artistName = self.oldModel.artist ?? ""
        }
        
        if cellModel.group == .lyricGroup && self.lyricArray.count > 0 {
            self.selectLyricModel = self.lyricArray[indexPath.row]
            self.selectLyricIndex = indexPath.row
            self.tableView.reloadData()
            
            self.selectLyricModel?.title = self.oldModel.title ?? ""
            self.selectLyricModel?.artist = self.oldModel.artist ?? ""
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.5) { [weak self] () in
                guard let wSelf = self else { return }
                guard let index = wSelf.lyricArray.firstIndex(where: { $0 == wSelf.selectLyricModel }) else { return }
                let selectIndexPath = IndexPath(row: index, section: wSelf.isOnlyLyric ? 1 : 2)
                wSelf.tableView.scrollToRow(at: selectIndexPath, at: .top, animated: true)
            }
        }
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.footTitle
    }
    
    // 点击AI前往搜索，复制文本
    func searchWithAIReminder(_ aiType: AIType) {
        guard let title = self.model?.title, !title.isEmpty, let artist = self.model?.artist, !artist.isEmpty else {
            self.showTwoAlert(title: "Reminder".localStr(), message: "Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr()) {
                self.popToSpecifiedViewController(ofType: MusicTagEditerViewController.self)
            }
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
    
    /// 返回到指定的控制器页面
    public func popToSpecifiedViewController(ofType type: UIViewController.Type) {
        if let viewControllers = self.navigationController?.viewControllers {
            for viewController in viewControllers {
                if viewController.isKind(of: type) {
                    // 找到指定类型的控制器，返回到该控制器
                    self.navigationController?.popToViewController(viewController, animated: true)
                    return
                }
            }
        }
    }
}

