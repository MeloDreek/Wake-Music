//
//  MatchingProgressView.swift
//  Mobie
//
//  Created by kaka on 2026/8/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

/// 正在匹配中的进度条
class MatchingProgressView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        self.addSubview(progressView)
        self.addSubview(numberLabel)
        self.addSubview(percentLabel)
    }
    
    private func setupAutoLayout() {
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(21.ckValue())
            make.centerY.equalToSuperview().offset(-8.ckValue())
            make.centerX.equalToSuperview()
            make.height.equalTo(8.ckValue())
        }
        
        numberLabel.snp.makeConstraints { make in
            make.leading.equalTo(progressView).offset(5.ckValue())
            make.top.equalTo(progressView.snp.bottom).offset(5.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        percentLabel.snp.makeConstraints { make in
            make.trailing.equalTo(progressView).offset(-5.ckValue())
            make.centerY.equalTo(numberLabel)
            make.size.greaterThanOrEqualTo(0)
        }
        
        
    }
    
    private func setupCusBuness() {
        self.update(current: 0, total: 0)

    }
    
    // MARK:  GET && SET
    
    var onCancelBlock: (()->Void)?
    
    
    // MARK: - 替换 update 方法
    func update(current: Int, total: Int) {
        guard total > 0 else {
            progressView.progress = 0
            numberLabel.text = "0/0"
            percentLabel.text = "0.0%"
            return
        }
        
        let progress = Float(current) / Float(total)
        progressView.progress = min(max(progress, 0), 1)
        numberLabel.text = "\(current)/\(total)"
        percentLabel.text = String(format: "%.2f%%", progress * 100)
    }
    
    // MARK:  懒加载
    lazy var progressView: RTLProgressView = {
        let view = RTLProgressView()
        view.isUserInteractionEnabled = false
        view.trackColor = UIColor.systemBackground.withAlphaComponent(0.5)
        view.progressColor = .systemBackground
        return view
    }()
    
    // 数量比
    lazy var numberLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.font = percentLabel.font
        view.textColor = percentLabel.textColor
        view.textAlignment = percentLabel.textAlignment
        return view
    }()
    
    // 百分比
    lazy var percentLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.font = UIFontLight(13.ckValue())
        view.textColor = .systemBackground
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        return view
    }()
    
}

