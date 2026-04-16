//
//  AVURLAsset+ZIP.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2024/2/3.
//

import AVFoundation

extension AVURLAsset {
    
    // 自动压缩视频
    public func compressVideo(outputURL: URL, completionHandler: @escaping (Data?, Error?) -> Void) {
        
        guard let exportSession = AVAssetExportSession(asset: self, presetName: AVAssetExportPresetMediumQuality) else {
            completionHandler(nil, NSError(domain: "-999", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create AVAssetExportSession"]))
            return
        }

        exportSession.outputFileType = AVFileType.mp4
        exportSession.outputURL = outputURL

        exportSession.exportAsynchronously {
            let data = try? Data(contentsOf: outputURL)
            switch exportSession.status {
            case .completed:
                completionHandler(data, nil)
            case .failed, .cancelled:
                completionHandler(data, exportSession.error)
            default:
                completionHandler(data, NSError(domain: "UnKnow", code: 99, userInfo: [NSLocalizedDescriptionKey: "UnKnow Error"]))
                break
            }
        }
    }
    
    // 資源數據
    public func fileData() -> Data? {
        let videoData = try? Data(contentsOf: self.url)
        
        return videoData
    }
}
