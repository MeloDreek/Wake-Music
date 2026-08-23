//
//  URL+Extension.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2024/3/28.
//

import Foundation
import AVFoundation

extension URL {
    
    /// 获得文件大小
    public var fileSizeString: String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            if let fileSize = attributes[.size] as? UInt64 {
                let byteCountFormatter = ByteCountFormatter()
                byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
                byteCountFormatter.countStyle = .file
                byteCountFormatter.includesUnit = true
                byteCountFormatter.isAdaptive = true
                return byteCountFormatter.string(fromByteCount: Int64(fileSize))
            } else {
                return ""
            }
        } catch {
            return ""
        }
    }
    
    /// 获得文件时长
    public var timeDuration: String {
        // 创建 AVAsset 实例
        let asset = AVAsset(url: self)
        
        // 获取时长（单位为秒）
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        // 如果时长无效则返回 nil
        guard !durationInSeconds.isNaN else {
            return "--:--"
        }
        
        // 计算分钟和秒数
        let minutes = Int(durationInSeconds) / 60
        let seconds = Int(durationInSeconds) % 60
        
        // 格式化为 "mm:ss" 格式
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // 获得这个文件夹下的所有文件大小
    public func totalFileSize() -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        // 检查该 URL 是否是目录
        guard let isDirectory = try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory == true else {
            return totalSize
        }
        
        // 使用 FileManager 遍历文件夹内容，包括子文件夹
        if let enumerator = fileManager.enumerator(at: self, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    // 获取文件的属性
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                    
                    // 如果是文件（而不是目录），获取其大小
                    if resourceValues.isDirectory == false, let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                } catch {
                    debugPrint("Error while getting file size for \(fileURL): \(error)")
                }
            }
        }
        
        return totalSize
    }
    
    /// 获取文件大小的字节数
    public var fileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            let size = (attributes[.size] as? Int64) ?? 0
//            debugPrint("文件size = \(size)")
            return size
        } catch {
            return 0
        }
    }
    
    /// 格式化文件大小
    public static func formatFileSize(_ size: Int64) -> String {
        
        if size <= 0 { return "" }
            
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        byteCountFormatter.countStyle = .file
        byteCountFormatter.includesUnit = true
        byteCountFormatter.isAdaptive = true
        return byteCountFormatter.string(fromByteCount: size)
    }
    
    /// 获取文件的创建时间（creation date）
    public var creationDate: Date? {
        return (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }

    /// 获取文件的修改时间（modification date）
    public var modificationDate: Date? {
        return (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
    
}


