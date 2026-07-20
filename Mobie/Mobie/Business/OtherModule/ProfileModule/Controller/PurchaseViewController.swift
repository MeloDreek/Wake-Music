//
//  PurchaseViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/28.
//

#if !Target_Mobie_Pro

import KakaFoundation
import AppGroupKit
import RevenueCat
import SafariServices
import ProgressHUD

class PurchaseViewController: SuperViewController {
    
    deinit {
        self.timer.stopTimer()
    }
    
    init(_ isFirst: Bool = false) {
        self.isFirst = isFirst
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
                
        contentView.addSubview(buyBackView)
        buyBackView.addSubview(buyoutButton)
        buyBackView.addSubview(tipsLabel)
        buyBackView.addSubview(lineView)
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let isX = kaka_safeAreaInsets().bottom > 10
        let height = isX ? kaka_safeAreaInsets().bottom + 50.ckValue() : (kaka_IsMacOS() ? 80.ckValue() : 60.ckValue())
        buyBackView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(height + 20.ckValue())
        }
        
        buyoutButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.height.equalTo(44.ckValue())
            if kaka_IsMacOS() {
                make.centerY.equalToSuperview().offset(-10.ckValue())
            }else{
                make.top.equalTo(isX ? 10.ckValue() : 8.ckValue())
            }
        }
        
        tipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(buyoutButton.snp.bottom).offset(8.ckValue())
        }
        
        lineView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(0.5.ckValue())
        }
        
        tableView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(buyBackView.snp.top)
        }
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.perform(#selector(setupLeftNavgationItem), with: nil, afterDelay: isFirst ? 2.8 : 0)
        
        self.darkAppearanceClick()
                        
        self.handlePriceGoods(self.priceArray)
        AppStoreKitManager.shared.refresRemoteProductsPrice() { [weak self] models in
            self?.handlePriceGoods(models)
            
            guard let yearModel = models.filter({ $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }).first, yearModel.price == 0 else { return }
            
            self?.perform(#selector(self?.showPremiumOffer), with: nil, afterDelay: 1)
        }
        
        // 监听网络变化
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
        
        try? self.reachability.startNotifier()
    }
    
    // 网络状态变化了
    @objc func reachabilityChanged(note: Notification) {
        guard let reachability = note.object as? ReachabilitySwift else { return }
        
        debugPrint("当前网络授权状况 = \(reachability.connection.description)")
        
        self.netConnect = reachability.connection
    }
    
    @objc func closeButtonClick() {
        self.onCancelBlock?()
        self.dismissAnimation(!self.isFirst, completion: nil)
    }
    
    func dismissAnimation(_ animation: Bool = true, completion: (()->Void)? = nil) {
        (self.navigationController ?? self)?.dismiss(animated: animation, completion: completion)
    }
    
    @objc func setupLeftNavgationItem() {
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(closeButtonClick))

    }
    
    @objc func lightAppearanceClick() {
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.overrideUserInterfaceStyle = .light
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.navigationItem.rightBarButtonItem = self.darkBarItem
    }
    
    @objc func darkAppearanceClick() {
        
        self.overrideUserInterfaceStyle = .dark
        self.navigationController?.overrideUserInterfaceStyle = .dark
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.navigationItem.rightBarButtonItem = self.lightBarItem
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.overrideUserInterfaceStyle == .dark ? .lightContent : .darkContent
    }
    
    lazy var lightBarItem: UIBarButtonItem = {
        let view = UIBarButtonItem(image: UIImage(systemName: "sun.max"), style: .plain, target: self, action: #selector(lightAppearanceClick))
        return view
    }()
    
    lazy var darkBarItem: UIBarButtonItem = {
        let view = UIBarButtonItem(image: UIImage(systemName: "moon.stars"), style: .plain, target: self, action: #selector(darkAppearanceClick))
        return view
    }()
    
    // MARK:  GET && SET 
    var selectModel: StoreProduct? {
        didSet {
            guard let vModel = self.selectModel else { return }
            
            let priceTitle = String(format: "Payment %@".localStr(), vModel.localizedPriceString)
            let lifetimeTitle = "Get Lifetime Access".localStr()
            
            var autoSubTitle: String
            if let freeTrialDays = vModel.freeTrialDays, freeTrialDays > 0 {
                autoSubTitle = String(format: "Free Trial for %d Days".localStr(), freeTrialDays)
            }else{
                autoSubTitle = "Get Started".localStr()
            }
            
            if vModel.productIdentifier == PurchaseStoreID.weekly.rawValue {
                tipsLabel.text = "Auto-renewable. Cancel anytime.".localStr()
                buyoutButton.setTitle(autoSubTitle, for: .normal)
                
            }else if vModel.productIdentifier == PurchaseStoreID.yearly.rawValue {
                tipsLabel.text = "Auto-renewable. Cancel anytime.".localStr()
                buyoutButton.setTitle(autoSubTitle, for: .normal)
                
            }else if vModel.productIdentifier == PurchaseStoreID.lifetime198.rawValue {
                let isOffer = vModel.price == 0

                tipsLabel.text = "One time purchase, valid forever".localStr()
                buyoutButton.setTitle(isOffer ? priceTitle : lifetimeTitle, for: .normal)
                
            } else if vModel.productIdentifier == PurchaseStoreID.lifetime298.rawValue {
                let isOffer = vModel.price == 0

                tipsLabel.text = "One time purchase, valid forever".localStr()
                buyoutButton.setTitle(isOffer ? priceTitle : lifetimeTitle, for: .normal)
            }
        }
    }
        
    // 原始的屏幕亮度
    var firstBrightness = 0.5
    
    // 订阅成功的回调
    var onPaySuccess: (()->Void)?
    
    // 取消的回调
    var onCancelBlock: (()->Void)?
    
    // 默认倒计时3小时
    let maxDiscountTime: Double = DiscountIAPManager.shared.maxDiscountTime
    
    // 记录倒计时Cell
    var discountCell: PurchasePriceCell?
    
    // 是否为首次进来
    var isFirst: Bool = false
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    // MARK:  懒加载 
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 50.ckValue()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: additionalSafeAreaInsets.bottom + 30.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PurchaseHeadCell.self, forCellReuseIdentifier: "PurchaseHeadCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PremiumBenefitsCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PriceTableViewCell")
        view.register(PurchasePriceCell.self, forCellReuseIdentifier: "PurchasePriceCell")
        view.tableFooterView = self.footView
        return view
    }()
    
    lazy var buyBackView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        return view
    }()
    
    lazy var tipsLabel: UILabel = {
        let view = UILabel()
        view.font = UIFontLight(10.ckValue())
        view.textColor = UIColor.secondaryLabel
        view.textAlignment = .center
        return view
    }()
    
    lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        return view
    }()
    
    lazy var buyoutButton: UIButton = {
        let normalTitle = UserInfoManager.shared.isVIP() ? "You have purchased".localStr() : "Time-limited purchase".localStr()

        let view = UIButton()
        view.isSelected = UserInfoManager.shared.isVIP()
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor.deAccent, for: .normal)
        view.setTitle(normalTitle, for: .normal)
        view.setTitle("You have purchased".localStr(), for: .selected)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.addTarget(self, action: #selector(payButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var benefitArray: [VIPBenefitsModel] = {
        return VIPBenefitsModel.allCases
    }()
    
    lazy var priceArray: [StoreProduct] = {
        return AppStoreKitManager.shared.saleArray
    }()
    
    lazy var footView: PurchaseFootView = {
        let view = PurchaseFootView(frame: CGRectMake(0, 0, self.view.width, 50.ckValue()))
        view.delegate = self
        return view
    }()
    
    lazy var timer: KakaTimer = {
        let timer = KakaTimer()
        return timer
    }()
    
    func aboutAttbuteStr() -> NSAttributedString {
        let message1 = "1. Once purchased, the cost will be deducted from your Apple Account.".localStr()
        let message2 = "2. Subscription can be cancelled 24 hours before the end of the subscription cycle.".localStr()
        let message3 = "3. If you have already purchased on another device, please resume the purchase on the new device.".localStr()
        let sumMessage = message1 + "\r" + message2 + "\r" + message3
        
        let attributedString = NSMutableAttributedString(string: sumMessage)
        
        let param = NSMutableParagraphStyle()
        param.lineSpacing = 5.ckValue()
        attributedString.addAttributes([.paragraphStyle: param], range: NSRange(location: 0, length: sumMessage.count))

        return attributedString
        
    }
    
}

extension PurchaseViewController: UITableViewDataSource, UITableViewDelegate, PurchaseFootViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }else if section == 1 {
            return priceArray.count
        }else if section == 2 {
            return benefitArray.count
        }else{
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseHeadCell", for: indexPath) as! PurchaseHeadCell
            cell.isDiscount = self.selectModel?.productIdentifier == PurchaseStoreID.lifetime198.rawValue
            return cell
        }else if indexPath.section == 1 {
            // 订阅产品
            let model = priceArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "PurchasePriceCell", for: indexPath) as! PurchasePriceCell
            cell.update(model: model, isSelect: model.productIdentifier == self.selectModel?.productIdentifier)
            return cell
        } else if indexPath.section == 2 {
            // VIP权益
            let maxSize = 32.ckValue()
            let benefits = benefitArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "PremiumBenefitsCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = benefits.titleStr()
            cellConfig.image = benefits.iconImage(maxSize)
            cellConfig.secondaryText = benefits.descStr()
            cellConfig.imageProperties.maximumSize = CGSizeMake(maxSize, maxSize)
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.imageToTextPadding = 15
            
            cell.accessoryType = .disclosureIndicator
            cell.contentConfiguration = cellConfig
            return cell
        }else{
            // 订阅说明
            let cell = tableView.dequeueReusableCell(withIdentifier: "PriceTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.secondaryAttributedText = self.aboutAttbuteStr()
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.imageToTextPadding = 15
            
            cell.contentConfiguration = cellConfig
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        
        if indexPath.section == 1 {
            self.selectModel = self.priceArray[indexPath.row]
            
            guard let cellArray = self.tableView.visibleCells.filter({ $0 is PurchasePriceCell }) as? [PurchasePriceCell] else {
                return
            }
            
            for index in 0..<cellArray.count {
                let subCell = cellArray[index]
                let model = self.priceArray[index]
                subCell.update(model: model, isSelect: model.productIdentifier == self.selectModel?.productIdentifier)
            }
            
            if let headCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PurchaseHeadCell {
                headCell.isDiscount = self.selectModel?.productIdentifier == PurchaseStoreID.lifetime198.rawValue
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 || section == 1 {
            return nil
        } else if section == 2 {
            return "What's included?".localStr()
        }else{
            return "About Premium".localStr()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            return 70.ckValue()
        } else {
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return nil
        }else{
            return nil
        }
    }
    
    // 恢复购买
    func purchaseFootViewClickRestore(view: PurchaseFootView) {
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
            }else{
                ProgressHUD.failed(error?.localizedDescription)
                debugPrint("❌ 支付校验凭证 = \(error?.localizedDescription ?? "")")
            }
        }
        
    }
    
    // 隐私政策
    func purchaseFootViewClickPrivacy(view: PurchaseFootView) {
        guard let vUrl = URL(string: kPrivacyUrl) else { return }
        
        if kaka_IsMacOS() {
            UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
        }else{
            let webVC = SFSafariViewController(url: vUrl)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }
    
    // 服务条款
    func purchaseFootViewClickService(view: PurchaseFootView) {
        guard let vUrl = URL(string: kUseItemUrl) else { return }
        
        if kaka_IsMacOS() {
            UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
        }else{
            let webVC = SFSafariViewController(url: vUrl)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }
    
    
    
}

#endif
