//
//  AppStoreKitManager+Price.swift
//  Kaka
//
//  Created by Kaka Inc.on 2022/4/27.
//  Copyright © 2022 Mars Tree. All rights reserved.
//

import RevenueCat
import StoreKit
import AppGroupKit

extension AppStoreKitManager {
    
    /// 获取远程本地价格信息
    public func refresRemoteProductsPrice(productIds: [PurchaseStoreID] = [.yearly, .lifetime198, .lifetime298], completion: (([StoreProduct])->Void)? = nil) {
        
#if !Target_Mobie_Pro
        
        if AppStoreKitManager.shared.saleArray.isEmpty {
            let defaultArr = StoreProduct.defaultProducts()
            AppStoreKitManager.shared.saleArray = defaultArr
            completion?(defaultArr)
        }
        
        let productIds = productIds.map { $0.rawValue }
        Purchases.shared.getProducts(productIds) { products in
            
            let goodsArray = products.sorted { model1, model2 in
                return model1.priceDecimalNumber.doubleValue < model2.priceDecimalNumber.doubleValue
            }
            
            AppStoreKitManager.shared.saleArray = goodsArray
            
            completion?(goodsArray)
        }
#endif
        
    }
    
//    /// 获取捐赠选项信息
//    public func refresDonationPrice(productIds: [PurchaseStoreID] = [.option1, .option2, .option3], completion: (([StoreProduct])->Void)? = nil) {
//        
//#if !Target_Mobie_Pro
//        let productIds = productIds.map { $0.rawValue }
//        Purchases.shared.getProducts(productIds) { products in
//            
//            let goodsArray = products.sorted { model1, model2 in
//                return model1.priceDecimalNumber.doubleValue < model2.priceDecimalNumber.doubleValue
//            }
//            
//            AppStoreKitManager.shared.donationArray = goodsArray
//            
//            completion?(goodsArray)
//        }
//        
//#endif
//    }
}
