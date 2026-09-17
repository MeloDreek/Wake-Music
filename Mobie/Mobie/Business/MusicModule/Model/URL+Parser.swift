//
//  URL+Parser.swift
//  Mobie
//
//  Created by 张文 on 10/21/24.
//

import KakaFoundation
import AppGroupKit
import KakaTaglibKit

extension URL {
    
    /// 源文件信息
    public func createMusicModel(handleType: FileHandleType, sourceType: ImportFileType, targetURL: URL, metadata: MetadataTagModel? = nil) -> MusicItemModel {
        
        if self.hasDirectoryPath {
            let folderModel = MusicItemModel(fileURL: self, sourceType: sourceType)
            return folderModel
        }
        
        var newModel = MusicItemModel(fileURL: self, sourceType: sourceType)

        // 歌曲名
        let songName: String? = metadata?.title
                
        // 艺术家名
        let artistName: String? = metadata?.artist
        
        var fullName: String = self.lastPathComponent
        if let songName = songName, !songName.isEmpty, let artistName = artistName, !artistName.isEmpty {
            fullName = artistName + " - " + songName + "." + self.pathExtension
        }
        
        // 检查重名文件并自增
        let baseFileName = fullName.replaceChar(oldChar: "/", newChar: "&")
        var fileName = baseFileName
        var fileCount = 1
        
        if handleType == .copy {
            while FileManager.default.fileExists(atPath: targetURL.appending(path: "\(fileName).\(self.pathExtension)").path(percentEncoded: false)) {
                fileName = "\(baseFileName) (\(fileCount))"
                fileCount += 1
            }
        }
        
        newModel.handleType = handleType
        newModel.title = metadata?.title
        newModel.artist = metadata?.artist
        newModel.album = metadata?.album
        
        if let year = metadata?.year {
            newModel.year = Int(year)
        }
        if let durationSeconds = metadata?.durationSeconds {
            newModel.durationSeconds = Int(durationSeconds)
        }
        if let track = metadata?.track {
            newModel.track = Int(track)
        }
        if let bitrate = metadata?.bitrate {
            newModel.bitrate = Int(bitrate)
        }
        if let sampleRate = metadata?.sampleRate {
            newModel.sampleRate = Int(sampleRate)
        }
        if let channel = metadata?.channel {
            newModel.channel = AudioChannels(channel: Int(channel))
        }
        newModel.genre = metadata?.genre
        newModel.comment = metadata?.comment
        
        newModel.lyricModel = metadata?.lyricModel?.convertSwiftModel()
                
        return newModel
    }
    
    /// 根据文件名称解析歌曲元数据
    public func parseSongInfo() -> (title: String, artist: String?, fileExtension: String) {
        // 获取文件名（不带后缀）
        let fileName = self.lastPathComponent.ocString.deletingPathExtension
        
        // 获取文件后缀
        let fileExtension = self.pathExtension
        
        // 使用正则表达式匹配“歌手名 - 歌名”格式
        let pattern = #"^(.*?)\s*-\s*(.*?)\s*$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = fileName as NSString
        let results = regex?.matches(in: fileName, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // 初始化 artist 和 album 为 nil，title 默认为文件名
        var artist: String? = nil
        var title: String = fileName
        
        // 如果有匹配结果，提取歌手名、歌名和专辑名
        if let match = results?.first {
            let artistRange = match.range(at: 1)
            let titleRange = match.range(at: 2)
            
            if artistRange.location != NSNotFound {
                artist = nsString.substring(with: artistRange).trimmingCharacters(in: .whitespaces)
            }
            if titleRange.location != NSNotFound {
                title = nsString.substring(with: titleRange).trimmingCharacters(in: .whitespaces)
            }
            
        }

        return (title, artist, fileExtension)
    }
    
    // 读取LRC内容
    func readLRCContentStr() -> String? {
        let encodings: [String.Encoding] = [.utf8, .init(rawValue: CFStringConvertEncodingToNSStringEncoding(0x80000632))] // GBK 编码

        var content: String?
        
        for encoding in encodings {
            if let data = try? Data(contentsOf: self, options: .mappedIfSafe),
               let fileStr = String(data: data, encoding: encoding) {
                content = fileStr
                break // 找到合适的编码后退出循环
            }
        }
        
        return content
    }
}

extension LyricLineModel {
    func convertSwiftModel() -> LyricInfoModel {
        var model = LyricInfoModel()
        model.title = self.title
        model.artist = self.artist
        model.album = self.album
        model.creater = self.creater
        model.isNoneTime = self.isNoneTime
        model.totalTime = self.totalTime
        model.offset = Int(self.offset)
        let tempArr = self.lyrics?.compactMap({
            return LyricModel(startTimestamp: $0.startTimestamp, endTimestamp: $0.endTimestamp, fullLyric: $0.fullLyric, realLyric: $0.realLyric, translatLyric: $0.translatLyric)
        })
        model.lyrics = tempArr?.sorted(by: { model1, model2 in
            return (model1.startTimestamp ?? 0) < (model2.startTimestamp ?? 0)
        })
        return model
    }
}
