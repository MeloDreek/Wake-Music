//
//  ImportViewController+Local.swift
//  Mobie
//
//  Created by 张文 on 12/16/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import ProgressHUD
import UniformTypeIdentifiers
import StoreKit

extension ImportViewController: UIDocumentPickerDelegate {
    func importFromFiles() {
        let audioArray = [UTType.text, UTType.data]
        
        let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: audioArray, asCopy: false)
        documentVC.delegate = self
        documentVC.allowsMultipleSelection = true
        documentVC.shouldShowFileExtensions = true
        self.present(documentVC, animated: true)
    }
    
    func importFromFolder() {
        let documentVC =
            UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        documentVC.delegate = self
        documentVC.allowsMultipleSelection = false
        documentVC.shouldShowFileExtensions = true
        self.present(documentVC, animated: true, completion: nil)
    }
    
    func importFromVideos() {
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "Conveter_App"])
        
        let convertVC = VideoConverterViewController(viewModel: self.viewModel)
        self.navigationController?.pushViewController(convertVC, animated: true)
    }
    
    func importFromUSB() {
        
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "PC"])
        
        let scanVC = ScanUSBViewController(self.viewModel)
        self.navigationController?.pushViewController(scanVC, animated: true)
    }
    
    func importFromWiFi() {
        AnalyticsManager.shared.logEvent("import_type", parameters: ["type": "PC"])
        
        let scanVC = WiFiServerViewController(self.viewModel)
        self.navigationController?.pushViewController(scanVC, animated: true)
    }
    
    // 处理文件选择的回调
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        let supportArray = urls.filter { $0.isSupportMusicFile(true) || $0.hasDirectoryPath }
        
        if supportArray.count == 0 {
            let audios = (["LRC"] + AudioExtension.playableAudioSuffixs).map { $0.uppercased() }
            let fileStr = audios.joined(separator: ", ")
            self.showOneAlert(title: "Please check your file format".localStr(), message: fileStr)
            return
        }
        
        let handType = kaka_IsMacOS() ? FileHandleType.link : FileHandleType.copy
//        let handType = FileHandleType.link
        
        self.viewModel.handleAudioURLs(handleType: handType, sourceType: .localFile, musicURLs: supportArray) { result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                debugPrint("File ❌ = \(error.localizedDescription)")
                break
            }
        } completion: { [weak self] models in
            
            if handType == .link {
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
            }
            
            controller.dismiss(animated: false)
            
            self?.navigationController?.dismiss(animated: true)
            
        }

        AnalyticsManager.shared.logEvent("import_musics", parameters: ["type": "files_App", "count": urls.count])
        
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 当用户取消文件选择时的处理
        debugPrint("Document picker was cancelled")
    }
    
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
                    errorMsg = "Access Restricted".localStr()
                }
                
                deleteGroup.leave()
            } catch {
                errorMsg = "Access Restricted".localStr()
                deleteGroup.leave()
                debugPrint("删除失败 = \(error.localizedDescription)")
            }
            
        }
        
        deleteGroup.notify(queue: .main) { [weak self] () in
            self?.showLongPressTips(errorMsg)
        }
    }
        
    func showLongPressTips(_ errorMsg: String?) {
        if errorMsg == nil {
            self.view.makeToast("Complete Deletion".localStr())
        }
        
        if UIApplication.shared.applicationState != .active {
            return
        }
        
#if !DEBUG
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
#endif
    }

}
