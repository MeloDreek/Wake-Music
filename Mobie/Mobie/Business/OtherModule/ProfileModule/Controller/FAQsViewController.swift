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
                
        let model1 = QuestionAnswerModel(questionStr: "What is Music Tag?".localStr(), realAnswerStr: "Music tag refers to the metadata embedded in a music file, including cover image, lyrics, title, artist, album, era, genre, track, sampling rate, bit rate, etc.".localStr(), emptyAnswerStr: nil, isFold: false)
        
        let audios = AudioExtension.audioSuffixs.map { $0.uppercased() }
        let fileStr = audios.joined(separator: ", ")
        let model2 = QuestionAnswerModel(questionStr: "What music formats are supported?".localStr(), realAnswerStr: fileStr, emptyAnswerStr: nil, isFold: true)
        
        let model3 = QuestionAnswerModel(questionStr: "Can album image and lyrics be embedded in music files?".localStr(), realAnswerStr: "Yes, we can embed all the missing basic tags, cover art, and lyrics into the music file. A music file with complete metadata can provide you with the best experience in offline music players.".localStr(), emptyAnswerStr: nil, isFold: true)
        
        let model4 = QuestionAnswerModel(questionStr: "Can I edit network files?".localStr(), realAnswerStr: "No. Parsing and editing the embedded metadata of music files requires the complete file, so we cannot directly modify online files. You need to download the music file to your local device to edit it.".localStr(), emptyAnswerStr: nil, isFold: true)
        
        let model5 = QuestionAnswerModel(questionStr: "How to verify that metadata has been embedded into the music file?".localStr(), realAnswerStr: "If you know ffmpeg, you can execute the command [ffmpeg - i file path] in the computer terminal. You will see the original music tag metadata".localStr(), emptyAnswerStr: nil, isFold: true)
                
        self.dataArray.append(QuestionAnswerModel())
        self.dataArray.append(model1)
        self.dataArray.append(model2)
        self.dataArray.append(model3)
        self.dataArray.append(model4)
        self.dataArray.append(model5)
                
        self.tableView.reloadData()
    }
    
    @objc func cancelBarItemClick() {
        (self.navigationController ?? self).dismiss(animated: true)
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
        view.register(FAQsTableViewCell.self, forCellReuseIdentifier: "FAQsTableViewCell")
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
            cellConfig.text = model.questionStr
            cellConfig.secondaryText = model.realAnswerStr
            cellConfig.textToSecondaryTextVerticalPadding = 10.ckValue()
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            if kaka_IsMacOS() {
                cellConfig.textProperties.font = UIFontBold(17)
                cellConfig.secondaryTextProperties.font = UIFontLight(15)
            }
            
            cell.contentConfiguration = cellConfig

            cell.accessoryType = .none
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
//#if DEBUG
//tableView.deselectRow(at: indexPath, animated: true)
//if let tabbarVC = self.tabBarController as? IOSTabbarViewController {
//    tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//}
//return
//#endif
        if indexPath.section == 0 {
            self.handleWithEmail()
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 200.ckValue() : UITableView.automaticDimension
    }
}

// MARK:  邮箱联系
extension FAQsViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wake Music".localStr()) Feedback"
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
        App Name: \("Wake Music".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}


struct QuestionAnswerModel {
    
    /// 问题
    var questionStr: String = ""
    
    /// 回答
    var realAnswerStr: String = ""
    
    /// 为空时后的回答
    var emptyAnswerStr: String?
    
    /// 是否为折叠
    var isFold: Bool = false
    
    func realAnswerString() -> String {
        return isFold ? "" : realAnswerStr
    }
    
}

class FAQsTableViewCell: UITableViewCell {
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
        let message = "Mail".localStr()
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
        let message = "Mail".localStr()
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
