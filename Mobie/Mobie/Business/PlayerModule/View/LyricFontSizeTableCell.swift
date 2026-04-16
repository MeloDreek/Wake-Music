//
//  LyricFontSizeTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import AppGroupKit

/// 歌词字体大小
class LyricFontSizeTableCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(minLabel)
        contentView.addSubview(maxLabel)
        contentView.addSubview(sliderView)
        contentView.addSubview(curLabel)
    }
    
    private func setupAutoLayout() {
        maxLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(10.ckValue())
            make.top.equalToSuperview().offset(10.ckValue())
            make.bottom.equalToSuperview().offset(-30.ckValue())
            make.size.equalTo(maxLabel.size)
        }
        
        minLabel.snp.makeConstraints { make in
            make.centerY.equalTo(maxLabel)
            make.leading.equalToSuperview().offset(10.ckValue())
            make.size.equalTo(maxLabel)
        }
        
        sliderView.snp.makeConstraints { make in
            make.leading.equalTo(minLabel.snp.trailing).offset(5.ckValue())
            make.trailing.equalTo(maxLabel.snp.leading).offset(-5.ckValue())
            make.height.equalTo(30.ckValue())
            make.centerY.equalTo(maxLabel)
        }
        
        curLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(maxLabel.snp.bottom)
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    private func setupCusBuness() {
        self.selectionStyle = .none
    }
    
    // MARK:  GET && SET
    
    let minimumValue: Float = 10.0
    let maximumValue: Float = 50.0
    
    var itemType: LyricSetCellGroup? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            let lyricConfig = MusicConfigManager.shared.lyricConfig
            if itemType == .norFontGroup {
                sliderView.value = lyricConfig.norFontSize
            }else{
                sliderView.value = lyricConfig.selFontSize
            }
            
            curLabel.text = String(format: "%.f", sliderView.value)
        }
    }
    
    // MARK:  懒加载
    
    lazy var minLabel: UILabel = {
        let font = UIFontLight(20.ckValue())
        let view = UILabel(frame: maxLabel.bounds)
        view.text = "A"
        view.textColor = .label
        view.textAlignment = .center
        view.font = font
        return view
    }()
    
    lazy var maxLabel: UILabel = {
        let font = UIFontBold(25.ckValue())
        let view = UILabel(frame: CGRectMake(0, 0, font.lineHeight * 1.2, font.lineHeight * 1.2))
        view.text = "A"
        view.textColor = .label
        view.textAlignment = .center
        view.font = font
        return view
    }()
    
    lazy var curLabel: UILabel = {
        let view = UILabel()
        view.text = "16"
        view.textColor = .label
        view.font = UIFontBold(16.ckValue())
        return view
    }()
    
    lazy var sliderView: UISlider = {
        let view = UISlider()
        view.minimumValue = minimumValue
        view.maximumValue = maximumValue
        view.addTarget(self, action: #selector(sliderViewVauleChanged(_:)), for: .valueChanged)
        view.addTarget(self, action: #selector(sliderViewEndTouchup(_:)), for: .touchUpInside)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(sliderTapped(_:)))
        view.addGestureRecognizer(tapGesture)
        #if !targetEnvironment(macCatalyst)
        let config1 = UIImage.SymbolConfiguration(pointSize: 10.ckValue(), weight: .light)
        let image1 = Reasource.systemNamed("circle.fill", color: .white, config: config1)
        
        let config2 = UIImage.SymbolConfiguration(pointSize: 20.ckValue(), weight: .light)
        let image2 = Reasource.systemNamed("circle.fill", color: .white, config: config2)
        
        view.minimumTrackTintColor = .white
        view.setThumbImage(image1, for: .normal)
        view.setThumbImage(image2, for: .highlighted)
        #endif
        return view
    }()
    
    // 点击进度条
    @objc func sliderTapped(_ gesture: UITapGestureRecognizer) {
        guard let slider = gesture.view as? UISlider else { return }
        let point = gesture.location(in: slider)

        // 计算点击的横向位置占 UISlider 宽度的比例
        let percentage = point.x / slider.bounds.width

        // 计算新的值
        let newValue = Float(percentage) * (slider.maximumValue - slider.minimumValue) + slider.minimumValue

        // 设置 UISlider 的值
        slider.setValue(newValue, animated: true)

        // 如果 UISlider 控制播放进度，则在此处更新播放进度
        self.sliderViewEndTouchup(slider)
    }
    
    // 拖动进度条
    @objc func sliderViewVauleChanged(_ sender: UISlider) {
                
        let progress = sender.value
        sender.value = progress
        
        curLabel.text = String(format: "%.f", sender.value)
    }
    
    // 手指松开
    @objc func sliderViewEndTouchup(_ sender: UISlider) {
        
        curLabel.text = String(format: "%.f", sender.value)
        
        var lyricConfig = MusicConfigManager.shared.lyricConfig
        if self.itemType == .norFontGroup {
            lyricConfig.norFontSize = sender.value
        }else{
            lyricConfig.selFontSize = sender.value
        }
        
        MusicConfigManager.shared.lyricConfig = lyricConfig
    }
    
}

