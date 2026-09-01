//
//  AboutAppViewController.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AppGroupKit
import SafariServices
import AVFoundation
import AVKit
import MessageUI

/// 关于APP信息
class AboutAppViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
        tableView.reloadData()
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = SettingCellItemType.abountUS.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.perform(#selector(getCacheSize), with: nil, afterDelay: 1)
    }
    
    @objc func getCacheSize() {
        DispatchQueue.global().sync {
            let cache = KakaCacheTools.getCacheSize()
            DispatchQueue.main.async {                
                self.cacheSize = cache
                self.tableView.reloadData()
            }
        }
    }
    
    var cacheSize: String = ""
        
    // MARK:  GET && SET 
    // App logo、隐私政策、服务条款，欢迎页、清理缓存
    lazy var dataArray: [[AboutAppCellType]] = {
        let section1: [AboutAppCellType] = [.crossSystem, .appStore]
        let section2: [AboutAppCellType] = [.privacy, .userMent]
        var section3: [AboutAppCellType] = [.contactus, .systemSet, .cleanCache]
        if kaka_IsMacOS() {
            section3.removeFirst()
        }
        return [section1, section2, section3]
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight + 30.ckValue(), right: 0)
        view.register(AboutAppTableCell.self, forCellReuseIdentifier: "AboutAppTableCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "AboutTableViewCell")
        return view
    }()
    
}

extension AboutAppViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataArray[indexPath.section][indexPath.row]
        if item == .crossSystem {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutAppTableCell", for: indexPath) as! AboutAppTableCell
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutTableViewCell", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            var cellConfig = UIListContentConfiguration.sidebarCell()
            cellConfig.text = item.titleStr()
            cellConfig.secondaryText = item.descStr()
            cellConfig.textProperties.color = UIColor.label
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 0)
            
            if item == .cleanCache {
                cellConfig.secondaryText = self.cacheSize
            }
            
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            
            cell.contentConfiguration = cellConfig
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = dataArray[indexPath.section][indexPath.row]
        if item == .appStore {
            let storeURL = Application.wakeMusic.appstoreURL()
            UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
        }
        
        if item == .systemSet {
            if let vURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(vURL)
            }
        }
        
        if item == .privacy {
            guard let vUrl = URL(string: kPrivacyUrl) else { return }
            
            if kaka_IsMacOS() {
                UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
            }else{
                let webVC = SFSafariViewController(url: vUrl)
                webVC.preferredControlTintColor = appMainColor
                self.present(webVC, animated: true)
            }
        }
        
        if item == .userMent {
            guard let vUrl = URL(string: kUseItemUrl) else { return }
            
            if kaka_IsMacOS() {
                UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
            }else{
                let webVC = SFSafariViewController(url: vUrl)
                webVC.preferredControlTintColor = appMainColor
                self.present(webVC, animated: true)
            }
        }
        
        if item == .contactus {
            self.handleWithEmail()
        }
        
        if item == .cleanCache {
            KakaCacheTools.finishCacheCompletion { [weak self] () in
                self?.cacheSize = "0kb"
                self?.tableView.reloadData()
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = dataArray[indexPath.section][indexPath.row]
        return item == .crossSystem ? 220.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return 30.ckValue()
        }else if section == 2 {
            let image = Reasource.named("welcome_system")
            let imageValue = image.size.height / image.size.width
            
            return contentView.width * imageValue + 30.ckValue()
        }else{
            return 20.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return self.createBeianView()
        }else if section == 2 {
            return self.createFootView()
        }else{
            return UIView()
        }
    }
    
    func createBeianView() -> UITableViewHeaderFooterView {
#if Target_Mobie_Pro
        let beianhao = "粤ICP备2023115933号-7A"
#else
        let beianhao = "粤ICP备2023115933号-5A"
#endif
        
        let footView = UITableViewHeaderFooterView()
        let footLabel = UILabel()
        footLabel.text = beianhao
        footLabel.textColor = .secondaryLabel
        footLabel.font = UIFontLight(12.ckValue())
        footLabel.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        footLabel.isHidden = PhoneSetManager.formatLanguage() != .chinese_simplified
        footView.contentView.addSubview(footLabel)
        footLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20.ckValue())
            make.top.equalTo(10.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        return footView
    }
    
    func createFootView() -> UITableViewHeaderFooterView {
        let image = Reasource.named("welcome_system")
        let imageValue = image.size.height / image.size.width
        
        let footView = UITableViewHeaderFooterView()
        let systemIconView = UIImageView(image: image)
        systemIconView.contentMode = .scaleAspectFit
        footView.contentView.addSubview(systemIconView)
        systemIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10.ckValue())
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.equalTo(systemIconView.snp.width).multipliedBy(imageValue)
        }
        return footView
    }
    
    
}


// MARK:  邮箱联系
extension AboutAppViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    
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
