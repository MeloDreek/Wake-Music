//
//  DocumentFolderWatcher.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import Foundation

@MainActor
protocol DocumentFolderWatcherDelegate: AnyObject {
    
    // 新增了文件
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL])
    
    // 删除了文件
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL])
}

class DocumentFolderWatcher {
    
    init(_ fileURL: URL) {
        self.fileURL = fileURL
        self.previousFiles = Set()
    }
    
    private var fileURL: URL
    private var folderDescriptor: Int32 = -1
    private var folderSource: DispatchSourceFileSystemObject?
    private var previousFiles: Set<String>

    weak var delegate:DocumentFolderWatcherDelegate?

    /// 开始监听
    func startWatching() {
        let folderPath = self.fileURL.path

        folderDescriptor = open(folderPath, O_EVTONLY)
        guard folderDescriptor >= 0 else {
            debugPrint("无法打开文件夹路径: \(folderPath)")
            return
        }

        folderSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: folderDescriptor, eventMask: .write, queue: DispatchQueue.global())
        
        folderSource?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.folderDidChange()
            }
        }

        folderSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.folderDescriptor)
            self.folderDescriptor = -1
        }

        folderSource?.resume()
        
        // 初始化当前文件列表
        self.previousFiles = self.currentFiles()
    }

    /// 停止监听
    func stopWatching() {
        folderSource?.cancel()
        folderSource = nil
    }

    /// 文件夹变化处理
    @MainActor private func folderDidChange() {
        
        // 获取当前文件列表
        let currentFiles = currentFiles()
        
        // 找出新增的文件
        let newFiles = currentFiles.subtracting(previousFiles)
        
        // 找出被删除的文件
        let deletedFiles = previousFiles.subtracting(currentFiles)
        
        // 更新之前的文件列表
        previousFiles = currentFiles
        
        if newFiles.count > 0 {
            let newFileURLs = newFiles.map { URL(fileURLWithPath: $0) }
            self.delegate?.documentFolderWatcherDidAddFiles(watcher: self, addFiles: newFileURLs)
        }
        
        if deletedFiles.count > 0 {
            let deletedFileURLs = deletedFiles.map { URL(fileURLWithPath: $0) }
            self.delegate?.documentFolderWatcherDidDeleteFiles(watcher: self, deleteFiles: deletedFileURLs)
        }
    }
    
    /// 获取当前文件列表
    private func currentFiles() -> Set<String> {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return Set(fileURLs.map { $0.path })
        } catch {
            debugPrint("无法获取文件夹内容: \(error.localizedDescription)")
            return Set()
        }
    }
}
