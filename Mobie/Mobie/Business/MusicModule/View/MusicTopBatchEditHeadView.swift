//
//  MusicTopBatchEditHeadView.swift
//  Mobie
//
//  Created by kaka on 2026/8/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

enum MusicTopHeadState: Int {
    case normal = 0
    case matching = 1
    case completed = 2
}

protocol MusicTopBatchEditHeadViewDelegate: AnyObject {
    // 开始编辑模式
    func musicTopHeadViewDidStartEditing(topView: MusicTopBatchEditHeadView)
    
    // 取消匹配
    func musicTopHeadViewDidClickCancel(topView: MusicTopBatchEditHeadView)
    
    // 已完成，重置状态
    func musicTopHeadViewDidCompletReset(topView: MusicTopBatchEditHeadView)
}

/// 首页顶部，批量处理进度条
class MusicTopBatchEditHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        contentView.addSubview(normalView)
        contentView.addSubview(matchingView)
        contentView.addSubview(completedView)
    }
    
    func setupContains() {
        normalView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        matchingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        completedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func handleBuness() {
        contentView.backgroundColor = .clear
        self.state = .normal
    }
        
    static func headHeight() -> CGFloat {
        let height = kaka_IsMacOS() ? 180.ckValue() : 180.ckValue()
        return height
    }
    
    // MARK: GET && SET
    
    weak var delegate: MusicTopBatchEditHeadViewDelegate?
    
    /// 进度状态
    var state: MusicTopHeadState = .normal {
        didSet {
            switch state {
            case .normal:
                self.normalView.isHidden = false
                self.matchingView.isHidden = true
                self.completedView.isHidden = true
                break
            case .matching:
                self.normalView.isHidden = true
                self.matchingView.isHidden = false
                self.completedView.isHidden = true
                break
            case .completed:
                self.normalView.isHidden = true
                self.matchingView.isHidden = true
                self.completedView.isHidden = false
                break
            }
        }
    }
    
    /// 更新进度
    func updateProgress(curModel: MusicItemModel?, completed: Int, total: Int) {
        self.matchingView.musicLabel.text = curModel?.mediaPlayURL.lastPathComponent
        self.matchingView.progressView.update(current: completed, total: total)
    }
    
    /// 更新完成后的状态
    func updateComplete(time: TimeInterval, completeTagCount: Int, misstagCount: Int) {
        self.completedView.updateComplete(time: time, completeTagCount: completeTagCount, misstagCount: misstagCount)
    }
    
    // MARK: 懒加载
    lazy var normalView: HeadNormaltView = {
        let view = HeadNormaltView(frame: self.bounds)
        view.onClickCallBack = { [weak self] () in
            guard let wSelf = self else { return }
            
            wSelf.delegate?.musicTopHeadViewDidStartEditing(topView: wSelf)
        }
        return view
    }()
    
    lazy var matchingView: HeadMatchingView = {
        let view = HeadMatchingView(frame: self.bounds)
        view.onCancelBlock = { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.delegate?.musicTopHeadViewDidClickCancel(topView: wSelf)
        }
        return view
    }()
    
    lazy var completedView: HeadCompletedView = {
        let view = HeadCompletedView(frame: self.bounds)
        view.onResetCallBack = { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.delegate?.musicTopHeadViewDidCompletReset(topView: wSelf)
        }
        return view
    }()
}


/// 默认状态
class HeadNormaltView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        self.addSubview(backView)
        
        backView.addSubview(iconView)
        backView.addSubview(audioView)
        backView.addSubview(titleLabel)
        backView.addSubview(startButton)
    }
    
    func setupContains() {
        let leadSpace = 20.ckValue()
        let topSpace = 15.ckValue()
        let iconSize = 35.ckValue()
        let textHeight = self.titleLabel.font.lineHeight
        
        backView.snp.makeConstraints { make in
            make.leading.equalTo(leadSpace / (kaka_IsMacOS() ? 2 : 4))
            make.top.equalTo(topSpace / 2)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(leadSpace)
            make.top.equalToSuperview().offset(topSpace)
            make.size.equalTo(iconSize)
        }
        
        audioView.snp.makeConstraints { make in
            make.bottom.equalTo(iconView)
            make.centerX.equalTo(iconView.snp.trailing)
            make.size.equalTo(iconSize * 0.5)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(leadSpace)
            make.top.equalTo(iconView).offset((iconSize - textHeight) / 3)
            make.trailing.equalToSuperview().inset(leadSpace)
            make.height.greaterThanOrEqualTo(0)
        }
        
        startButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(leadSpace)
            make.bottom.equalToSuperview().offset(-15.ckValue())
            make.size.equalTo(startButton.size)
        }
    }
    
    func handleBuness() {
        
    }
    
    var onClickCallBack: (()->Void)?
    
    
    lazy var backView: UIView = {
        let view = UIView()
        view.backgroundColor = appMainColor
        view.layer.cornerRadius = 20.ckValue()
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var iconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("touchid", color: .white))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var audioView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("waveform", color: .yellow))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let str1 = "Audio Fingerprint".localStr()
        let str2 = "Auto Recognize".localStr()
        let str3 = "Permanent Embed".localStr()
        
        let sumStr = str1 + "\r" + str2 + "\r" + str3
        
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 5.ckValue()
        paraStyle.alignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        let attbuteStr = NSAttributedString(string: sumStr, attributes: [.foregroundColor: UIColor.white, .font: UIFontBold(16.ckValue()), .paragraphStyle: paraStyle])
        
        let view = UILabel()
        view.numberOfLines = 0
        view.attributedText = attbuteStr
        return view
    }()
    
    lazy var startButton: UIButton = {
        let text = "Batch Auto-Embed".localStr()
        let font = UIFontBold(14.ckValue())
        let textHeight = font.lineHeight + 20.ckValue()
        
        let view = UIButton(type: .custom)
        view.frame = CGRectMake(0, 0, text.width(font) + 50.ckValue(), textHeight)
        view.backgroundColor = .white
        view.setTitle(text, for: .normal)
        view.setTitleColor(appMainColor, for: .normal)
        view.titleLabel?.font = font
        view.layer.masksToBounds = true
        view.layer.cornerRadius = textHeight / 2
        view.addTarget(self, action: #selector(startButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func startButtonClick() {
        self.onClickCallBack?()
    }
}


/// 匹配中...
class HeadMatchingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        self.addSubview(backView)
        self.addSubview(loadingView)
        self.addSubview(cancelButton)
        self.addSubview(musicLabel)
        self.addSubview(progressView)
    }
    
    func setupContains() {
        let leadSpace = 20.ckValue()
        let topSpace = 15.ckValue()
        let iconSize = 35.ckValue()
        
        backView.snp.makeConstraints { make in
            make.leading.equalTo(leadSpace / (kaka_IsMacOS() ? 2 : 4))
            make.top.equalTo(topSpace / 2)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        loadingView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(leadSpace)
            make.top.equalToSuperview().offset(topSpace)
            make.size.equalTo(iconSize)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10.ckValue())
            make.centerY.equalTo(loadingView)
            make.size.equalTo(cancelButton.size)
        }
        
        musicLabel.snp.makeConstraints { make in
            make.leading.equalTo(loadingView)
            make.centerY.equalToSuperview().offset(-10.ckValue())
            make.centerX.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        progressView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-15.ckValue())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(45.ckValue())
        }
        
    }
    
    func handleBuness() {
        
    }
    
    var onCancelBlock: (()->Void)?
    
    lazy var backView: UIView = {
        let view = UIView()
        view.backgroundColor = appMainColor
        view.layer.cornerRadius = 20.ckValue()
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = .white
        view.startAnimating()
        return view
    }()
    
    lazy var musicLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.font = UIFontBold(16.ckValue())
        view.textAlignment = .center
        view.numberOfLines = 2
        view.lineBreakMode = .byTruncatingMiddle
        return view
    }()
    
    lazy var progressView: MatchingProgressView = {
        let view = MatchingProgressView()
        view.update(current: 0, total: 0)
        return view
    }()
    
    lazy var cancelButton: LoadingButton = {
        let text = "Cancel".localStr()
        let font = UIFontLight(13.ckValue())
        
        let attbuteStr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.75), .underlineStyle: 1])
        
        let view = LoadingButton(type: .custom)
        view.frame = CGRectMake(0, 0, text.width(font) + 35.ckValue(), font.lineHeight + 16.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = view.frame.size.height / 2
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(cancelButtonClick), for: .touchUpInside)
        return view
    }()
    
    // 取消
    @objc func cancelButtonClick() {
        self.onCancelBlock?()
    }
}

/// 完成状态
class HeadCompletedView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        self.addSubview(backView)
        self.addSubview(resetButton)
        self.addSubview(spentTimeLabel)
        self.addSubview(completeIconView)
        self.addSubview(completeLabel)
        self.addSubview(pointView)
        self.addSubview(missingLabel)
    }
    
    func setupContains() {
        let leadSpace = 20.ckValue()
        let topSpace = 15.ckValue()
        
        backView.snp.makeConstraints { make in
            make.leading.equalTo(leadSpace / (kaka_IsMacOS() ? 2 : 4))
            make.top.equalTo(topSpace / 2)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        spentTimeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(topSpace * 2)
            make.leading.equalTo(leadSpace)
            make.size.greaterThanOrEqualTo(0)
        }
        
        resetButton.snp.makeConstraints { make in
            make.centerY.equalTo(spentTimeLabel)
            make.trailing.equalToSuperview().offset(-10.ckValue())
            make.size.equalTo(resetButton.size)
        }
        
        completeIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-10.ckValue())
            make.height.equalToSuperview().multipliedBy(0.45)
            make.width.equalTo(completeIconView.snp.height)
        }
        
        pointView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-25.ckValue())
            make.size.equalTo(pointView.size)
        }
        
        missingLabel.snp.makeConstraints { make in
            make.centerY.equalTo(pointView)
            make.leading.equalTo(pointView.snp.trailing).offset(13.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        completeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(pointView)
            make.trailing.equalTo(pointView.snp.leading).offset(-13.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        
        
    }
    
    func handleBuness() {
        
    }
    
    func updateComplete(time: TimeInterval, completeTagCount: Int, misstagCount: Int) {
        let spendTime = time.toLocalizedDurationString()
        let completeStr = "Complete Tags".localStr() + ": " + "\(completeTagCount)"
        let missStr = "Missing Tags".localStr() + ": " + "\(misstagCount)"
        
        self.spentTimeLabel.text = spendTime
        self.completeLabel.text = completeStr
        self.missingLabel.text = missStr
    }
    
    var onResetCallBack: (()->Void)?
    
    lazy var backView: UIView = {
        let view = UIView()
        view.backgroundColor = appMainColor
        view.layer.cornerRadius = 20.ckValue()
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var completeIconView: UIImageView = {
        let image = Reasource.systemNamed("checkmark.circle.fill", color: .white)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var spentTimeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.textAlignment = .center
        view.font = UIFontNumber(17.ckValue())
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var completeLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.textAlignment = .center
        view.font = UIFontBold(13.ckValue())
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var pointView: UIView = {
        let size = 7.ckValue()
        let view = UIView(frame: CGRectMake(0, 0, size, size))
        view.backgroundColor = .white
        view.layer.masksToBounds = true
        view.layer.cornerRadius = size / 2
        return view
    }()
    
    lazy var missingLabel: UILabel = {
        let view = UILabel()
        view.textColor = .white
        view.textAlignment = .center
        view.font = completeLabel.font
        view.layer.masksToBounds = true
        return view
    }()
    
    lazy var resetButton: LoadingButton = {
        let text = "Reset".localStr()
        let font = UIFontLight(13.ckValue())
        
        let attbuteStr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.white, .underlineStyle: 1])
        
        let view = LoadingButton(type: .custom)
        view.frame = CGRectMake(0, 0, text.width(font) + 35.ckValue(), font.lineHeight + 16.ckValue())
        view.layer.masksToBounds = true
        view.layer.cornerRadius = view.frame.size.height / 2
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(resetButtonClick), for: .touchUpInside)
        return view
    }()
    
    // 重置
    @objc func resetButtonClick() {
        self.onResetCallBack?()
    }
    
}

