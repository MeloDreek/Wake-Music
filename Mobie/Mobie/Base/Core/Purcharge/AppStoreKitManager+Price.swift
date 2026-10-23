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
    public func refresRemoteProductsPrice(productIds: [PurchaseStoreID] = PurchaseStoreID.paywallProducts, completion: (([StoreProduct])->Void)? = nil) {
        
#if !Target_Mobie_Pro
        
        let productIds = productIds.map { $0.rawValue }
        Purchases.shared.getProducts(productIds) { products in
            // 只展示 App Store 返回的真实商品，不能用虚构价格补齐缺失商品。
            let goodsArray = PurchaseStoreID.paywallProducts.compactMap { id in
                products.first { $0.productIdentifier == id.rawValue }
            }
            
            AppStoreKitManager.shared.saleArray = goodsArray
            
            completion?(goodsArray)
        }
#endif
        
    }
    
}
