//
//  AudioTagListView.swift
//  Mobie
//
//  Created by 张文 on 10/10/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit

class AudioTagListView: UIView, TagListViewDelegate {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(listView)
    }
    
    private func preSetupContains() {
        listView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(30.ckValue())
            make.leading.equalTo(20.ckValue())
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.model = KakaMusicPlayer.shared.playingMusic
    }
        
    var onClickBlock: ((String)->Void)?
    
    
    var model: MusicItemModel? {
        didSet {
            // 比特率、采样率、声道、WebDav
            self.listView.removeAllTags()
            
            guard let model = self.model else { return }
            
            let isDTSAudio = model.addPathExtension().uppercased().contains("DTS")
            
            if model.isLocalFile() || isDTSAudio {
                
                let meteData = TaglibMetadataParser.readMetadata(withFileURL: model.mediaPlayURL, read: .all)
                self.setBitrateValue(model.bitrate ?? Int(meteData?.bitrate ?? 0))
                self.setSampleRateValue(model.sampleRate ?? Int(meteData?.sampleRate ?? 0))
                
                if model.fileSourceType == .fromApple {
                    self.listView.addTag(model.mediaPlayURL.pathExtension.uppercased())
                    self.listView.addTag("Apple Music")
                }
                
                if isDTSAudio && model.fileSourceType != .demoFile {
                    if model.bitrate == nil && model.sampleRate == nil {
                        self.listView.addTag("DTS")
                    }
                    self.listView.addTag(AudioChannels.surround51.formatStr())
                }else{
                    self.listView.addTag(model.channel?.formatStr() ?? AudioChannels.stereo.formatStr())
                }
                
            }else{
                if let navSong = model.navidromeSong {
                    self.setBitrateValue(navSong.bitRate * 1000)
                    
                    if let cacheURL = SandboxFileManager.shared.getDownloadPlayURL(model), navSong.samplingRate == 0 {
                        if let basicInfo = TaglibMetadataParser.readMetadata(withFileURL: cacheURL, read: .basic) {
                            self.setSampleRateValue(Int(basicInfo.sampleRate))
                        }
                    }else{
                        self.setSampleRateValue(navSong.samplingRate)
                    }
                    
                    self.listView.addTag(model.fileSourceType.titleStr())
                    
                    self.listView.addTag(model.channel?.formatStr() ?? AudioChannels.stereo.formatStr())
                }else{
                    let bitrate = model.bitrate
                    let sampleRate = model.sampleRate
                    self.setBitrateValue(bitrate)
                    self.setSampleRateValue(sampleRate)
                    if bitrate == 0 && sampleRate == 0 {
                        self.listView.addTag(model.addPathExtension().removeChar(".").uppercased())
                    }
                    self.listView.addTag(model.fileSourceType.titleStr())
                    
                    self.listView.addTag(model.channel?.formatStr() ?? AudioChannels.stereo.formatStr())
                }
            }
            
        }
    }
    
    func setBitrateValue(_ bitrate: Int?) {
        guard let bitrate = bitrate, bitrate > 0 else { return }
        
        var bitrateStr: String = ""
        
        if bitrate >= 1000000 {
            // 大于等于 1 Mbps
            let bitrateInMbps = Double(bitrate) / 1000000.0
            bitrateStr = String(format: "%.1f Mbps", bitrateInMbps)
        } else if bitrate >= 1000 {
            // 大于等于 1 kbps 小于 1 Mbps
            let bitrateInKbps = Double(bitrate) / 1000.0
            
            if bitrateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                // 整数时去掉小数点
                bitrateStr = String(format: "%.0f kbps", bitrateInKbps)
            } else {
                // 非整数时保留小数点后1位
                bitrateStr = String(format: "%.1f kbps", bitrateInKbps)
            }
        } else {
            // 低于 1000 bps
            bitrateStr = String(format: "%.0f bps", Double(bitrate))
        }
        
        // 添加比特率标签
        self.listView.addTag(bitrateStr)
    }

    
    func setSampleRateValue(_ sampleRate: Int?) {
        guard let sampleRate = sampleRate, sampleRate > 0 else { return }

        if sampleRate >= 1000000 {
            // 处理 MHz
            let sampleRateInMHz = Double(sampleRate) / 1000000.0
            var sampleRateStr: String = ""
            
            if sampleRateInMHz.truncatingRemainder(dividingBy: 1) == 0 {
                // 整数时去掉小数点
                sampleRateStr = String(format: "%.0f MHz", sampleRateInMHz)
            } else {
                // 非整数时保留小数点后1位
                sampleRateStr = String(format: "%.1f MHz", sampleRateInMHz)
            }
            
            self.listView.addTag(sampleRateStr)
        } else if sampleRate >= 1000 {
            // 处理 kHz
            let sampleRateInKbps = Double(sampleRate) / 1000.0
            var sampleRateStr: String = ""
            
            if sampleRateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                sampleRateStr = String(format: "%.0f kHz", sampleRateInKbps)
            } else {
                sampleRateStr = String(format: "%.1f kHz", sampleRateInKbps)
            }
            
            self.listView.addTag(sampleRateStr)
        } else {
            // 处理 Hz 和 mHz
            if sampleRate < 1000 {
                // 处理 mHz
                let sampleRateInMHz = Double(sampleRate) * 1000.0
                let sampleRateStr = String(format: "%.0f mHz", sampleRateInMHz)
                self.listView.addTag(sampleRateStr)
            } else {
                // 处理 Hz
                let sampleRateStr = String(format: "%.0f Hz", Double(sampleRate))
                self.listView.addTag(sampleRateStr)
            }
        }
    }
    
    lazy var listView: TagListView = {
        let view = TagListView()
        view.delegate = self
        view.alignment = .center
        view.textFont = UIFontBold(12.ckValue())
        view.tagBackgroundColor = .clear
        view.textColor = UIColor.white.withAlphaComponent(0.6)
        view.borderColor = view.textColor
        view.borderWidth = 1.ckValue()
        view.paddingX = 10.ckValue()
        view.paddingY = 5.ckValue()
        view.marginX = 5.ckValue()
        view.marginY = 2.ckValue()
        return view
    }()
    
    func tagPressed(_ title: String, tagView: TagView, sender: TagListView) {
        self.onClickBlock?(title)
    }
    
}
