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
        
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
        }
        
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
    
    @objc func postTimerNoti() {
        
        self.timer.startTimer(seconds: 0.01, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            guard let lastDiscountTime = DiscountIAPManager.shared.lastDiscountTime else {
                DiscountIAPManager.shared.lastDiscountTime = Date().timeIntervalSince1970
                return
            }
            
            let nowDate = Date()
            
            var leftTime = nowDate.timeIntervalSince1970 - lastDiscountTime
            leftTime = wSelf.maxDiscountTime - leftTime
            
            if leftTime < 0 {
                DiscountIAPManager.shared.lastDiscountTime = Date().timeIntervalSince1970
            }
            
            self?.updateDiscountTime(leftTime)
        }
    }
    
    @objc func updateDiscountTime(_ leftTime: Double) {
        
        guard let payCell = self.purchaseCell ?? (self.collectionView.visibleCells.filter({ $0 is WelcomePurchaseCell }).first as? WelcomePurchaseCell) else { return }
        
        if self.purchaseCell == nil {
            self.purchaseCell = payCell
        }
        
        if leftTime <= 0 {
            self.finishAllPage()
            return
        }
        
        let totalMilliseconds = Int(leftTime * 100)
        let hours = totalMilliseconds / (60 * 60 * 100)
        let minutes = (totalMilliseconds % (60 * 60 * 100)) / (60 * 100)
        let seconds = (totalMilliseconds % (60 * 100)) / 100
        let milliseconds = totalMilliseconds % 100
        
        let timerString = String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, milliseconds)
        payCell.timerLabel.text = timerString
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
        self.purchaseManager.refresRemoteProductsPrice { products in
            let discountModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }.first
            let lifetimeModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }.first
            let weeklyModel = products.filter { $0.productIdentifier == PurchaseStoreID.weekly.rawValue }.first
            
            let lifetimeArray = [discountModel, lifetimeModel].compactMap { $0 }.sorted { product1, product2 in
                return product1.price < product2.price
            }
            
            // 终身限免期
            let isLifetimeOffer = (discountModel?.price == 0) && (lifetimeModel?.price == 0)
            // 周会员免费试用 x 天
            let isTrialWeekly = (weeklyModel?.freeTrialDays ?? 0) > 0
            
            // 限免期和中国用户永远推荐买断制
            if /*PhoneSetManager.formatLanguage() == .chinese_simplified ||*/ isLifetimeOffer {
                self.productArray = lifetimeArray
                self.selectModel = lifetimeArray.first
            }else{
                self.productArray = isTrialWeekly ? [weeklyModel!] : lifetimeArray
                self.selectModel = isTrialWeekly ? weeklyModel : lifetimeArray.first
            }
            
            self.collectionView.reloadData()
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
        
        self.currentIndex += 1
        
        if self.currentIndex >= dataArray.count {
            if (self.dataArray.last?.isPurchase ?? false) && !UserInfoManager.shared.isVIP() {
                self.continePurchase()
            }else{
                self.finishAllPage()
            }
            return
        }
        
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
            privacyLabel.isHidden = subModel.isPurchase
            
            let isFirst = currentIndex == 0
            nextButton.backgroundColor = isFirst ? .white : .black
            nextButton.setTitleColor(isFirst ? .black : .white, for: .normal)
            
            let freeTrailDays = self.selectModel?.freeTrialDays ?? 0
            let freeTrialStr = String(format: "Free Trial for %@ Days".localStr(), "\(freeTrailDays)")
            nextButton.setTitle((subModel.isPurchase && freeTrailDays > 0) ? freeTrialStr : "Continue".localStr(), for: .normal)
            
            privacyLabel.overrideUserInterfaceStyle = isFirst ? .dark : .light
            pageControl.overrideUserInterfaceStyle = isFirst ? .dark : .light
            
            self.postTimerNoti()
        }
    }
    
    var dataArray = WelcomeInfoModel.welcomeDataArray()
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    // 选中的内购产品
    var selectModel: StoreProduct?
    
    // 支付Cell
    var purchaseCell: WelcomePurchaseCell?
    
    // 内购产品
    lazy var productArray: [StoreProduct] = {
        return AppStoreKitManager.shared.saleArray
    }()
    
    let maxDiscountTime: Double = DiscountIAPManager.shared.maxDiscountTime
    
    // MARK:  懒加载
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: contentView.bounds, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.isPagingEnabled = true
        view.bounces = false
        view.isScrollEnabled = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? UISemanticContentAttribute.forceRightToLeft : UISemanticContentAttribute.forceLeftToRight
        view.register(WelcomeTapeCollectCell.self, forCellWithReuseIdentifier: "WelcomeTapeCollectCell")
        view.register(WelcomeBaseCollectCell.self, forCellWithReuseIdentifier: "WelcomeBaseCollectCell")
#if !Target_Mobie_Pro
        view.register(WelcomePurchaseCell.self, forCellWithReuseIdentifier: "WelcomePurchaseCell")
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
    
    lazy var timer: KakaTimer = {
        return KakaTimer()
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
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WelcomePurchaseCell", for: indexPath) as! WelcomePurchaseCell
            cell.delegate = self
            cell.products = self.productArray
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


extension WelcomeViewController: WelcomePurchaseCellDelegate {
    
    // 进入限制版
    func welcomePurchaseDidLimited(cell: WelcomePurchaseCell) {
        self.finishAllPage()
    }
    
    // 恢复购买
    func welcomePurchaseDidRestore(cell: WelcomePurchaseCell) {
        ProgressHUD.animate("Please wait".localStr())
        self.purchaseManager.restorePurcharge { [weak self] () in
            self?.verfityPurchageRecord()
        } fail: { errorMsg in
            ProgressHUD.failed(errorMsg)
        }
    }
    
    // 校验支付凭证
    func verfityPurchageRecord() {
        
        Purchases.shared.getCustomerInfo(fetchPolicy: .default) { [weak self] customerInfo, error in
            
            if let activePremium = customerInfo?.entitlements.all[PremiumEntitlID], activePremium.isActive {
                self?.purchaseManager.handlePayBigModel(activePremium: activePremium)
                ProgressHUD.succeed()
                self?.finishAllPage()
            }else{
                ProgressHUD.failed("No data available".localStr())
            }
        }
    }
    
}
