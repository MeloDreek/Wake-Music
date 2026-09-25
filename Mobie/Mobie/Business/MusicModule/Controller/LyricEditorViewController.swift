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
import SafariServices


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

    private var isReadingAITags = false

    private func aiMenu() -> UIMenu {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        let actions = LyricAIProvider.available(language: language).map { provider in
            UIAction(title: provider.title) { [weak self] _ in
                self?.prepareAIPrompt(for: provider)
            }
        }
        return UIMenu(children: actions)
    }

    private func prepareAIPrompt(for provider: LyricAIProvider) {
        view.endEditing(true)
        guard !isReadingAITags else { return }
        // Never use titleStr()/filePathName() or uncommitted editor values.
        // Only tags actually embedded in the local file qualify.
        guard let url = musicModel?.mediaPlayURL, url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            showMissingAITags()
            return
        }
        isReadingAITags = true
        let knownDuration = musicModel?.durationSeconds ?? 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let scoped = url.startAccessingSecurityScopedResource()
            let metadata = TaglibMetadataParser.readMetadata(withFileURL: url, read: .basic)
            let tags = LyricAIProvider.embeddedTags(title: metadata?.title, artist: metadata?.artist)
            let duration = LyricAIProvider.durationText(seconds: Int(metadata?.durationSeconds ?? 0), fallback: knownDuration)
            if scoped { url.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isReadingAITags = false
                guard self.viewIfLoaded?.window != nil, self.presentedViewController == nil else { return }
                guard let tags else {
                    self.showMissingAITags()
                    return
                }
                let prompt = String(format: "LyricAI.PersonalUse".localStr(), duration ?? "—")
                    + "\n\n" + String(format: "LyricAI.Prompt".localStr(), tags.title, tags.artist)
                let alert = UIAlertController(title: provider.title, message: prompt, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Copy".localStr(), style: .default) { _ in
                    UIPasteboard.general.string = prompt
                })
                alert.addAction(UIAlertAction(title: String(format: "LyricAI.CopyAndOpen".localStr(), provider.title), style: .default) { [weak self] _ in
                    UIPasteboard.general.string = prompt
                    self?.openAI(provider)
                })
                alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }

    private func openAI(_ provider: LyricAIProvider) {
        // Wait for the prompt alert to finish dismissing before browser fallback.
        if let alert = presentedViewController as? UIAlertController {
            alert.dismiss(animated: true) { [weak self] in self?.openAI(provider) }
            return
        }
#if targetEnvironment(macCatalyst)
        // Apple's Catalyst implementation sends Safari view-controller content
        // to the default browser, without trying the AI's desktop app.
        present(SFSafariViewController(url: provider.url), animated: true)
#else
        // Open the native URL scheme directly. Unlike canOpenURL, open does not
        // require LSApplicationQueriesSchemes; its completion determines fallback.
        UIApplication.shared.open(provider.appURL, options: [:]) { [weak self] opened in
            guard !opened else { return }
            DispatchQueue.main.async {
                guard let self, self.viewIfLoaded?.window != nil else { return }
                self.present(SFSafariViewController(url: provider.url), animated: true)
            }
        }
#endif
    }

    private func showMissingAITags() {
        let alert = UIAlertController(title: "LyricAI.Search".localStr(), message: "LyricAI.MissingMetadata".localStr(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localStr(), style: .default))
        present(alert, animated: true)
    }
    
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
        view.register(LyricAISearchCell.self, forCellReuseIdentifier: "LyricAISearchCell")
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
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : 3
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
        } else if indexPath.row == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricAISearchCell", for: indexPath) as! LyricAISearchCell
            cell.menuButton.menu = aiMenu()
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = indexPath.row == 0 ? NoneLyricCellType.textManual.titleStr() : "Import LRC".localStr()
#if !targetEnvironment(macCatalyst)
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
#endif
            cellConfig.textProperties.color = appMainColor
            cellConfig.image = UIImage(systemName: indexPath.row == 0 ? "doc.on.clipboard" : "doc.badge.plus")
            cellConfig.imageProperties.tintColor = appMainColor
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
            cell.backgroundColor = .secondarySystemGroupedBackground
            cell.accessoryType = .disclosureIndicator
            cell.contentConfiguration = cellConfig
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.view.endEditing(true)
        
        if indexPath.section == 1 && indexPath.row == 0 {
            guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
            self.textView.text = text
            self.placeLabel.isHidden = true
        }
        
        if indexPath.section == 1 && indexPath.row == 1 {
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

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? "LyricAI.Workflow".localStr() : nil
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        self.placeLabel.isHidden = textView.text.count > 0
    }
    
    func textViewDidChange(_ textView: UITextView) {
        
    }
    
}



// Foundation-only model, also exercised by the standalone regression tests.
enum LyricAIProvider: String, CaseIterable {
    case chatGPT, gemini, grok, claude, doubao, deepSeek, kimi

    static func available(language: String) -> [Self] {
        let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
        let simplified = normalized == "zh-hans" || normalized.hasPrefix("zh-hans-")
        return simplified ? allCases : [.chatGPT, .gemini, .grok, .claude]
    }

    static func embeddedTags(title: String?, artist: String?) -> (title: String, artist: String)? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
              let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty else { return nil }
        return (title, artist)
    }

    static func durationText(seconds: Int, fallback: Int) -> String? {
        let duration = seconds > 0 ? seconds : fallback
        guard duration > 0 else { return nil }
        if duration >= 3600 {
            return String(format: "%d:%02d:%02d", duration / 3600, duration / 60 % 60, duration % 60)
        }
        return String(format: "%02d:%02d", duration / 60, duration % 60)
    }

    var title: String {
        switch self {
        case .chatGPT: return "ChatGPT"
        case .gemini: return "Gemini"
        case .grok: return "Grok"
        case .claude: return "Claude"
        case .doubao: return "豆包"
        case .deepSeek: return "DeepSeek"
        case .kimi: return "Kimi"
        }
    }

    var url: URL {
        let address: String
        switch self {
        case .chatGPT: address = "https://chatgpt.com/"
        case .gemini: address = "https://gemini.google.com/"
        case .grok: address = "https://grok.com/"
        case .claude: address = "https://claude.ai/"
        case .doubao: address = "https://www.doubao.com/chat/"
        case .deepSeek: address = "https://chat.deepseek.com/"
        case .kimi: address = "https://www.kimi.com/"
        }
        return URL(string: address)!
    }

    var appURL: URL {
        let address: String
        switch self {
        case .chatGPT: address = "chatgpt://"
        case .gemini: address = "googlegemini://"
        case .grok: address = "grok://"
        case .claude: address = "claude://"
        case .doubao: address = "snssdk497858://"
        case .deepSeek: address = "deepseek://"
        case .kimi: address = "kimi://"
        }
        return URL(string: address)!
    }
}

private final class LyricAISearchCell: UITableViewCell {
    let menuButton = UIButton(type: .custom)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        var config = UIListContentConfiguration.cell()
        config.text = "LyricAI.Search".localStr()
        config.textProperties.color = appMainColor
#if !targetEnvironment(macCatalyst)
        config.textProperties.font = UIFontBold(17.ckValue())
#endif
        config.image = UIImage(systemName: "sparkles")
        config.imageProperties.tintColor = appMainColor
        config.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
        contentConfiguration = config
        selectionStyle = .none
        accessoryType = .disclosureIndicator
        // A full-row primary menu action works on tap, keyboard and Catalyst,
        // without private menu presentation APIs or long-press-only interaction.
        // Cover the accessory area too, so tapping the chevron opens the menu.
        addSubview(menuButton)
        menuButton.snp.makeConstraints { $0.edges.equalToSuperview() }
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.accessibilityLabel = "LyricAI.Search".localStr()
        accessibilityElements = [menuButton]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        bringSubviewToFront(menuButton)
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
