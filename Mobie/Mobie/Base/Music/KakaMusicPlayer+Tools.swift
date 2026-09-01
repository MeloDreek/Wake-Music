//
//  KakaMusicPlayer+Tools.swift
//  Wakemusic
//
//  Created by Melo on 9/10/24.
//

import KakaFoundation
import KakaUIKit
import AVFoundation
import AppGroupKit
import FFmpegKit

extension KakaMusicPlayer {
    
    // 使用 FFmpeg 提取 PCM 样本
    func extractPCMSamplesWithFFmpeg(audioURL: URL, completion: @escaping ([Float]) -> Void) {
        // 创建 AVAsset 和 AVAssetReader
        let asset = AVAsset(url: audioURL)
        
        // 获取音频轨道
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            debugPrint("没有音频轨道")
            completion([])
            return
        }
        
        do {
            // 创建 AVAssetReader
            let reader = try AVAssetReader(asset: asset)
            
            // 设置音频输出
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,  // 设置为你音频的采样率（通常为44100或其他）
                AVNumberOfChannelsKey: 2,  // 通常是立体声
                AVLinearPCMBitDepthKey: 16, // PCM 16-bit depth
                AVLinearPCMIsFloatKey: true, // PCM 使用浮动点
                AVLinearPCMIsBigEndianKey: false
            ]
            
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            reader.add(output)
            
            // 开始读取
            reader.startReading()
            
            var pcmSamples: [Float] = []
            
            // 读取样本
            while let sampleBuffer = output.copyNextSampleBuffer() {
                // 获取音频数据
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                    continue
                }
                
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                
                _ = data.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
                }
                
                // 将 PCM 数据转换为 Float 数组
                let sampleCount = length / 2 // 每个样本是16位（2字节）
                let floatSamples = (0..<sampleCount).map { index -> Float in
                    let startIndex = index * 2
                    let int16Value = Int16(data[startIndex]) | (Int16(data[startIndex + 1]) << 8)
                    return Float(int16Value) / Float(Int16.max)  // 转换为 [-1, 1] 范围内的浮动值
                }
                
                pcmSamples.append(contentsOf: floatSamples)
            }
            
            // 完成时回调
            completion(pcmSamples)
            
        } catch {
            print("创建 AVAssetReader 失败: \(error.localizedDescription)")
            completion([])
        }
        
    }

    /*
    func extractPCMSamplesWithFFmpeg(audioURL: URL, completion: @escaping ([Float]) -> Void) {
        let inputPath = audioURL.path
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let uniqueFileName = UUID().uuidString + ".pcm"
        let tempOutputPath = cacheDirectory.appendingPathComponent(uniqueFileName).path

        // 使用 FFmpeg 命令将音频转换为 PCM 格式
        let command = "-i \"\(inputPath)\" -f f32le -acodec pcm_f32le \"\(tempOutputPath)\""
        

        FFmpegKit.executeAsync(command) { session in
            let returnCode = session?.getReturnCode()

            if let returnCode = returnCode, returnCode.isValueSuccess() {
                // 读取输出文件中的 PCM 样本
                do {
                    let pcmData = try Data(contentsOf: URL(fileURLWithPath: tempOutputPath))
                    let floatArray = pcmData.toFloatArray()
                    DispatchQueue.main.async {
                        completion(floatArray)
                    }
                } catch {
                    debugPrint("Failed to read PCM data: \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }

                // 删除临时文件
                try? FileManager.default.removeItem(atPath: tempOutputPath)

            } else {
                debugPrint("FFmpeg command failed with return code: \(returnCode?.description ?? "unknown")")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    */
    
}

extension KakaMusicPlayer {
    
    // 生成和创建视频转音乐的临时路径
    func videoToAudioURL(_ audioType: AudioFormatEnum) -> URL? {
        
        // 创建输出文件路径
        var targetStr = SandboxType_OtherTemp
        
        if !FileManager.default.fileExists(atPath: targetStr) {
            try? FileManager.default.createDirectory(atPath: targetStr, withIntermediateDirectories: true, attributes: nil)
        }
        
        targetStr = targetStr.appending("/\(Date.uniqueNanosecondTimestamp()).\(audioType.suffixName())")

        var audioOutputURL: URL
        if #available(iOS 16.0, *) {
            audioOutputURL = URL(filePath: targetStr, directoryHint: .notDirectory, relativeTo: nil)
        } else {
            audioOutputURL = URL(fileURLWithPath: targetStr, isDirectory: false)
        }
        
        // 如果文件已经存在，删除它
        if FileManager.default.fileExists(atPath: audioOutputURL.path) {
            try? FileManager.default.removeItem(at: audioOutputURL)
        }
        
        return audioOutputURL
        
    }
    
    // 生成和创建铃声的临时路径
    func createRingtoneURL(musicName: String, audioType: AudioFormatEnum) -> URL? {
        
        // 创建输出文件路径
        var targetStr = SandboxType_OtherTemp + "/" + musicName + "/Medio/"
        
        if !FileManager.default.fileExists(atPath: targetStr) {
            try? FileManager.default.createDirectory(atPath: targetStr, withIntermediateDirectories: true, attributes: nil)
        }
        
        targetStr = targetStr.appending("ringtone.aiff")

        var audioOutputURL: URL
        if #available(iOS 16.0, *) {
            audioOutputURL = URL(filePath: targetStr, directoryHint: .notDirectory, relativeTo: nil)
        } else {
            audioOutputURL = URL(fileURLWithPath: targetStr, isDirectory: false)
        }
        
        // 如果文件已经存在，删除它
        if FileManager.default.fileExists(atPath: audioOutputURL.path) {
            try? FileManager.default.removeItem(at: audioOutputURL)
        }
        
        return audioOutputURL
        
    }
    
}

extension KakaMusicPlayer {
    // 打开访达
    public func showInFinderCatalyst(_ fileURL: URL) {
        guard kaka_IsMacOS() else { return }
        
        // Finder 的行为是选中这个文件，所以我们传它所在的目录
        let folderURL = fileURL.deletingLastPathComponent()
        
        // 如果是文件夹就直接打开，否则打开其所在目录
        let targetURL = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: nil) && fileURL.path.hasSuffix("/") ? fileURL : folderURL

        UIApplication.shared.open(targetURL, options: [:]) { success in
            if !success {
                debugPrint("无法在 Finder 中打开路径: \(targetURL.path)")
            }
        }
    }
    
    // 删除所有m3u缓存文件
    public func deleteAllM3uCache() {
        // 删除所有m3u缓存
        let m3uArray = SandboxFileManager.shared.preDownloadURL().readLocalSubFiles().filter {
            $0.pathExtension.contains("m3u")
        }
        
        for index in 0..<m3uArray.count {
            let subM3uURL = m3uArray[index]
            try? FileManager.default.removeItem(at: subM3uURL)
        }
    }
}

// 扩展 Data 以将 PCM 数据转换为 [Float]
extension Data {
    func toFloatArray() -> [Float] {
        var array: [Float] = []
        let length = self.count / MemoryLayout<Float>.size
        array.reserveCapacity(length)
        
        self.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            let unsafeBufferPointer = rawBufferPointer.bindMemory(to: Float.self)
            let unsafePointer = unsafeBufferPointer.baseAddress!
            array.append(contentsOf: UnsafeBufferPointer(start: unsafePointer, count: length))
        }
        
        return array
    }
}
