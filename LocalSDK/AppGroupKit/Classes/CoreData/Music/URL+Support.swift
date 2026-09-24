//
//  URL+Support.swift
//  AppGroupKit
//
//  Created by Melo on 7/26/24.
//

import Foundation

extension URL {
    /// 检测是否为支持的格式或后缀
    public func isSupportMusicFile(_ isLRC: Bool) -> Bool {
        let fileExtension = self.pathExtension.lowercased()
        
        return AudioExtension.isPlayableAudioExtension(fileExtension) || (isLRC && fileExtension == "lrc")
    }
}

extension String {
    /// 提取字符串中第一个阿拉伯数字，兼容中日韩、俄文、Emoji前缀等文件名
    public func extractFirstNumber() -> Int? {
        let pattern = #"(?<!\d)(\d{1,6})(?!\d)"#  // 最多提取6位数字
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
           let range = Range(match.range(at: 1), in: self) {
            return Int(self[range])
        }
        
        return nil
    }
}
