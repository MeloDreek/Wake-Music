//
//  WelcomeViewController.swift
//  AppLock
//
//  Created by Kaka Inc. on 2024/1/2.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import SafariServices
import KakaObjcKit
import StoreKit
import RevenueCat
import ProgressHUD

class WelcomeViewController: SuperViewController {
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        
        contentView.addSubview(collectionView)
        contentView.addSubview(bottomView)
        
        bottomView.addSubview(privacyLabel)
        bottomView.addSubview(pageControl)
        bottomView.addSubview(nextButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        collectionView.frame = contentView.bounds
                
        privacyLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(kaka_safeAreaInsets().bottom / 2 + 15.ckValue())
            make.leading.equalToSuperview().offset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        nextButton.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.85)
            make.height.equalTo(nextButton.layer.cornerRadius * 2)
            make.bottom.equalTo(privacyLabel.snp.top).offset(-15.ckValue())
        }
        
        pageControl.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(nextButton.snp.top).offset(-15.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        // 适配屏幕旋转
        self.flowLayout.itemSize = CGSizeMake(contentView.width, contentView.height)
        collectionView.frame = CGRectMake(0, 0, contentView.width, contentView.height)
        self.collectionView.reloadData()
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.view.backgroundColor = UIColor.white
        contentView.backgroundColor = UIColor.clear
        
        self.scrollViewDidScroll(collectionView)
        
        // 清空一些缓存
        
        MusicConfigManager.reset()
        AppLocalManager.reset()
        MusicConfigManager.shared.lastPlayTime = 0
        
        KakaMusicPlayer.shared.playingMusic = MusicItemModel.demoMusicModel()
        self.setupPlayerStyle(false)
        
        if !self.dataArray[0].isTapeStyle {
            self.startPlayAnimation()
            self.bottomView.overrideUserInterfaceStyle = .dark
        }
        
        // 监听网络变化
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
                
        self.fetchNetworkApi()

        try? self.reachability.startNotifier()
        
        self.modalPresentationStyle = .fullScreen
        
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { [weak self] context in
            guard let wSelf = self else { return }
            let isLandScape = size.width > size.height && !kaka_IsMacOS()
            wSelf.bottomView.frame = CGRectMake(0, (wSelf.isStarPlay || isLandScape) ? wSelf.contentView.height - wSelf.bottomView.height : wSelf.contentView.height, wSelf.contentView.width, wSelf.bottomView.height)
        } completion: {  context in
            
        }
    }
    
    // 网络状态变化了
    @objc func reachabilityChanged(note: Notification) {
                
        guard let reachability = note.object as? ReachabilitySwift else { return }
        
        debugPrint("当前网络授权状况 = \(reachability.connection.description)")
        
        self.netConnect = reachability.connection
        
        if reachability.connection == .unavailable {
            return
        }
        
        self.fetchNetworkApi()
        
        // ASA归因
        DispatchQueue.global().asyncAfter(wallDeadline: .now() + 0.1) {
            AppleSearchAdsManager.shared.handleASAAttribution()
        }
    }
    
    func fetchNetworkApi() {
        // 触发网络权限
        AnalyticsManager.shared.logEvent("first_open")
                
#if !Target_Mobie_Pro
//        // 尝试恢复购买
//        AppStoreKitManager().restorePurcharge {
//            Purchases.shared.getCustomerInfo(fetchPolicy: .default) { customerInfo, error in
//                if let activePremium = customerInfo?.entitlements.all[PremiumEntitlID], activePremium.isActive {
//                    AppStoreKitManager.shared.handlePayBigModel(activePremium: activePremium, completion: {
//                        self.refreshDataSource()
//                    })
//                }else{
//                    UserInfoManager.shared.payGoodsId = nil
//                    UserInfoManager.shared.payStatus = .normal
//                    
//                    self.refreshDataSource()
//                    debugPrint("❌ 支付校验凭证 = \(error?.localizedDescription ?? "")")
//                }
//            }
//        } fail: { error in
//            UserInfoManager.shared.payGoodsId = nil
//            UserInfoManager.shared.payStatus = .normal
//            
//            self.refreshDataSource()
//            debugPrint("恢复购买失败 = \(error)")
//        }
        
        // 提取内购价格
        self.purchaseManager.refresRemoteProductsPrice { [weak self] products in
            DispatchQueue.main.async {
                guard let self else { return }
                self.productArray = PurchaseStoreID.paywallProducts.compactMap { storeID in
                    products.first { $0.productIdentifier == storeID.rawValue }
                }
                // Recommend a full year of Premium, without artificial urgency or trial promises.
                self.selectModel = self.productArray.first {
                    $0.productIdentifier == PurchaseStoreID.yearly.rawValue
                } ?? self.productArray.first
                self.updateContinueButton()
                self.collectionView.reloadData()
            }
        }
#else
//        MusicConfigManager.shared.playerEngine = .wakePlayer
#endif
        
    }
    
    func refreshDataSource() {
        self.dataArray = WelcomeInfoModel.welcomeDataArray()
        self.pageControl.numberOfPages = self.dataArray.count
        self.collectionView.reloadData()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppLocalManager.shared.appearanceStyle.statusBarStyle()
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
    }
    
    // 下一页
    @objc func nextButtonClick() {
        guard !isProcessingPurchase else { return }

        let nextIndex = self.currentIndex + 1
        if nextIndex >= dataArray.count {
            if (self.dataArray.last?.isPurchase ?? false) && !UserInfoManager.shared.isVIP() {
                guard self.selectModel != nil else { return }
                self.continePurchase()
            }else{
                self.finishAllPage()
            }
            return
        }
        self.currentIndex = nextIndex
        
        self.view.backgroundColor = dataArray[currentIndex].backColor
        pageControl.currentPage = currentIndex
        
        self.collectionView.scrollToItem(at: IndexPath(row: currentIndex, section: 0), at: .centeredHorizontally, animated: true)
    }
    
    @objc func startPlayAnimation() {
        self.isStarPlay = true
        UIView.animate(withDuration: 0.35) { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.bottomView.top = wSelf.contentView.bounds.height - wSelf.bottomView.height
        } completion: { finish in
            self.collectionView.isScrollEnabled = true
        }

    }
    
    // MARK:  GET && SET
    
    // 已经在播放了
    var isStarPlay: Bool = false
    
    // 是否展示过好评页面
    var isShowedReview: Bool = false
    
    
    
    /// 当前页码
    var currentIndex: Int = 0 {
        didSet {
            
            guard dataArray.indices.contains(currentIndex) else {
                // 越界时，安全处理
                return
            }
            
            let subModel = dataArray[currentIndex]
            pageControl.isHidden = subModel.isPurchase
            // 购买页同样保留可访问的隐私政策与服务条款。
            privacyLabel.isHidden = false
            
            let isFirst = currentIndex == 0
            nextButton.backgroundColor = isFirst ? .white : .black
            nextButton.setTitleColor(isFirst ? .black : .white, for: .normal)
            
            privacyLabel.overrideUserInterfaceStyle = isFirst ? .dark : .light
            pageControl.overrideUserInterfaceStyle = isFirst ? .dark : .light
                        
            
            updateContinueButton()
        }
    }
    
    var dataArray = WelcomeInfoModel.welcomeDataArray()
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    // 选中的内购产品
    var selectModel: StoreProduct?

    // Both purchasing and restoring are single-flight operations during onboarding.
    var isProcessingPurchase = false {
        didSet {
            updateContinueButton()
            collectionView.visibleCells.compactMap { $0 as? WelcomePaywallViewCell }.forEach {
                $0.isProcessingPurchase = isProcessingPurchase
            }
        }
    }
    
    // 内购产品
    lazy var productArray: [StoreProduct] = {
        return PurchaseStoreID.paywallProducts.compactMap { storeID in
            AppStoreKitManager.shared.saleArray.first { $0.productIdentifier == storeID.rawValue }
        }
    }()

    private func updateContinueButton() {
        let isPurchasePage = dataArray.indices.contains(currentIndex) && dataArray[currentIndex].isPurchase
        nextButton.setTitle("Continue".localStr(), for: .normal)
        nextButton.isEnabled = !isProcessingPurchase && (!isPurchasePage || selectModel != nil || UserInfoManager.shared.isVIP())
        nextButton.alpha = nextButton.isEnabled ? 1 : 0.45
    }
    
    // MARK:  懒加载
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: contentView.bounds, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.isPagingEnabled = true
        view.bounces = false
        view.isScrollEnabled = !self.dataArray[0].isTapeStyle
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? UISemanticContentAttribute.forceRightToLeft : UISemanticContentAttribute.forceLeftToRight
        view.register(WelcomeTapeCollectCell.self, forCellWithReuseIdentifier: "WelcomeTapeCollectCell")
        view.register(WelcomeBaseCollectCell.self, forCellWithReuseIdentifier: "WelcomeBaseCollectCell")
#if !Target_Mobie_Pro
        view.register(WelcomePaywallViewCell.self, forCellWithReuseIdentifier: "WelcomePaywallViewCell")
#endif
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSizeMake(contentView.width, contentView.height)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    
    lazy var purchaseManager: AppStoreKitManager = {
        return AppStoreKitManager()
    }()
    
    lazy var bottomView: UIView = {
        let bottomHeight = kaka_safeAreaInsets().bottom + 180.ckValue()
        let isLandScape = self.contentView.width > self.contentView.height && !kaka_IsMacOS()
        let frame = CGRectMake(0, (self.isStarPlay || isLandScape) ? self.contentView.height - bottomHeight : self.contentView.height, self.contentView.width, bottomHeight)

        let view = UIView(frame: frame)
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var privacyLabel: UILabel = {
        let text1 = "Privacy Policy".localStr()
        let text2 = "Terms of Service".localStr()
        
        let sumText = String(format: "Continuing means you have agreed to %@ and %@".localStr(), text1, text2)
        let attributedString = NSMutableAttributedString(string: sumText, attributes: [
            .font: UIFontLight(13.ckValue()),
            .foregroundColor: UIColor.gray
        ])
        
        let range1 = (sumText as NSString).range(of: text1)
        let range2 = (sumText as NSString).range(of: text2)
        
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range1)
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range2)
        
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        label.addGestureRecognizer(tapGesture)
        
        return label
    }()

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let text = privacyLabel.attributedText?.string else { return }
                
        let range1 = (text as NSString).range(of: "Privacy Policy".localStr())
        let range2 = (text as NSString).range(of: "Terms of Service".localStr())
        
        let location = gesture.location(in: privacyLabel)
        
        let textStorage = NSTextStorage(attributedString: privacyLabel.attributedText!)
        let textContainer = NSTextContainer(size: privacyLabel.bounds.size)
        let layoutManager = NSLayoutManager()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textContainer.lineFragmentPadding = 0
        
        let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        if NSLocationInRange(characterIndex, range1) {
            openURL(kPrivacyUrl)
        } else if NSLocationInRange(characterIndex, range2) {
            openURL(kUseItemUrl)
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if kaka_IsMacOS() {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            let webVC = SFSafariViewController(url: url)
            webVC.preferredControlTintColor = appMainColor
            self.present(webVC, animated: true)
        }
    }
    
    lazy var nextButton: UIButton = {
        let view = UIButton()
        view.backgroundColor = UIColor.black
        view.setTitleColor(.white, for: .normal)
        view.setTitle("Continue".localStr(), for: .normal)
        view.layer.cornerRadius = 25.ckValue()
        view.titleLabel?.font = UIFontBold(16.ckValue())
        view.addTarget(self, action: #selector(nextButtonClick), for: .touchUpInside)
        return view
    }()
    
    lazy var pageControl: UIPageControl = {
        let view = UIPageControl()
        view.currentPageIndicatorTintColor = UIColor.label
        view.pageIndicatorTintColor = UIColor.secondaryLabel
        view.currentPage = currentIndex
        view.numberOfPages = dataArray.count
        return view
    }()
    
    @objc func closeButtonClick() {
        self.dismiss(animated: true)
    }
    
}

extension WelcomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let subModel = dataArray[indexPath.row]

        if subModel.isTapeStyle {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WelcomeTapeCollectCell", for: indexPath) as! WelcomeTapeCollectCell
            cell.onPlayBlock = { [weak self] () in
                self?.startPlayAnimation()
            }
            return cell
        }else if subModel.isPurchase {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WelcomePaywallViewCell", for: indexPath) as! WelcomePaywallViewCell
            cell.delegate = self
            cell.product = self.selectModel
            cell.isProcessingPurchase = isProcessingPurchase
            return cell
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WelcomeBaseCollectCell", for: indexPath) as! WelcomeBaseCollectCell
            cell.model = subModel
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        let page = Int(round(offset.x / flowLayout.itemSize.width)) % dataArray.count

        self.currentIndex = page
        
        self.view.backgroundColor = dataArray[page].backColor
        pageControl.currentPage = page
    }
    
}


extension WelcomeViewController: WelcomePaywallCellDelegate {
    
    // 进入限制版
    func welcomePurchaseDidLimited(cell: WelcomePaywallViewCell) {
        guard !isProcessingPurchase else { return }
        self.finishAllPage()
    }
    
    // 恢复购买
    func welcomePurchaseDidRestore(cell: WelcomePaywallViewCell) {
        guard !isProcessingPurchase else { return }
        isProcessingPurchase = true
        ProgressHUD.animate("Processing...".localStr())
        self.purchaseManager.restorePurcharge { [weak self] () in
            self?.verfityPurchageRecord()
        } fail: { [weak self] errorMsg in
            self?.isProcessingPurchase = false
            ProgressHUD.dismiss()
            ProgressHUD.failed(errorMsg)
        }
    }
    
    // 查看全部方案；取消后仍停留在引导页，只有完成购买才结束引导。
    func welcomePurchaseDidAllBenefit(cell: WelcomePaywallViewCell) {
        guard !isProcessingPurchase else { return }
        AppStoreKitManager.presentPurcharseVC(self, animated: true, success: { [weak self] in
            self?.finishAllPage()
        })
    }
    
    // 校验支付凭证
    func verfityPurchageRecord() {
        
        Purchases.shared.getCustomerInfo(fetchPolicy: .default) { [weak self] customerInfo, error in
            self?.isProcessingPurchase = false
            ProgressHUD.dismiss()
            
            if let activePremium = customerInfo?.entitlements.all[PremiumEntitlID], activePremium.isActive {
                self?.purchaseManager.handlePayBigModel(activePremium: activePremium)
                ProgressHUD.succeed()
                self?.finishAllPage()
            }else{
                ProgressHUD.failed(KakaError.emptyData.errorDescription)
            }
        }
    }
    
}
