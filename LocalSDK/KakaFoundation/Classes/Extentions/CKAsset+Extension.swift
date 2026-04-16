//
//  CKAsset+Extension.swift
//  KakaUIKit
//
//  Created by Melo Dreek on 2023/6/1.
//


import KakaFoundation
import CloudKit

extension CKAsset {
    
    // 未加密的二进制==读取图片
    public func assetImage() -> KakaImage? {
        guard let filePath = self.fileURL else { return nil }
        
        if #available(iOS 16.0, macOS 13.0, *) {
            return KakaImage(contentsOfFile: filePath.path(percentEncoded: false))
        } else {
            return KakaImage(contentsOfFile: filePath.path)
        }
        
    }
    
    // 原始的文件流
    public func originFileData() -> Data? {
        guard let filePath = self.fileURL else { return nil }
        
        do {
            let data = try Data(contentsOf: filePath)
            return data
        } catch {
            return nil
        }
    }
    
}
