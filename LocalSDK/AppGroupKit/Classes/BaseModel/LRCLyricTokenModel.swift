//
//  LRCLyricTokenModel.swift
//  AppGroupKit
//
//  Created by 张文 on 5/11/25.
//

import SmartCodable

public struct LRCLyricTokenModel: SmartCodableX {
    
    public init(prefix: String, target: String, lastTime: TimeInterval) {
        self.prefix = prefix
        self.target = target
        self.lastTime = lastTime
    }
    
    public init() {
        
    }
    
    /// 前置
    public var prefix: String = ""
    
    /// target
    public var target: String = ""
    
    /// 上次的时间戳
    public var lastTime: TimeInterval = 0
    
    
    /// {prefix}:{nonce}
    public func tokenStr() -> String {
        let none = Date().convertString()
        return "{\(self.prefix)}:{\(none)}"
    }
    
    /// 是否超过了5分钟
    public func isBeyond5Minites() -> Bool {
        // 当前时间戳
        let currentTime = Date().timeIntervalSince1970
        // 5分钟的秒数
        let fiveMinutes: TimeInterval = 5 * 60
        
        // 检查是否超过了5分钟
        return (currentTime - lastTime) > fiveMinutes
    }
    
}

