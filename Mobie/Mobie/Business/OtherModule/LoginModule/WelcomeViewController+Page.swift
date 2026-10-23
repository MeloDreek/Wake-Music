import Foundation
import UIKit
import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AppGroupKit
import RevenueCat
import ProgressHUD

extension WelcomeViewController {
    func fetchOffer() {
#if !Target_Mobie_Pro
        guard dataArray.contains(where: \.isPurchase), !isLoadingOffer, !isProcessingPurchase, !isFinishing else { return }
        let requestID = UUID()
        offerRequestID = requestID
        isLoadingOffer = true
        trialDays = nil
        updatePage()

        // A failed storefront/eligibility request must never strand a first-time user.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.offerRequestID == requestID, self.isLoadingOffer else { return }
            self.offerRequestID = nil
            self.isLoadingOffer = false
            self.trialDays = nil // Unknown eligibility is not a promise of a free trial.
            self.updatePage()
        }
        purchaseManager.refresRemoteProductsPrice { [weak self] products in
            DispatchQueue.main.async {
                guard let self, self.offerRequestID == requestID, !self.isFinishing else { return }
                // Never silently substitute another subscription when monthly is unavailable.
                self.selectedProduct = products.first { $0.productIdentifier == PurchaseStoreID.monthly.rawValue }
                guard let product = self.selectedProduct,
                      product.introductoryDiscount?.paymentMode == .freeTrial else {
                    self.isLoadingOffer = false
                    self.updatePage()
                    return
                }
                Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [product.productIdentifier]) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self, self.offerRequestID == requestID, !self.isFinishing else { return }
                        self.trialDays = result[product.productIdentifier]?.status == .eligible ? product.onboardingTrialDays : nil
                        self.isLoadingOffer = false
                        self.updatePage()
                    }
                }
            }
        }
#endif
    }

    func continuePurchase() {
        guard !isProcessingPurchase, !isLoadingOffer, !isFinishing,
              let product = selectedProduct, product.productIdentifier == PurchaseStoreID.monthly.rawValue else { return }
        isProcessingPurchase = true
        ProgressHUD.animate("Processing...".localStr())
        purchaseManager.startPurcharge(product: product) { [weak self] _ in
            DispatchQueue.main.async {
                // startPurcharge already verifies and persists the active entitlement.
                ProgressHUD.dismiss()
                self?.isProcessingPurchase = false
                self?.finishAllPage()
            }
        } failBlock: { [weak self] error in
            DispatchQueue.main.async {
                ProgressHUD.dismiss()
                guard let self else { return }
                self.isProcessingPurchase = false
                if error != KakaError.youhaveCanceled.errorDescription { self.showOneAlert(message: error) }
            }
        }
    }

    @objc func finishAllPage() {
        guard !isProcessingPurchase, !isFinishing,
              let scene = view.window?.windowScene?.delegate as? SceneDelegate,
              let window = scene.window, let coordinator = scene.modeCoordinator else { return }
        isFinishing = true
        offerRequestID = nil
        AppLocalManager.shared.isFirstLaunch = false
        view.isUserInteractionEnabled = false
        if !kaka_IsMacOS(), !UIAccessibility.isReduceMotionEnabled {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = window.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .fromLeft : .fromRight
            transition.duration = 0.35
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: "welcome.finish")
        }
        window.rootViewController = coordinator.restoredRootController()
        window.makeKeyAndVisible()
    }
}

extension WelcomeViewController: WelcomePaywallCellDelegate {
    func welcomePurchaseDidLimited(cell: WelcomePaywallViewCell) {
        finishAllPage()
    }

    func welcomePurchaseDidRestore(cell: WelcomePaywallViewCell) {
        guard !isProcessingPurchase, !isFinishing else { return }
        isProcessingPurchase = true
        ProgressHUD.animate("Processing...".localStr())
        purchaseManager.restorePurcharge { [weak self] in
            DispatchQueue.main.async {
                ProgressHUD.dismiss()
                self?.isProcessingPurchase = false
                self?.finishAllPage()
            }
        } fail: { [weak self] error in
            DispatchQueue.main.async {
                ProgressHUD.dismiss()
                self?.isProcessingPurchase = false
                self?.showOneAlert(message: error)
            }
        }
    }

    func welcomePurchaseDidAllBenefit(cell: WelcomePaywallViewCell) {
        guard !isProcessingPurchase, !isFinishing else { return }
        AppStoreKitManager.presentPurcharseVC(self, animated: true, success: { [weak self] in
            self?.finishAllPage()
        })
    }
}

extension StoreProduct {
    var onboardingTrialDays: Int? {
        guard let offer = introductoryDiscount, offer.paymentMode == .freeTrial else { return nil }
        let unit: Calendar.Component
        switch offer.subscriptionPeriod.unit {
        case .day: unit = .day
        case .week: unit = .weekOfYear
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        return WelcomeTrialDuration.days(value: offer.subscriptionPeriod.value,
                                         periods: offer.numberOfPeriods, unit: unit)
    }
}
