//
//  UserInfoManager+Extension.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2023/12/12.
//

import AppGroupKit
import KakaUIKit

extension UserInfoManager {
    
    // 会员截止日期
    public func vipExpirationDate() -> String {
#if Target_Mobie_Pro
        return "Premium User".localStr()
#else
        switch payStatus {
        case .normal: return "Basic User".localStr()
        case .subscribing, .expired:
            guard let expireDate = self.membershipExpirationDate else {
                return "Premium Expired".localStr()
            }
            
            let dateStr = expireDate.convertToDateString(dateFormat: "yyyy-MM-dd")
            return dateStr
        case .lifetime: return "♾️"
        case .refunded: return "Refunded".localStr()
        }
#endif
        
    }
    
    // 用户头像
    public func getAvatarImage() -> UIImage {
        guard let cusImage = SandboxFileManager.shared.readRemoteAvatar(self) else {
            let avatarPlace = Reasource.named(self.localAvatarName ?? avatarDefaultName)
            
            return avatarPlace
        }
        
        return cusImage
    }
    
}
