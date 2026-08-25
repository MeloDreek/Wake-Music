//
//  KakSliderControl.swift
//  KakaUIKit
//
//  Created by 张文 on 5/19/25.
//

import Combine
import UIKit


/// Implements a slider control similar to one found in Apple Music on iOS 16.
open class KakSliderControl: UIControl {
    public var isContinuous: Bool = false // 设为 false，以便在松手时回调
    public let trackLayoutGuide: UILayoutGuide = .init()
    public var feedbackGenerator: (any SliderFeedbackGenerator)? = ImpactSliderFeedbackGenerator()
    open var defaultTrackColor: UIColor = .secondarySystemFill {
        didSet {
            updateColors()
        }
    }
    open var defaultProgressColor: UIColor = .systemFill {
        didSet {
            updateColors()
        }
    }
    open var enlargedTrackColor: UIColor? {
        didSet {
            updateColors()
        }
    }
    open var enlargedProgressColor: UIColor? {
        didSet {
            updateColors()
        }
    }

    public var minimumValue: Float = 0
    public var maximumValue: Float = 1
    
    public var valueRange: ClosedRange<Float> = 0...1

    // 1. 允许通过 isSliderInteracting 保护 value 赋值
    public var value: Float {
        get {
            let progress = Float(progressView.bounds.width / trackView.bounds.width)
            return Self.internalValueRange.convert(value: progress, to: valueRange)
        }
        set {
            // 取消这行的注释：如果用户正在触摸/拖拽控件，忽略来自外部播放器的 UI 更新
            guard !self.isSliderInteracting else { return }

            let clampedValue = max(valueRange.lowerBound, min(valueRange.upperBound, newValue))
            let convertedValue = valueRange.convert(value: clampedValue, to: Self.internalValueRange)
            progressConstraint = progressConstraint.constraintWithMultiplier(CGFloat(convertedValue))
        }
    }

    private var isSliderInteracting: Bool = false

    public var onEditingChanged: ((Bool) -> Void)?
    
    public var valuePublisher: AnyPublisher<Float, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: Self.intrinsicHeight)
    }

    private static let intrinsicHeight: CGFloat = 24
    private static let defaultTrackHeight: CGFloat = 7
    private static let enlargedTrackHeight: CGFloat = 12
    private static let internalValueRange: ClosedRange<Float> = 0...1

    private let trackView: UIView = .init()
    private let progressView: UIView = .init()

    private let valueSubject: PassthroughSubject<Float, Never> = .init()

    private var heightConstraint: NSLayoutConstraint = .init()
    private var progressConstraint: NSLayoutConstraint = .init()
    private var hasPreviousSessionChangedProgress: Bool = false

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        trackView.layer.cornerRadius = trackView.bounds.height / 2
    }

    // 2. 修改点击开始逻辑：不再立即触发 valueSubject.send
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        self.isSliderInteracting = true
        onEditingChanged?(true)
        enlargeTrack()
        feedbackGenerator?.preapre()

        // 仅更新UI视图表现，并标记 Session 已变动，以便松手时统一 send
        let location = touch.location(in: self)
        let progress = max(0, min(1, location.x / trackView.bounds.width))
        progressConstraint = progressConstraint.constraintWithMultiplier(progress)
        
        hasPreviousSessionChangedProgress = true
        return true
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let previousLocation = touch.previousLocation(in: self)
        let location = touch.location(in: self)
        let translationX = location.x - previousLocation.x
        let newWidth = effectiveUserInterfaceLayoutDirection == .leftToRight
            ? progressView.bounds.width + translationX
            : progressView.bounds.width - translationX

        let progress = progressView.bounds.width / trackView.bounds.width
        let newProgress = max(0, min(1, newWidth / trackView.bounds.width))

        if newProgress != progress {
            switch newProgress {
                case 0:
                    feedbackGenerator?.generateMinimumValueFeedback()
                case 1:
                    feedbackGenerator?.generateMaximumValueFeedback()
                default:
                    break
            }
        }

        progressConstraint = progressConstraint.constraintWithMultiplier(newProgress)

        hasPreviousSessionChangedProgress = true
        return true
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        reduceTrack()

        if hasPreviousSessionChangedProgress {
            hasPreviousSessionChangedProgress = false
            // 仅在松手时发送值
            valueSubject.send(value)
            sendActions(for: .valueChanged)
        }

        self.isSliderInteracting = false
        onEditingChanged?(false)
    }

    public override func cancelTracking(with event: UIEvent?) {
        reduceTrack()

        if hasPreviousSessionChangedProgress {
            hasPreviousSessionChangedProgress = false
            // 仅在取消时发送值
            valueSubject.send(value)
            sendActions(for: .valueChanged)
        }

        self.isSliderInteracting = false
        onEditingChanged?(false)
    }

    private func setup() {
        isMultipleTouchEnabled = false
        backgroundColor = .clear

        trackView.isUserInteractionEnabled = false
        trackView.clipsToBounds = true
        trackView.backgroundColor = defaultTrackColor
        trackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackView)

        addLayoutGuide(trackLayoutGuide)

        progressView.isUserInteractionEnabled = false
        progressView.clipsToBounds = true
        progressView.backgroundColor = defaultProgressColor
        progressView.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(progressView)

        heightConstraint = trackView.heightAnchor.constraint(equalToConstant: Self.defaultTrackHeight)
        progressConstraint = progressView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: 0.5)

        NSLayoutConstraint.activate([
            heightConstraint,
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),

            trackLayoutGuide.topAnchor.constraint(equalTo: trackView.topAnchor),
            trackLayoutGuide.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            trackView.bottomAnchor.constraint(equalTo: trackLayoutGuide.bottomAnchor),
            trackView.trailingAnchor.constraint(equalTo: trackLayoutGuide.trailingAnchor),

            progressConstraint,
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor)
        ])
    }

    private func enlargeTrack() {
        heightConstraint.constant = Self.enlargedTrackHeight
        setNeedsLayout()

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.curveEaseIn, .allowAnimatedContent, .allowUserInteraction]
        ) { [unowned self] in
            enlargedTrackColor.map { trackView.backgroundColor = $0 }
            enlargedProgressColor.map { progressView.backgroundColor = $0 }
            layoutIfNeeded()
        }
    }

    private func reduceTrack() {
        heightConstraint.constant = Self.defaultTrackHeight
        setNeedsLayout()

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: [.curveEaseOut, .allowAnimatedContent, .allowUserInteraction]
        ) { [unowned self] in
            trackView.backgroundColor = defaultTrackColor
            progressView.backgroundColor = defaultProgressColor
            layoutIfNeeded()
        }
    }

    private func updateColors() {
        if heightConstraint.constant == Self.defaultTrackHeight {
            trackView.backgroundColor = defaultTrackColor
            progressView.backgroundColor = defaultProgressColor
        } else {
            enlargedTrackColor.map { trackView.backgroundColor = $0 }
            enlargedProgressColor.map { progressView.backgroundColor = $0 }
        }
    }

    private func updateProgress(for location: CGPoint) {
        // 计算新进度
        let progress = max(0, min(1, location.x / trackView.bounds.width))
        progressConstraint = progressConstraint.constraintWithMultiplier(progress)
        
        // 发布新值
        valueSubject.send(value)
        
        // 更新 UI
        if isContinuous {
            sendActions(for: .valueChanged)
        }
    }
}

