//
//  DownloadViewController+Action.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import AppGroupKit
import ProgressHUD
import KakaTaglibKit
import SafariServices
import Alamofire
import SwiftyDropbox

extension DownloadViewController {
    
    // 开始下载
    @objc func startDownloadClick() {
        
        self.dataArray = DownloadManager.shared.taskArray
        self.tableView.reloadData()
        
        guard dataArray.count > 0, let firstModel = dataArray.first else {
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        if self.isDownloading {
            return
        }
        
        self.isDownloadAll = true
        self.updateRightBarItem()
        
        self.handleMusicDownloadURL(firstModel)
        
    }

    
    func handleMusicDownloadURL(_ tempModel: MusicItemModel) {
        var model = tempModel
        
        if let file = model.smbFile {
            self.isDownloading = true
            SMBDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self else { return }
                guard DownloadManager.shared.taskArray.contains(model) else {
                    self.isDownloading = false
                    self.stopDownloadAction()
                    return
                }
                switch result {
                case .success(let url):
                    model.mediaPlayURL = url
                    self.downloadWithTask(model)
                case .failure(let error):
                    self.isDownloading = false
                    self.stopDownloadAction()
                    self.view.makeToast(error.errorDescription)
                }
            }
        }else if let file = model.boxFile {
            self.isDownloading = true
            BoxDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self else { return }
                guard DownloadManager.shared.taskArray.contains(model) else {
                    self.isDownloading = false
                    self.stopDownloadAction()
                    return
                }
                switch result {
                case .success(let url):
                    model.mediaPlayURL = url
                    self.downloadWithTask(model)
                case .failure(let error):
                    self.isDownloading = false
                    self.stopDownloadAction()
                    self.view.makeToast(error.errorDescription)
                }
            }
        }else if let file = model.pcloudFile {
            self.isDownloading = true
            PCloudDriveService.shared.fileURL(file) { [weak self] result in
                guard let self = self else { return }
                guard DownloadManager.shared.taskArray.contains(model) else {
                    self.isDownloading = false
                    self.stopDownloadAction()
                    return
                }
                switch result {
                case .success(let url):
                    model.mediaPlayURL = url
                    self.downloadWithTask(model)
                case .failure(let error):
                    self.isDownloading = false
                    self.stopDownloadAction()
                    self.view.makeToast(error.errorDescription)
                }
            }
        }else if let baiduFile = model.baiduFileModel {
            let access_token = baiduFile.baiduUser?.access_token ?? ""
            KakaMusicPlayer.shared.fetchBaiduDownloadURL(accessToken: access_token, fileModel: baiduFile) { result in
                switch result {
                case .success(let downloadURL):
                    model.mediaPlayURL = downloadURL
                    self.downloadWithTask(model)
                case .failure(let failure):
                    appKeyWindow?.makeToast(failure.errorDescription)
                }
            }
        }else if let aliFileModel = model.aliFileModel {
            KakaMusicPlayer.shared.fetchAliyunDownloadURL(fileModel: aliFileModel) { result in
                switch result {
                case .success(let downloadURL):
                    model.mediaPlayURL = downloadURL
                    self.downloadWithTask(model)
                case .failure(let failure):
                    appKeyWindow?.makeToast(failure.errorDescription)
                }
            }
        }else if let drive115Model = model.drive115Model {
            KakaMusicPlayer.shared.fetch115DownloadPlayURL(file115: drive115Model) { result in
                switch result {
                case .success(let downloadURL):
                    model.mediaPlayURL = downloadURL
                    self.downloadWithTask(model)
                case .failure(let failure):
                    appKeyWindow?.makeToast(failure.errorDescription)
                }
            }
        }else if let dropboxFile = model.dropboxFile {
            KakaMusicPlayer.shared.fetchDropboxDownloadPlayURL(dropboxFile: dropboxFile) { result in
                switch result {
                case .success(let downloadURL):
                    model.mediaPlayURL = downloadURL
                    self.downloadWithTask(model)
                case .failure(let failure):
                    appKeyWindow?.makeToast(failure.errorDescription)
                }
            }
        }
        else{
            self.downloadWithTask(model)
        }
    }
    
    // 下载歌曲
    private func downloadWithTask(_ model: MusicItemModel) {
        
        let downloadURL = model.mediaPlayURL
                
        var folderURL = SandboxFileManager.shared.basePublicFileURL()
        if let downloadFolderName = model.downloadFolderName {
            folderURL = folderURL.appendingPathComponent(downloadFolderName)
        }
        var targetFilePath = folderURL.appendingPathComponent(model.downloadPathName())
        if model.pcloudFile != nil || model.boxFile != nil || model.smbFile != nil {
            // Different cloud folders can contain identically named songs. Preserve local files.
            let originalURL = targetFilePath
            var suffix = 1
            while FileManager.default.fileExists(atPath: targetFilePath.path) {
                let stem = originalURL.deletingPathExtension().lastPathComponent
                targetFilePath = folderURL.appendingPathComponent("\(stem) (\(suffix))").appendingPathExtension(originalURL.pathExtension)
                suffix += 1
            }
        }
        let destinationURL = targetFilePath
        
        if (model.pcloudFile == nil && model.boxFile == nil) {
            debugPrint("下载地址 = \(downloadURL)， 目标地址 = \(targetFilePath)")
        }
        
        self.isDownloading = true
        let progressView = CircleProgressView(frame: CGRectMake(0, 0, 30.ckValue(), 30.ckValue()))
        
        let destination: DownloadRequest.Destination = { _, response in
            return (destinationURL, (model.pcloudFile == nil && model.boxFile == nil) ? [.removePreviousFile, .createIntermediateDirectories] : [.createIntermediateDirectories])
        }
        
        var headers: HTTPHeaders = HTTPHeaders.default
        if let googleFile = model.googleFile {
            headers.add(name: "Authorization", value: "Bearer " + (googleFile.googleUser?.accessToken ?? ""))
        }
        
        let request = AF.download(downloadURL, headers: headers, to: destination)
        if model.pcloudFile != nil || model.boxFile != nil || model.smbFile != nil { request.validate(statusCode: 200..<300) }
        request.downloadProgress { progressValue in
            let progress = progressValue.fractionCompleted
            debugPrint("下载进度 = \(progress)")
            
            progressView.progress = progress
            
            var downloadingCell: MusicTableViewCell?
            if let index = self.dataArray.firstIndex(where: { $0 == model }) {
                downloadingCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicTableViewCell
                downloadingCell?.accessoryView = progressView
            }
          }.responseURL { response in
            switch response.result {
            case .success(let fileURL):
                self.downloadSameFolderLRCFile(model: model, localFileURL: fileURL) {
                    self.dataArray = DownloadManager.shared.removeFromDownloads(model)
                    self.tableView.reloadData()
                    self.refreshDataAction()
                    
                    self.isDownloading = false
                    NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)

                    if let nextModel = self.dataArray.first, self.isDownloadAll {
                        self.handleMusicDownloadURL(nextModel)
                    }else{
                        self.stopDownloadAction()
                    }
                }
                break
            case .failure(let error):
                if model.pcloudFile != nil || model.boxFile != nil || model.smbFile != nil, response.fileURL == destinationURL {
                    // Validation occurs after moving a download; never retain an HTTP error body as music.
                    try? FileManager.default.removeItem(at: destinationURL)
                    self.stopDownloadAction()
                }
                debugPrint("❌下载失败 = \(error.localizedDescription)")
                self.isDownloading = false
                self.tableView.reloadData()
                self.view.makeToast(error.localizedDescription)
                break
            }
        }
        
    }
    
    // 下载同文件夹下的同名LRC文件
    private func downloadSameFolderLRCFile(model: MusicItemModel, localFileURL: URL, completion: (()->Void)? = nil) {
        guard let _ = model.webFileModel, let lrcFileURL = model.lrcFileInSameFolderURL() else {
            completion?()
            return
        }
        
        let folderURL = SandboxFileManager.shared.lyricsPathURL()
        let targetFilePath = folderURL.appendingPathComponent(lrcFileURL.lastPathComponent)
        
        let progressView = CircleProgressView(frame: CGRectMake(0, 0, 30.ckValue(), 30.ckValue()))
        
        
        let destination: DownloadRequest.Destination = { _, response in
            return (targetFilePath, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        AF.download(folderURL, to: destination).downloadProgress { progressValue in
            let progress = progressValue.fractionCompleted
            debugPrint("歌词文件进度 = \(progress)")
            progressView.progress = progress
            
            var downloadingCell: MusicTableViewCell?
            if let index = self.dataArray.firstIndex(where: { $0 == model }) {
                downloadingCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicTableViewCell
                downloadingCell?.accessoryView = progressView
            }
          }.responseURL { response in
            switch response.result {
            case .success(let fileURL):
                if let lrcContent = fileURL.readLRCContentStr() {
                    debugPrint("LRC已下载 = \(lrcContent)")
                    let success = TaglibMetadataParser.setLyris(lrcContent, toFileURL: localFileURL)
                    if success {
                        appKeyWindow?.makeToast(model.showTitleName() + "\r\r" + "The LRC lyrics file of the same name has been embedded in the music file".localStr())
                        
                        NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil)
                    }
                }
                break
            case .failure(let error):
                self.isDownloading = false
                debugPrint("不存在同名文件 = \(error.localizedDescription)")
                break
            }
        }
        
    }
    
}
