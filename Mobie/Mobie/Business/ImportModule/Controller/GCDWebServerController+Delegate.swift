//
//  GCDWebServerController+Delegate.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/3/28.
//

import GCDWebServer
import AppGroupKit
import ProgressHUD
import KakaUIKit
import KakaFoundation
import KSPlayer
import StoreKit


extension GCDWebServerController: GCDWebUploaderDelegate {
        
    // 已关闭
    func webServerDidStop(_ server: GCDWebServer) {
        self.isUploading = false
        debugPrint("连接已关闭")
    }

    // 已经开始，连接刚创建
    func webServerDidStart(_ server: GCDWebServer) {
        debugPrint("连接已开始")
    }
    
    // 开始新任务，用户将文件拖动了进来
    func webServerDidConnect(_ server: GCDWebServer) {
        self.isUploading = true
        debugPrint("server.serverURL = \(server.serverURL?.absoluteString ?? "❌")")
        self.tableView.reloadData()
    }
    
    // 失去连接
    func webServerDidDisconnect(_ server: GCDWebServer) {
        self.isUploading = false
        self.tableView.reloadData()
    }
    
    // 完成一个文件的上传
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        debugPrint("上传 = \(path)")
        self.isUploading = uploader.isRunning
        
        let pathURL = URL(fileURLWithPath: path)
        
        self.viewModel.handleAudioURLs(handleType: .move, sourceType: .localFile, targetFolderURL: self.viewModel.baseFileURL, musicURLs: [pathURL]) { [weak self] result in
            switch result {
            case .success(let oneModel):
                self?.dataArray.insert(oneModel, at: 0)
                if self?.playIndex != -1 {
                    self?.playIndex += 1
                }
                self?.tableView.reloadData()
            case .failure(let error):
                self?.view.makeToast(error.localizedDescription)
            }
        } completion: { [weak self] models in
            self?.tableView.reloadData()
        }
        
        if let shareVC = self.presentedViewController as? UIActivityViewController {
            shareVC.dismiss(animated: false)
        }
        
    }
    
    // 删除了文件
    func webUploader(_ uploader: GCDWebUploader, didDeleteItemAtPath path: String) {
        
        let pathURL = URL(fileURLWithPath: path)

        guard let index = self.dataArray.firstIndex(where: {
            $0.mediaPlayURL == pathURL
        }) else { return }
                
        dataArray.remove(at: index)
        tableView.reloadData()
        
    }
    
    // 在网页端已下载了文件
    func webUploader(_ uploader: GCDWebUploader, didDownloadFileAtPath path: String) {
        debugPrint("用户在网页端下载了文件")
    }
    
    // 创建了文件夹
    func webUploader(_ uploader: GCDWebUploader, didCreateDirectoryAtPath path: String) {
        
    }
    
    // 移动了文件
    func webUploader(_ uploader: GCDWebUploader, didMoveItemFromPath fromPath: String, toPath: String) {
        
    }
    
}
