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
                failBlock(error?.localizedDescription ?? "")
                return
            }
            
            Purchases.shared.getCustomerInfo(fetchPolicy: .default) { customerInfo, error in
                guard let customerInfo = customerInfo else {
                    failBlock(error?.localizedDescription ?? "")
                    return
                }
                
                guard let activePremium = customerInfo.entitlements.all[PremiumEntitlID], activePremium.isActive else {
                    failBlock("Unknown Error")
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
            
            guard customerInfo.entitlements.active.count > 0 else {
                fail?("No Purchase Records".localStr())
                return
            }
            
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
