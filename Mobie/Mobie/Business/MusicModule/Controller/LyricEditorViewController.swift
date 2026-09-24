//
//  LyricEditorViewController.swift
//  Mobie
//
//  Created by 张文 on 11/11/24.
//


import KakaFoundation
import KakaUIKit
import AppGroupKit
import WaketagLibKit


/// 手动编辑歌词内容
class LyricEditorViewController: SuperViewController {
    init(musicModel: MusicItemModel?) {
        super.init(nibName: nil, bundle: nil)
        self.musicModel = musicModel
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
        self.navigationItem.largeTitleDisplayMode = .automatic
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonClick))
        
        self.textView.text = self.musicModel?.lyricModel?.toLyricString(true)
        
        self.textViewDidEndEditing(self.textView)
    }
    
    @objc func doneButtonClick() {
        self.view.endEditing(true)
        
        guard let lyricText = self.textView.text, lyricText.count > 0 else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        let tempModel = TaglibMetadataParser.parseSynchronizedLyrics(lyricText)
        
        guard let lyricModel = tempModel?.convertSwiftModel(), let lyrics = lyricModel.lyrics, lyrics.count > 0 else {
            self.view.makeToast("Invalid LRC lyrics format".localStr())
            return
        }
        
        self.editCallBack?(lyricModel)
        self.cancelButtonClick()
    }
    
    // MARK:  GET && SET
    var musicModel: MusicItemModel?
    
    var editCallBack: ((LyricInfoModel)->Void)?
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30.ckValue(), right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ExportTableViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "FeedbackQuestionCell")
        return view
    }()
    
    lazy var textView: UITextView = {
        let view = UITextView()
        view.delegate = self
        view.backgroundColor = .clear
        view.font = UIFontLight(16.ckValue())
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var placeLabel: UILabel = {
        let view = UILabel()
        view.text = LyricInfoModel.createDemoString()
        view.font = UIFontLight(16.ckValue())
        view.textColor = UIColor.secondaryLabel
        view.numberOfLines = 0
        return view
    }()
    
}

extension LyricEditorViewController: UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FeedbackQuestionCell", for: indexPath)
            cell.selectionStyle = .none
            cell.contentView.addSubview(textView)
            textView.snp.makeConstraints { make in
                make.leading.equalTo(10.ckValue())
                make.trailing.equalToSuperview()
                make.centerY.equalToSuperview()
                make.top.equalTo(10.ckValue())
            }
            cell.contentView.addSubview(placeLabel)
            placeLabel.snp.makeConstraints { make in
                make.top.equalTo(textView).offset(10.ckValue())
                make.leading.equalTo(textView).offset(10.ckValue())
                make.centerX.equalTo(textView)
                make.height.greaterThanOrEqualTo(0)
            }
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = indexPath.section == 1 ? NoneLyricCellType.textManual.titleStr() : "Import LRC".localStr()
#if !targetEnvironment(macCatalyst)
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
#endif
            cellConfig.textProperties.color = UIColor.white
            cellConfig.textProperties.alignment = .center
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
            cell.backgroundColor = indexPath.section == 1 ? UIColor.systemBlue : UIColor.systemRed
            cell.accessoryType = .none
            cell.contentConfiguration = cellConfig
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        
        if indexPath.section == 1 {
            guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
            self.textView.text = text
            self.placeLabel.isHidden = true
        }
        
        if indexPath.section == 2 {
            self.selectLocalLyrics()
        }
    }
    
    // 选择本地歌词
    func selectLocalLyrics() {
        self.view.endEditing(true)
        
        let lyricVC = LibraryLyricsViewController(isSelect: true)
        lyricVC.onSelectCallback = { [weak self] (subURL) in
            self?.readLyricTextFile(subURL)
        }
        let navVC = KakaNavigationController(rootViewController: lyricVC)
        navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
        self.present(navVC, animated: true)
    }
    
    func readLyricTextFile(_ firstURL: URL) {
        // 检查是否成功读取内容
        guard let fileContent = firstURL.readLRCContentStr(), fileContent.count > 1 else {
            self.view.makeToast("Unable to open document. Text encoding Unicode (UTF-8 and GBK) is not applicable.".localStr())
            return
        }
        
        self.placeLabel.isHidden = true
        self.textView.text = fileContent
        self.tableView.reloadData()
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return (self.view.height - app_navHeight - kaka_safeAreaInsets().bottom) * 0.6
        }else{
            return kaka_IsMacOS() ? 50 : UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return NoneLyricCellType.textManual.titleStr()
        }else{
            return nil
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeLabel.isHidden = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        self.placeLabel.isHidden = textView.text.count > 0
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
    }
    
}



extension LyricInfoModel {
    
    public static func createDemoString() -> String {
        var fullLyric = ""
        
        let titleStr = MusicTagType.artist.titleStr() + " - " + MusicTagType.title.titleStr()
 
        fullLyric.append("[00:00.00]" + " " + titleStr)
        fullLyric.append("\r")
        
        fullLyric.append("[00:03.10]" + " " + "Lyrics line 1".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[00:05.10]" + " " + "Lyrics line 2".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[00:07.10]" + " " + "Lyrics line 3".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("······")
        fullLyric.append("\r")
        
        fullLyric.append("······")
        fullLyric.append("\r")
        
        fullLyric.append("······")
        fullLyric.append("\r")
        
        fullLyric.append("[00:05.32]" + " " + "······")
                
        return fullLyric
    }
    
}
