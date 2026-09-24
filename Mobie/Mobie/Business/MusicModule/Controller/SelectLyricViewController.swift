//
//  SelectLyricViewController.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import WaketagLibKit
import NVActivityIndicatorView
import StoreKit

/// 选择已经匹配的歌词
class SelectLyricViewController: SuperViewController {
    
    init(music: MusicItemModel, result: AudioFingerprintModel?) {
        super.init(nibName: nil, bundle: nil)
        
        self.music = music
        self.result = result
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
        contentView.addSubview(loadingView)
        contentView.addSubview(loadingLabel)
        contentView.addSubview(tableView)
        contentView.addSubview(embeddedButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        loadingView.frame = CGRectMake((self.view.width - loadingView.size.width) / 2, (self.view.height - loadingView.size.height) / 2, loadingView.size.width, loadingView.size.height)
        loadingLabel.frame = CGRectMake(0, CGRectGetMaxY(loadingView.frame) + 12.ckValue(), self.view.width, loadingLabel.font.lineHeight * 1.5)
        
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
        self.title = "Select Lyrics".localStr()
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        self.navigationItem.rightBarButtonItem = self.moreButtomItem
        
        self.refreshDataAction()
    }
    
    func refreshDataAction() {
        let requestID = UUID()
        self.lyricRequestID = requestID
        self.selectLyricModel = nil
        self.lyricArray = []
        
        let tempLyric = TaglibMetadataParser.readMetadata(withFileURL: self.music.mediaPlayURL, read: .all).lyricModel
        if let lyrics = tempLyric?.lyrics, lyrics.count > 0 {
            self.embeddedLyric = tempLyric?.convertSwiftModel()
        }
        
        if let result = self.result, let lyrics = result.lyrics, lyrics.count > 0 {
            self.updateLyrics(lyrics)
        }else{
            
            self.loadingView.startAnimating()
            self.tableView.isHidden = true
            self.loadingView.isHidden = false
            self.loadingLabel.isHidden = false
            self.embeddedButton.isHidden = true
            self.tableView.reloadData()
            
            self.musicMatcher.matchLocalAudio(model: self.music) { [weak self] result in
                guard let self = self, self.lyricRequestID == requestID else { return }
                
                switch result {
                case .success(let model):
                    self.updateLyrics(model.lyrics ?? [])
                case .failure(let failure):
                    self.updateLyrics([])
                    self.showOneAlert(message: failure.errorDescription)
                }
            }
        }
        
    }

    private func updateLyrics(_ lyrics: [LyricInfoModel]) {
        self.lyricArray = lyrics
        self.selectLyricModel = nil
        self.loadingView.stopAnimating()
        self.tableView.isHidden = false
        self.loadingView.isHidden = true
        self.loadingLabel.isHidden = true
        self.embeddedButton.isHidden = false
        self.tableView.reloadData()
    }

    private func lyric(at indexPath: IndexPath) -> LyricInfoModel? {
        // Empty results still display a placeholder row; a pending tap can also
        // refer to an index from before the most recent refresh.
        guard indexPath.section == 1, lyricArray.indices.contains(indexPath.row) else { return nil }
        return lyricArray[indexPath.row]
    }
    
    // 内嵌事件
    @objc func doneButtonClick() {
        guard let selectLyricModel = self.selectLyricModel else {
            let section2Array = (self.tableView.indexPathsForVisibleRows ?? []).compactMap {
                return $0.section > 0
            }
            
            for i in 0..<section2Array.count {
                let subPath = IndexPath(row: i, section: 1)
                let subCell = self.tableView.cellForRow(at: subPath)
                subCell?.kaka_playShakeAnim()
            }
            
            return
        }
        
        self.onSelectBlock?(selectLyricModel)
        self.cancelButtonClick()
    }
    
    // 没有歌词
    @objc func noneLyricsAction() {
        let editVC = LyricEditorViewController(musicModel: self.music)
        editVC.title = self.music.filePathName()
        editVC.editCallBack = { [weak self] (newLyric) in
            guard let wSelf = self else { return }
            let lyricStr = newLyric.toLyricString(false) ?? ""
            let lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(lyricStr).convertSwiftModel()
            wSelf.onSelectBlock?(lyricModel)
            wSelf.cancelButtonClick()
        }
        self.navigationController?.pushViewController(editVC, animated: true)
    }
    
    // 设置为纯音乐
    func setPureMusicAction() {
        // 设置为纯音乐
        let lyricStr = "[00:00.000]" + "Instrumental · Enjoy the music".localStr()
        let lyricModel = TaglibMetadataParser.parseSynchronizedLyrics(lyricStr).convertSwiftModel()
        self.onSelectBlock?(lyricModel)
        self.cancelButtonClick()
    }
    
    // MARK: GET && SET
    var music: MusicItemModel!
    var result: AudioFingerprintModel?
    
    var selectLyricModel: LyricInfoModel?  // 当前选中的歌词
    var embeddedLyric: LyricInfoModel?  // 当前内嵌的歌词
    var onSelectBlock: ((LyricInfoModel)->Void)?
    private var lyricRequestID = UUID()
    
    // MARK: 懒加载
    
    lazy var musicMatcher: AudioFingerprintMatcher = {
        return AudioFingerprintMatcher()
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 80.ckValue() + kaka_safeAreaInsets().bottom, right: 0)
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(LRCLyricTableViewCell.self, forCellReuseIdentifier: "LRCLyricTableViewCell")
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        view.isHidden = true
        return view
    }()
    
    lazy var loadingLabel: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.font = UIFontLight(16.ckValue())
        view.textAlignment = .center
        view.textColor = .secondaryLabel
        view.text = "Processing...".localStr()
        return view
    }()
    
    // 手动粘贴歌词、设置为纯音乐
    lazy var moreButtomItem: UIBarButtonItem = {
        var actionArray = [UIAction]()
        
        let subMenu1 = UIAction(title: NoneLyricCellType.textManual.titleStr(), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.noneLyricsAction()
        })
        
        let subMenu2 = UIAction(title: NoneLyricCellType.pureMusic.titleStr(), identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
            self?.setPureMusicAction()
        })
        
        actionArray.append(subMenu1)
        actionArray.append(subMenu2)
                
        let addMenu = UIMenu(title: "", children: actionArray)
        
        let importBarItem = UIBarButtonItem(image: Reasource.systemNamed("ellipsis.circle"), menu: addMenu)
        return importBarItem
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
        let label = UILabel()
        label.text = "Embed".localStr()
        label.textColor = .white
        label.font = UIFontBold(17.ckValue())
        
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(doneButtonClick))
        view.addGestureRecognizer(tap)
        
        return view
    }()

    
    lazy var lyricArray: [LyricInfoModel] = {
        return [LyricInfoModel]()
    }()
    
}

extension SelectLyricViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else{
            return lyricArray.count > 0 ? lyricArray.count : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if let embeddedLyric = self.embeddedLyric {
                let cell = tableView.dequeueReusableCell(withIdentifier: "LRCLyricTableViewCell", for: indexPath) as! LRCLyricTableViewCell
                cell.updateLyric(lyricModel: embeddedLyric, isSelect: cell.isSelected)
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = .none
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.updateMessage("No embedded lyrics found".localStr())
                return cell
            }
            
        }else{
            if let lyricModel = self.lyric(at: indexPath) {
                let cell = tableView.dequeueReusableCell(withIdentifier: "LRCLyricTableViewCell", for: indexPath) as! LRCLyricTableViewCell
                let isSelected = self.selectLyricModel == lyricModel
                cell.updateLyric(lyricModel: lyricModel, isSelect: isSelected)
                cell.accessoryType = .none
                cell.accessoryView = isSelected ? cell.selectIconView : cell.nonSelectIconView
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.updateMessage()
                return cell
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return self.lyric(at: indexPath) == nil ? nil : indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let lyricModel = self.lyric(at: indexPath) else { return }
        
        self.selectLyricModel = lyricModel
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Current Embedded Lyrics".localStr()
        }else{
            return "Others".localStr()
        }
    }
    
    
}
