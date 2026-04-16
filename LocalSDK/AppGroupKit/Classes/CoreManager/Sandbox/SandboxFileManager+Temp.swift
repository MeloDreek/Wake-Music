//
//  SandboxFileManager+Temp.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2024/4/20.
//

import KakaFoundation
import KakaUIKit
import CloudKit


// 临时文件
extension SandboxFileManager {

    // 将文件复制到临时文件夹
    public func copyFileToOtherTemp(sourceURL: URL, success: ((URL)->Void)? = nil, fail: ((String)->Void)? = nil) {
        do {
            
            var targetStr = SandboxType_OtherTemp
            
            if !FileManager.default.fileExists(atPath: targetStr) {
                try? FileManager.default.createDirectory(atPath: targetStr, withIntermediateDirectories: true, attributes: nil)
            }
            
            targetStr = targetStr.appending("/\(Date.uniqueNanosecondTimestamp()).\(sourceURL.pathExtension)")
            
            var targetFilePath: URL
            if #available(iOS 16.0, *) {
                targetFilePath = URL(filePath: targetStr, directoryHint: .notDirectory, relativeTo: nil)
            } else {
                targetFilePath = URL(fileURLWithPath: targetStr, isDirectory: false)
            }
            
            if FileManager.default.fileExists(atPath: targetFilePath.path) {
                try FileManager.default.removeItem(at: targetFilePath)
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: targetFilePath)
            
            DispatchQueue.main.async {
                success?(targetFilePath)
            }
            
        } catch {
            DispatchQueue.main.async {
                fail?(error.localizedDescription)
            }
        }
    }
    
    /// 删除其他临时文件
    public func deleteOtherTempFiles() {
        var targetStr = SandboxType_OtherTemp
        do {
            var targetFilePath: URL
            if #available(iOS 16.0, *) {
                targetFilePath = URL(filePath: targetStr, directoryHint: .isDirectory, relativeTo: nil)
            } else {
                targetFilePath = URL(fileURLWithPath: targetStr, isDirectory: true)
            }
            try FileManager.default.removeItem(at: targetFilePath)
        } catch {
            debugPrint("删除失败: \(error.localizedDescription)")
        }
    }
    
}

// MARK: 本地头像
extension SandboxFileManager {
    
    // 保存头像到沙盒
    public func saveAvatarImageSanbox(userModel: UserInfoManager, image: KakaImage) -> CKAsset? {
                
        var accountFolderPath = self.getDocumentFilePath().appendingPathComponent(CloudRecordType_OtherImage).path
        
        // 将路径转成沙盒URL的正确方法
        var accountFolderURL: URL
        if #available(iOS 16.0, *) {
            accountFolderURL = URL(filePath: accountFolderPath, directoryHint: .notDirectory, relativeTo: nil)
        } else {
            accountFolderURL = URL(fileURLWithPath: accountFolderPath, isDirectory: true)
        }
        
        do {
            // 1、创建文件夹
            if !FileManager.default.fileExists(atPath: accountFolderPath) {
                // 之前没记录，创建文件夹
                try FileManager.default.createDirectory(atPath: accountFolderPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 2、压缩图片
            guard let imageData = image.dataWithCompression() else {
                return nil
            }
            
            // 3、写入二进制文件
            let fileName = userModel.cloudUserID + ".jpg"
            var assetPath: URL!
            if #available(iOS 16.0, *) {
                assetPath = accountFolderURL.appending(path: fileName, directoryHint: .notDirectory)
            } else {
                assetPath = accountFolderURL.appendingPathComponent(fileName, isDirectory: false)
            }
            
            try? imageData.write(to: assetPath, options: .atomic)

            return CKAsset(fileURL: assetPath)
        
        } catch {
            return nil
        }
        
    }
    
    // 读取沙盒里的远程头像
    public func readRemoteAvatar(_ userModel: UserInfoManager) -> UIImage? {
        
        let accountFolderPath = self.getDocumentFilePath().appendingPathComponent(CloudRecordType_OtherImage + "/" + userModel.cloudUserID + ".jpg").path
                
        if FileManager.default.fileExists(atPath: accountFolderPath) {
            guard let imageData = FileManager.default.contents(atPath: accountFolderPath) else {
                return nil
            }
            
            return UIImage(data: imageData)
        } else {
            return nil
        }
        
    }
    
    // 删除沙盒里的远程头像
    public func deleteRemoteAvatar(_ userModel: UserInfoManager) {
        
        let accountFolderPath = self.getDocumentFilePath().appendingPathComponent(CloudRecordType_OtherImage + "/" + userModel.cloudUserID + ".jpg").path
        
        if FileManager.default.fileExists(atPath: accountFolderPath) {
            do {
                try FileManager.default.removeItem(atPath: accountFolderPath)
                debugPrint("✅删除沙盒头像成功")
            } catch {
                debugPrint("❌删除沙盒头像失败 = \(error.localizedDescription)")
            }
        }
    }
    
}

