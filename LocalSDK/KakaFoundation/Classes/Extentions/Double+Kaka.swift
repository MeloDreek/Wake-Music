//
//  Double+Kaka.swift
//  KakaFoundation
//
//  Created by Kaka Inc.on 2021/11/24.
//

import Foundation

extension Double {
    /// 保留n位小数点
    public func keepZero(_ count: Int) -> String {
        let value = String(format: "%.\(count)f", self)
        return value
    }
}

extension CGFloat {
    /// 保留n位小数点
    public func keepZero(_ count: Int) -> String {
        let value = String(format: "%.\(count)f", self)
        return value
    }
    
    /// 去掉多余的0
    public func cleanZero() -> String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : "\(self)"
    }
    
}

extension Float {
    /// 保留n位小数点
    public func keepZero(_ count: Int) -> String {
        let value = String(format: "%.\(count)f", self)
        return value
    }
    
    /// 去掉多余的0
    public func cleanZero() -> String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : "\(self)"
    }
    
}

extension TimeInterval {
    
    /// 时间戳转字符串
    public func timeFormatStr() -> String {
        let date = Date(timeIntervalSince1970: self)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let dateStr = formatter.string(from: date)
        return dateStr
    }
    
}
