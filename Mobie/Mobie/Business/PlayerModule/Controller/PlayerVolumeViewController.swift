//
//  PlayerVolumeViewController.swift
//  Mobie
//
//  Created by 张文 on 11/13/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal

/// 自定义音量
class PlayerVolumeViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(titleLabel)
        
        contentView.addSubview(musicModeView)
        contentView.addSubview(gameModeView)
        contentView.addSubview(messageLabel)
        
        contentView.addSubview(progressView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalToSuperview().offset(25.ckValue())
        }
        
        let sideSpace = self.view.width * 0.04
        let middleSpace = self.view.width * 0.02
        let modeWidth = (self.view.width - sideSpace * 2 - middleSpace) / 2
        
        musicModeView.snp.remakeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(25.ckValue())
            make.leading.equalToSuperview().offset(sideSpace)
            make.width.equalTo(modeWidth)
            make.height.equalTo(kaka_IsiPhone() ? 105 : 160)
        }
        
        gameModeView.snp.remakeConstraints { make in
            make.centerY.equalTo(musicModeView)
            make.trailing.equalToSuperview().inset(sideSpace)
            make.width.equalTo(modeWidth)
            make.height.equalTo(musicModeView)
        }
        
        messageLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(gameModeView.snp.bottom).offset(30.ckValue())
            make.leading.equalTo(musicModeView).offset(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        progressView.snp.remakeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(30.ckValue())
            make.centerX.equalToSuperview()
            make.leading.equalTo(musicModeView)
            make.height.equalTo(progressView.height)
        }
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.update()
        self.overrideUserInterfaceStyle = .dark
    }
    
    func updateNowVolume(_ value: Int) {
        
        debugPrint("音量 = \(value)")
        
        let playbackVolume = Float(value) / 100.0
        KakaMusicPlayer.shared.playerView.playerLayer?.player.playbackVolume = playbackVolume
        MusicConfigManager.shared.volume = playbackVolume
                
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                KakaMusicPlayer.shared.play()
            }
        }
    }
    
    func update() {
        musicModeView.playMode = .music
        gameModeView.playMode = .game
        
        messageLabel.text = MusicConfigManager.shared.playMode.descStr()
        self.view.layoutIfNeeded()
    }
    
    lazy var progressView: RulerProgressView = {
        let view = RulerProgressView(frame: CGRectMake(0, 0, self.view.width * 0.8, 80.ckValue()))
        let value = Int(100.0 * MusicConfigManager.shared.volume)
        view.setValue(value)
        view.valueChanged = { [weak self] (value) in
            self?.updateNowVolume(value)
        }
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let sumStr = "Volume".localStr()
                
        let attbuteStr = NSMutableAttributedString(string: sumStr, attributes: [.font: UIFontBold(18.ckValue()), .foregroundColor: UIColor.label])
        
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.attributedText = attbuteStr
        return view
    }()
    
    lazy var messageLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .secondaryLabel
        view.textAlignment = .center
        view.font = UIFontLight(14.ckValue())
        view.text = MusicConfigManager.shared.playMode.descStr()
        return view
    }()
    
    lazy var musicModeView: MusicVolumeModeView = {
        let view = MusicVolumeModeView()
        view.addTarget(self, action: #selector(musicModeViewClick), for: .touchUpInside)
        return view
    }()
    
    lazy var gameModeView: MusicVolumeModeView = {
        let view = MusicVolumeModeView()
        view.addTarget(self, action: #selector(gameModeViewClick), for: .touchUpInside)
        return view
    }()
    
    @MainActor @objc func musicModeViewClick() {
        
        if MusicConfigManager.shared.playMode == .music {
            return
        }
        
        MusicConfigManager.shared.playMode = .music
        KakaMusicPlayer.shared.setupAudioCategory()
        self.update()
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                KakaMusicPlayer.shared.play()
            }
        }
        
        (appKeyWindow ?? self.view).makeToast("Successful".localStr())
    }
    
    @objc func gameModeViewClick() {
        
        if MusicConfigManager.shared.playMode == .game {
            return
        }
        
        MusicConfigManager.shared.playMode = .game
        KakaMusicPlayer.shared.setupAudioCategory()
        self.update()
        
        if KakaMusicPlayer.shared.isPlaying {
            KakaMusicPlayer.shared.pause()
            
            DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.1) {
                KakaMusicPlayer.shared.play()
            }
        }
        
        (appKeyWindow ?? self.view).makeToast("Successful".localStr())
    }
}

extension PlayerVolumeViewController: PanModalPresentable {
    var panScrollable: UIScrollView? {
        return nil
    }

    var shouldRoundTopCorners: Bool {
        return true
    }
    
    var longForm: PanModalHeight {
        let messWidth = self.view.width * 0.96
        let massHeight1 = MusicPlayMode.music.descStr().height(forWidth: messWidth, font: messageLabel.font)
        let massHeight2 = MusicPlayMode.game.descStr().height(forWidth: messWidth, font: messageLabel.font)
        
        let maxMassHeight = max(massHeight1, massHeight2)
        
        let contentHeight = 25.ckValue() + titleLabel.font.lineHeight + (kaka_IsiPhone() ? 130 : 185) + maxMassHeight + 110.ckValue() + 50.ckValue() + kaka_safeAreaInsets().bottom
        return .contentHeightIgnoringSafeArea(contentHeight)
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


class MusicVolumeModeView: UIControl {
    
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
        self.addSubview(colorView)
        self.addSubview(iconImgView)
        self.addSubview(titleLabel)
        self.addSubview(selectIconView)
    }
    
    func preSetupContains() {
        colorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(13.ckValue())
            make.centerX.equalToSuperview()
            make.top.equalTo(13.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        iconImgView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalToSuperview().inset(5.ckValue())
            make.size.equalTo(35.ckValue())
        }
        
        selectIconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8.ckValue())
            make.bottom.equalToSuperview().inset(8.ckValue())
            make.size.equalTo(selectIconView.size)
        }
        
    }
    
    func preSetupHandleBuness() {
        self.isUserInteractionEnabled = true
        self.backgroundColor = .secondarySystemBackground
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 8.ckValue()
    }
    
    // MARK:  GET && SET
    var playMode: MusicPlayMode? {
        didSet {
            guard let playMode = self.playMode else { return }
            let isSelect = MusicConfigManager.shared.playMode == playMode
            iconImgView.image = playMode.iconImage()
            titleLabel.text = playMode.titleStr()
            selectIconView.image = Reasource.systemNamed(isSelect ? "checkmark.circle" : "circle", color: .white)
            colorView.backgroundColor = playMode.tintColor().withAlphaComponent(0.5)
            
            self.layer.borderColor = isSelect ? playMode.tintColor().cgColor : UIColor.clear.cgColor
            self.layer.borderWidth = isSelect ? 3.ckValue() : 0
        }
    }
    
    // MARK:  懒加载
    lazy var iconImgView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var colorView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.isUserInteractionEnabled = false
        view.numberOfLines = 0
        view.font = UIFontBold(18.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = .label
        return view
    }()
    
    lazy var selectIconView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.tintColor = appMainColor
        view.contentMode = .scaleAspectFit
        return view
    }()
    
}

class RulerProgressView: UIView {
    
    // MARK: - Properties
    private var totalMarks: Int = 101           // 总刻度数（0 到 100，每隔1个刻度）
    private var currentValue: Int = 0           // 当前值
    private let rulerLineWidth: CGFloat = 1.ckValue()     // 刻度线宽度
    private var rulerSpacing: CGFloat = 0       // 动态计算的刻度间距
    private let markHeight: CGFloat = 12.ckValue()        // 普通刻度高度
    private let longMarkHeight: CGFloat = 20.ckValue()    // 长刻度高度
    private let importantMarkHeight: CGFloat = 30.ckValue() // 关键刻度高度
    
    // 动态标签
    private let valueLabel = UILabel()
    
    // 颜色配置
    private let progressColor = ThemeColorType.color9.color().withAlphaComponent(0.58)     // 当前进度色块颜色
    private let rulerColor = UIColor.secondaryLabel  // 刻度颜色
    private let pointerColor = UIColor.accent      // 当前指针颜色
    
    // 值变化回调
    var valueChanged: ((Int) -> Void)?
    
    // MARK: - Initialization
    init(frame: CGRect, totalMarks: Int = 101) {
        self.totalMarks = totalMarks
        super.init(frame: frame)
        backgroundColor = .clear
        setupLabel()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        setupLabel()
        setupGesture()
    }
    
    // 设置动态标签
    private func setupLabel() {
        valueLabel.textColor = pointerColor
        valueLabel.font = UIFont.boldSystemFont(ofSize: 14)
        valueLabel.textAlignment = .center
        valueLabel.text = "0"
        valueLabel.translatesAutoresizingMaskIntoConstraints = true
        addSubview(valueLabel)
    }
    
    // 添加手势
    private func setupGesture() {
        // 拖动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        addGestureRecognizer(panGesture)
        
        // 点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        calculateSpacing()
        updateLabelPosition()
        setNeedsDisplay() // 重新绘制
    }
    
    // 动态计算刻度间距
    private func calculateSpacing() {
        guard totalMarks > 1 else { return }
        rulerSpacing = bounds.width / CGFloat(totalMarks - 1)
    }
    
    // 更新标签位置
    private func updateLabelPosition() {
        let pointerX = CGFloat(currentValue) * rulerSpacing
        valueLabel.frame = CGRect(x: pointerX - 20.ckValue(), y: bounds.height / 2 - importantMarkHeight - 20.ckValue(), width: 40.ckValue(), height: 20.ckValue())
        valueLabel.text = "\(currentValue)"
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard totalMarks > 0 else { return }
        let context = UIGraphicsGetCurrentContext()
        let centerY = rect.height / 2
        
        // 绘制当前进度色块
        context?.setFillColor(progressColor.cgColor)
        let progressRect = CGRect(x: 0, y: centerY - importantMarkHeight / 2, width: CGFloat(currentValue) * rulerSpacing, height: importantMarkHeight)
        context?.fill(progressRect)
        
        // 绘制刻度线
        for i in 0..<totalMarks {
            let x = CGFloat(i) * rulerSpacing
            var lineHeight = markHeight
            
            if i % 25 == 0 { // 关键刻度：0、25、50、75、100
                lineHeight = importantMarkHeight
            } else if i % 5 == 0 { // 其他长刻度
                lineHeight = longMarkHeight
            }
            
            context?.setLineWidth(rulerLineWidth)
            context?.setStrokeColor(rulerColor.cgColor)
            context?.move(to: CGPoint(x: x, y: centerY - lineHeight / 2))
            context?.addLine(to: CGPoint(x: x, y: centerY + lineHeight / 2))
            context?.strokePath()
            
            // 绘制关键刻度值
            if i % 25 == 0 {
                let label = "\(i)"  // 每隔25的值：0、25、50、75、100
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.label
                ]
                let size = label.size(withAttributes: attributes)
                var labelX = x - size.width / 2
                let labelY = centerY + importantMarkHeight / 2 + 5
                
                // 调整第一个和最后一个刻度值的标签位置
                if i == 0 {
                    labelX = max(0, labelX) // 确保不超出左边界
                } else if i == totalMarks - 1 {
                    labelX = min(bounds.width - size.width, labelX) // 确保不超出右边界
                }
                
                label.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: attributes)
            }
        }
        
        // 绘制当前指针
        let pointerX = CGFloat(currentValue) * rulerSpacing
        context?.setLineWidth(2.ckValue())
        context?.setStrokeColor(pointerColor.cgColor)
        context?.move(to: CGPoint(x: pointerX, y: centerY - importantMarkHeight))
        context?.addLine(to: CGPoint(x: pointerX, y: centerY + importantMarkHeight))
        context?.strokePath()
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translationX = gesture.translation(in: self).x
        let deltaValue = Int(translationX / rulerSpacing)  // 每次增量为1
        let newValue = max(0, min(100, currentValue + deltaValue))  // 限制在0-100范围内
        
        if newValue != currentValue {
            currentValue = newValue
            updateLabelPosition()
            setNeedsDisplay() // 重绘
        }
        
        // 重置拖动偏移
        gesture.setTranslation(.zero, in: self)
        
        // 仅在松手时回调
        if gesture.state == .ended {
            self.valueChanged?(currentValue)
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let newValue = Int(location.x / rulerSpacing)  // 每次增量为1
        currentValue = max(0, min(100, newValue))  // 限制在0-100范围内
        valueChanged?(currentValue)
        updateLabelPosition()
        setNeedsDisplay() // 重绘
    }
    
    // MARK: - Public Methods
    func setValue(_ value: Int) {
        currentValue = max(0, min(value, 100))  // 限制在0-100范围内
        updateLabelPosition()
        setNeedsDisplay() // 重绘
    }
}



//class RulerProgressView: UIView {
//    
//    // MARK: - Properties
//    private var totalMarks: Int = 101           // 总刻度数（每两个刻度表示2音量值）
//    private var currentValue: Int = 0           // 当前值
//    private let rulerLineWidth: CGFloat = 1.ckValue()     // 刻度线宽度
//    private var rulerSpacing: CGFloat = 0       // 动态计算的刻度间距
//    private let markHeight: CGFloat = 12.ckValue()        // 普通刻度高度
//    private let longMarkHeight: CGFloat = 20.ckValue()    // 长刻度高度
//    private let importantMarkHeight: CGFloat = 30.ckValue() // 关键刻度高度
//    
//    // 动态标签
//    private let valueLabel = UILabel()
//    
//    // 颜色配置
//    private let progressColor = ThemeColorType.color9.color().withAlphaComponent(0.58)     // 当前进度色块颜色
//    private let rulerColor = UIColor.secondaryLabel  // 刻度颜色
//    private let pointerColor = UIColor.accent      // 当前指针颜色
//    
//    // 值变化回调
//    var valueChanged: ((Int) -> Void)?
//    
//    // MARK: - Initialization
//    init(frame: CGRect, totalMarks: Int = 101) {
//        self.totalMarks = totalMarks
//        super.init(frame: frame)
//        backgroundColor = .clear
//        setupLabel()
//        setupGesture()
//    }
//    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        backgroundColor = .clear
//        setupLabel()
//        setupGesture()
//    }
//    
//    // 设置动态标签
//    private func setupLabel() {
//        valueLabel.textColor = pointerColor
//        valueLabel.font = UIFont.boldSystemFont(ofSize: 14)
//        valueLabel.textAlignment = .center
//        valueLabel.text = "0"
//        valueLabel.translatesAutoresizingMaskIntoConstraints = true
//        addSubview(valueLabel)
//    }
//    
//    // 添加手势
//    private func setupGesture() {
//        // 拖动手势
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
//        addGestureRecognizer(panGesture)
//        
//        // 点击手势
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
//        addGestureRecognizer(tapGesture)
//    }
//    
//    // MARK: - Layout
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        calculateSpacing()
//        updateLabelPosition()
//        setNeedsDisplay() // 重新绘制
//    }
//    
//    // 动态计算刻度间距
//    private func calculateSpacing() {
//        guard totalMarks > 1 else { return }
//        rulerSpacing = bounds.width / CGFloat(totalMarks - 1)
//    }
//    
//    // 更新标签位置
//    private func updateLabelPosition() {
//        let pointerX = CGFloat(currentValue / 2) * rulerSpacing
//        valueLabel.frame = CGRect(x: pointerX - 20.ckValue(), y: bounds.height / 2 - importantMarkHeight - 20.ckValue(), width: 40.ckValue(), height: 20.ckValue())
//        valueLabel.text = "\(currentValue)"
//    }
//    
//    // MARK: - Drawing
//    override func draw(_ rect: CGRect) {
//        guard totalMarks > 0 else { return }
//        let context = UIGraphicsGetCurrentContext()
//        let centerY = rect.height / 2
//        
//        // 绘制当前进度色块
//        context?.setFillColor(progressColor.cgColor)
//        let progressRect = CGRect(x: 0, y: centerY - importantMarkHeight / 2, width: CGFloat(currentValue / 2) * rulerSpacing, height: importantMarkHeight)
//        context?.fill(progressRect)
//        
//        // 绘制刻度线
//        for i in 0..<totalMarks {
//            let x = CGFloat(i) * rulerSpacing
//            var lineHeight = markHeight
//            
//            if i % 5 == 0 { // 关键刻度
//                lineHeight = longMarkHeight
//            }
//            if i % 25 == 0 { // 0、50、100 等重要刻度
//                lineHeight = importantMarkHeight
//            }
//            
//            context?.setLineWidth(rulerLineWidth)
//            context?.setStrokeColor(rulerColor.cgColor)
//            context?.move(to: CGPoint(x: x, y: centerY - lineHeight / 2))
//            context?.addLine(to: CGPoint(x: x, y: centerY + lineHeight / 2))
//            context?.strokePath()
//            
//            // 绘制关键刻度值
//            if i % 25 == 0 {
//                let label = "\(i * 2)"
//                let attributes: [NSAttributedString.Key: Any] = [
//                    .font: UIFont.systemFont(ofSize: 10),
//                    .foregroundColor: UIColor.label
//                ]
//                let size = label.size(withAttributes: attributes)
//                var labelX = x - size.width / 2
//                let labelY = centerY + importantMarkHeight / 2 + 5
//                
//                // 调整第一个和最后一个刻度值的标签位置
//                if i == 0 {
//                    labelX = max(0, labelX) // 确保不超出左边界
//                } else if i == totalMarks - 1 {
//                    labelX = min(bounds.width - size.width, labelX) // 确保不超出右边界
//                }
//                
//                label.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: attributes)
//            }
//        }
//        
//        // 绘制当前指针
//        let pointerX = CGFloat(currentValue / 2) * rulerSpacing
//        context?.setLineWidth(2.ckValue())
//        context?.setStrokeColor(pointerColor.cgColor)
//        context?.move(to: CGPoint(x: pointerX, y: centerY - importantMarkHeight))
//        context?.addLine(to: CGPoint(x: pointerX, y: centerY + importantMarkHeight))
//        context?.strokePath()
//    }
//    
//    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
//        let translationX = gesture.translation(in: self).x
//        let deltaValue = Int(translationX / rulerSpacing) * 2
//        let newValue = max(0, min((totalMarks - 1) * 2, currentValue + deltaValue))
//        
//        if newValue != currentValue {
//            currentValue = newValue
//            updateLabelPosition()
//            setNeedsDisplay() // 重绘
//        }
//        
//        // 重置拖动偏移
//        gesture.setTranslation(.zero, in: self)
//        
//        // 仅在松手时回调
//        if gesture.state == .ended {
//            self.valueChanged?(currentValue)
//        }
//    }
//    
//    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
//        let location = gesture.location(in: self)
//        let newValue = Int(location.x / rulerSpacing) * 2
//        currentValue = max(0, min((totalMarks - 1) * 2, newValue))
//        valueChanged?(currentValue)
//        updateLabelPosition()
//        setNeedsDisplay() // 重绘
//    }
//    
//    // MARK: - Public Methods
//    func setValue(_ value: Int) {
//        currentValue = max(0, min(value, (totalMarks - 1) * 2))
//        updateLabelPosition()
//        setNeedsDisplay() // 重绘
//    }
//}
//

