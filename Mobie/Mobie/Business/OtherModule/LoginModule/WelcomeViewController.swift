import UIKit
import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaObjcKit
import SafariServices
import RevenueCat
import ProgressHUD

class WelcomeViewController: SuperViewController {
    let dataArray = WelcomeInfoModel.welcomeDataArray()
    var currentIndex = 0
    var selectedProduct: StoreProduct?
    var trialDays: Int?
    var isLoadingOffer = false
    var offerRequestID: UUID?
    var isFinishing = false
    var isProcessingPurchase = false {
        didSet { if isViewLoaded { updatePage() } }
    }
    let purchaseManager = AppStoreKitManager()
    private let gradient = CAGradientLayer()
    private let footer = UIStackView()
    private var lastCollectionSize = CGSize.zero
    private var reachability: ReachabilitySwift?
    private var hasLoggedFirstOpen = false

    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.backgroundColor = .clear
        view.layer.insertSublayer(gradient, at: 0)
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        contentView.addSubview(collectionView)
        contentView.addSubview(footer)
        footer.axis = .vertical
        footer.spacing = 14
        [pageControl, nextButton, privacyTextView].forEach(footer.addArrangedSubview)
        [collectionView, footer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            footer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            footer.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -48).welcomePriority(999),
            footer.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            footer.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 8),
            collectionView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8)
        ])
        updatePage()
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        overrideUserInterfaceStyle = .dark
        modalPresentationStyle = .fullScreen
        // Onboarding is informational: do not reset settings, change player style or auto-play.
        if !hasLoggedFirstOpen {
            hasLoggedFirstOpen = true
            AnalyticsManager.shared.logEvent("first_open")
        }
        reachability = try? ReachabilitySwift()
        if let reachability {
            NotificationCenter.default.addObserver(self, selector: #selector(networkChanged(_:)),
                                                   name: .reachabilitySwiftChanged, object: reachability)
            try? reachability.startNotifier()
        }
        fetchOffer()
    }

    deinit {
        reachability?.stopNotifier()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = view.bounds
        CATransaction.commit()
        let size = collectionView.bounds.size
        guard size.width > 0, size.height > 0, size != lastCollectionSize else { return }
        lastCollectionSize = size
        flowLayout.itemSize = size
        flowLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0),
                                    at: .centeredHorizontally, animated: false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    @objc private func networkChanged(_ note: Notification) {
        guard let connection = note.object as? ReachabilitySwift, connection.connection != .unavailable else { return }
        if selectedProduct == nil { fetchOffer() }
        DispatchQueue.global().async { AppleSearchAdsManager.shared.handleASAAttribution() }
    }

    @objc func nextButtonClick() {
        guard !isProcessingPurchase, !isFinishing else { return }
        if dataArray[currentIndex].isPurchase && !UserInfoManager.shared.isVIP() {
            guard !isLoadingOffer else { return }
            if selectedProduct == nil { fetchOffer() } else { continuePurchase() }
        } else if currentIndex == dataArray.count - 1 {
            finishAllPage()
        } else {
            showPage(currentIndex + 1)
        }
    }

    private func showPage(_ index: Int) {
        guard dataArray.indices.contains(index), !isProcessingPurchase else { return }
        currentIndex = index
        updatePage()
        collectionView.scrollToItem(at: IndexPath(item: index, section: 0),
                                    at: .centeredHorizontally, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func pageControlChanged() { showPage(pageControl.currentPage) }

    func updatePage() {
        guard dataArray.indices.contains(currentIndex) else { return }
        let model = dataArray[currentIndex]
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.colors = [model.glowColor.cgColor, model.backColor.cgColor, UIColor.rgb(12, 13, 22).cgColor]
        gradient.locations = [0, 0.56, 1]
        CATransaction.commit()
        view.backgroundColor = model.backColor
        pageControl.currentPage = currentIndex
        pageControl.isEnabled = !isProcessingPurchase
        collectionView.isScrollEnabled = !isProcessingPurchase

        let buttonTitle: String
        if model.isPurchase && !UserInfoManager.shared.isVIP() {
            if let trialDays {
                buttonTitle = String(format: "Free Trial for %d Days".localStr(), trialDays)
            } else if !isLoadingOffer && selectedProduct == nil {
                buttonTitle = "Retry".localStr()
            } else {
                buttonTitle = "Continue".localStr()
            }
        } else {
            buttonTitle = (currentIndex == dataArray.count - 1 ? "Get Started" : "Continue").localStr()
        }
        nextButton.setTitle(buttonTitle, for: .normal)
        nextButton.backgroundColor = .white
        nextButton.isEnabled = !isProcessingPurchase && !(model.isPurchase && isLoadingOffer)
        nextButton.alpha = nextButton.isEnabled ? 1 : 0.55
        collectionView.visibleCells.compactMap { $0 as? WelcomePaywallViewCell }.forEach(configurePaywall)
    }

    private func configurePaywall(_ cell: WelcomePaywallViewCell) {
        cell.delegate = self
        cell.configure(product: selectedProduct, trialDays: trialDays, isLoading: isLoadingOffer)
        cell.isProcessingPurchase = isProcessingPurchase
    }

    lazy var flowLayout: WelcomePagingLayout = {
        let layout = WelcomePagingLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.dataSource = self
        view.delegate = self
        view.isPagingEnabled = true
        view.bounces = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.register(WelcomeBaseCollectCell.self, forCellWithReuseIdentifier: "feature")
        view.register(WelcomePaywallViewCell.self, forCellWithReuseIdentifier: "premium")
        return view
    }()
    private lazy var pageControl: UIPageControl = {
        let control = UIPageControl()
        control.numberOfPages = dataArray.count
        control.currentPageIndicatorTintColor = .white
        control.pageIndicatorTintColor = .white.withAlphaComponent(0.3)
        control.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        return control
    }()
    private lazy var nextButton: UIButton = {
        // A custom button avoids the system title cross-fade briefly blanking the CTA
        // when the last page or an asynchronously checked trial offer changes its text.
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.setTitleColor(.rgb(25, 23, 35), for: .normal)
        button.layer.cornerRadius = 18
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        button.accessibilityIdentifier = "onboarding.continue"
        button.addTarget(self, action: #selector(nextButtonClick), for: .touchUpInside)
        return button
    }()
    private lazy var privacyTextView: UITextView = {
        let privacy = "Privacy Policy".localStr()
        let terms = "Terms of Service".localStr()
        let text = String(format: "Continuing means you have agreed to %@ and %@".localStr(), privacy, terms)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3
        let value = NSMutableAttributedString(string: text, attributes: [
            .font: UIFontMetrics(forTextStyle: .caption2).scaledFont(for: .systemFont(ofSize: 12)),
            .foregroundColor: UIColor.white.withAlphaComponent(0.72),
            .paragraphStyle: paragraph
        ])
        for (title, url) in [(privacy, kPrivacyUrl), (terms, kUseItemUrl)] {
            let range = (text as NSString).range(of: title)
            if range.location != NSNotFound, let url = URL(string: url) { value.addAttribute(.link, value: url, range: range) }
        }
        let view = UITextView()
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.attributedText = value
        view.linkTextAttributes = [.foregroundColor: UIColor.white, .underlineStyle: NSUnderlineStyle.single.rawValue]
        view.isEditable = false
        view.isScrollEnabled = false
        view.adjustsFontForContentSizeCategory = true
        view.delegate = self
        return view
    }()
}

final class WelcomePagingLayout: UICollectionViewFlowLayout {
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { true }
}

extension WelcomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { dataArray.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if dataArray[indexPath.item].isPurchase {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "premium", for: indexPath) as! WelcomePaywallViewCell
            configurePaywall(cell)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "feature", for: indexPath) as! WelcomeBaseCollectCell
        cell.model = dataArray[indexPath.item]
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateVisiblePage() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { updateVisiblePage() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateVisiblePage() }
    }
    private func updateVisiblePage() {
        // Geometric hit testing respects both LTR and RTL; offset / width does not.
        let center = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        guard let index = collectionView.indexPathForItem(at: center)?.item else { return }
        currentIndex = index
        updatePage()
        UIAccessibility.post(notification: .screenChanged, argument: collectionView.cellForItem(at: IndexPath(item: index, section: 0)))
    }
}

extension WelcomeViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        guard URL.absoluteString == kPrivacyUrl || URL.absoluteString == kUseItemUrl else { return false }
        if kaka_IsMacOS() { UIApplication.shared.open(URL) }
        else { present(SFSafariViewController(url: URL), animated: true) }
        return false
    }
}
