//
//  GoogleErrorResponse.swift
//  Mobie
//
//  Created by 张文 on 10/25/25.
//

import SmartCodable

struct GoogleErrorResponse: SmartCodable {
    var error: GoogleDriveErrorDetail?
    
    // 需要重新登录
    func isNeedRefreshToken() -> Bool {
        guard let e = error else { return false }
        // code=401 且 reason 是 authError（无效或过期 token）
        if e.code == 401 {
            if e.message.lowercased().contains("invalid credentials") ||
               e.status.uppercased() == "UNAUTHENTICATED" {
                return true
            }
        }
        
        return false
    }
    
    // 需要重新授权
    func isNeedAuthAgain() -> Bool {
        guard let e = error else { return false }
        let msg = e.message.lowercased()
        let status = e.status.uppercased()

        if e.code == 400 || e.code == 403 || e.code == 401 {
            // refresh token 被撤销 / 权限失效 / scope 改变
            if msg.contains("invalid_grant")
                || msg.contains("unauthorized_client")
                || msg.contains("access_denied")
                || msg.contains("insufficientpermissions")
                || status == "PERMISSION_DENIED" {
                return true
            }
        }
        
        return false
    }
}

struct GoogleDriveErrorDetail: SmartCodable {
    var code: Int?
    var message: String = ""
    var errors: [GoogleDriveErrorItem]?
    var status: String = ""
}

struct GoogleDriveErrorItem: SmartCodable {
    var message: String = ""
    var domain: String = ""
    var reason: String = ""
    var location: String?
    var locationType: String?
}



struct GoogleTokenResponse: SmartCodable {
    var access_token: String = ""
    var expires_in: TimeInterval = 0
    var token_type: String = ""
    var refresh_token: String = ""
    var user_id: String?
    var project_id: String?
}
