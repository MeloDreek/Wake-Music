import UIKit

func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
@main enum OnboardingProbe {
    @MainActor static func main() {
        let calendar = Calendar(identifier: .gregorian)
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let february = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        precondition(WelcomeTrialDuration.days(value: 3, periods: 1, unit: .day) == 3)
        precondition(WelcomeTrialDuration.days(value: 1, periods: 2, unit: .weekOfYear) == 14)
        precondition(WelcomeTrialDuration.days(value: 1, periods: 1, unit: .month, startingAt: january) == 31)
        precondition(WelcomeTrialDuration.days(value: 1, periods: 1, unit: .month, startingAt: february) == 28)
        precondition(WelcomeTrialDuration.days(value: Int.max, periods: 2, unit: .day) == nil)
        precondition(WelcomeTrialDuration.days(value: 0, periods: 1, unit: .day) == nil)
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.08)) }
        func layout(_ vc: WelcomeViewController, width: CGFloat, height: CGFloat) {
            vc.loadViewIfNeeded()
            vc.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            for _ in 0..<4 { vc.view.setNeedsLayout(); vc.view.layoutIfNeeded(); vc.viewDidLayoutSubviews() }
        }
        let product = StoreProduct()
        AppStoreKitManager.products = [product]
        for locale in ["zh-Hans", "en", "de", "ar"] {
            fixtureLocale = locale
            for size in [CGSize(width: 320, height: 568), CGSize(width: 440, height: 860), CGSize(width: 820, height: 650)] {
                let vc = WelcomeViewController()
                vc.view.semanticContentAttribute = locale == "ar" ? .forceRightToLeft : .forceLeftToRight
                layout(vc, width: size.width, height: size.height)
                drain()
                let count = vc.dataArray.count
#if Target_Mobie_Pro
                precondition(count == 4)
#else
                precondition(count == 5)
#endif
                for index in 0..<count {
                    vc.currentIndex = index
                    vc.updatePage()
                    vc.collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
                    vc.collectionView.layoutIfNeeded()
                    vc.scrollViewDidEndScrollingAnimation(vc.collectionView)
                    vc.view.layoutIfNeeded()
                    precondition(vc.currentIndex == index, "RTL page tracking")
                    let cell = vc.collectionView.cellForItem(at: IndexPath(item: index, section: 0))!
                    cell.layoutIfNeeded()
                    let button = descendants(vc.view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "onboarding.continue" }!
                    let rect = button.convert(button.bounds, to: vc.view)
                    precondition(rect.height >= 54 && rect.minX >= 23 && rect.maxX <= size.width - 23.0 + 1)
                    precondition(rect.maxY < size.height)
                    if index == count - 1 && !vc.dataArray[index].isPurchase {
                        precondition(button.title(for: .normal) == "Get Started".localStr())
                    }
                    if vc.dataArray[index].isPurchase {
                        let labels = descendants(cell).compactMap { $0 as? UILabel }.compactMap(\.text)
                        precondition(labels.contains("Upgrade to Premium".localStr()))
                        precondition(labels.contains("Your ultimate music player. Play anytime, anywhere, and enjoy total listening freedom!".localStr()))
                        precondition(!labels.contains("Connect Your Music".localStr()))
                        precondition(button.backgroundColor?.isEqual(UIColor.white) == true)
                    }
                    precondition(vc.collectionView.frame.maxY <= rect.minY, "Content must not sit behind the CTA")
                    let links = descendants(vc.view).compactMap { $0 as? UITextView }.first!
                    var countLinks = 0
                    links.attributedText.enumerateAttribute(.link, in: NSRange(location: 0, length: links.attributedText.length)) { value, _, _ in if value != nil { countLinks += 1 } }
                    precondition(countLinks == 2)
                    if locale == "zh-Hans" && size.width == 440 {
                        let format = UIGraphicsImageRendererFormat(); format.scale = 2
                        let image = UIGraphicsImageRenderer(size: size, format: format).image { vc.view.layer.render(in: $0.cgContext) }
                        try! image.pngData()!.write(to: URL(fileURLWithPath: fixtureOutput + "/page-\(index).png"))
                    }
                }
                print("PASS layout \(locale) \(size) pages=\(count)")
            }
        }
        UserInfoManager.shared.premium = true
        precondition(WelcomeInfoModel.welcomeDataArray().count == 4)
        UserInfoManager.shared.premium = false
#if !Target_Mobie_Pro
        fixtureLocale = "zh-Hans"
        for (discount, status, expected) in [(nil, Eligibility.Status.eligible, nil), (Discount(), .eligible, 3), (Discount(), .ineligible, nil), (Discount(), .unknown, nil)] as [(Discount?, Eligibility.Status, Int?)] {
            product.introductoryDiscount = discount
            Purchases.shared.status = status
            let vc = WelcomeViewController()
            layout(vc, width: 440, height: 860)
            drain()
            precondition(vc.trialDays == expected)
            vc.currentIndex = 4; vc.updatePage()
            let button = descendants(vc.view).compactMap { $0 as? UIButton }.first { $0.accessibilityIdentifier == "onboarding.continue" }!
            let expectedTitle = expected.map { String(format: "Free Trial for %d Days".localStr(), $0) } ?? "Continue".localStr()
            precondition(button.title(for: .normal) == expectedTitle)
        }
        AppStoreKitManager.products = []
        let unavailable = WelcomeViewController()
        layout(unavailable, width: 440, height: 860); drain()
        unavailable.currentIndex = 4; unavailable.updatePage()
        let requests = AppStoreKitManager.requests
        unavailable.nextButtonClick(); drain()
        precondition(AppStoreKitManager.requests == requests + 1)
        precondition(AppStoreKitManager.purchases == 0, "Unavailable must retry, never purchase")
        AppStoreKitManager.deferResponse = true
        let pending = WelcomeViewController()
        layout(pending, width: 440, height: 860)
        pending.currentIndex = 4; pending.nextButtonClick()
        precondition(AppStoreKitManager.purchases == 0, "No purchase while checking offer")
        pending.offerRequestID = UUID() // A superseded request must not update the offer.
        AppStoreKitManager.pending?([product]); drain()
        precondition(pending.selectedProduct == nil)
        print("PASS monthly offer: paid / eligible / ineligible / unknown / unavailable / pending / stale response")
#else
        precondition(AppStoreKitManager.requests == 0, "Pro must never fetch an onboarding offer")
#endif
        print("PASS onboarding trial duration and entitlement routing")
    }
}
