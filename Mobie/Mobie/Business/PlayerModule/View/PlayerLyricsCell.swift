//
//  PlayerLyricsView.swift
//  Mobie
//
//  Created by 张文 on 11/14/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaTaglibKit
import MediaPlayer
import NVActivityIndicatorView


class PlayerLyricsCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(grawView)
        grawView.addSubview(timeLabel)
        grawView.addSubview(playIconView)

        contentView.addSubview(lyricLabel)
    }
    
    func preSetupContains() {
        let lyricConfig = MusicConfigManager.shared.lyricConfig

        grawView.snp.makeConstraints { make in
            make.leading.equalTo(12.ckValue())
            make.top.equalToSuperview()
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        timeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(Self.timeLabelLeading)
            make.width.equalTo(timeLabel.width)
            make.height.greaterThanOrEqualTo(timeLabel.height)
        }
        
        playIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(3.ckValue())
            make.size.equalTo(playIconView.size)
        }
        
        lyricLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(lyricConfig.lineSpace)
            make.leading.equalTo(timeLabel.snp.trailing).offset(Self.playIconViewTraing)
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .none
    }
        
    func update(model: LyricModel?, isPlaying: Bool, isDragPlay: Bool) {
        guard let fullLyric = model?.fullLyric, fullLyric.count > 0 else { return }
        let lyricConfig = MusicConfigManager.shared.lyricConfig
        
        self.lyricLabel.text = fullLyric

        guard let startTimestamp = model?.startTimestamp else {
            self.lyricLabel.textColor = UIColor.hexColor(lyricConfig.norFontColor)
            self.lyricLabel.font = UIFontLight(CGFloat(lyricConfig.norFontSize))
            return
        }
        
        self.grawView.isHidden = !isDragPlay
        self.lyricLabel.textAlignment = lyricConfig.alignment.textAlignment()
        self.lyricLabel.textColor = UIColor.hexColor(isPlaying ? lyricConfig.selFontColor : lyricConfig.norFontColor)
        self.lyricLabel.font = isPlaying ? UIFontBold(CGFloat(lyricConfig.selFontSize)) : UIFontLight(CGFloat(lyricConfig.norFontSize))
            
        let minutes = Int(startTimestamp / 1000.0) / 60
        let seconds = Int(startTimestamp / 1000.0) % 60
        let hundredths = Int(startTimestamp.truncatingRemainder(dividingBy: 1000))  //毫秒
        let formatStr = String(format: "%02d'\r%02d.%03d", minutes, seconds, hundredths)

        self.timeLabel.text = formatStr
        
        lyricLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(lyricConfig.lineSpace)
            make.leading.equalTo(timeLabel.snp.trailing).offset(5.ckValue())
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        self.layoutIfNeeded()
    }
    
    static let playIconViewSize = 25.ckValue()
    static let timeLabelLeading = 3.ckValue()
    static let playIconViewTraing = 5.ckValue()
    
    lazy var timeLabel: UILabel = {
        let testText = "120'\r55.999"
        let font = UIFontBold(8.ckValue())
        
        let view = UILabel(frame: CGRectMake(0, 0, testText.width(font) + 3.ckValue(), font.lineHeight))
        view.backgroundColor = .clear
        view.textAlignment = .center
        view.numberOfLines = 2
        view.textColor = UIColor.secondaryLabel
        view.font = font
        view.text = testText
        return view
    }()
    
    lazy var lyricLabel: UILabel = {
        let lyricConfig = MusicConfigManager.shared.lyricConfig
        
        let view = UILabel()
        view.backgroundColor = .clear
        view.numberOfLines = 0
        view.textColor = UIColor.hexColor(lyricConfig.norFontColor)
        view.textAlignment = lyricConfig.alignment.textAlignment()
        view.font = UIFontLight(CGFloat(lyricConfig.norFontSize))
        return view
    }()
    
    lazy var grawView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.backgroundColor = UIColor.systemFill.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var playIconView: UIImageView = {
        let image = Reasource.systemNamed("play.fill", color: .secondaryLabel)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(Self.playIconViewSize, Self.playIconViewSize)
        return view
    }()
    
}

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
        middleView.addSubview(upgradeButton)
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
        
        upgradeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if kaka_IsiPad() {
                make.width.equalTo(400.ckValue())
            } else {
                make.width.equalToSuperview().multipliedBy(0.75)
            }
            make.top.equalTo(messaleLabel.snp.bottom).offset(30.ckValue())
            make.height.equalTo(upgradeButton.layer.cornerRadius * 2)
            make.bottom.equalToSuperview()
        }
        
        middleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-50.ckValue())
            make.width.equalToSuperview().multipliedBy(0.9) // 可根据需要调整
        }
    }
    
    func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.overrideUserInterfaceStyle = .dark
    }
    
    // MARK:  GET && SET
    
    var onClickCallBack: (()->Void)?
    
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
        
        emptyImgView.image =  Reasource.systemNamed("exclamationmark.triangle.fill", color: .orange)
        titleLabel.text = "No Embedded Lyrics in This Song".localStr()
        let emptyText = "Please make sure your file contains embedded LRC lyrics.".localStr()
        
        messaleLabel.text = emptyText
        upgradeButton.setTitle("Auto Search LRC".localStr(), for: .normal)
        
        self.layoutIfNeeded()
        
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
    
    lazy var upgradeButton: UIButton = {
        let view = UIButton()
        view.addTarget(self, action: #selector(upgradeButtonClick), for: .touchUpInside)
        view.backgroundColor = appMainColor
        view.setTitleColor(UIColor.deAccent, for: .normal)
        view.titleLabel?.font = UIFontBold(15.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 25.ckValue()
        return view
    }()
    
    @objc func upgradeButtonClick() {
        self.onClickCallBack?()
    }
    
}

class DragTimeLineView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        self.addSubview(leftIconView)
        self.addSubview(lineView)
        self.addSubview(rightIconView)
    }
    
    func preSetupContains() {
        
        let sideSpace = 15.ckValue()
        
        leftIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(sideSpace)
            make.size.equalTo(leftIconView)
        }
        
        lineView.snp.makeConstraints { make in
            make.centerY.equalTo(leftIconView)
            make.height.equalTo(0.5.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalTo(leftIconView.snp.trailing).offset(10.ckValue())
        }
        
        rightIconView.snp.makeConstraints { make in
            make.centerY.equalTo(leftIconView)
            make.trailing.equalToSuperview().inset(sideSpace)
            make.width.equalTo(rightIconView.size)
        }
    }
    
    func preSetupHandleBuness() {
        self.isUserInteractionEnabled = false
    }
    
    lazy var leftIconView: UIImageView = {
        var imageName: String
        if #available(iOS 18.0, *) {
            imageName = "arrow.up.and.down.righttriangle.up.righttriangle.down"
        }else{
            imageName = "rectangle.compress.vertical"
        }
        let image = Reasource.systemNamed(imageName, color: .secondaryLabel)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(25.ckValue(), 20.ckValue())
        return view
    }()
    
    lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.5)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 0.25.ckValue()
        return view
    }()
    
    lazy var rightIconView: UIImageView = {
        let image = Reasource.systemNamed("play.fill", color: .secondaryLabel)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.size = leftIconView.size
        return view
    }()

}

