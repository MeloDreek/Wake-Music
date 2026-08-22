//
//  VideoConverterViewController+Action.swift
//  Wake Music
//
//  Created by Melo on 9/10/24.
//

import KakaFoundation
import AppGroupKit
import AVFoundation
import AVKit
import Photos
import KakaTaglibKit
import AudioToolbox
import StoreKit
import KSPlayer
import PhotosUI

extension VideoConverterViewController: PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
    
    // 选择视频
    func selectVideoAction() {
        
        if kaka_IsMacOS() {
            let audioArray = AudioExtension.videoUTTypes
            
            let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: audioArray, asCopy: false)
            documentVC.allowsMultipleSelection = false
            documentVC.delegate = self
            documentVC.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            documentVC.shouldShowFileExtensions = true
            self.present(documentVC, animated: true)
        }else{
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        var config = PHPickerConfiguration()
                        config.filter = .videos
                        config.selectionLimit = 1
                        config.preferredAssetRepresentationMode = .current
                        
                        let picker = PHPickerViewController(configuration: config)
                        picker.delegate = self
                        self.present(picker, animated: true)
                    }else{
                        self.showOneAlert(message: "You have denied access to the album, please re-enable it.".localStr(), confirm: "Settings".localStr()) {
                            guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(vURL)
                        }
                    }
                }
            }
        }
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let itemProvider = results.first?.itemProvider else {
            picker.dismiss(animated: true)
            return
        }
        
        self.videoCell?.startLoading()
        self.tableView.isUserInteractionEnabled = false

        
        // 定义支持的UTType数组
        let supportedTypes = AudioExtension.videoUTTypes.map { $0.identifier }

        // 检查每一个支持的类型
        for type in supportedTypes {
            if itemProvider.hasItemConformingToTypeIdentifier(type) {
                // 如果找到匹配的类型，加载文件
                itemProvider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] vURL, error in
                    guard let videoURL = vURL else {
                        DispatchQueue.main.async {
                            self?.videoCell?.stopLoading()
                            self?.tableView.isUserInteractionEnabled = true
                            self?.view.makeToast(error?.localizedDescription ?? "")
                        }
                        return
                    }

                    SandboxFileManager.shared.copyFileToOtherTemp(sourceURL: videoURL) { [weak self] targetURL in
                        self?.convertVideoToAudio(targetURL)
                        picker.dismiss(animated: true)
                    } fail: { [weak self] errorMsg in
                        self?.tableView.isUserInteractionEnabled = true
                        self?.view.makeToast(errorMsg)
                        self?.deleteVideoFile()
                        picker.dismiss(animated: true)
                    }
                }
                return
            }
        }
        
        // 如果没有找到任何支持的类型
        DispatchQueue.main.async {
            self.videoCell?.stopLoading()
            self.tableView.isUserInteractionEnabled = true
            picker.dismiss(animated: false)
            
            self.showOneAlert(title: "Unsupported video formats".localStr(), message: itemProvider.description)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.videoCell?.startLoading()
        self.tableView.isUserInteractionEnabled = false
        
        guard let videoURL = urls.first else { return }
        SandboxFileManager.shared.copyFileToOtherTemp(sourceURL: videoURL) { [weak self] targetURL in
            self?.convertVideoToAudio(targetURL)
        } fail: { [weak self] errorMsg in
            self?.tableView.isUserInteractionEnabled = true
            self?.view.makeToast(errorMsg)
            self?.deleteVideoFile()
        }
    }
    
    // 点击视频
    func clickVideoCell(_ fileURL: URL) {
        
        let alertController = UIAlertController(title: "Original Video".localStr(), message: fileURL.fileSizeString, preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Preview".localStr(), style: .default) { [weak self] (sender) in
            let player = AVPlayer(url: fileURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            playerViewController.entersFullScreenWhenPlaybackBegins = true
            playerViewController.exitsFullScreenWhenPlaybackEnds = true
            self?.present(playerViewController, animated: true)
        }
        
        let action2 = UIAlertAction(title: "Continue to select video".localStr(), style: .destructive) { [weak self] (sender) in
            self?.deleteVideoFile()
        }
        
        let action3: UIAlertAction = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        action3.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        
        self.present(alertController, animated: true, completion: nil)
        
    }
    
    func deleteVideoFile() {
        self.tableView.isUserInteractionEnabled = true
        self.videoCell?.stopLoading()
        self.videoCell?.progress = 0
        
        self.coverImage = nil
        self.videoURL = nil
        self.musicModel = nil
        self.audioOutputURL = nil
        self.tableView.reloadData()
    }
    
    // 处理音乐编辑
    func handleEditMusic(_ actionType: MusicActionType) {
        if actionType == .title {
            self.editSongTitleAction()
        }
        
        if actionType == .artist {
            self.editArtistAction()
        }
        
        if actionType == .album {
            self.editAlbumNameAction()
        }
    }

    // ✍️编辑歌曲名
    private func editSongTitleAction() {
        
        guard let oldModel = self.musicModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.title.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.placeholder = oldModel.showTitleName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            guard let wSelf = self else { return }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            let success = SandboxFileManager.shared.updateTitleTag(oldModel: oldModel, newTitle: nameText)
            self?.musicModel?.title = success ? nameText : oldModel.title
            
            if success {
                self?.view.makeToast("Embedded Success".localStr())
                
                self?.tableView.reloadData()
                
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: wSelf.musicModel, oldFileName: oldModel.filePathName())
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑歌手名
    private func editArtistAction() {
        
        guard let oldModel = self.musicModel else { return }
        
        let editAlertVC = UIAlertController(title: MusicActionType.artist.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.placeholder = oldModel.showArtistName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            guard let wSelf = self else { return }
            
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            let success = SandboxFileManager.shared.updateArtistTag(oldModel: oldModel, newArtist: nameText)
            
            if success {
                self?.musicModel?.artist = nameText
                self?.view.makeToast("Embedded Success".localStr())
                
                self?.tableView.reloadData()
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: wSelf.musicModel, oldFileName: oldModel.filePathName())
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    // ✍️编辑专辑名
    private func editAlbumNameAction() {
        guard let oldModel = self.musicModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.album.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.placeholder = oldModel.album ?? "Unknown Album".localStr()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
                        
            let success = TaglibMetadataParser.setAlbum(nameText, toFileURL: oldModel.mediaPlayURL)
            if success {
                self?.musicModel?.album = nameText
                KakaMusicPlayer.shared.updateOneMusicModel(newModel: self?.musicModel, oldFileName: oldModel.filePathName())
                self?.tableView.reloadData()
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
}

