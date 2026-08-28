//
//  RTLProgressView.swift
//  KakaUIKit
//
//  Created by kaka on 2026/8/28.
//

import KakaFoundation
import SnapKit

/// 专门用于匹配/下载卡片的轻量进度条（无交互、支持 RTL 自动镜像）
public class RTLProgressView: UIView {
    
    public var progress: Float = 0 {
        didSet {
            let clamped = max(0, min(1, progress))
            progressWidthConstraint?.isActive = false
            progressView.snp.makeConstraints { make in
                self.progressWidthConstraint = make.width.equalToSuperview().multipliedBy(CGFloat(clamped)).constraint
            }
            self.layoutIfNeeded()
        }
    }
    
    public var trackColor: UIColor = UIColor.systemBackground.withAlphaComponent(0.5) {
        didSet { trackView.backgroundColor = trackColor }
    }
    
    public var progressColor: UIColor = .systemBackground {
        didSet { progressView.backgroundColor = progressColor }
    }
    
    private let trackView = UIView()
    private let progressView = UIView()
    private var progressWidthConstraint: SnapKit.Constraint?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        self.backgroundColor = .clear
        
        trackView.backgroundColor = trackColor
        trackView.clipsToBounds = true
        addSubview(trackView)
        
        progressView.backgroundColor = progressColor
        progressView.clipsToBounds = true
        trackView.addSubview(progressView)
        
        trackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 🔴 使用 SnapKit 的 leading / trailing / top / bottom
        // iOS 在 RTL（阿拉伯语/希伯来语）模式下会自动将 leading 识别为物理右侧，从而实现完美的从右往左填充！
        progressView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            self.progressWidthConstraint = make.width.equalToSuperview().multipliedBy(0).constraint
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // 保持圆角外观
        let radius = bounds.height / 2
        trackView.layer.cornerRadius = radius
        progressView.layer.cornerRadius = radius
    }
}
