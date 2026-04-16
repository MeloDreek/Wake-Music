//
//  URL+Kaka.swift
//  KakaFoundation
//
//  Created by Kaka Inc. on 2024/1/26.
//

import AVFoundation

extension URL {
    
    // 读取视频封面
    public func getVideoThumbnail() -> KakaImage? {
        let asset = AVAsset(url: self)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let duration = asset.duration.seconds
        let time = CMTime(seconds: duration >= 6 ? 6 : duration / 2, preferredTimescale: 1)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            
            #if os(iOS)
            let thumbnail = UIImage(cgImage: cgImage)
            #elseif os(macOS)
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            #endif
            
            return thumbnail
        } catch {
            debugPrint("生成视频封面地址错误: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 文件夹下的所有子文件路径，不遍历子文件夹
    public func readLocalSubFiles() -> [URL] {

        let fileManager = FileManager.default
        var resultFiles: [URL] = []
        
        do {
            // 获取文件夹内容（包括文件和子文件夹）
            let baseSubFiles = try fileManager.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            // 过滤隐藏文件（可选）并保存
            resultFiles = baseSubFiles
        } catch {
            debugPrint("Error reading contents of directory: \(error)")
        }
        
        return resultFiles
        
    }
    
    /// 是否为LRC歌词文件
    public func isLRCFile() -> Bool {
        return self.pathExtension.lowercased() == "lrc"
    }
    
    // 视频的尺寸
    public func videoSize() -> CGSize? {
        let asset = AVAsset(url: self)
        let track = asset.tracks(withMediaType: .video).first
        guard let naturalSize = track?.naturalSize else {
            return nil
        }
        
        return naturalSize
    }
    
    // 累计的文件个数
    public func totalFileCount() -> Int {
        let fileManager = FileManager.default
        var totalCount: Int = 0
        
        // 检查该 URL 是否是目录
        guard let isDirectory = try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory == true else {
            return totalCount
        }
        
        // 使用 FileManager 遍历文件夹内容，包括子文件夹
        if let enumerator = fileManager.enumerator(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    // 获取文件的属性
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    
                    // 如果是文件（而不是目录），增加计数
                    if resourceValues.isDirectory == false {
                        totalCount += 1
                    }
                } catch {
                    debugPrint("Error while checking file for \(fileURL): \(error)")
                }
            }
        }
        
        return totalCount
    }
    
    // 判断两个文件大小的差差距
    public func fileSizeDifference(to url: URL) -> Double {
        do {
            let attributes1 = try FileManager.default.attributesOfItem(atPath: self.path)
            let attributes2 = try FileManager.default.attributesOfItem(atPath: url.path)
            
            if let fileSize1 = attributes1[.size] as? Int64, let fileSize2 = attributes2[.size] as? Int64 {
                let sizeDifference = abs(Double(fileSize1 - fileSize2)) / (1024 * 1024) // Convert bytes to MB
                debugPrint("文件大小相差 = \(sizeDifference)")
                return sizeDifference
            }
        } catch {
            debugPrint("Error: \(error)")
        }
        
        return 0
    }
    
    

    
}
