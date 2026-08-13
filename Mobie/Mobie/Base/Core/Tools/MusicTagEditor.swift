//
//  MusicTagEditor.swift
//  Waketag
//
//  Created by Melo on 11/22/24.
//
import KakaFoundation
import KakaUIKit
import AVFoundation
import AppGroupKit
import Alamofire



class MusicTagEditor {
    
    static let shared = MusicTagEditor()
    
    static let maxImageCount = 3

}




extension MusicTagEditor {
    
    
    // 1️⃣使用iTunes查询
    func requestITunesAlbumImages(title: String, artist: String, completion: @escaping (Result<[MusicReleaseModel], KakaError>) -> Void) {
        let keyword = "\(artist) \(title)"
        let urlStr = "https://itunes.apple.com/search?term=\(keyword)&entity=song&limit=\(Self.maxImageCount)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        debugPrint("iTunes接口 = \(urlStr)")
        
        APIManager.shared.GET(requestURL: urlStr, parameters: [:]) { data in
            guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = dict["results"] as? [[String: Any]], results.count > 0 else {
                self.requestAccurateAlbumImages(title: title, artist: artist, completion: completion)
                return
            }
            
            guard let itunesArray = [ITunesSongModel].deserialize(from: results), itunesArray.count > 0 else {
                self.requestAccurateAlbumImages(title: title, artist: artist, completion: completion)
                return
            }
            
            let modelArray = itunesArray.map {
                let model = MusicReleaseModel(title: $0.trackName, date: $0.releaseDate, country: $0.country, length: nil, branzImages: nil, itunesModel: $0)
                return model
            }
            
            let sortArray = Array(Set(modelArray)) // 去重
            completion(.success(sortArray))
            
        } fail: { error in
            self.requestAccurateAlbumImages(title: title, artist: artist, completion: completion)
        }
    }
    
    // 2️⃣获取精准的专辑艺术图
    private func requestAccurateAlbumImages(title: String, artist: String, completion: @escaping (Result<[MusicReleaseModel], KakaError>) -> Void) {
        
        let query = "recording:\(title) AND artist:\(artist)"
        let urlStr = "https://musicbrainz.org/ws/2/recording/?query=\(query)&fmt=json&limit=3&inc=releases".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        debugPrint("请求录音ID = \(urlStr)")

        APIManager.shared.GET(requestURL: urlStr, parameters: [:]) { data in
            guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let recordings = dict["recordings"] as? [[String: Any]], recordings.count > 0 else {
                self.requestArtistImage(title: title, artist: artist, completion: completion)
                return
            }

            let uniqueReleases = self.extractUniqueReleases(from: recordings)

            guard !uniqueReleases.isEmpty else {
                self.requestArtistImage(title: title, artist: artist, completion: completion)
                return
            }
            
            // 再查封面图
            self.requestCoverImage(releases: uniqueReleases, completion: completion)

        } fail: { error in
            self.requestArtistImage(title: title, artist: artist, completion: completion)
        }
    }
    
    // 提取 release 并去重、截前3个
    private func extractUniqueReleases(from recordings: [[String: Any]]) -> [MusicReleaseModel] {
        var allReleases: [MusicReleaseModel] = []
        var idSet: Set<String> = []

        for recording in recordings {
            guard let releases = recording["releases"] as? [[String: Any]],
                  let releaseModels = [MusicReleaseModel].deserialize(from: releases) else { continue }

            for model in releaseModels {
                guard !idSet.contains(model.id) else { continue }
                idSet.insert(model.id)
                allReleases.append(model)
                if allReleases.count >= Self.maxImageCount { break }
            }

            if allReleases.count >= Self.maxImageCount { break }
        }

        return allReleases
    }
    
    /// 3️⃣获取艺术家的封面（不准确，但数据多）
    func requestArtistImage(title: String, artist: String, completion: @escaping (Result<[MusicReleaseModel], KakaError>) -> Void) {
        
        let urlStr = "https://musicbrainz.org/ws/2/release/?query=artist:\(artist)AND\(title)&fmt=json"
        
        debugPrint("🔗请求艺术家地址 = \(urlStr)")
        
        APIManager.shared.GET(requestURL: urlStr, parameters: [:]) { data in
            let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
            let releases = dict?["releases"] as? [[String: Any]]
            guard var models = [MusicReleaseModel].deserialize(from: releases), models.count > 0 else {
                completion(.failure(.emptyData))
                return
            }
            
            models = models.count >= Self.maxImageCount ? Array(models.prefix(Self.maxImageCount)) : models
            self.requestCoverImage(releases: models, completion: completion)
        } fail: { error in
            completion(.failure(KakaError.custom(error.errorDescription)))
        }

    }
    
    // 加载封面图
    private func requestCoverImage(releases: [MusicReleaseModel], completion: @escaping (Result<[MusicReleaseModel], KakaError>) -> Void) {
        
        var resultArray = [MusicReleaseModel]()
        
        let fetchDataGroup = DispatchGroup()
        
        for index in 0..<releases.count {
            fetchDataGroup.enter()
            var subModel = releases[index]
            let urlStr = "https://coverartarchive.org/release/\(subModel.id)"
            
            debugPrint("🔗请求图片地址 = \(urlStr)")
            APIManager.shared.GET(requestURL: urlStr, parameters: [:]) { data in
                                
                let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
                let images = dict?["images"] as? [[String: Any]]
                guard let imagesModels = [MusicReleaseImage].deserialize(from: images), imagesModels.count > 0 else {
                    fetchDataGroup.leave()
                    return
                }
                
                subModel.branzImages = imagesModels.first
                resultArray.append(subModel)
                fetchDataGroup.leave()
                
            } fail: { error in
                fetchDataGroup.leave()
            }
        }
        
        fetchDataGroup.notify(queue: .main) {
            if resultArray.count > 0 {
                let sortArray = Array(Set(resultArray)) // 去重
                completion(.success(sortArray))
            }else{
                completion(.failure(.emptyData))
            }
        }

    }
    
    
}

// 上传歌词
extension MusicTagEditor {
    
    // 处理歌词的上传
    public func publishNewLyric(musicModel: MusicItemModel, lyricModel: LyricInfoModel) {
        
        self.requestChallenge { result in
            switch result {
            case .success(let lrcToken):
                self.publishLyric(token: lrcToken, musicModel: musicModel, lyricModel: lyricModel)
            case .failure(let error):
                debugPrint("error = \(error.localizedDescription)")
            }
        }
                
    }
    
    // 上传歌词
    private func publishLyric(token: LRCLyricTokenModel, musicModel: MusicItemModel, lyricModel: LyricInfoModel) {
        let urlStr = "https://lrclib.net/api/publish"
        let header: HTTPHeaders = HTTPHeaders([HTTPHeader(name: "X-Publish-Token", value: token.tokenStr())])
        
        let parameters: Parameters = ["trackName": musicModel.title ?? "",
                                      "artistName": musicModel.artist ?? "",
                                      "albumName": musicModel.album ?? "",
                                      "duration": musicModel.durationSeconds,
                                      "plainLyrics": lyricModel.toLyricString(false),
                                      "syncedLyrics": lyricModel.toLyricString(false)]
        
        
        APIManager.shared.POST(requestURL: urlStr, parameters: parameters, header: header) { data in
            let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
            
            debugPrint("🎸上传歌词 = \(dict ?? [:])")
            

        } fail: { error in
            debugPrint("🎸上传歌词 = \(error.localizedDescription)")
        }
    }
    
    // 获取Token
    private func requestChallenge(completion: @escaping (Result<LRCLyricTokenModel, KakaError>) -> Void) {
        
        guard let lyricToken = AppLocalManager.shared.lyricToken, !lyricToken.isBeyond5Minites() else {
            
            let urlStr = "https://lrclib.net/api/request-challenge"
            let parameters: Parameters = [:]
            
            APIManager.shared.GET(requestURL: urlStr, parameters: parameters) { data in
                let dict = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any]
                
                debugPrint("🎸歌词Token = \(dict ?? [:])")
                guard let model = LRCLyricTokenModel.deserialize(from: dict) else {
                    completion(.failure(.emptyData))
                    return
                }
                
                AppLocalManager.shared.lyricToken = model
                completion(.success(model))

            } fail: { error in
                debugPrint("获取Token失败 = \(error.localizedDescription)")
                completion(.failure(KakaError.custom(error.errorDescription)))
            }
            
            return
        }
        
        completion(.success(lyricToken))
    }
    
    
}

extension MusicTagEditor {
    // 生成和创建视频转音乐的临时路径
    func videoToAudioURL(_ audioType: AudioFormatEnum) -> URL? {
        
        // 创建输出文件路径
        var targetStr = SandboxType_OtherTemp
        
        if !FileManager.default.fileExists(atPath: targetStr) {
            try? FileManager.default.createDirectory(atPath: targetStr, withIntermediateDirectories: true, attributes: nil)
        }
        
        targetStr = targetStr.appending("/\(Date.uniqueNanosecondTimestamp()).\(audioType.suffixName())")

        var audioOutputURL: URL
        if #available(iOS 16.0, *) {
            audioOutputURL = URL(filePath: targetStr, directoryHint: .notDirectory, relativeTo: nil)
        } else {
            audioOutputURL = URL(fileURLWithPath: targetStr, isDirectory: false)
        }
        
        // 如果文件已经存在，删除它
        if FileManager.default.fileExists(atPath: audioOutputURL.path) {
            try? FileManager.default.removeItem(at: audioOutputURL)
        }
        
        return audioOutputURL
        
    }
    
}

/*
 0、根据名称获取录音中的MBID：https://musicbrainz.org/ws/2/recording/?query=七里香&fmt=json&limit=3&inc=releases
 1、根据艺术家名称获取MBID: https://musicbrainz.org/ws/2/release/?query=artist:周杰伦AND七里香&fmt=json
 2、根据MBID再获取专辑封面：https://coverartarchive.org/release/bf546753-256b-43cb-9310-e78d5b341075
 */


/*
 0、根据名称获取录音中的MBID：https://musicbrainz.org/ws/2/recording/?query=七里香&fmt=json&limit=3&inc=releases
 1、根据艺术家名称获取MBID: https://musicbrainz.org/ws/2/release/?query=artist:周杰伦AND七里香&fmt=json
 2、根据MBID再获取专辑封面：https://coverartarchive.org/release/bf546753-256b-43cb-9310-e78d5b341075
 */

