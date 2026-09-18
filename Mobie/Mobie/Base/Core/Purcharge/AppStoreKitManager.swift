//
//  AppStoreKitManager.swift
//  Kaka
//
//  Created by Kaka Inc. on 2021/9/30.
//

import RevenueCat
import StoreKit
import KakaFoundation
import SmartCodable
import AppGroupKit

// 自定义的Key
public let PremiumEntitlID = "premium"

extension StoreProduct {
    var paywallTitle: String {
        PurchaseStoreID(rawValue: productIdentifier)?.formatStr() ?? localizedTitle
    }

    var paywallDetail: String {
        guard let storeID = PurchaseStoreID(rawValue: productIdentifier) else { return localizedDescription }
        switch storeID {
        case .weekly: return "Auto-renewable. Cancel anytime.".localStr()
        case .monthly: return "Purchase.Monthly.Description".localStr()
        case .yearly: return "Purchase.Annual.Description".localStr()
        case .lifetime198: return "Purchase.Lifetime.Description".localStr()
        case .lifetime298: return "Purchase.FamilyLifetime.Description".localStr()
        }
    }

    /// 显示实际结算周期和总价，不以月均价替代年费，也不假定试用资格。
    var paywallBillingSummary: String {
        guard let storeID = PurchaseStoreID(rawValue: productIdentifier) else { return localizedPriceString }
        let key: String
        switch storeID {
        case .weekly: return localizedPriceString
        case .monthly: key = "Purchase.Billing.Monthly"
        case .yearly: key = "Purchase.Billing.Annual"
        case .lifetime198, .lifetime298: key = "Purchase.Billing.Once"
        }
        return String(format: key.localStr(), localizedPriceString)
    }
}

// MARK: - Compact paywall copy
extension StoreProduct {
    /// Eligibility must come from RevenueCat, not merely the existence of an offer.
    func compactPaywallSubtitle(isEligibleForTrial: Bool) -> String? {
        guard let id = PurchaseStoreID(rawValue: productIdentifier), id == .monthly || id == .yearly else { return nil }
        if isEligibleForTrial, let duration = localizedFreeTrialDuration {
            return String(format: "Purchase.FreeTrialDuration".localStr(), duration)
        }
        guard id == .yearly, let monthlyPrice = localizedPricePerMonth else { return nil }
        return String(format: "%@/mo".localStr(), monthlyPrice)
    }

    private var localizedFreeTrialDuration: String? {
        guard let offer = introductoryDiscount, offer.paymentMode == .freeTrial else { return nil }
        let (count, overflow) = offer.subscriptionPeriod.value.multipliedReportingOverflow(by: offer.numberOfPeriods)
        guard !overflow, count > 0 else { return nil }
        var components = DateComponents()
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.zeroFormattingBehavior = .dropAll
        // Format the actual offer unit: one calendar month is not always 30 days.
        switch offer.subscriptionPeriod.unit {
        case .day:
            components.day = count
            formatter.allowedUnits = [.day]
        case .week:
            components.weekOfMonth = count
            formatter.allowedUnits = [.weekOfMonth]
        case .month:
            components.month = count
            formatter.allowedUnits = [.month]
        case .year:
            components.year = count
            formatter.allowedUnits = [.year]
        @unknown default:
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        formatter.calendar = calendar
        return formatter.string(from: components)
    }
}

/// 内购管理者
public class AppStoreKitManager {
    
    public init() {}
    
    public static let shared = AppStoreKitManager()
    
    // 支付异常的重试数
    var payRetryCount: Int = 0
    
    /// 校验重试次数
    public var verRetryCount: Int = 0
    
    // 不需要缓存的
    public var saleArray: [StoreProduct] = StoreProduct.defaultProducts()
    public var donationArray: [StoreProduct] = StoreProduct.defaultProducts()
    
    
    lazy var sharedUD: UserDefaults = {
        return UserDefaults(suiteName: Application.wakeMusic.sharedGroupName()) ?? UserDefaults.standard
    }()
  
    /// 当前购买的ID
    public func currentStoreID() -> StoreProduct? {
        if let payID = UserInfoManager.shared.payedStoreModel() {
            let storeID = self.saleArray.filter { $0.productIdentifier == payID.rawValue }.first
            return storeID
        }else{
            return nil
        }
    }
    
    // MARK:  内购步骤
  
    
    /// 1、发起支付
    /// - Parameters:
    ///   - identifier: 内购ID
    ///   - applicationUsername: 本服务器可能需要的信息
    ///   - SuccessBlock: 支付成功
    ///   - FailBlock: 支付失败
    public func startPurcharge(product: StoreProduct, successBlock: @escaping(EntitlementInfo)-> Void, failBlock: @escaping (String)-> Void) {
        
        self.verRetryCount = 0
        
        Purchases.shared.purchase(product: product) { (transaction, info, error, cancelled) in
            if cancelled {
                failBlock(KakaError.youhaveCanceled.errorDescription)
                return
            }
            
            guard let transaction = transaction else {
                failBlock(error?.localizedDescription ?? "Unknown Error❗️".localStr())
                return
            }
            
            Purchases.shared.getCustomerInfo(fetchPolicy: .default) { customerInfo, error in
                guard let customerInfo = customerInfo else {
                    failBlock(error?.localizedDescription ?? "Unknown Error❗️".localStr())
                    return
                }
                
                guard let activePremium = customerInfo.entitlements.all[PremiumEntitlID], activePremium.isActive else {
                    failBlock("Unknown Error❗️".localStr())
                    return
                }
                
                if UserInfoManager.shared.isPostAAAttribution {
                    if let product = self.saleArray.filter({ transaction.productIdentifier == $0.productIdentifier }).first {
                        let price = product.priceDecimalNumber.doubleValue
                        AppleSearchAdsManager.shared.postbackAdAttribution(eventType: .purchase, eventValue: price, admodel: nil)
                    }
                }
                
                debugPrint("Unlocked Pro Cats 🎉 = \(activePremium.description)")
                self.handlePayBigModel(activePremium: activePremium)
                successBlock(activePremium)
                                    
            }
        }
        
    }
  
     /// 2、恢复购买
    public func restorePurcharge(success:(()->Void)? = nil, fail:((String)->Void)? = nil) {
#if !Target_Mobie_Pro
        Purchases.shared.restorePurchases { (customerInfo, error) in
            guard let customerInfo = customerInfo else {
                fail?(error?.localizedDescription ?? "")
                return
            }
            
            guard let premium = customerInfo.entitlements.all[PremiumEntitlID], premium.isActive else {
                fail?("No Purchase Records".localStr())
                return
            }

            self.handlePayBigModel(activePremium: premium)
            success?()
        }
#endif
    }
}

/*
 21000 App Store无法读取你提供的JSON数据
 21002 收据数据不符合格式
 21003 收据无法被验证
 ​​​21004 你提供的共享密钥和账户的共享密钥不一致​​​ 21005 收据服务器当前不可用
 21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
 21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
 21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
 -----------------------------------
 ©著作权归作者所有：来自51CTO博客作者haocold的原创作品，请联系作者获取转载授权，否则将追究法律责任
 iOS 内购订阅型项目
 https://blog.51cto.com/u_15844020/5792151
 */
