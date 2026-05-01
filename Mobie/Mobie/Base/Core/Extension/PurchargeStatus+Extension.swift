//
//  PurchargeStatus+Extension.swift
// Wake Music
//
//  Created by Kaka Inc. on 2023/12/12.
//

import AppGroupKit
import KakaUIKit

extension PurchargeStatus {
    public func statusImage() -> UIImage? {
        switch self {
        case .normal: return nil
        case .subscribing: return Reasource.named("pay_success")
        case .lifetime: return Reasource.named("pay_success")
        case .expired: return Reasource.named("pay_expired")
        case .refunded: return Reasource.named("pay_refunded")
        }
    }
    
    public func statusMessage() -> String {
        switch self {
        case .normal:
            return "Basic User".localStr()
        case .subscribing:
            return "Subscribing".localStr()
        case .lifetime:
            return "Lifetime".localStr()
        case .expired:
            return "Expired, please renew".localStr()
        case .refunded:
            return "Refunded, please renew".localStr()
        }
    }
}

extension UserInfoManager {
    // 是否为VIP
    public func isVIP() -> Bool {
        
#if Target_Mobie_Pro
        return true
#else
    
//        return true
        return self.isPremium()
        
#endif
        
    }
}
