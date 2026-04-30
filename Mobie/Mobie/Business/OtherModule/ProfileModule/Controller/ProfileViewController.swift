//
//  ProfileViewController.swift
//  AppLock
//
//  Created by Kaka Inc. on 2024/1/2.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaObjcKit
import KakaPhotoBrowser
import StoreKit
import SafariServices
import ProgressHUD
import RevenueCat
import MessageUI
import Combine

class ProfileViewController: SuperViewController {
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = self.contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = KakaTabbarType.profile.formatStr()
        
        // 主题颜色
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 开始折扣倒计时
        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationItem), name: Notification.Name(rawValue: kStartDiscountPriceKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationItem), name: Notification.Name(rawValue: kPurchageSuccessKey), object: nil)
                
        // 监听是否填好了兑换码
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNoti), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // 监听支付成功
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kPurchageSuccessKey), object: nil)
        
        // 播放引擎切换了
        NotificationCenter.default.addObserver(self, selector: #selector(updateNavigationItem), name: Notification.Name(rawValue: kPlayerEngineChangedKey), object: nil)

    }
    
    @objc func didBecomeActiveNoti() {
        if !self.isJumpRedeem { return }
        
        self.isJumpRedeem = false
        self.checkFreecodeStatus()
    }
    
    private func checkFreecodeStatus() {
        ProgressHUD.animate("Please wait".localStr())
        AppStoreKitManager.shared.restorePurcharge { [weak self] () in
            self?.verfityPurchageRecord()
        } fail: { errorMsg in
            ProgressHUD.failed(errorMsg)
        }
    }
    
    // 校验本地购买凭证
    func verfityPurchageRecord() {
        
        Purchases.shared.getCustomerInfo(fetchPolicy: .default) { customerInfo, error in
            
            if let activePremium = customerInfo?.entitlements.all[PremiumEntitlID], activePremium.isActive {
                AppStoreKitManager.shared.handlePayBigModel(activePremium: activePremium)
                ProgressHUD.succeed("Successful".localStr())
                self.tableView.reloadData()
            }else{
                ProgressHUD.failed(error?.localizedDescription)
                debugPrint("❌ 支付校验凭证 = \(error?.localizedDescription ?? "")")
            }
        }
        
    }
    
    @objc func updateNavigationItem() {
        self.navigationItem.rightBarButtonItem = (kaka_IsMacOS() || UserInfoManager.shared.isVIP() || !DiscountIAPManager.shared.isShowDiscount()) ? nil : self.premiumBarItem
        
        if UserInfoManager.shared.isVIP() && UserInfoManager.shared.payGoodsId == PurchaseStoreID.weekly.rawValue {
            self.navigationItem.rightBarButtonItem = self.premiumBarItem
        }
        self.tableView.reloadData()
    }
    
    // 监听 tintColor 的变化
    @objc func appModeStyleChanged(_ noti: Notification) {
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if kaka_safeAreaInsets().top > 20 || kaka_IsiPad() {
            self.navigationController?.navigationBar.prefersLargeTitles = true
            self.navigationItem.largeTitleDisplayMode = .automatic
        }else{
            self.navigationController?.navigationBar.prefersLargeTitles = false
            self.navigationItem.largeTitleDisplayMode = .never
        }
        
        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        barAppearance.configureWithTransparentBackground() // 底层透明，但内容穿透
        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
                
        self.tableView.reloadData()
    }

    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    var isJumpRedeem: Bool = false
        
    lazy var purchaseManager: AppStoreKitManager = {
        return AppStoreKitManager()
    }()
    
    private var dataArray: [SettingGroupCellModel] {
        get {
            var tempArray = [SettingGroupCellModel]()
            let isChinese = PhoneSetManager.formatLanguage() == .chinese_simplified
            
            let itemArray1: [SettingCellItemType] = (UserInfoManager.shared.isVIP() || !isChinese) ? [.loginAccount] : [.loginAccount, .promoCode, .freePlan]
            let model1 = SettingGroupCellModel(group: .accountGroup, headTitle: "Account".localStr(), itemArray: itemArray1, footTitle: nil)
            
            let itemArray2: [SettingCellItemType] = kaka_IsMacOS() ? [.selectPlayer, .playConfig, .cacheConfig, .appTintColor] : [.selectPlayer, .playConfig, .cacheConfig, .applogo, .appTintColor, .appearance]
            
            let model3 = SettingGroupCellModel(group: .safetyGroup, headTitle: "Settings".localStr().lowercased(), itemArray: itemArray2, footTitle: nil)
                        
            let itemArray4: [SettingCellItemType] = [.steveJobs, .types, .contactus, .abountUS]
            let model4 = SettingGroupCellModel(group: .othersGroup, headTitle: "Others".localStr().lowercased(), itemArray: itemArray4, footTitle: nil)
            
            tempArray.append(model1)
            
            if !UserInfoManager.shared.isVIP() && kaka_IsMacOS() {
                let model2 = SettingGroupCellModel(group: .guideVIPGroup, headTitle: nil, itemArray: [.guideVIP], footTitle: nil)
                tempArray.append(model2)
            }
            
            tempArray.append(model3)
            tempArray.append(model4)
            
            if UserInfoManager.shared.isVIP() && !AppLocalManager.shared.isDeleteRanting {
                let ranting = SettingGroupCellModel(group: .rantingGroup, headTitle: nil, itemArray: [.guideRanting], footTitle: nil)
                tempArray.append(ranting)
            }
            
            return tempArray
        }
    }
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.contentView.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: kaka_IsiPhone() ? 0 : 20.ckValue(), left: 0, bottom: playingHeight, right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ProfileTableViewCell")
        view.register(GuidePremiumViewCell.self, forCellReuseIdentifier: "GuidePremiumViewCell")
        view.register(LoginedViewCell.self, forCellReuseIdentifier: "LoginedViewCell")
        view.register(GuideRatingViewCell.self, forCellReuseIdentifier: "GuideRatingViewCell")
        return view
    }()
    
    
    lazy var premiumBarItem: UIBarButtonItem = {
        let timerView = PremiumTimerView(frame: CGRectMake(0, 0, PremiumTimerView.maxWidth(), 30.ckValue()))
        timerView.onStopCallback = { [weak self] () in
            self?.navigationItem.rightBarButtonItem = nil
        }
        timerView.addTarget(self, action: #selector(vipCenterClick), for: .touchUpInside)
        
        let item = UIBarButtonItem(customView: timerView)
        item.style = .done
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        item.width = PremiumTimerView.maxWidth()
        return item
    }()
    
}

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate, GuideRatingViewCellDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataArray[indexPath.section].itemArray[indexPath.row]
        
        if item == .loginAccount {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoginedViewCell") as! LoginedViewCell
            cell.update()
            cell.onAvatarBlock = { [weak self] (avatarView) in
                self?.showBigAvatarImage(avatarView)
            }
            return cell
        } else if item == .guideVIP {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GuidePremiumViewCell", for: indexPath) as! GuidePremiumViewCell
            
            return cell
        } else if item == .guideRanting {
            let cell = tableView.dequeueReusableCell(withIdentifier: "GuideRatingViewCell", for: indexPath) as! GuideRatingViewCell
            cell.delegate = self
            return cell
        } else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileTableViewCell", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = item.titleStr()
            cellConfig.textProperties.color = UIColor.label
            cellConfig.image = item.cellImage()
            cellConfig.imageProperties.cornerRadius = 6.ckValue()
            cellConfig.imageProperties.maximumSize = CGSize(width: 30.ckValue(), height: 30.ckValue())
            
            if item == .selectPlayer || item == .appTintColor || item == .appearance {
                
                if item == .selectPlayer && MusicConfigManager.shared.playerEngine == .avPlayer {
                    cell.accessoryView = warningView()
                }else{
                    cell.accessoryView = nil
                }
                
                if item == .appTintColor {
                    cell.accessoryView = themeColorView()
                }
                
                if item == .appearance && !kaka_IsMacOS() {
                    cell.accessoryView = appearanceView()
                }
                
            }else{
                cell.accessoryView = nil
            }
            
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.imageToTextPadding = 15
            cell.contentConfiguration = cellConfig
            
            return cell
        }
    }
    
    func themeColorView() -> UIView {
        if kaka_IsMacOS() {
            let colorView = UIImageView(image: Reasource.named("random_color"))
            colorView.size = CGSizeMake(23.ckValue(), 23.ckValue())
            return colorView
        }else{
            let colorWell = UIColorWell(frame: CGRectMake(0, 0, 28.ckValue(), 28.ckValue()))
            colorWell.isUserInteractionEnabled = false
            return colorWell
        }
    }
    
    func warningView() -> UIImageView {
        let view = UIImageView(image: Reasource.systemNamed("exclamationmark.triangle.fill", color: .systemRed))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(20.ckValue(), 20.ckValue())
        return view
    }
    
    func appearanceView() -> UIView {
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.appearanceMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = AppLocalManager.shared.appearanceStyle.formatStr()
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    
    func appearanceMenu() -> UIMenu {
        let appearArray: [AppearanceStyle] = [.auto, .light, .dark]
        var actionArray = [UIAction]()
        for subType in appearArray {
            let action = UIAction(title: subType.formatStr(), image: subType.iconImage(), state: AppLocalManager.shared.appearanceStyle == subType ? .on : .off, handler: { [weak self] _ in
                AppLocalManager.shared.appearanceStyle = subType
                self?.tableView.reloadData()
                NotificationCenter.default.post(name: Notification.Name(kAppearanceChangedKey), object: nil)
            })
            actionArray.append(action)
        }
        
        let menu = UIMenu(title: "Appearance".localStr(), children: actionArray)
        return menu
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = dataArray[indexPath.section].itemArray[indexPath.row]
                
        if item == .abountUS {
            let aboutVC = AboutAppViewController()
            self.navigationController?.pushViewController(aboutVC, animated: true)
        }
        
        if item == .steveJobs {
            guard let vURL = PhoneSetManager.steveJobsURL() else { return }
            let safariVC = SFSafariViewController(url: vURL)
            safariVC.preferredControlTintColor = appMainColor
            self.present(safariVC, animated: true)
        }
        
        if item == .loginAccount {
            let userVC = UserInfoViewController()
            self.navigationController?.pushViewController(userVC, animated: true)
        }
        
        if item == .applogo {
            let logoVC = AppLogoViewController()
            self.present(KakaNavigationController(rootViewController: logoVC), animated: true)
        }
        
        if item == .playConfig {
            let config = PlayConfigViewController()
            self.navigationController?.pushViewController(config, animated: true)
        }
        
        if item == .guideVIP {
            self.vipCenterClick()
        }
        
        if item == .guideiOS {
            let guideVC = LargeImageViewController(.WakeMusic)
            self.present(KakaNavigationController(rootViewController: guideVC), animated: true)
        }
        
        if item == .cacheConfig {
            let cacheVC = PlayCacheViewController()
            self.navigationController?.pushViewController(cacheVC, animated: true)
        }
        
        if item == .freePlan {
            if let vURL = URL(string: kPremiumUrl) {
                let webVC = SFSafariViewController(url: vURL)
                webVC.preferredControlTintColor = appMainColor
                self.present(webVC, animated: true)
            }
        }
        
        if item == .selectPlayer {
            let playerVC = PlayerEngineViewController()
            self.navigationController?.pushViewController(playerVC, animated: true)
        }
        
        if item == .promoCode {
            let iOSUrl = "https://apps.apple.com/redeem"
            
            if let vURL = URL(string: iOSUrl) {
                UIApplication.shared.open(vURL, options: [:]) { finish in
                    self.isJumpRedeem = finish
                }
            }
        }
        
        if item == .donate {
            let donateVC = DonateViewController()
            self.navigationController?.pushViewController(donateVC, animated: true)
        }
        
        if item == .contactus {
            self.handleWithEmail()
        }
        
        if item == .types {
            let typeVC = SupportTypeViewController()
            self.navigationController?.pushViewController(typeVC, animated: true)
        }
        
        if item == .appearance && kaka_IsMacOS() {
            guard let vURL = URL(string: SystemSettingPath.appearance.settingPathStr()) else { return }
            UIApplication.shared.open(vURL)
        }
        
        if item == .appTintColor {
            let themeVC = ThemeColorViewController()
            let navVC = KakaNavigationController(rootViewController: themeVC)
            navVC.modalPresentationStyle = kaka_IsiPad() ? .fullScreen : .automatic
            self.present(navVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataArray[section].headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return dataArray[section].footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let group = dataArray[indexPath.section]
        let item = group.itemArray[indexPath.row]
        
        if item == .loginAccount {
            return kaka_IsiPhone() ? 80.ckValue() : 170.ckValue()
        }else if item == .guideVIP || item == .guideRanting {
            return UITableView.automaticDimension
        } else {
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let group = dataArray[indexPath.section]
        let item = group.itemArray[indexPath.row]
        
        return item == .guideRanting
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let group = dataArray[indexPath.section]
        let item = group.itemArray[indexPath.row]
        if item != .guideRanting { return nil }
        
        let action = UIContextualAction(style: .destructive, title: nil) { [weak self] action, view, finish in
            AppLocalManager.shared.isDeleteRanting = true
            self?.tableView.reloadData()
        }
        action.image = Reasource.systemNamed("trash", color: .white)
        action.backgroundColor = UIColor.systemRed
        
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    
    
    func showBigAvatarImage(_ avatarView: UIImageView) {
        if kaka_IsMacOS() { return }
        let photoItem = KakaPhotoItem(sourceView: avatarView, image: avatarView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: self)
    }
    
    func guideCommentDidScore(cell: GuideRatingViewCell) {
        let vUrl = Application.wakeMusic.appstoreWriteURL()
        UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
    }
    
    func guideCommentDidShare(cell: GuideRatingViewCell, shareButton: UIButton) {
        let storeURL = Application.wakeMusic.appstoreURL()

        let shareVC = UIActivityViewController(activityItems: [storeURL], applicationActivities: nil)
        if !kaka_IsiPhone() {
            shareVC.popoverPresentationController?.sourceView = shareButton
        }
        self.present(shareVC, animated: true, completion: nil)
    }
    
    
    

    
}

// MARK:  邮箱联系
extension ProfileViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        if !MFMailComposeViewController.canSendMail() {
            let redbookURL = URL(string: "xhsdiscover://user/\(SocialMediaType.redbook.socialMediaURL().mediaID ?? "")")!
            if UIApplication.shared.canOpenURL(redbookURL) {
                UIApplication.shared.open(redbookURL)
            }else{
                UIPasteboard.general.string = companyEmail
                self.showOneAlert(title: "Copied".localStr(), message: companyEmail, confirm: "Done".localStr(), complete: nil)
            }
            return
        }
        
        let emailVC = MFMailComposeViewController()
        emailVC.mailComposeDelegate = self
        emailVC.setToRecipients([companyEmail])
        emailVC.setSubject("\(kaka_osType().iconStr()) \("Wake Music".localStr()) Feedback")
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
                
        emailVC.setMessageBody(messageBody, isHTML: false)
        self.present(emailVC, animated: true, completion: nil)
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
        let model = device.model
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
