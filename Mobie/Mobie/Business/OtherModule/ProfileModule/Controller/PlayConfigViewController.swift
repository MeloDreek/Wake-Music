//
//  PlayConfigViewController.swift
//  Mobie
//
//  Created by 张文 on 10/29/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PhotosUI
import KakaPhotoBrowser
import ZLImageEditor
import Kingfisher
import Combine

class PlayConfigViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.navigationItem.largeTitleDisplayMode = .never
        self.title = SettingCellItemType.playConfig.titleStr()
        
        
        // 播放引擎切换了
        NotificationCenter.default.addObserver(self, selector: #selector(playerConfigUIChanged), name: Notification.Name(rawValue: kPlayerEngineChangedKey), object: nil)
        
        // Nav转码格式
        MusicConfigManager.shared.$navFormats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] engine in
                self?.playerConfigUIChanged()
            }.store(in: &cancellables)
        
        // 最大比特率
        MusicConfigManager.shared.$navMaxBitRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] engine in
                self?.playerConfigUIChanged()
            }.store(in: &cancellables)
        
        // 屏幕歌词顺序变化了
        MusicConfigManager.shared.$lyricSortStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] engine in
                self?.playerConfigUIChanged()
            }.store(in: &cancellables)
        
    }
    
    @objc func playerConfigUIChanged() {
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    lazy var dataArray: [PlayConfigGroupModel] = {
        let model1 = PlayConfigGroupModel(group: .playerGroup, headTitle: nil, itemArray: [.preDownload, .playerStyle, .playerBack, .playAnimation], footTitle: nil)
        let model2 = PlayConfigGroupModel(group: .otherGroup, headTitle: nil, itemArray: [.lyricStyle, .showExtension, .lastTimeCache, .showMissTags], footTitle: nil)
        let model3 = PlayConfigGroupModel(group: .naviGroup, headTitle: "When playing Navidrome's music".localStr(), itemArray: [.transcoding, .targetFormat, .targetMaxBitRate], footTitle: nil)
        return [model1, model2, model3]
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = self.headView
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(PlayConfigTableCell.self, forCellReuseIdentifier: "PlayConfigTableCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height * 1.5))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: SettingCellItemType.playConfig.cellImage())
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(height)
        }
        return view
    }()
    
}

extension PlayConfigViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayConfigTableCell", for: indexPath) as! PlayConfigTableCell
        let itemType = dataArray[indexPath.section].itemArray[indexPath.row]
        cell.itemType = itemType
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let itemType = dataArray[indexPath.section].itemArray[indexPath.row]

        if itemType == .playerStyle {
            let playerVC = PlayerStyleViewController()
            self.navigationController?.pushViewController(playerVC, animated: true)
        }
        
        if itemType == .playerBack {
            let playerVC = PlayBackgroundListController()
            self.navigationController?.pushViewController(playerVC, animated: true)
        }
        
        if itemType == .playAnimation {
            let animation = PlayAnimationController()
            if kaka_IsiPhone() {
                self.presentPanModal(animation)
            }else{
                self.present(animation, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataArray[section].headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.footTitle
    }
    
    
}

class PlayConfigTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var itemType: PlayConfigItemType? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            
            switch itemType {
            case .preDownload:
                self.accessoryType = .none
                self.accessoryView = self.preDownloadSwitch
                self.preDownloadSwitch.isOn = MusicConfigManager.shared.isPreDownload
                self.selectionStyle = .none
                cellConfig.secondaryText = "Download.PreDownloadHelp".localStr()
                cellConfig.secondaryTextProperties.numberOfLines = 0
                
            case .playerStyle, .playerBack, .playAnimation:
                self.accessoryType = .disclosureIndicator
                self.accessoryView = nil
                self.selectionStyle = .default
                break
            case .showMissTags:
                self.accessoryType = .none
                self.accessoryView = self.misstagSwitchView
                break
                
            case .lastTimeCache:
                self.accessoryType = .none
                self.accessoryView = self.lastcacheSwitchView
                break                
            case .showExtension:
                self.accessoryType = .none
                self.accessoryView = self.extensionSwitchView
                break
            case .lyricStyle:
                self.accessoryType = .none
                self.accessoryView = self.lyricPlayerView()
                self.selectionStyle = .default
                break
            
            case .transcoding:
                self.accessoryType = .none
                self.accessoryView = self.transcodingSwitchView
                break
            case .targetFormat:
                self.accessoryType = .none
                self.accessoryView = self.targetFormatView()
                self.selectionStyle = .default
                break
            case .targetMaxBitRate:
                self.accessoryType = .none
                self.accessoryView = self.maxBiteRateView()
                self.selectionStyle = .default
                break
            
            }
                        
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            self.contentConfiguration = cellConfig
        }
    }
    
    private lazy var preDownloadSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = appMainColor
        toggle.addTarget(self, action: #selector(preDownloadChanged(_:)), for: .valueChanged)
        return toggle
    }()

    @objc private func preDownloadChanged(_ sender: UISwitch) {
        MusicConfigManager.shared.isPreDownload = sender.isOn
        if sender.isOn { KakaMusicPlayer.shared.prepareNextMusic() }
        else { DownloadManager.shared.cancelPreDownload() }
    }

    lazy var misstagSwitchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.isOn = MusicConfigManager.shared.isShowMissTag
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(misstagSwitchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func misstagSwitchViewClick(_ sender: UISwitch) {
        MusicConfigManager.shared.isShowMissTag = sender.isOn
    }
    
    lazy var lastcacheSwitchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.isOn = MusicConfigManager.shared.isLastCache
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(lastcacheSwitchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func lastcacheSwitchViewClick(_ sender: UISwitch) {
        MusicConfigManager.shared.isLastCache = sender.isOn
        
        if !sender.isOn {
            MusicConfigManager.shared.lastPlayTime = 0
            MusicConfigManager.shared.lastTotalTime = 0
        }
    }
    
    // 是否显示扩展名
    lazy var extensionSwitchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.isOn = MusicConfigManager.shared.isShowExtension
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(extensionSwitchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func extensionSwitchViewClick(_ sender: UISwitch) {
        MusicConfigManager.shared.isShowExtension = sender.isOn
        NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
    }
    
    // 屏幕歌词
    func lyricPlayerView() -> UIView {
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.lyricPlayerMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = MusicConfigManager.shared.lyricSortStyle.formatStr()
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    func lyricPlayerMenu() -> UIMenu {
        
        let normalArray: [LyricSortStyle] = [.dontShow, .firstLine, .secondLine]
        var actionArray1 = [UIAction]()
        let selectType = MusicConfigManager.shared.lyricSortStyle

        for subType in normalArray {
            let action = UIAction(title: subType.formatStr(), image: nil, state: selectType == subType ? .on : .off, handler: { _ in
                MusicConfigManager.shared.lyricSortStyle = subType
//                NotificationCenter.default.post(name: Notification.Name(kScreenLyricSortChangedKey), object: nil, userInfo: nil)
            })

            actionArray1.append(action)
        }
        let normalMenu = UIMenu(title: "", options: .displayInline, children: actionArray1)
        return normalMenu
        
    }
    
    // 是否转码
    lazy var transcodingSwitchView: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.isOn = MusicConfigManager.shared.isTranscoding
        view.onTintColor = ColorFontManager.shared.accentTyle == .color0 ? ColorFontManager.shared.defaultType.color() : ColorFontManager.shared.accentTyle.color()
        view.addTarget(self, action: #selector(transcodingSwitchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func transcodingSwitchViewClick(_ sender: UISwitch) {
        MusicConfigManager.shared.isTranscoding = sender.isOn
        if sender.isOn {
            MusicConfigManager.shared.navFormats = .mp3
            MusicConfigManager.shared.navMaxBitRate = .bitRate128
        }else{
            MusicConfigManager.shared.navFormats = .raw
            MusicConfigManager.shared.navMaxBitRate = .bitRate0
        }
        
    }
    
    // 转码格式
    func targetFormatView() -> UIView {
        let isCoding = MusicConfigManager.shared.isTranscoding
        let navFormats = isCoding ? MusicConfigManager.shared.navFormats.formatStr() : "No Transcoding".localStr()
        
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.targetFormatMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = navFormats
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    func targetFormatMenu() -> UIMenu {
        
        let normalArray: [NavidromeTargetFormat] = [.mp3, .opus, .aac]
        var actionArray1 = [UIAction]()
        let selectType = MusicConfigManager.shared.navFormats

        for subType in normalArray {
            let action = UIAction(title: subType.formatStr(), image: nil, state: selectType == subType ? .on : .off, handler: { _ in
                MusicConfigManager.shared.navFormats = subType
            })

            actionArray1.append(action)
        }
        let normalMenu = UIMenu(title: PlayConfigItemType.targetFormat.titleStr(), options: .displayInline, children: actionArray1)
        return normalMenu
    }
    
    // 目标比特率
    func maxBiteRateView() -> UIView {
        let isCoding = MusicConfigManager.shared.isTranscoding
        let navFormats = isCoding ? MusicConfigManager.shared.navMaxBitRate.formatStr() : "No Transcoding".localStr()
        
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.maxBiteRateMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = navFormats
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    func maxBiteRateMenu() -> UIMenu {
        
        let normalArray: [NavidromeMaxBitRate] = [.bitRate128, .bitRate192, .bitRate320]
        var actionArray1 = [UIAction]()
        let selectType = MusicConfigManager.shared.navMaxBitRate

        for subType in normalArray {
            let action = UIAction(title: subType.formatStr(), image: nil, state: selectType == subType ? .on : .off, handler: { _ in
                MusicConfigManager.shared.navMaxBitRate = subType
            })

            actionArray1.append(action)
        }
        let normalMenu = UIMenu(title: PlayConfigItemType.targetMaxBitRate.titleStr(), options: .displayInline, children: actionArray1)
        return normalMenu
    }
    
}
