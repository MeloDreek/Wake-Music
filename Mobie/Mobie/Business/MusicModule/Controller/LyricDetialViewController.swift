//
//  LyricDetialViewController.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import UniformTypeIdentifiers
import StoreKit
import SafariServices


/// 歌词详情页
class LyricDetialViewController: SuperViewController {
    
    init(editModel: MusicItemModel) {
        self.editModel = editModel
        
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
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = "Lyrics".localStr()
        self.updateActionItem()
    }
    
    func updateActionItem() {
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarItemClick))
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .done, target: self, action: #selector(editLyricAction))
        
    }
    
    @objc func cancelBarItemClick() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    @objc func editLyricAction() {
        
        if self.editModel.fileSourceType == .demoFile {
            self.view.makeToast("Demo audio is read-only and cannot be edited".localStr())
            return
        }
        
        if let lyricModel = self.editModel.lyricModel, let lyrics = lyricModel.lyrics, lyrics.count > 0 {
            // 有歌词
            self.haveLyricsAction(lyricModel)
        }else{
            // 没有歌词
            self.noneLyricsAction()
        }
    }
    
    
    // MARK:  GET && SET
    var editModel: MusicItemModel!
    
    var onEditCallback: ((MusicItemModel)->Void)?
    
    // MARK:  懒加载
    lazy var haveLyricItem: UIBarButtonItem = {
        let view = UIBarButtonItem()
        return view
    }()
    
    lazy var noneLyricItem: UIBarButtonItem = {
        let view = UIBarButtonItem()
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.separatorStyle = .singleLine
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.register(LyricDetialHeadCell.self, forCellReuseIdentifier: "LyricDetialHeadCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "LycisEmptyViewCell")
        view.register(MeteDataLycisViewCell.self, forCellReuseIdentifier: "MeteDataLycisViewCell")
        return view
    }()
    
    func addIconView() -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: "plus"))
        view.size = CGSize(width: 20.ckValue(), height: 20.ckValue())
        view.contentMode = .scaleAspectFit
        return view
    }
    
}

extension LyricDetialViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else{
            guard let lyricArray = self.editModel.lyricModel?.lyrics, lyricArray.count > 0 else {
                return 2
            }
            
            return lyricArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricDetialHeadCell", for: indexPath) as! LyricDetialHeadCell
            cell.model = self.editModel
            return cell
        }else{
            guard let lyricModel = self.editModel.lyricModel, let lyricArray = lyricModel.lyrics, lyricArray.count > 0 else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "LycisEmptyViewCell", for: indexPath)
                var cellConfig = UIListContentConfiguration.cell()
                cellConfig.text = indexPath.row == 0 ? "There are no lyrics embedded in this file, please add them.".localStr() : "Set to pure music".localStr()
                cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
                cell.accessoryType = .none
                cell.accessoryView = self.addIconView()
                cell.contentConfiguration = cellConfig
                return cell
            }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataLycisViewCell", for: indexPath) as! MeteDataLycisViewCell
            cell.update(lyricModel: lyricArray[indexPath.row], isNoneTime: lyricModel.isNoneTime)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            return
        }
        
        guard let lyricArray = self.editModel.lyricModel?.lyrics, lyricArray.count > 0 else {
            // 没有歌词时
            if indexPath.row == 0 {
                self.pastedLyricContent()
            }else{
                // 设置为纯音乐
                let lyricStr = "[00:00.000]" + "Pure Music. Please Enjoy.".localStr()
                self.setLyricContent(lyricStr)
                self.navigationController?.popViewController(animated: true)
            }
            return
        }
    }
    
    
}

extension LyricDetialViewController {
    
    // 有歌词
    func haveLyricsAction(_ lyricModel: LyricInfoModel) {
        
        let title = self.editModel.filePathName()
        let alertController = UIAlertController(title: title, message: "Lyrics".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Edit".localStr(), style: .default) { [weak self] (sender) in
            guard let wSelf = self else { return }
            if !UserInfoManager.shared.isVIP() {
                self?.vipCenterClick()
                return
            }
            
            let editVC = LyricEditorViewController(musicModel: self?.editModel)
            editVC.title = wSelf.editModel.filePathName()
            editVC.editCallBack = { [weak self] (newLyric) in
                guard let wSelf = self else { return }
                let lyricStr = newLyric.toLyricString(false) ?? ""
                wSelf.setLyricContent(lyricStr)
            }
            self?.navigationController?.pushViewController(editVC, animated: true)
        }
        
        let action2 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { [weak self] (sender) in
            guard let wSelf = self else { return }
            if !UserInfoManager.shared.isVIP() {
                self?.vipCenterClick()
                return
            }
            
            self?.showTwoAlert(title: "Reminder".localStr(), message: "Are you sure to delete it?".localStr(), complete: {
                wSelf.setLyricContent("")
            })
        }
        
        let action3 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action3.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // 没有歌词
    func noneLyricsAction() {
        let title = self.editModel.filePathName()
        let alertController = UIAlertController(title: title, message: "Lyrics".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Search with AI".localStr(), style: .default) { [weak self] (sender) in
            self?.searchWithAI()
        }
        let action2 = UIAlertAction(title: "Lyrics Library".localStr(), style: .default) { [weak self] (sender) in
            self?.selectLocalLyrics()
        }
        let action3 = UIAlertAction(title: "Paste Lyrics Text".localStr(), style: .default) { [weak self] (sender) in
            self?.pastedLyricContent()
        }
        let action4 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        alertController.addAction(action4)
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        action3.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        action4.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // 选择本地歌词
    func selectLocalLyrics() {
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        let lyricVC = LyricListViewController(isSelect: true)
        lyricVC.onSelectCallback = { [weak self] (subURL) in
            self?.readLyricTextFile(subURL)
        }
        let navVC = KakaNavigationController(rootViewController: lyricVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // AI搜索歌词
    func searchWithAI() {
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        
        guard let editModel = self.editModel, let title = editModel.title, !title.isEmpty else {
            appKeyWindow?.makeToast("Please fill in the title and artist for this song. AI will recommend more accurate cover art or lyrics for you!".localStr())
            return
        }
        
        let searchVC = SearchTagViewController(model: editModel, isOnlyLyric: true)
        searchVC.onDoneBlock = { [weak self] (coverModel, lyricModel) in
            if let lyricModel = lyricModel, let lyricStr = lyricModel.toLyricString() {
                self?.setLyricContent(lyricStr)
            }
        }
        let navVC = KakaNavigationController(rootViewController: searchVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    // 粘贴歌词内容
    func pastedLyricContent() {
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        let editVC = LyricEditorViewController(musicModel: self.editModel)
        editVC.title = self.editModel.filePathName()
        editVC.editCallBack = { [weak self] (newLyric) in
            guard let wSelf = self else { return }
            let lyricStr = newLyric.toLyricString(false) ?? ""
            wSelf.setLyricContent(lyricStr)
        }
        self.navigationController?.pushViewController(editVC, animated: true)
    }
    
    func readLyricTextFile(_ firstURL: URL) {
        // 检查是否成功读取内容
        guard let fileContent = firstURL.readLRCContentStr(), fileContent.count > 1 else {
            self.view.makeToast("Unable to open document. Text encoding Unicode (UTF-8 and GBK) is not applicable.".localStr())
            return
        }
        
        self.setLyricContent(fileContent)
    }
    
    // 写入歌词
    func setLyricContent(_ content: String) {
        
        guard var origialModel = self.editModel else { return }
        
        let success = TaglibMetadataParser.setLyris(content, toFileURL: origialModel.mediaPlayURL)
        if success {
            origialModel.lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(content)?.convertSwiftModel()
            if KakaMusicPlayer.shared.playingMusic == origialModel {
                KakaMusicPlayer.shared.playingMusic = origialModel
            }
            self.editModel = origialModel
            self.tableView.reloadData()
            self.onEditCallback?(origialModel)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene, content.count > 3 {
                appKeyWindow?.makeToast("Embedded Success".localStr())
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
        
        debugPrint("写入歌词 = \(success)")
    }
    
    
    

}

class LyricDetialHeadCell: UITableViewCell {
    
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
        self.addSubview(nameLabel)
    }
    
    private func preSetupContains() {
        
        var height = 180.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
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
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
            make.bottom.equalToSuperview()
        }
    }
    
    var model: MusicItemModel? {
        didSet {
            guard let model = self.model else { return }
            nameLabel.text = model.showTitleName() + "\r" + (model.artist ?? "")
        }
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "quote.bubble.fill"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.textAlignment = .center
        view.font = UIFontBold(15.ckValue())
        return view
    }()
}


class MeteDataLycisViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .none
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(lyricModel: LyricModel, isNoneTime: Bool) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = lyricModel.formatLyricStr(isNoneTime)
        cellConfig.textProperties.color = .label
        cellConfig.textProperties.font = UIFontLight(15.ckValue())
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)

        self.contentConfiguration = cellConfig
    }
    
}
