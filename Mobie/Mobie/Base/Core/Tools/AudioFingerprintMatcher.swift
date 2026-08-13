//
//  AudioFingerprintMatcher.swift
//  Waketag
//
//  Created by kaka on 2026/5/20.
//

import KakaFoundation
import AppGroupKit
import AVFoundation
import ShazamKit
import Alamofire

/// 音频指纹识别器
class AudioFingerprintMatcher: NSObject, SHSessionDelegate {
    
    private lazy var session: SHSession = {
        return SHSession()
    }()
    
    private var isLyrics: Bool = true
    
    private var model: MusicItemModel?
    
    // 一般错误
    private let normalError = "Audio fingerprint successfully generated, but no match was found in the global cloud database. This is usually due to unique acoustic waveform variations. Please edit manually.".localStr()
    
    // 格式问题
    private let formatError = "This specific audio format is not supported for fingerprinting. We highly recommend using modern popular formats such as FLAC, M4A, WAV, or MP3. Please edit manually.".localStr()

    // 关键改动：使用字典通过“指纹的 ID”作为 key 来管理多个并发的回调，防止批量识别时闭包被覆盖
    private var completions: [String: (Result<AudioFingerprintModel, KakaError>) -> Void] = [:]
    
    override init() {
        super.init()

        self.session.delegate = self
    }
    
    // MARK: - 麦克风识曲专用私有属性
    private let audioEngine = AVAudioEngine()
    private var signatureGeneratorForMic: SHSignatureGenerator?
    private let micSignatureKey = "KAKA_MIC_RECOGNITION_KEY" // 独家固定的 Key，用于从 completions 中存取麦克风的回调


    
    /// 传入本地音频模型的 URL 进行音频指纹识别，回调返回 元数据模型
    /// - Parameters:
    ///   - model: 音频模型
    ///   - isRequestLyrics: 是否请求歌词，不请求则快很多
    ///   - completion: 回调的元数据
    func matchLocalAudio(model: MusicItemModel, isRequestLyrics: Bool = true, completion: @escaping (Result<AudioFingerprintModel, KakaError>) -> Void) {
        
        self.model = model
        self.isLyrics = isRequestLyrics
        
        // 0. 特殊处理：拦截 DSD 等非 PCM 编码的超级发烧级音频格式
        // 因为这类文件的后缀和底层编码 AVAudioFile 无法直接处理，提前拦截能给予用户最精准的引导
        let pathExtension = model.mediaPlayURL.pathExtension.lowercased()
        if pathExtension == "dsf" || pathExtension == "dff" || pathExtension == "ape" {
            completion(.failure(.custom(self.formatError)))
            return
        }
        
        // 1. 读取音频文件
        guard let audioFile = try? AVAudioFile(forReading: model.mediaPlayURL) else {
            debugPrint("无法读取音频文件")
            // 细化读文件失败的提示：可能是权限、文件损坏，或者系统不支持该格式
            completion(.failure(.custom(self.formatError)))
            return
        }
        
        // 2. 配置 ShazamKit 标准格式
        guard let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            completion(.failure(.custom(self.formatError)))
            return
        }
        
        // 3. 初始化指纹生成器与 Converter
        let signatureGenerator = SHSignatureGenerator()
        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: targetFormat) else {
            // 如果 Converter 初始化失败，多半是因为源音频编码太特殊（如非标准多声道或极高位深）
            completion(.failure(.custom("Unsupported audio encoding channel or sample rate. Please edit it manually.".localStr())))
            return
        }
        
        // 4. 读取与转码
        let bufferSize = 44100 * 12
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(bufferSize)),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(bufferSize)) else {
            completion(.failure(.custom("System memory is insufficient to process this audio file. This is usually due to temporary high system overhead. Please edit it manually.".localStr())))
            return
        }
        
        do {
            try audioFile.read(into: inputBuffer, frameCount: AVAudioFrameCount(bufferSize))
            
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { inNumPackages, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }
            
            if status == .haveData && error == nil {
                let time = AVAudioTime(sampleTime: 0, atRate: targetFormat.sampleRate)
                try signatureGenerator.append(outputBuffer, at: time)
            } else {
                debugPrint("音频格式转换失败: \(String(describing: error))")
                completion(.failure(.custom("Audio format conversion failed. The media container could not be processed. Please edit it manually.".localStr())))
                return
            }
        } catch {
            debugPrint("读取或转换时出错: \(error)")
            // 兜底捕获异常，比如不可预测的硬件解密失败
            completion(.failure(.custom("\(error.localizedDescription) ❌")))
            return
        }
        
        // 5. 生成指纹
        let signature = signatureGenerator.signature()
        
        // 将 signature 的底层数据转为 Base64 字符串作为唯一 Key
        let signatureKey = signature.dataRepresentation.base64EncodedString()
        self.completions[signatureKey] = completion
        
        // 提交匹配
        self.session.match(signature)
    }
    
    // MARK: - SHSessionDelegate 代理回调
    // 识别成功
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async {
            let signature = match.querySignature
            let signatureKey = signature.dataRepresentation.base64EncodedString()
            guard let completion = self.completions[signatureKey] else {
                debugPrint("⚠️ 严重警告：成功回调了，但字典里找不到对应的 Key！")
                return
            }
            
            self.completions.removeValue(forKey: signatureKey)
            
            guard let firstTrack = match.mediaItems.first else {
                completion(.failure(.unknowError))
                return
            }
            
            let audioModel = firstTrack.convertAudioModel()
            if self.isLyrics {
                
                self.fetchLRCLyricArray(audioModel: audioModel, model: self.model) { result in
                    switch result {
                    case .success(let lyrics):
                        var newModel = audioModel
                        newModel.lyrics = lyrics
                        completion(.success(newModel))
                        break
                    case .failure(_):
                        completion(.success(audioModel))
                        break
                    }
                }
//                self.requestFingerLRCLyricLib(audioModel: audioModel) { result in
//                    switch result {
//                    case .success(let newModel):
//                        completion(.success(newModel))
//                        break
//                    case .failure(_):
//                        completion(.success(audioModel))
//                        break
//                    }
//                }
            }else{
                completion(.success(audioModel))
            }
        }
    }
    
    // 没找到匹配，或者识别失败
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            let signatureKey = signature.dataRepresentation.base64EncodedString()
            guard let completion = self.completions[signatureKey] else {
                debugPrint("⚠️ 严重警告：失败回调了，但字典里找不到对应的 Key！")
                return
            }
            
            self.completions.removeValue(forKey: signatureKey)
            
            debugPrint("未找到匹配或发生错误: \(String(describing: error))")
            
            if let shazamError = error as? SHError {
                // 更加详尽的 SHError 枚举映射
                switch shazamError.code {
                    // 100: 音频格式不被系统识别（如一些非标准编码）
                case .invalidAudioFormat:
                    completion(.failure(.custom(self.formatError)))
                    break
                    // 101: 音频不连续，可能中间有严重损坏、静音块或者文件断层
                case .audioDiscontinuity:
                    completion(.failure(.custom("Audio stream interruption detected. The file may be corrupted or incomplete. Please edit it manually.".localStr())))
                    break
                    // 200: 无法从音频生成指纹。最常见的原因是音频文件前十几秒全是静音（没有声音特征）
                case .signatureInvalid:
                    completion(.failure(.custom("Failed to generate a valid acoustic signature. Please check if the audio file is muted or completely silent. Please edit it manually.".localStr())))
                    break
                    // 201: 生成的指纹时间长度不符合规范（太短或超限）
                case .signatureDurationInvalid:
                    completion(.failure(.custom("Audio sample is too short or invalid for fingerprinting. The duration is insufficient for acoustic analysis. Please edit it manually.".localStr())))
                    break
                    // 202: 极其高频！Shazam 官方曲库里确实没有这首歌的指纹记录
                case .matchAttemptFailed:
                    completion(.failure(.custom(self.normalError)))
                    break
                    // 300: 自定义曲库格式错误（App 内未使用自定义曲库时一般不触发）
                case .customCatalogInvalid:
                    completion(.failure(.custom("The custom music catalog container is invalid or corrupted. Acoustic signatures cannot be indexed. Please edit it manually.".localStr())))
                    break
                    // 301: 自定义曲库的 URL 格式非法
                case .customCatalogInvalidURL:
                    completion(.failure(.custom("The URL for the custom music catalog is invalid.".localStr())))
                    break
                    // 400: 同步到用户的 Shazam 音乐同步库时失败
                case .mediaLibrarySyncFailed:
                    completion(.failure(.custom(self.normalError)))
                    break
                    // 500: 框架内部通用未知错误
                case .internalError:
                    completion(.failure(.custom(self.normalError)))
                    break
                    // 600: 获取一首或多首歌曲的详细媒体信息失败
                case .mediaItemFetchFailed:
                    completion(.failure(.custom(self.normalError)))
                    break
                @unknown default:
                    completion(.failure(.custom(self.normalError)))
                    break
                }
            } else {
                // 其它未知错误
                debugPrint("❌音频指纹检索失败：\(error?.localizedDescription ?? "")")
                completion(.failure(.custom(self.normalError)))
            }
        }
        
    }
    
}

extension AudioFingerprintMatcher {
    /// 5.1 启动麦克风“听歌识曲”
    /// - Parameters:
    ///   - timeout: 自动截止识别的超时时间（秒），默认 12 秒已足够 Shazam 识别
    func startTunnelingMicrophone(timeout: TimeInterval = 12.0, completion: @escaping (Result<AudioFingerprintModel, KakaError>) -> Void) {
        // 1. 如果当前引擎正在运行，先重置
        if audioEngine.isRunning {
            self.stopTunnelingMicrophone()
        }
        
        // 2. 检查并请求麦克风权限（iOS 系统的硬性要求）
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if permissionStatus == .denied || permissionStatus == .restricted {
            completion(.failure(.custom("Microphone permission denied. Please enable it in Settings to use Live Recognition.".localStr())))
            return
        }
        
        // 3. 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(.failure(.custom("Failed to initialize system audio hardware interface.".localStr())))
            return
        }
        
        // 4. 初始化全新的指纹生成器，并将回调安全寄存
        self.signatureGeneratorForMic = SHSignatureGenerator()
        self.completions[micSignatureKey] = completion
        
        // 5. 配置 AVAudioEngine 的 Input Node
        let inputNode = audioEngine.inputNode
        let bus = 0
        let inputFormat = inputNode.inputFormat(forBus: bus)
        
        // 确保输入格式合法，防止个别蓝牙耳机导致硬件采样率为 0
        guard inputFormat.sampleRate > 0 else {
            completion(.failure(.custom("Invalid audio input hardware sample rate.".localStr())))
            return
        }
        
        // 6. 安装音频 Tap 实时捞取麦克风 Buffer 并塞入指纹生成器
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            do {
                try self.signatureGeneratorForMic?.append(buffer, at: time)
            } catch {
                debugPrint("麦克风 Buffer 写入指纹生成器失败: \(error)")
            }
        }
        
        // 7. 启动音频引擎
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: bus)
            completion(.failure(.custom("Failed to start audio engine compiler for recording.".localStr())))
            return
        }
        
        // 8. 设定一个定时器，到了超时时间如果用户没手动停止，自动触发识别
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self else { return }
            if self.audioEngine.isRunning {
                debugPrint("⏰ 麦克风录音达到上限（\(timeout)秒），开始自动提交检索...")
                self.stopTunnelingMicrophone(shouldMatch: true)
            }
        }
    }
    
    /// 5.2 停止麦克风录音
    /// - Parameter shouldMatch: 是否在停止时提交给服务器匹配。如果用户手动点了“取消”，传入 false 即可
    func stopTunnelingMicrophone(shouldMatch: Bool = true) {
        guard audioEngine.isRunning else { return }
        
        // 1. 关停引擎并卸载 Tap
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        // 恢复系统的底层音频环境（非强制，视你的 App 是否有后台播放需求而定）
        _ = try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        guard shouldMatch, let generator = signatureGeneratorForMic else {
            // 如果不需要匹配（比如用户中途点了取消），彻底清理
            self.completions.removeValue(forKey: micSignatureKey)
            self.signatureGeneratorForMic = nil
            return
        }
        
        // 2. 生成指纹
        let signature = generator.signature()
        self.signatureGeneratorForMic = nil
        
        // 3. 【高能注意】：因为麦克风流生成的 signatureKey 是随机的，为了让 Delegate 能够无缝兼容，
        // 我们在提交 match 之前，把之前用固定的 micSignatureKey 存的回调，转移到真实的 signatureKey 字典中
        let realSignatureKey = signature.dataRepresentation.base64EncodedString()
        if let micCompletion = self.completions[micSignatureKey] {
            self.completions[realSignatureKey] = micCompletion
            self.completions.removeValue(forKey: micSignatureKey) // 功成身退，清除老 Key
        }
        
        // 4. 提交给官方云端库匹配
        self.session.match(signature)
    }
}

extension AudioFingerprintMatcher {
    
    /// 统一处理歌词搜索
    /// - Parameters:
    ///   - audioModel: 优先指纹信息
    ///   - model: 内嵌信息
    ///   - completion: 去重排序后的歌词数组回调
    func fetchLRCLyricArray(audioModel: AudioFingerprintModel, model: MusicItemModel?, completion: @escaping (Result<[LyricInfoModel], KakaError>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var tempArray = [LRCLibLyricModel]()
        
        // 1️⃣ 优先根据指纹信息搜索
        dispatchGroup.enter()
        self.requestFingerLRCLyricLib(audioModel: audioModel) { result in
            switch result {
            case .success(let lyrics):
                tempArray.append(contentsOf: lyrics)
                break
            case .failure(_):
                break
            }
            dispatchGroup.leave()
        }
        
        // 2️⃣ 其次根据内嵌的信息搜索
        if (model?.title != audioModel.title) || (model?.artist != audioModel.artist) {
            dispatchGroup.enter()
            self.requestEmbedLRCLyricLib(model: model) { result in
                switch result {
                case .success(let lyrics):
                    tempArray.append(contentsOf: lyrics)
                    break
                case .failure(_):
                    break
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            
            guard tempArray.count > 0 else {
                completion(.failure(.emptyData))
                return
            }
            
            // 1. 采用高效率的去重方式（保留原厂顺序，不使用无序的 Set）
            var uniqueLyrics: [LRCLibLyricModel] = [] // 假设这是你的歌词模型类型
            var seenIds = Set<String>()
            for lyric in tempArray {
                // 假设用歌词的 ID 或者标志作为唯一键，如果没有，可以拼个 String: "\(lyric.title ?? "")-\(lyric.artist ?? "")"
                let uniqueKey = "\(lyric.name)-\(lyric.artistName)-\(lyric.syncedLyrics?.count ?? 0)"
                if !seenIds.contains(uniqueKey) {
                    seenIds.insert(uniqueKey)
                    uniqueLyrics.append(lyric)
                }
            }

            // 2. 智能化权重积分排序
            let sortArray = uniqueLyrics.enumerated().sorted { (item1, item2) -> Bool in
                let index1 = item1.offset
                let index2 = item2.offset
                let model1 = item1.element
                let model2 = item2.element
                
                // 计算 model1 和 model2 的匹配得分
                let score1 = self.calculateMatchScore(model: model1, target: audioModel)
                let score2 = self.calculateMatchScore(model: model2, target: audioModel)
                
                if score1 != score2 {
                    return score1 > score2 // 分数高的排前面
                }
                
                // 💡 降级兜底：如果分数一模一样，严格保留 LRCLIB 接口返回的原厂先后顺序（热度高者居前）
                return index1 < index2
            }.map { $0.element }
            
            let lyricArray = sortArray.compactMap({ $0.convertLyricModel() })
            completion(.success(lyricArray))
        }
    }
    
    /// 使用内嵌的信息搜索歌词
    func requestEmbedLRCLyricLib(model: MusicItemModel?, completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        guard let model = model else {
            completion(.failure(.unknowError))
            return
        }
        
        let getUrl = "https://lrclib.net/api/get"
        let getParameters: Parameters = [
            "track_name": model.title ?? "",
            "artist_name": model.artist ?? "",
            "album_name": model.album ?? "",
            "duration": model.durationSeconds
        ]
        
        AF.request(getUrl, method: .get, parameters: getParameters).responseData { response in
            
            switch response.result {
            case .success(let data):
                let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                
                // 检查是否是 LRCLIB 标准的 404 Track not found
                if let statusCode = dict?["statusCode"] as? Int, statusCode == 404 {
                    completion(.failure(.unknowError))
                    return
                }
                
                // 正常解析精准匹配到的歌词
                guard let lyricModel = LRCLibLyricModel.deserialize(from: dict) else {
                    completion(.failure(.unknowError))
                    return
                }
                
                debugPrint("✅ 内嵌标题搜索 - 精准匹配(get)成功获取歌词！")
                completion(.success([lyricModel]))
                break
            case .failure(let afError):
                // 如果是网络彻底断开或超时，直接报网络错误，没必要再走搜索了
                let errorMsg = afError.errorDescription ?? afError.localizedDescription
                debugPrint("精准匹配时发生系统级网络错误❌: \(errorMsg)")
                completion(.failure(KakaError.custom(errorMsg)))
                break
            }
        }
    }
    
    /// 聚合查询入口：先精准匹配，失败则自动转为模糊搜索
    func requestFingerLRCLyricLib(audioModel: AudioFingerprintModel, completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        
        // ⚠️ 识别后的标题不一定是真正的标题，可以考虑优先使用本身内嵌的标题
        let getUrl = "https://lrclib.net/api/get"
        let getParameters: Parameters = [
            "track_name": audioModel.title ?? "",
            "artist_name": audioModel.artist ?? "",
            "album_name": audioModel.album ?? "",
            "duration": audioModel.duration ?? 0
        ]
        
        // 🚀 第一道防线：精准匹配
        AF.request(getUrl, method: .get, parameters: getParameters).responseData { [weak self] response in
            guard let self = self else { return }
            
            switch response.result {
            case .success(let data):
                let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                
                // 检查是否是 LRCLIB 标准的 404 Track not found
                if let statusCode = dict?["statusCode"] as? Int, statusCode == 404 {
                    debugPrint("⚠️ 精准匹配(get)未找到歌词(404)，正在自动启动第二防线：模糊搜索(search)...")
                    self.performBlurrySearch(audioModel: audioModel, completion: completion)
                    return
                }
                
                // 正常解析精准匹配到的歌词
                guard let lyricModel = LRCLibLyricModel.deserialize(from: dict) else {
                    // 如果解析失败，也怀疑是数据异样，降级去搜索试试
                    self.performBlurrySearch(audioModel: audioModel, completion: completion)
                    return
                }
                
                debugPrint("✅ 指纹信息搜索 - 精准匹配(get)成功获取歌词！")
                completion(.success([lyricModel]))
//                var newModel = audioModel
//                newModel.lyrics = [lyricModel]
//                completion(.success(newModel))
                break
            case .failure(let afError):
                // 如果是网络彻底断开或超时，直接报网络错误，没必要再走搜索了
                let errorMsg = afError.errorDescription ?? afError.localizedDescription
                debugPrint("精准匹配时发生系统级网络错误❌: \(errorMsg)")
                completion(.failure(KakaError.custom(errorMsg)))
                break
            }
        }
    }
    
    /// 第二道防线：模糊搜索LRC歌词
    private func performBlurrySearch(audioModel: AudioFingerprintModel, completion: @escaping (Result<[LRCLibLyricModel], KakaError>) -> Void) {
        
        let searchUrl = "https://lrclib.net/api/search"
        // 将歌名和歌手拼接，作为模糊搜索的核心关键词
        let query = "\(audioModel.title ?? "") \(audioModel.artist ?? "")"
        let searchParameters: Parameters = ["q": query]
        
        AF.request(searchUrl, method: .get, parameters: searchParameters).responseData { response in
            switch response.result {
            case .success(let data):
                
                let dictArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]]
                
                debugPrint("搜索LRC歌词 = \(dictArray ?? [])")

                guard let lyricArray = [LRCLibLyricModel].deserialize(from: dictArray), lyricArray.count > 0 else {
                    completion(.failure(.custom("No lyrics found in cloud database.")))
                    return
                }
                
                completion(.success(lyricArray))
                
                break
            case .failure(let afError):
                let errorMsg = afError.errorDescription ?? afError.localizedDescription
                debugPrint("模糊搜索时发生网络错误❌: \(errorMsg)")
                completion(.failure(KakaError.custom(errorMsg)))
                break
            }
        }
    }
    
    /// 工业级权重评分机制
    private func calculateMatchScore(model: LRCLibLyricModel, target: AudioFingerprintModel) -> Int {
        var score = 0
        
        let targetTitle = target.title?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let targetArtist = target.artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let modelTitle = model.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let modelArtist = model.artistName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 维度 1：歌名与歌手完美匹配 (最高权重)
        if modelTitle == targetTitle && modelArtist == targetArtist {
            score += 100
        } else if modelTitle == targetTitle {
            score += 40 // 歌名对上了，歌手没对上
        }
        
        // 维度 2：必须优先保障带时间轴的 LRC 歌词！(核心用户体验)
        // 假设你的 LyricModel 里面有判断是否有同步时间轴的属性，比如 syncedLyricsStr
        if let syncedLrc = model.syncedLyrics, !syncedLrc.isEmpty {
            score += 50 // 有时间轴的，无条件加巨分
        }
        
        // 维度 3：时长（Duration）容差校验 (防止原唱与各种短版/翻唱错位)
        if let targetDuration = target.duration, targetDuration > 0,
           let modelDuration = model.duration, modelDuration > 0 {
            let diff = abs(targetDuration - modelDuration)
            if diff <= 3 {
                score += 20  // 时长误差在 3 秒内，高度疑似正轨
            } else if diff <= 10 {
                score += 5   // 时长误差在 10 秒内
            }
        }
        
        return score
    }
    
}
