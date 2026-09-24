//
//  PurchaseViewController.swift
//  Wakemusic
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
            make.leading.trailing.equalTo(buyoutButton)
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
        self.perform(#selector(setupLeftNavgationItem), with: nil, afterDelay: 0)
        
        self.darkAppearanceClick()
                        
        self.handlePriceGoods(AppStoreKitManager.shared.saleArray)
        self.reloadProducts()

    }

    private func reloadProducts() {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        tableView.reloadData()
        AppStoreKitManager.shared.refresRemoteProductsPrice { [weak self] models in
            DispatchQueue.main.async {
                self?.isLoadingProducts = false
                self?.handlePriceGoods(models)
            }
        }
    }

    func handlePriceGoods(_ models: [StoreProduct]) {
        let selectedID = selectModel?.productIdentifier
        priceArray = PurchaseStoreID.paywallProducts.compactMap { id in
            models.first { $0.productIdentifier == id.rawValue }
        }
        if !canToggleFamilySharing { isFamilySharingEnabled = false }
        selectModel = visibleProducts.first { $0.productIdentifier == selectedID }
            ?? visibleProducts.first { $0.productIdentifier == PurchaseStoreID.yearly.rawValue }
            ?? visibleProducts.first
        refreshTrialEligibility()
        tableView.reloadData()
    }

    private func refreshTrialEligibility() {
        let generation = UUID()
        eligibilityRequestID = generation
        trialEligibleProductIDs.removeAll()
        updatePurchaseButton()
        let ids = priceArray.filter { $0.introductoryDiscount?.paymentMode == .freeTrial }.map(\.productIdentifier)
        guard !ids.isEmpty else { return }
        Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: ids) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.eligibilityRequestID == generation else { return }
                self.trialEligibleProductIDs = Set(ids.filter { result[$0]?.status == .eligible })
                self.updatePurchaseButton()
                self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
            }
        }
    }
    
    @objc func closeButtonClick() {
        self.onCancelBlock?()
        self.dismissAnimation(true, completion: nil)
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
            updatePurchaseButton()
        }
    }

    private func updatePurchaseButton() {
        guard let product = selectModel else {
            buyoutButton.isEnabled = false
            buyoutButton.setTitle("Continue".localStr(), for: .normal)
            tipsLabel.text = nil
            return
        }
        let ownedID = UserInfoManager.shared.payedStoreModel()
        let ownsSelection = UserInfoManager.shared.isVIP() && ownedID?.rawValue == product.productIdentifier
        // 已有终身会员无需再订阅；个人终身仍可主动选择家庭共享方案。
        let ownsLifetime = UserInfoManager.shared.isVIP() && ownedID?.isSubscription == false
        let isFamilyUpgrade = ownedID == .lifetime198 && product.productIdentifier == PurchaseStoreID.lifetime298.rawValue
        let alreadyCovered = ownsSelection || (ownsLifetime && !isFamilyUpgrade)
        buyoutButton.isEnabled = !alreadyCovered && !isPurchasing
        let buttonTitle: String
        if alreadyCovered {
            buttonTitle = "You have purchased".localStr()
        } else if trialEligibleProductIDs.contains(product.productIdentifier), let days = product.onboardingTrialDays {
            buttonTitle = String(format: "Free Trial for %d Days".localStr(), days)
        } else {
            buttonTitle = "Continue".localStr()
        }
        buyoutButton.setTitle(buttonTitle, for: .normal)
        tipsLabel.text = product.productType == .autoRenewableSubscription
            ? "Auto-renewable. Cancel anytime.".localStr()
            : "One time purchase, valid forever".localStr()
    }

    var isPurchasing = false {
        didSet {
            updatePurchaseButton()
            familySharingFooter.toggleButton.isEnabled = !isPurchasing
        }
    }
    private var isLoadingProducts = false
    private var eligibilityRequestID = UUID()
    private var trialEligibleProductIDs = Set<String>()
    private var isFamilySharingEnabled = false

    private var canToggleFamilySharing: Bool {
        priceArray.contains { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue } &&
        priceArray.contains { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }
    }

    private var visibleProducts: [StoreProduct] {
        let lifetimeID: PurchaseStoreID = isFamilySharingEnabled ? .lifetime298 : .lifetime198
        return [PurchaseStoreID.monthly, .yearly, lifetimeID].compactMap { id in
            priceArray.first { $0.productIdentifier == id.rawValue }
        }
    }

    private lazy var familySharingFooter: PurchaseFamilySharingFooter = {
        let footer = PurchaseFamilySharingFooter(reuseIdentifier: nil)
        footer.toggleButton.addTarget(self, action: #selector(toggleFamilySharing), for: .touchUpInside)
        return footer
    }()

    @objc private func toggleFamilySharing() {
        guard !isPurchasing, canToggleFamilySharing else { return }
        let selectedLifetime = selectModel?.productIdentifier == PurchaseStoreID.lifetime198.rawValue ||
            selectModel?.productIdentifier == PurchaseStoreID.lifetime298.rawValue
        isFamilySharingEnabled.toggle()
        if selectedLifetime {
            let id = isFamilySharingEnabled ? PurchaseStoreID.lifetime298 : .lifetime198
            selectModel = visibleProducts.first { $0.productIdentifier == id.rawValue }
        }
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
    }
        
    // 原始的屏幕亮度
    var firstBrightness = 0.5
    
    // 订阅成功的回调
    var onPaySuccess: (()->Void)?
    
    // 取消的回调
    var onCancelBlock: (()->Void)?
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 50.ckValue()
        view.estimatedSectionFooterHeight = 64
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
        view.numberOfLines = 2
        return view
    }()
    
    lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator
        return view
    }()
    
    lazy var buyoutButton: UIButton = {
        let view = UIButton()
        view.isEnabled = false
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor.deAccent, for: .normal)
        view.setTitle("Continue".localStr(), for: .normal)
        view.setTitleColor(.secondaryLabel, for: .disabled)
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
        return []
    }()
    
    lazy var footView: PurchaseFootView = {
        let view = PurchaseFootView(frame: CGRectMake(0, 0, self.view.width, 50.ckValue()))
        view.delegate = self
        return view
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
            return max(1, visibleProducts.count)
        }else if section == 2 {
            return benefitArray.count
        }else{
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PurchaseHeadCell", for: indexPath) as! PurchaseHeadCell
            return cell
        }else if indexPath.section == 1 {
            if visibleProducts.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "PriceTableViewCell", for: indexPath)
                var config = UIListContentConfiguration.cell()
                config.text = isLoadingProducts ? "Processing...".localStr() : "Purchase.ProductsUnavailable".localStr()
                config.secondaryText = isLoadingProducts ? nil : "Retry".localStr()
                config.textProperties.numberOfLines = 0
                cell.contentConfiguration = config
                return cell
            }
            // 订阅产品
            let model = visibleProducts[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "PurchasePriceCell", for: indexPath) as! PurchasePriceCell
            cell.update(model: model,
                        isSelect: model.productIdentifier == self.selectModel?.productIdentifier,
                        subtitle: model.compactPaywallSubtitle(isEligibleForTrial: trialEligibleProductIDs.contains(model.productIdentifier)))
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
            guard !isPurchasing else { return }
            guard !visibleProducts.isEmpty else {
                reloadProducts()
                return
            }
            self.selectModel = self.visibleProducts[indexPath.row]
            tableView.reloadSections(IndexSet(integer: 1), with: .none)
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
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == 1, canToggleFamilySharing else { return nil }
        familySharingFooter.configure(isEnabled: isFamilySharingEnabled, isPurchasing: isPurchasing)
        return familySharingFooter
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 1 && canToggleFamilySharing ? UITableView.automaticDimension : 12
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
                self.handlePriceGoods(self.priceArray)
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

private final class PurchaseFamilySharingFooter: UITableViewHeaderFooterView {
    let toggleButton = UIButton(type: .system)
    private let explanation = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        explanation.font = .preferredFont(forTextStyle: .footnote)
        explanation.adjustsFontForContentSizeCategory = true
        explanation.textColor = .secondaryLabel
        explanation.numberOfLines = 0
        explanation.text = "Purchase.FamilySharingFooter".localStr()
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = appMainColor
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        toggleButton.configuration = configuration
        toggleButton.titleLabel?.numberOfLines = 0
        toggleButton.titleLabel?.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [explanation, toggleButton])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            toggleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(isEnabled: Bool, isPurchasing: Bool) {
        explanation.isHidden = !isEnabled
        toggleButton.configuration?.title = (isEnabled ? "Purchase.DisableFamilySharing" : "Purchase.EnableFamilySharing").localStr()
        toggleButton.isEnabled = !isPurchasing
    }
}

#endif
