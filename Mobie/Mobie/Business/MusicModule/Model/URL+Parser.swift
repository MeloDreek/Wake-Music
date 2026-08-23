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
        let songInfo = self.parseSongInfo()

        // 歌曲名
        var songName: String = ((metadata?.title?.count ?? 0) > 0) ? (metadata?.title ?? Date().convertString()) : (songInfo.title)
        if songName.contains("." + songInfo.fileExtension) {
            songName = songName.replaceChar(oldChar: "." + songInfo.fileExtension, newChar: "")
        }
        songName = songName.standardFileName
        
        // 艺术家名
        var artistName: String = ((metadata?.artist?.count ?? 0) > 0) ? (metadata?.artist ?? "Unknown Artist".localStr()) : (songInfo.artist ?? "")
        
        artistName = artistName.standardFileName
        
        // 检查重名文件并自增
        let baseFileName = "\(artistName) - \(songName)".replaceChar(oldChar: ".", newChar: "")
        var fileName = baseFileName
        var fileCount = 1
        
        if handleType == .copy {
            if #available(iOS 16.0, *) {
                while FileManager.default.fileExists(atPath: targetURL.appending(path: "\(fileName).\(self.pathExtension)").path(percentEncoded: false)) {
                    fileName = "\(baseFileName) (\(fileCount))"
                    fileCount += 1
                }
            } else {
                while FileManager.default.fileExists(atPath: targetURL.appendingPathComponent("\(fileName).\(self.pathExtension)").path) {
                    fileName = "\(baseFileName) (\(fileCount))"
                    fileCount += 1
                }
            }
        }
        
        var albumName: String = ((metadata?.album?.count ?? 0) > 0) ? (metadata?.album ?? "Unknown Album".localStr()) : "Unknown Album".localStr()
        albumName = albumName.standardFileName
        
        newModel.handleType = handleType
        newModel.title = songName
        newModel.artist = artistName
        newModel.album = albumName
        
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
