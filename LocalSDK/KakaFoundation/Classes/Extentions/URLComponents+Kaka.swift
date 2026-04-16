//
//  URLComponents+Kaka.swift
//  KakaFoundation
//
//  Created by Kaka Inc. on 2024/4/11.
//

import Foundation

extension URLComponents {
    /// http://domin.com
    public func dominUrlStr() -> String {
        
        guard let vScheme = scheme, let vHost = host, vScheme.count > 0, vHost.count > 0 else {
            var result = self.string ?? ""
            if result.contains("http://") {
                return result
            }else{
                result = "http://" + result
                return result
            }
        }
        
        let result = vScheme + "://" + vHost
        
        return result
    }
}
