//
//  LyricEditorViewController.swift
//  Mobie
//
//  Created by 张文 on 11/11/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import MusicKit
import MessageUI
import SafariServices


/// 编辑歌词内容
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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonClick))
        
        self.textView.text = self.musicModel?.lyricModel?.toLyricString(true)

        self.textViewDidEndEditing(self.textView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.textView.isHidden = !UserInfoManager.shared.isVIP()
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
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK:  GET && SET
    var musicModel: MusicItemModel?
    
    var editCallBack: ((LyricInfoModel)->Void)?
    
    lazy var aiArray: [AIType] = {
        return AIType.allTypes()
    }()
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "BasicAiTypeViewCell")
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
        return section == 0 ? aiArray.count : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let aiType = self.aiArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "BasicAiTypeViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.image = aiType.iconImage()
            cellConfig.text = aiType.titleStr()
            cellConfig.image = aiType.iconImage()
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.imageProperties.maximumSize = CGSizeMake(30.ckValue(), 30.ckValue())
            cell.contentConfiguration = cellConfig
            cell.accessoryType = .disclosureIndicator
            return cell
        }else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = "Import LRC file".localStr()
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
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        if indexPath.section == 0 {
            let aiType = self.aiArray[indexPath.row]
            self.searchWithAIReminder(aiType)
        }
        
        if indexPath.section == 1 {
            self.selectLocalLyrics()
        }
    }
    
    // 选择本地歌词
    func selectLocalLyrics() {
        self.view.endEditing(true)
        
        let lyricVC = LyricListViewController(isSelect: true)
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
    
    
    

    
    // 点击AI前往搜索，复制文本
    func searchWithAIReminder(_ aiType: AIType) {
        guard let title = self.musicModel?.title, !title.isEmpty, let artist = self.musicModel?.artist, !artist.isEmpty else {
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 || indexPath.section == 1 {
            return UITableView.automaticDimension
        }else{
            return  (self.view.height - app_navHeight - kaka_safeAreaInsets().bottom) * 0.8
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "AI"
        }else if section == 1 {
            return nil
        }else{
            guard let lyrics = self.musicModel?.lyricModel?.lyrics, lyrics.count > 0 else {
                return "Please copy and paste the lyrics text according to the LRC specification".localStr()
            }
            
            return "Lyrics".localStr()
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
        
        fullLyric.append("[ti:\("Title".localStr())]" + " " + "Optional".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[ar:\("Artist".localStr())]" + " " + "Optional".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[al:\("Album".localStr())]" + " " + "Optional".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[by:\("Lyrics Maker".localStr())]" + " " + "Optional".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[00:03.10]" + " " + "Line 1".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[00:05.10]" + " " + "Line 2".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("[00:07.10]" + " " + "Line 3".localStr())
        fullLyric.append("\r")
        
        fullLyric.append("······")
        fullLyric.append("\r")
        
        fullLyric.append("[00:05.32]" + " " + "The last line of lyrics".localStr())
                
        return fullLyric
    }
}
