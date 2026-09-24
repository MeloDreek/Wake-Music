//
//  MacTabbarViewController+Drop.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import AppGroupKit
import UniformTypeIdentifiers
import AVFoundation
import ProgressHUD

// MARK: 拖拽文件进来
extension MacTabbarViewController: UIDropInteractionDelegate {
    
    func registerDragDrop() {
        let dropInteraction = UIDropInteraction(delegate: self)
        dropInteraction.allowsSimultaneousDropSessions = true
        self.view.addInteraction(dropInteraction)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        // 允许处理文件和文件夹
        let allUTTypes = [UTType.data, UTType.text]
        let identifiers = allUTTypes.map({ $0.identifier }) + AudioExtension.playableAudioSuffixs
        return session.hasItemsConforming(toTypeIdentifiers: identifiers) || session.items.contains { item in
            item.itemProvider.hasItemConformingToTypeIdentifier(UTType.folder.identifier)
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        debugPrint("开始拖拽")
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        debugPrint("拖拽完成")
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        debugPrint("拖拽离开")
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
        
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        debugPrint("处理拖拽进来的文件 = \(session.items)")
        self.handleDropItem(session: session)
    }
    
    // 处理拖拽进来的资源
    private func handleDropItem(session: UIDropSession) {
        var musicArray = [URL]()
        let drapDataGroup = DispatchGroup()
        let allUTTypes = [UTType.data, UTType.text]

        for subItem in session.items {
            if subItem.itemProvider.hasItemConformingToTypeIdentifier(UTType.folder.identifier) {
                // 处理文件夹
                drapDataGroup.enter()
                subItem.itemProvider.loadItem(forTypeIdentifier: UTType.folder.identifier, options: nil) { item, error in
                    guard let folderURL = item as? URL else {
                        drapDataGroup.leave()
                        return
                    }
                    self.recursivelyLoadFiles(from: folderURL, into: &musicArray, with: drapDataGroup)
                    drapDataGroup.leave()
                }
            } else {
                // 处理单个文件
                for index in 0..<allUTTypes.count {
                    let imageType = allUTTypes[index]
                    if subItem.itemProvider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                        drapDataGroup.enter()
                        subItem.itemProvider.loadItem(forTypeIdentifier: imageType.identifier, options: nil) { item, error in
                            guard let itemURL = item as? URL else {
                                drapDataGroup.leave()
                                return
                            }
                            musicArray.append(itemURL)
                            drapDataGroup.leave()
                        }
                        break
                    }
                }
            }
        }
        
        drapDataGroup.notify(queue: .main) { [weak self] in
            
            let supportArray = musicArray.filter { $0.isSupportMusicFile(true) || $0.hasDirectoryPath }
            
            if supportArray.count == 0 {
                let audios = AudioExtension.playableAudioSuffixs.map { $0.uppercased() }
                let fileStr = audios.joined(separator: ", ")
                self?.showOneAlert(title: "Please check your file format".localStr(), message: fileStr)
                return
            }
            
            self?.viewModel.handleAudioURLs(handleType: .link, sourceType: .fromFile, musicURLs: supportArray, oneBlock: { result in
                
            }, completion: { [weak self] models in
                guard let navVC = self?.contentDict[PrimaryCellItemType.allMusics.rawValue], let musicVC = navVC.topViewController as? MusicsViewController else { return }
                musicVC.refreshDataAction()
            })
            
            // 上报文件后缀
            let extensionStr = musicArray.map({ $0.lastPathComponent }).joined(separator: " & ")
            let params: [String: Any] = ["extensions": extensionStr]
            AnalyticsManager.shared.logEvent("file_extension", parameters: params)
        }
    }
    
    private func recursivelyLoadFiles(from folderURL: URL, into musicArray: inout [URL], with dispatchGroup: DispatchGroup) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in fileURLs {
                if fileURL.hasDirectoryPath {
                    // 递归处理子文件夹
                    self.recursivelyLoadFiles(from: fileURL, into: &musicArray, with: dispatchGroup)
                } else {
                    // 处理单个文件
                    dispatchGroup.enter()
                    musicArray.append(fileURL)
                    dispatchGroup.leave()
                }
            }
        } catch {
            debugPrint("Error reading folder contents: \(error)")
        }
    }
    
}
