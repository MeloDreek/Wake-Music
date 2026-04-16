//
//  MusicsViewController+Library.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/24.
//

import KakaFoundation
import PhotosUI
import KakaUIKit
import AppGroupKit
import StoreKit
import ProgressHUD

extension MusicsViewController: UIDocumentPickerDelegate {
    
    // 导入音乐文件
    @objc func importFromFiles() {
        
        let audioArray = [UTType.text, UTType.data]
        
        let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: audioArray, asCopy: false)
        documentVC.delegate = self
        documentVC.allowsMultipleSelection = true
        documentVC.shouldShowFileExtensions = true
        self.present(documentVC, animated: true)
        
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "files_App"])
        
    }
    
    // 导入文件夹
    func importFromFolder() {
        let documentVC =
            UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentVC.delegate = self
        documentVC.allowsMultipleSelection = false
        documentVC.shouldShowFileExtensions = true
        self.present(documentVC, animated: true, completion: nil)
        
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "files_App"])
    }
    
    // 处理文件选择的回调
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        let supportArray = urls.filter { $0.isSupportMusicFile(true) || $0.hasDirectoryPath }
        
        if supportArray.count == 0 {
            let audios = (["LRC"] + AudioExtension.audioSuffixs).map { $0.uppercased() }
            let fileStr = audios.joined(separator: ", ")
            self.showOneAlert(title: "Please check your file format".localStr(), message: fileStr)
            return
        }
        
        let handType = kaka_IsMacOS() ? FileHandleType.link : FileHandleType.copy
//        let handType = FileHandleType.link
        
        self.viewModel.handleAudioURLs(handleType: handType, sourceType: .localFile, targetFolderURL: self.viewModel.baseFileURL, musicURLs: supportArray) { result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                debugPrint("File ❌ = \(error.localizedDescription)")
                break
            }
        } completion: { [weak self] models in
            
            controller.dismiss(animated: false)
                                    
            if handType == .link {
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            }
            
        }

        AnalyticsManager.shared.logEvent("import_musics", parameters: ["type": "files_App", "count": urls.count])
        
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 当用户取消文件选择时的处理
        debugPrint("Document picker was cancelled")
    }
    
}

extension MusicsViewController {
    
    // 原文件后提示同步
    func deleteOriginalFiles(urls: [URL], photos: [MusicItemModel]) {
        
        let deleteGroup = DispatchGroup()
        
        var errorMsg: String? = nil
        
        for subURL in urls {
            deleteGroup.enter()
                        
            do {

                if FileManager.default.isReadableFile(atPath: subURL.path) {
                    // 本地文件直接操作
                    try kaka_IsMacOS() ? FileManager.default.trashItem(at: subURL, resultingItemURL: nil) : FileManager.default.removeItem(at: subURL)
                    debugPrint("移动至废纸篓 = \(subURL.path)")
                } else if subURL.startAccessingSecurityScopedResource() {
                    defer {
                        subURL.stopAccessingSecurityScopedResource()
                    }
                    
                    try kaka_IsMacOS() ? FileManager.default.trashItem(at: subURL, resultingItemURL: nil) : FileManager.default.removeItem(at: subURL)
                    debugPrint("移动至废纸篓 = \(subURL.path)")
                } else {
                    errorMsg = "Access is restricted".localStr()
                }
                
                deleteGroup.leave()
            } catch {
                errorMsg = "Access is restricted".localStr()
                deleteGroup.leave()
                debugPrint("删除失败 = \(error.localizedDescription)")
            }
            
        }
        
        deleteGroup.notify(queue: .main) { [weak self] () in
            if errorMsg == nil {
                self?.view.makeToast("Complete Deletion".localStr())
            }
            
            if UIApplication.shared.applicationState != .active {
                return
            }
            
        }
    }
        
}
