//
//  WebDavFileObject+Extension.swift
//  Mobie
//
//  Created by 张文 on 12/31/24.
//

import FilesProvider
import AppGroupKit

extension WebDavFileObject {
    
    /// 文件类型
    func fileType() -> ConnectFileType {
        if self.isDirectory {
            return .folder
        }else if self.url.isSupportMusicFile(false) {
            return .music
        }else{
            return .other
        }
    }
    
    // 第一个文字
    func firstChar(_ sortType: SortedbyType) -> String {
        let title: String = self.name
        
        let collator =  UILocalizedIndexedCollation.current()
        let titleIndex = collator.section(for: title, collationStringSelector: #selector(NSObject.description))
        
        // sectionTitles = [A-Z+#]
        let firstChar = collator.sectionTitles[titleIndex]
        
        return firstChar
    }
    
    // 文件占位图
    func placeImage() -> UIImage? {
        switch self.fileType() {
        case .folder:
            return UIImage(named: "folder_icon")
        case .music:
            let fileExtension = self.url.pathExtension.lowercased()
            if self.url.isLRCFile() {
                return UIImage(named: "lyric_place")
            }else{
                return UIImage(named: "\(fileExtension)_icon") ?? UIImage(named: "music_place")
            }
        case .other:
            let isVideo = AudioExtension.videoSuffixs.contains(self.url.pathExtension.lowercased())
            return isVideo ? UIImage(named: "video_place") : UIImage(named: "file_place")
        }
    }
    
    /// 是否选中
    public var isSelected: Bool {
        get {
            guard let cachedValue = objc_getAssociatedObject(self, &WebDavFileKeys.kSelectKey) as? NSNumber else {
                return false
            }
            
            return cachedValue.boolValue
        }
        set {
            let newValue = NSNumber(value: newValue)
            objc_setAssociatedObject(self, &WebDavFileKeys.kSelectKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private struct WebDavFileKeys {
        static var kSelectKey: Void?
    }
    
}

extension WebDavFileObject {
    
    /// 转为本地的模型
    func convertFileModel(server: WebdavUserModel) -> WebdavFileModel {
        let fileModel = WebdavFileModel(webdavUser: server, fileName: self.name, filePath: self.path, mediaPlayURL: self.url, fileSize: self.size, childrensCount: self.childrensCount, fileExtension: self.url.pathExtension, isDirectory: self.isDirectory, creationDate: self.creationDate?.timeIntervalSince1970, modifiedDate: self.modifiedDate?.timeIntervalSince1970, isHidden: self.isHidden, isReadOnly: self.isReadOnly)        
        return fileModel
    }
    
}
