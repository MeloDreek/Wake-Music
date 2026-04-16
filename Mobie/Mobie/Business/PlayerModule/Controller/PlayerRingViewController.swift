//
//  PlayerRingViewController.swift
//  Mobie
//
//  Created by 张文 on 11/13/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import FFmpegKit
import AVFoundation

/// 手机铃声
class PlayerRingViewController: SuperViewController {
    
    init(_ musicModel: MusicItemModel) {
        super.init(nibName: nil, bundle: nil)
        self.musicModel = musicModel
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(titleLabel)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalToSuperview().offset(25.ckValue())
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.overrideUserInterfaceStyle = .dark
        
//        self.convertAudioFormat()
    }
    
    func convertAudioFormat() {
        
        let audioType = AudioFormatEnum.mp3
        let musicName = self.musicModel.filePathName().removeChar(self.musicModel.addPathExtension())
        
        guard let audioOutputURL = KakaMusicPlayer.shared.createRingtoneURL(musicName: musicName, audioType: audioType) else {
            return
        }
        
        // 根据音频格式选择输出参数
        let audioFormat = audioType.encoderStr()
        
        let videoURL = self.musicModel.mediaPlayURL
        
        // 获取视频时长
        let asset = AVAsset(url: videoURL)
        let durationInSeconds = CMTimeGetSeconds(asset.duration)
        
        // 构建FFmpeg命令
        var command = "-i \"\(videoURL.path)\" -vn -acodec \(audioFormat)"
        
//        if durationInSeconds > 28 {
            // 只保留前30秒
//            durationInSeconds = max(durationInSeconds - 3, 0) // 确保不为负值
//            command += " -t 28"
//        }
        
        command += " \(audioOutputURL.path)"
                
        /*
        // 执行FFmpeg命令
        FFmpegKit.executeAsync(command) { [weak self] session in
            let returnCode = session?.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                self?.audioOutputURL = audioOutputURL
                debugPrint("转化成功 = \(audioOutputURL)")
            } else {
                debugPrint("转化失败")
            }
        } withLogCallback: { logCallback in
            
        } withStatisticsCallback: { staticCallback in
            let processedTime = (staticCallback?.getTime() ?? 0) / 1000
            let progress = durationInSeconds > 0 ? (processedTime / durationInSeconds) : 0
            DispatchQueue.main.async {
                // 根据time更新UI，例如进度条
                debugPrint("当前 = \(processedTime)，总时间 = \(durationInSeconds), 转换进度 = \(progress)")
            }
        }
         */
        
    }
    
    // MARK:  GET && SET
    var musicModel: MusicItemModel!
    
    var audioOutputURL: URL?
    
    // MARK:  懒加载
    lazy var titleLabel: UILabel = {
        let sumStr = "Ringtone".localStr()
                
        let attbuteStr = NSMutableAttributedString(string: sumStr, attributes: [.font: UIFontBold(18.ckValue()), .foregroundColor: UIColor.label])
        
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.attributedText = attbuteStr
        return view
    }()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let serverURL = self.audioOutputURL else {
            return
        }
        
        let shareVC = UIActivityViewController(activityItems: [serverURL], applicationActivities: nil)
        
        self.present(shareVC, animated: true, completion: nil)
    }
    
}

extension PlayerRingViewController: PanModalPresentable {
    var panScrollable: UIScrollView? {
        return nil
    }

    var shouldRoundTopCorners: Bool {
        return true
    }
    
    var longForm: PanModalHeight {
        return .contentHeightIgnoringSafeArea(500.ckValue() + kaka_safeAreaInsets().bottom)
    }
    
    var orientation: PanModalOrientation {
        return .vertical
    }
    
    var verticalOffset: CGFloat {
        return app_navHeight
    }
    
    var horizontalOffset: CGFloat {
        return 0
    }
    
    var cornerRadius: CGFloat {
        return 25.ckValue()
    }

    var anchorModalToLongForm: Bool {
        return false
    }
    
    var transitionAnimationOptions: UIView.AnimationOptions {
        return [.allowUserInteraction, .beginFromCurrentState]
    }
    
}

