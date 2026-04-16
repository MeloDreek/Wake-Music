//
//  KakaError+Extension.swift
//  Mobie
//
//  Created by 张文 on 10/3/24.
//

import AppGroupKit
import SmartCodable

/*
百度网盘的错误对象
https://pan.baidu.com/union/doc/okumlx17r
 */
struct BaiduDriveError: SmartCodable {
    var error_code: Int = -1
    var request_id: String = ""
    var errno: Int = -1
    var message: String = ""
    
    // 是否为不支持的格式
    func isUnsupportedFormat() -> Bool {
        return error_code == 31304
    }
    
    /*
     ⚠️是否为身份证验证失败
     -6：身份验证失败
     31045：请检查access_token是否过期，用户授权时是否勾选网盘权限等
     */
    func isAuthenticationFailed() -> Bool {
        return error_code == -6 || error_code == 31045
    }

    static func parseError(_ error: Error) -> BaiduDriveError? {
        guard let nsError = error.nsError else { return nil }
        
        guard var baidu = BaiduDriveError.deserialize(from: nsError.domain) else {
            return nil
        }
        
        baidu.message = baidu.toJSONString() ?? ""
        return baidu
    }
    
}
