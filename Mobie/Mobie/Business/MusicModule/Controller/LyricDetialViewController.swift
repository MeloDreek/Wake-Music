//
//  LyricDetialViewController.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import WaketagLibKit
import UniformTypeIdentifiers
import StoreKit
import SafariServices

enum NoneLyricCellType: Int, CaseIterable {
    case autoMatch = 0
    case textManual = 1
    case pureMusic = 2
    
    func titleStr() -> String {
        switch self {
        case .autoMatch:
            return "Auto Search LRC".localStr()
        case .textManual:
            return "Manual Paste Lyrics".localStr()
        case .pureMusic:
            return "Set as Instrumental".localStr()
        }
    }
    
    func backgroundColor() -> UIColor {
        switch self {
        case .autoMatch:
            return UIColor.systemRed
        case .textManual:
            return UIColor.systemBlue
        case .pureMusic:
            return UIColor.systemGreen
        }
    }
}

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
        
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = MusicTagType.lyrics.titleStr()
        self.updateActionItem()
    }
    
    // 更新右侧按钮
    func updateActionItem() {
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        if let lyricModel = self.editModel.lyricModel, let lyrics = lyricModel.lyrics, lyrics.count > 0 {
            // 有歌词
            self.navigationItem.rightBarButtonItem = self.haveLyricItem
        }else{
            // 没有歌词
            self.navigationItem.rightBarButtonItem = nil
        }
        
    }
    
    /// 有歌词
    @objc func editLyricAction() {
        if let lyricModel = self.editModel.lyricModel, let lyrics = lyricModel.lyrics, lyrics.count > 0 {
            // 有歌词
            self.haveLyricsAction(lyricModel)
        }else{
            // 没有歌词
            self.noneLyricsAction()
        }
    }
    
    // 没有歌词
    @objc func noneLyricsAction() {
        if !UserInfoManager.shared.isVIP() {
            let title = "🫆" + "Auto-Match".localStr()
            let message = "HD 4K cover art and lyrics are Premium metadata features. The free version supports manually editing basic metadata like Title, Artist, and Album. Upgrade to Premium to take your music collection to the next level!".localStr()
            self.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                self.vipCenterClick()
            }
            return
        }
        
        let editVC = LyricEditorViewController(musicModel: self.editModel)
        editVC.title = self.editModel.filePathName()
        editVC.editCallBack = { [weak self] (newLyric) in
            guard let wSelf = self else { return }
            let lyricStr = newLyric.toLyricString(false) ?? ""
            wSelf.setLyricContent(lyricStr)
        }
        self.present(KakaNavigationController(rootViewController: editVC), animated: true)
    }
    
    // 设置为纯音乐
    func setPureMusicAction() {
        // 设置为纯音乐
        let lyricStr = "[00:00.000]" + "Instrumental · Enjoy the music".localStr()
        self.setLyricContent(lyricStr)
        self.navigationController?.popViewController(animated: true)
    }
    
    // 搜索歌词页面
    func searchLyricAction() {
        if !UserInfoManager.shared.isVIP() {
            let title = "🫆" + "Auto-Match".localStr()
            let message = "HD 4K cover art and lyrics are Premium metadata features. The free version supports manually editing basic metadata like Title, Artist, and Album. Upgrade to Premium to take your music collection to the next level!".localStr()
            self.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                self.vipCenterClick()
            }
            return
        }
        
        let lyricVC = SelectLyricViewController(music: self.editModel, result: nil)
        lyricVC.onSelectBlock = { [weak self] (lyricModel) in
            self?.setLyricContent(lyricModel.toLyricString() ?? "")
        }
        self.present(KakaNavigationController(rootViewController: lyricVC), animated: true)
    }
    
    // MARK:  GET && SET
    var editModel: MusicItemModel!
    
    var onEditCallback: ((MusicItemModel)->Void)?
    
    // MARK:  懒加载
    lazy var haveLyricItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(editLyricAction))
        return item
    }()
    
    lazy var noneLyricItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "pencil.and.outline"), style: .plain, target: self, action: #selector(noneLyricsAction))
        return item
    }()
    
    lazy var cellTypeArray: [NoneLyricCellType] = {
        return NoneLyricCellType.allCases
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.separatorStyle = .singleLine
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.tableHeaderView = self.headView
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "LycisEmptyViewCell")
        view.register(MeteDataLycisViewCell.self, forCellReuseIdentifier: "MeteDataLycisViewCell")
        return view
    }()
    
    lazy var headView: LyricDetialHeadView = {
        let view = LyricDetialHeadView(frame: CGRectMake(0, 0, contentView.width, LyricDetialHeadView.height()))
        view.model = self.editModel
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
        guard let lyricArray = self.editModel.lyricModel?.lyrics, lyricArray.count > 0 else {
            return self.cellTypeArray.count
        }
        
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let lyricArray = self.editModel.lyricModel?.lyrics, lyricArray.count > 0 else {
            return 1
        }
        
        return lyricArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let lyricModel = self.editModel.lyricModel, let lyricArray = lyricModel.lyrics, lyricArray.count > 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LycisEmptyViewCell", for: indexPath)
            let subType = NoneLyricCellType(rawValue: indexPath.section)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = subType?.titleStr()
            cellConfig.textProperties.numberOfLines = 0
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
            cellConfig.textProperties.color = UIColor.white
            cellConfig.textProperties.alignment = .center
            cell.backgroundColor = subType?.backgroundColor()
            cell.accessoryType = .none
            cell.contentConfiguration = cellConfig
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataLycisViewCell", for: indexPath) as! MeteDataLycisViewCell
        cell.update(lyricModel: lyricArray[indexPath.row], isNoneTime: lyricModel.isNoneTime)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let lyricArray = self.editModel.lyricModel?.lyrics, lyricArray.count > 0 else {
            let subType = self.cellTypeArray[indexPath.section]
            switch subType {
            case .autoMatch:
                self.searchLyricAction()
                break
            case .textManual:
                self.noneLyricsAction()
                break
            case .pureMusic:
                self.setPureMusicAction()
                break
            }
            return
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kaka_IsMacOS() ? 50 : UITableView.automaticDimension
    }
    
    
}

extension LyricDetialViewController {
    
    // 有歌词
    func haveLyricsAction(_ lyricModel: LyricInfoModel) {
        
        let title = self.editModel.filePathName()
        let alertController = UIAlertController(title: title, message: MusicTagType.lyrics.titleStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Edit".localStr(), style: .default) { [weak self] (sender) in
            guard let wSelf = self else { return }
            
            if !UserInfoManager.shared.isVIP() {
                let title = "🫆" + "Auto-Match".localStr()
                let message = "HD 4K cover art and lyrics are Premium metadata features. The free version supports manually editing basic metadata like Title, Artist, and Album. Upgrade to Premium to take your music collection to the next level!".localStr()
                wSelf.showTwoAlert(title: title, message: message, confirm: "Unlock Premium".localStr()) {
                    wSelf.vipCenterClick()
                }
                return
            }
            
            let editVC = LyricEditorViewController(musicModel: wSelf.editModel)
            editVC.title = wSelf.editModel.filePathName()
            editVC.editCallBack = { [weak self] (newLyric) in
                guard let wSelf = self else { return }
                let lyricStr = newLyric.toLyricString(false) ?? ""
                wSelf.setLyricContent(lyricStr)
            }
            self?.present(KakaNavigationController(rootViewController: editVC), animated: true)
        }
        let action2 = UIAlertAction(title: "Copy".localStr(), style: .default) { [weak self] (sender) in
            UIPasteboard.general.string = lyricModel.toLyricString(true)
            self?.view.makeToast("Copied".localStr())
        }
        let action3 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { [weak self] (sender) in
            guard let wSelf = self else { return }
            
            self?.showTwoAlert(message: "Are you sure to delete it?".localStr(), complete: {
                wSelf.setLyricContent("")
            })
        }
        
        let action4 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        alertController.addAction(action4)
        
        
        self.present(alertController, animated: true, completion: nil)
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
            self.editModel = origialModel
            self.tableView.reloadData()
            self.onEditCallback?(origialModel)
            
            self.view.makeToast("Embedded Success".localStr())
        }
        
        debugPrint("写入歌词 = \(success)")
        self.updateActionItem()
    }
}

class LyricDetialHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(starImgView)
        contentView.addSubview(nameLabel)
    }
    
    private func preSetupContains() {
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 100
        }
        
        let value = starImgView.image!.size.width / starImgView.image!.size.height
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15.ckValue())
            make.centerX.equalToSuperview()
            make.height.equalTo(height)
            make.width.equalTo(starImgView.snp.height).multipliedBy(value)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    var model: MusicItemModel? {
        didSet {
            guard let model = self.model else { return }
            nameLabel.text = model.showTitleName() + "\r" + (model.artist ?? "")
        }
    }
    
    static func height() -> CGFloat {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 100
        }
        
        return height + 25.ckValue() + 100.ckValue()
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "text.quote"))
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
