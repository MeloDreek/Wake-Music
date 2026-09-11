//
//  NoneLyriclistView.swift
//  Mobie
//
//  Created by kaka on 2026/9/11.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

// MARK:  没有歌词时的样式
class NoneLyriclistView: UIView {
    
    public init(frame: CGRect, isShowIcon: Bool) {
        super.init(frame: frame)
        
        self.isShowIcon = isShowIcon
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        self.addSubview(middleView)
        
        middleView.addSubview(emptyImgView)
        middleView.addSubview(titleLabel)
        middleView.addSubview(messaleLabel)
        middleView.addSubview(editButton)
        middleView.addSubview(faqButton)
    }
    
    func preSetupContains() {
        emptyImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.size.equalTo(isShowIcon ? 135.ckValue() : 1.ckValue())
            make.height.equalTo(emptyImgView.snp.width)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.top.equalTo(emptyImgView.snp.bottom).offset(20.ckValue())
            make.height.greaterThanOrEqualTo(titleLabel.font.lineHeight)
        }
        
        messaleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(20.ckValue())
            make.top.equalTo(titleLabel.snp.bottom).offset(10.ckValue())
            make.height.greaterThanOrEqualTo(messaleLabel.font.lineHeight)
        }
        
        editButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPad() {
                make.width.equalTo(400.ckValue())
            } else {
                make.width.equalToSuperview().multipliedBy(0.85)
            }
            make.top.equalTo(messaleLabel.snp.bottom).offset(30.ckValue())
            make.height.equalTo(editButton.layer.cornerRadius * 2)
        }
        
        faqButton.snp.makeConstraints { make in
            make.top.equalTo(editButton.snp.bottom).offset(15.ckValue())
            make.centerX.equalToSuperview()
            make.width.equalTo(editButton)
            make.height.equalTo(faqButton.layer.cornerRadius * 2)
            make.bottom.equalToSuperview()
        }
        
        middleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-50.ckValue())
            make.width.equalToSuperview().multipliedBy(0.9) // 可根据需要调整
        }
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .random()
        self.overrideUserInterfaceStyle = .dark
    }
    
    // MARK:  GET && SET
    
    var onEditCallBack: (()->Void)?
    
    var onEngineCallBack: (()->Void)?
    
    var onFaqCallBack: (()->Void)?
    
    var musicModel: MusicItemModel?
    
    var isShowIcon: Bool = true
    
    var isShowLyric: Bool {
        get {
            guard let model = KakaMusicPlayer.shared.playingMusic else { return false }
            
            if model.fileSourceType == .demoFile {
                return true
            }else{
                return model.isHaveLyric()
            }
        }
    }
    
    func updateContent(_ model: MusicItemModel) {
        self.musicModel = model
        emptyImgView.image = Reasource.systemNamed("exclamationmark.triangle.fill", color: .orange)
        
        // 只有在“非本地文件”且“使用 AVPlayer”时才展示启用引擎提示，其余情况均展示默认的无歌词提示
        let isAVPlayerRemote = !model.isLocalFile() && MusicConfigManager.shared.playerEngine == .avPlayer
        
        let btnTitle: String
        let title: String
        let message: String
        
        if isAVPlayerRemote {
            btnTitle = "All-Format Audio Engine".localStr()
            title = "Switch to the All-Format Audio Engine".localStr()
            message = "The current engine cannot read embedded artwork or lyrics from remote audio files. Switch to the All-Format Audio Engine to read this metadata while streaming. This is a paid feature.".localStr()
        } else {
            btnTitle = "Edit Embedded Lyrics".localStr()
            title = "No Embedded Lyrics in This Song".localStr()
            message = "Built for lifelong music collections, Wakemusic prioritizes embedded LRC lyrics over unreliable online matching. Please complete your missing metadata with our Music Tag Editor.".localStr()
        }
        
        editButton.setTitle(btnTitle, for: .normal)
        titleLabel.text = title
        messaleLabel.text = message
        
        self.layoutIfNeeded()
    }
    
    // MARK:  懒加载
    lazy var middleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var emptyImgView: UIImageView = {
        let image = Reasource.named("gift_box")
        let view = UIImageView(image: image)
        view.isHidden = !self.isShowIcon
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.label
        view.font = UIFontBold(20.ckValue())
        return view
    }()
    
    lazy var messaleLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.secondaryLabel
        view.font = UIFontLight(16.ckValue())
        return view
    }()
    
    lazy var editButton: UIButton = {
        let view = UIButton()
        view.setTitle("Edit Embedded Lyrics".localStr(), for: .normal)
        view.addTarget(self, action: #selector(editButtonClick), for: .touchUpInside)
        view.backgroundColor = UIColor.systemBlue
        view.setTitleColor(UIColor.white, for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 25.ckValue()
        return view
    }()
    
    lazy var faqButton: UIButton = {
        let view = UIButton()
        view.setTitle("FAQ".localStr(), for: .normal)
        view.addTarget(self, action: #selector(faqButtonClick), for: .touchUpInside)
        view.backgroundColor = UIColor.systemOrange
        view.setTitleColor(UIColor.white, for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 25.ckValue()
        return view
    }()
    
    @objc func editButtonClick() {
        guard let musicModel = self.musicModel else { return }
        let isAVPlayerRemote = !musicModel.isLocalFile() && MusicConfigManager.shared.playerEngine == .avPlayer
        if isAVPlayerRemote {
            self.onEngineCallBack?()
        }else{
            self.onEditCallBack?()
        }
    }
    
    @objc func faqButtonClick() {
        self.onFaqCallBack?()
    }
    
    
}
