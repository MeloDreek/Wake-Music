//
//  VideoConverterViewController+Crop.swift
//  Mobie
//
//  Created by 张文 on 9/25/24.
//

import KakaFoundation
import KSPlayer
import AppGroupKit
import FFmpegKit
import AVFoundation
import StoreKit
import WaketagLibKit

extension VideoConverterViewController {
    
    // 解码为音频并转换格式，同时写入音乐库
    func convertVideoToAudio(_ videoURL: URL) {
        
        guard let audioOutputURL = KakaMusicPlayer.shared.videoToAudioURL(self.audioType) else { return }
        
        // 获取视频时长
        let asset = AVAsset(url: videoURL)
        let durationInSeconds = CMTimeGetSeconds(asset.duration)
        
        // 创建音频轨道
        guard let _ = asset.tracks(withMediaType: .audio).first else {
            debugPrint("没有音频轨道")
            return
        }
        
        // 创建AVAssetExportSession
        self.audioSeccsion = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        self.audioSeccsion?.outputURL = audioOutputURL
        self.audioSeccsion?.outputFileType = self.audioType.outputFileType()
        self.audioSeccsion?.shouldOptimizeForNetworkUse = true
        if self.isAutoCropAudio && durationInSeconds > 3 {
            let endTime = CMTimeMakeWithSeconds(durationInSeconds - 3, preferredTimescale: 600) // 剪去最后3秒后的时长
            let timeRange = CMTimeRange(start: .zero, end: endTime)
            self.audioSeccsion?.timeRange = timeRange
        }
        
        
        self.timer.startTimer(seconds: 0.01, repeats: true, callSoon: true) { [weak self] vTimer in
            guard let sesstion = self?.audioSeccsion else { return }
            debugPrint("转换进度 = \(sesstion.progress)")
            self?.videoCell?.progress = Double(sesstion.progress)
        }
                        
        // 开始导出
        self.audioSeccsion?.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async { [weak self] () in

                switch self?.audioSeccsion?.status {
                case .completed:
                    debugPrint("转换完成")
                    self?.timer.stopTimer()
                    self?.videoCell?.progress = 1
                    self?.autoEditMusicInfo(audioURL: audioOutputURL, videoURL: videoURL)
                    break
                case .waiting:
                    debugPrint("正在等待")
                    break
                case .exporting:
                    debugPrint("正在转换")
                    break
                case .failed:
                    debugPrint("转换失败")
                    self?.timer.stopTimer()
                    self?.showOneAlert(message: "Conversion failed, the source file may be incorrect. Please change the audio quality or source file.".localStr(), confirm: "OK".localStr())
                    self?.deleteVideoFile()
                case .cancelled:
                    debugPrint("已取消")
                    break
                default:
                    break
                }
                
                self?.audioSeccsion = nil
            }
        })
        
    }

    
    // 直接修改封面、歌名、歌手、专辑、年代
    func autoEditMusicInfo(audioURL: URL, videoURL: URL) {
        
        self.videoURL = videoURL
            
        // 设置音乐标签
        let tempImage = videoURL.getVideoThumbnail()
        self.coverImage = tempImage?.croppedToCenteredSquare()

        let songName = "Video to Music".localStr() + Date().convertString(false)
        let artistName = "Wakemusic".localStr()
        
        TaglibMetadataParser.setCoverArt(self.coverImage, toFileURL: audioURL)
        TaglibMetadataParser.setTitle(songName, toFileURL: audioURL)
        TaglibMetadataParser.setArtist(artistName, toFileURL: audioURL)
        TaglibMetadataParser.setAlbum("Video to Music".localStr(), toFileURL: audioURL)
        TaglibMetadataParser.setLyris("", toFileURL: audioURL)
        TaglibMetadataParser.setYear(Int32(Date().year), toFileURL: audioURL)
        
        let baseFileName = "\(artistName) - \(songName)".replaceChar(oldChar: ".", newChar: "")
        
        // 音乐文件
        var fileName = baseFileName
        var fileCount = 1
        
        while FileManager.default.fileExists(atPath: SandboxFileManager.shared.basePublicFileURL().path.ocString.appendingPathComponent("\(fileName).\(audioURL.pathExtension)")) {
            fileName = "\(baseFileName) (\(fileCount))"
            fileCount += 1
        }
        
        let fullFileName = fileName + "." + audioURL.pathExtension
        let targetURL = self.viewModel.baseFileURL.appendingPathComponent(fullFileName)
        
        try? FileManager.default.moveItem(at: audioURL, to: targetURL)
        
        // 在主线程中将文件转移到Document文件夹
        DispatchQueue.main.async { [weak self] () in
                            
            let model = MusicItemModel(fileURL: targetURL, sourceType: .fromVideos)
            let meteDate = TaglibMetadataParser.readMetadata(withFileURL: targetURL, read: .basicCover)
            self?.musicModel = meteDate?.mergeTagLibInfo(model)
            self?.musicModel?.handleType = .link
            self?.audioOutputURL = audioURL
            self?.videoCell?.stopLoading()
            
            self?.tableView.reloadData()
            self?.finishVideoConvert()
            
        }
        
    }


    
    // 完成后到提示
    func finishVideoConvert() {
        self.tableView.isUserInteractionEnabled = true
        
        let alertController = UIAlertController(title: "Successful".localStr(), message: "Audio extracted successfully! Would you like to select another video, edit the current track, or leave?".localStr(), preferredStyle: .alert)
        let action1 = UIAlertAction(title: "Continue to select video".localStr(), style: .destructive) { [weak self] (sender) in
            self?.deleteVideoFile()
        }
        let action2 = UIAlertAction(title: "Edit Current Track".localStr(), style: .default) { [weak self] (sender) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let cell1 = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? VideoAudioInfoViewCell {
                    cell1.kaka_playShakeAnim()
                }
                if let cell2 = self?.tableView.cellForRow(at: IndexPath(row: 1, section: 1)) as? VideoAudioInfoViewCell {
                    cell2.kaka_playShakeAnim()
                }
                if let cell3 = self?.tableView.cellForRow(at: IndexPath(row: 2, section: 1)) as? VideoAudioInfoViewCell {
                    cell3.kaka_playShakeAnim()
                }
            }
            
#if !DEBUG
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
#endif
            
        }
        
        let action3 = UIAlertAction(title: "Leave".localStr(), style: .cancel) { [weak self] (sender) in
            self?.cancelBarClick()
#if !DEBUG
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
#endif

        }
                
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(action3)
        
        
        self.present(alertController, animated: true, completion: nil)
        
        // 写入封面
        if let musicModel = self.musicModel, let newImage = musicModel.coverArt {
            SandboxFileManager.shared.writeMusicthumbnailImage(model: musicModel, image: newImage)
        }
        
    }
    
}
