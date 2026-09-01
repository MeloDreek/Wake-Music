//
//  FAQsViewController.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MessageUI
import SafariServices

import UIKit

struct QuestionAnswerModel {
    /// 问题
    var question: String = ""
    
    /// 回答（每一项代表一个独立的段落/要点）
    var answers: [String] = []
    
    /// 底部说明
    var footer: String?
    
    func questionStr() -> NSAttributedString {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.ckValue()           // 行与行之间的间距
        paragraphStyle.paragraphSpacing = 10.ckValue()     // 段与段（数组元素）之间的间距
        
        let boldFont = UIFontBold(kaka_IsMacOS() ? 15 : 18)
        
        let attributeStr = NSAttributedString(string: self.question, attributes: [
            .font: boldFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ])
        
        return attributeStr
    }
    
    /// 回答富文本，控制间距等等
    func answerStr() -> NSAttributedString {
        let attributeStr = NSMutableAttributedString()
        
        // 全局段落样式：控制行距和段间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.ckValue()
        paragraphStyle.paragraphSpacing = 10.ckValue()
        
        let boldFont = UIFontLight(kaka_IsMacOS() ? 15 : 17)
        let mediumFont = UIFontLight(kaka_IsMacOS() ? 13 : 16)
        
        for (index, text) in answers.enumerated() {
            // 为每段文本应用统一的属性
            let itemAttributeStr = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: mediumFont,
                    .foregroundColor: UIColor.secondaryLabel,
                    .paragraphStyle: paragraphStyle
                ]
            )
            
            // 匹配段落开头的粗体高亮（如 "● Apple 生态首选：" 格式）
            if let colonRange = text.range(of: "：") ?? text.range(of: ":") {
                let nsRange = NSRange(text.startIndex..<colonRange.upperBound, in: text)
                itemAttributeStr.addAttributes([
                    .font: boldFont,
                    .foregroundColor: UIColor.label
                ], range: nsRange)
            }
            
            attributeStr.append(itemAttributeStr)
            
            // 只要不是最后一段，就追加换行符
            if index < answers.count - 1 {
                attributeStr.append(NSAttributedString(string: "\n"))
            }
        }
        
        return attributeStr
    }
}

/// 常见问题
class FAQsViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.title = "FAQ".localStr()
        
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: Reasource.systemNamed("envelope"), style: .plain, target: self, action: #selector(handleWithEmail))

        // 1️⃣ 音频格式选择
            let formatModel = QuestionAnswerModel(
                question: "What is the best audio format?".localStr(),
                answers: [
                    "Although our universal audio engine supports all formats, 'best' depends on your specific use case.".localStr(),
                    "● Apple Ecosystem Preferred: ALAC (packaged as M4A) is Apple's proprietary lossless audio format and the standard for Apple Music Hi-Res Lossless, offering the highest decoding efficiency on iOS and Mac devices.".localStr(),
                    "● Preferred for Cross-Platform Lossless: FLAC is the lossless format with the best compatibility. It offers excellent sound quality, a moderate file size, and full support for music tags like cover art and lyrics.".localStr(),
                    "● Ultimate Audiophile & Master Collection: If you have high-end wired equipment and don't mind storage space, DSF (DSD) and WAV are the best choices for master-grade lossless audio, typically requiring expensive Hi-Fi headphones or speakers to reach their full potential.".localStr(),
                    "● Ultimate Spatial Surround: DTS features exceptional spatial immersion and low-frequency performance, making it ideal for car audio systems and blockbuster movie tuning—delivering truly mind-blowing spatial audio! (Note: DTS format itself cannot directly embed cover art and music metadata)".localStr(),
                    "● Space-Saving & Daily Listening: If you want to save storage space, MP3 and AAC remain the best choices for balancing sound quality with compact file sizes.".localStr()
                ],
                footer: "Except for DTS, all the audio formats mentioned above support embedding complete music metadata such as cover art and lyrics.".localStr()
            )

            // 2️⃣ 离线与元数据坚持
            let matchModel = QuestionAnswerModel(
                question: "Why not match metadata online?".localStr(),
                answers: [
                    "Whether it's offline music or tracks in your cloud storage or NAS, your music collection is a lifelong asset. That's why we insist on reading metadata directly embedded within the audio files first, rather than relying on online databases that might fail or mismatch.".localStr(),
                    "Online matching relies heavily on your audio file names or embedded titles, artist names, and track durations. Any non-standard element can lead to incorrect cover art and lyrics.".localStr(),
                    "You can use our built-in music tag editor to ensure every audio file contains complete embedded metadata. It now supports acoustic fingerprinting to automatically identify metadata and batch-embed it directly into your audio files.".localStr(),
                    "Tip: After switching the grouping mode on the home screen to 【Music Tags】, you can batch auto-embed metadata and resave or re-upload the files to your cloud storage or NAS, achieving true permanent collection value!".localStr()
                ]
            )
                    
            // 3️⃣ 音乐标签定义
            let tagModel = QuestionAnswerModel(
                question: "What is Music Tag?".localStr(),
                answers: [
                    "Music tags (ID3 Metadata) refer to metadata embedded permanently inside audio files, including cover art, lyrics, track title, artist, album, release year, genre, sample rate, bit rate, and more.".localStr(),
                    "Once metadata is written into tags, no matter what device you transfer your music files to, this information will never be lost!".localStr(),
                    "Note: Parsing music tags across dozens of audio formats—especially complex embedded cover art and lyrics—is a demanding technical challenge that not all music players are capable of handling.".localStr()
                ]
            )
            
            // 4️⃣ 音频指纹识别
            let audioFingerModel = QuestionAnswerModel(
                question: "What is Audio Fingerprinting?".localStr(),
                answers: [
                    "Just as every person has a unique fingerprint, every song's audio waveform possesses a unique 【acoustic signature】.".localStr(),
                    "Acoustic fingerprinting technology can rapidly extract these waveform features to accurately identify and complete song cover art, lyrics, title, artist, and album information within seconds.".localStr()
                ]
            )
                    
            // 5️⃣ 云端与网盘文件编辑
            let networkModel = QuestionAnswerModel(
                question: "Can I edit cloud files?".localStr(),
                answers: [
                    "Directly editing files in cloud storage or NAS is currently not supported.".localStr(),
                    "Writing embedded metadata requires reading and writing the entire audio file. Therefore, you need to download the music file to your local device first, export it after editing, and then re-upload it to your cloud storage or NAS.".localStr(),
                    "Once re-uploaded to cloud storage or NAS, you can stream directly without downloading. Our all-format audio engine seamlessly parses embedded cover art, lyrics, and metadata. Wakemusic is likely the only music player on the App Store to achieve this.".localStr()
                ]
            )
                    
            // 6️⃣ 意见反馈
            let otherModel = QuestionAnswerModel(
                question: "Have more questions or suggestions?".localStr(),
                answers: [
                    "Feel free to reach out to us at any time via the email entrance at the top. We read and reply to every user's feedback and suggestions carefully!".localStr()
                ]
            )
        
        self.dataArray.append(QuestionAnswerModel())
        self.dataArray.append(formatModel)
        self.dataArray.append(matchModel)
        self.dataArray.append(tagModel)
        self.dataArray.append(audioFingerModel)
        self.dataArray.append(networkModel)
        self.dataArray.append(otherModel)
                
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationItem.largeTitleDisplayMode = .never
        
        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        barAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
    }
    
    //MARK: - 🌹 Lazy Init 🌹
    
    lazy var dataArray: [QuestionAnswerModel] = {
        return [QuestionAnswerModel]()
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight + 20.ckValue(), right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "FAQsTableViewCell")
        view.register(SocialMediaTableCell.self, forCellReuseIdentifier: "SocialMediaTableCell")
        return view
    }()
        
}

extension FAQsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SocialMediaTableCell", for: indexPath) as! SocialMediaTableCell
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "FAQsTableViewCell", for: indexPath)
            let model = self.dataArray[indexPath.section]
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.attributedText = model.questionStr()
            cellConfig.secondaryAttributedText = model.answerStr()
            
            cellConfig.textToSecondaryTextVerticalPadding = 10.ckValue()
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.textProperties.numberOfLines = 0
            cellConfig.secondaryTextProperties.numberOfLines = 0
            
            cell.contentConfiguration = cellConfig
            cell.accessoryType = .none
            cell.selectionStyle = .none
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            self.handleWithEmail()
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let model = self.dataArray[section]
        
        return model.footer
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 200.ckValue() : UITableView.automaticDimension
    }
}

// MARK:  邮箱联系
extension FAQsViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wakemusic".localStr()) Feedback"
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
        
        let canOpenMailScheme = UIApplication.shared.canOpenURL(URL(string: "mailto:")!)
        let mailtoURL = URL(string: "mailto:\(companyEmail)?subject=\(subject)&body=\(messageBody)")!
        
        if !MFMailComposeViewController.canSendMail() {
            
            if canOpenMailScheme {
                // 2️⃣ 打开第三方邮件客户端
                UIApplication.shared.open(mailtoURL)
            }else{
                // 3️⃣ 用户没有任何邮件客户端
                if kaka_IsMacOS() {
                    UIApplication.shared.open(FeedbackURL)
                }else{
                    let feedbackVC = SFSafariViewController(url: FeedbackURL)
                    self.present(feedbackVC, animated: true)
                }
            }
            return
        }
        
        // 1️⃣ 优先使用Apple的邮件客户端
        if canOpenMailScheme && kaka_IsMacOS() {
            UIApplication.shared.open(mailtoURL)
        }else{
            let emailVC = MFMailComposeViewController()
            emailVC.mailComposeDelegate = self
            emailVC.setToRecipients([companyEmail])
            emailVC.setSubject(subject)
            emailVC.setMessageBody(messageBody, isHTML: false)
            self.present(emailVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        if result == .sent {
            self.view.makeToast("Thank you for your feedback".localStr())
        }
        
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
    func getDeviceInformation() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = kaka_IsMacOS() ? "macOS" : device.model
        let appVersion = ((Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "") + "_" + "\(UserInfoManager.shared.isVIP() ? "1" : "0")"

        return """
        App Name: \("Wakemusic".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}


class SocialMediaTableCell: UITableViewCell {
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
        contentView.addSubview(socialImgView)
        contentView.addSubview(mailLabel)
    }
    
    private func preSetupContains() {
        socialImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(10.ckValue())
            make.width.equalToSuperview()
        }
        
        mailLabel.snp.remakeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.size.equalTo(mailLabel.size)
        }
    }
    
    private func preSetupHandleBuness() {
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    lazy var socialImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.image = Reasource.named("support_social")
        return view
    }()
    
    lazy var mailLabel: UILabel = {
        let font = UIFontLight(11.ckValue())
        let message = "E-Mail".localStr()
        let nameSize = CGSize(width: message.width(font) + 30.ckValue(), height: font.lineHeight + 10.ckValue())
        let corners: UIRectCorner = PhoneSetManager.isArabicLanguage() ? [.topRight] : [.topLeft]
        
        let view = UILabel(frame: CGRect(x: 0, y: 0, width: nameSize.width, height: nameSize.height))
        view.corner(byRoundingCorners: corners, radii: 20.ckValue())
        view.layer.masksToBounds = true
        view.text = message
        view.backgroundColor = appMainColor
        view.font = font
        view.textColor = .white
        view.textAlignment = .center
        return view
    }()
}
