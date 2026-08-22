//
//  PlayBackgroundListController+Upload.swift
//  Mobie
//
//  Created by 张文 on 5/21/25.
//

import KakaFoundation
import AppGroupKit
import PhotosUI
import ZLImageEditor

extension PlayBackgroundListController: PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
    
    @objc func uploadCustomBackground() {
        
        if kaka_IsMacOS() {
            let imageArray: [UTType] = [.png, .jpeg, .tiff, .rawImage]
            
            let documentVC = UIDocumentPickerViewController(forOpeningContentTypes: imageArray, asCopy: false)
            documentVC.allowsMultipleSelection = false
            documentVC.delegate = self
            documentVC.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            documentVC.shouldShowFileExtensions = true
            self.present(documentVC, animated: true)
        }else{
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        var config = PHPickerConfiguration()
                        config.filter = .images
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
        picker.dismiss(animated: true)
        
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        guard let itemProvider = results.first?.itemProvider else { return }
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
                
        itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { object, error in
            guard let image = object as? UIImage else { return }
            
            DispatchQueue.main.async { [weak self] () in
                if kaka_IsMacOS() {
                    self?.saveNewBackgroundImage(image)
                    return
                }
                
                ZLImageEditorConfiguration.default()
                    .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                    .adjustTools([.brightness, .contrast, .saturation])
                    .clipRatios(kaka_IsMacOS() ? [.wh16x9] : [.wh9x16])
                    .showClipDirectlyIfOnlyHasClipTool(true)
                
                ZLEditImageViewController.showEditImageVC(parentVC: self, image: image) { [weak self] newImage, model in
                    self?.saveNewBackgroundImage(newImage)
                }
            }
            
        })
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.tableView.isUserInteractionEnabled = false
        
        guard let imageURL = urls.first else { return }
        
        guard let image = UIImage(contentsOfFile: imageURL.path) else { return }
        
        self.saveNewBackgroundImage(image)
    }
    
    func saveNewBackgroundImage(_ image: UIImage) {
        
        guard UserInfoManager.shared.isVIP() else {
            self.vipCenterClick()
            return
        }
        
        guard let imageData = image.pngData() else { return }
        let fileName = Date().convertString() + ".png"
        let targetFileURL = SandboxFileManager.shared.customPlayerbackURL().appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: targetFileURL, options: .atomic)
            self.refreshDataAction()
        } catch {
            self.view.makeToast(error.localizedDescription)
        }
        
    }
    
}
