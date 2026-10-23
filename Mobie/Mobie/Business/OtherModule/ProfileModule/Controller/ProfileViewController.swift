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
        
        // 购买状态更新后刷新高级版入口
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
        ProgressHUD.animate("Processing...".localStr())
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
        self.navigationItem.rightBarButtonItem = UserInfoManager.shared.isVIP() ? nil : self.premiumBarItem
        
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
                
        self.updateNavigationItem()
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
            
            let itemArray1: [SettingCellItemType] = UserInfoManager.shared.isVIP() ? [.loginAccount] : [.loginAccount]
            let model1 = SettingGroupCellModel(group: .accountGroup, headTitle: "Account".localStr(), itemArray: itemArray1, footTitle: nil)
            
            let itemArray2: [SettingCellItemType] = kaka_IsMacOS() ? [.selectPlayer, .playConfig, .appTintColor] : [.selectPlayer, .playConfig, .applogo, .appTintColor, .appearance]
            
            let model3 = SettingGroupCellModel(group: .safetyGroup, headTitle: "Settings".localStr().lowercased(), itemArray: itemArray2, footTitle: nil)
                        
            let model4 = SettingGroupCellModel(group: .othersGroup, headTitle: "Others".localStr().lowercased(), itemArray: [.types, .FAQ, .abountUS], footTitle: nil)
            
            tempArray.append(model1)
            
            if UserInfoManager.shared.isVIP() && UserInfoManager.shared.isFreeTrail {
                let model2 = SettingGroupCellModel(group: .guideVIPGroup, headTitle: nil, itemArray: [.guideVIP], footTitle: nil)
                tempArray.append(model2)
            }else{
                if !UserInfoManager.shared.isVIP() {
                    let model2 = SettingGroupCellModel(group: .guideVIPGroup, headTitle: nil, itemArray: [.guideVIP], footTitle: nil)
                    tempArray.append(model2)
                }
            }
            
            tempArray.append(model3)
            tempArray.append(model4)
            
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
        return view
    }()
    
    
    lazy var premiumBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "crown"), style: .plain, target: self, action: #selector(vipCenterClick))
        item.accessibilityLabel = "Unlock Premium".localStr()
        return item
    }()
    
}

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate {
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
        
        
        
        if item == .selectPlayer {
            let playerVC = PlayerEngineViewController()
            self.navigationController?.pushViewController(playerVC, animated: true)
        }
        
        if item == .types {
            let typeVC = SupportTypeViewController()
            self.navigationController?.pushViewController(typeVC, animated: true)
        }
        
        if item == .FAQ {
            let faqVC = FAQsViewController()
            self.navigationController?.pushViewController(faqVC, animated: true)
        }
        
        if item == .appearance && kaka_IsMacOS() {
            guard let vURL = URL(string: SystemSettingPath.appearance.settingPathStr()) else { return }
            UIApplication.shared.open(vURL)
        }
        
        if item == .appTintColor {
            let themeVC = ThemeColorViewController()
            let navVC = KakaNavigationController(rootViewController: themeVC)
            navVC.modalPresentationStyle = kaka_IsMacOS() ? .automatic : .fullScreen
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
        } else {
            return UITableView.automaticDimension
        }
    }
    
    func showBigAvatarImage(_ avatarView: UIImageView) {
        if kaka_IsMacOS() { return }
        let photoItem = KakaPhotoItem(sourceView: avatarView, image: avatarView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: self)
    }
    
}
