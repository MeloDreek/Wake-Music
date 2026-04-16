//
//  AudioWaveformView.swift
//  Wake Music
//
//  Created by Melo on 9/11/24.
//

import KakaFoundation

class AudioWaveformView: UIView {
    
    deinit {
        debugPrint("### AudioWaveformView ###")
    }
    
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
        
    }
    
    private func preSetupContains() {
        
    }
    
    
    private func preSetupHandleBuness() {
        
    }
    
    // MARK:  GET && SET
    
    var samples: [Float] = []
    var audioURL: URL!

    func setSamples(_ samples: [Float], audioURL: URL) {
        self.samples = samples
        self.audioURL = audioURL
        self.setNeedsDisplay()  // 触发重新绘制
    }
    
    let strokeColor = appMainColor.cgColor
    
    // MARK:  懒加载

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // 先绘制波形
        self.drawWaveform(rect)
    }
    
    func drawWaveform(_ rect: CGRect) {
        guard samples.count > 0 else { return }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(1.0)
        context?.setStrokeColor(strokeColor)
        
        let middleY = rect.height / 2
        let step = max(1, samples.count / Int(rect.width))
        
        for x in stride(from: 0, to: samples.count, by: step) {
            let sample = samples[x]
            let scaledSample = CGFloat(sample) * middleY  // 缩放样本
            let y = middleY - scaledSample
            
            if x == 0 {
                context?.move(to: CGPoint(x: CGFloat(x) / CGFloat(step), y: y))
            } else {
                context?.addLine(to: CGPoint(x: CGFloat(x) / CGFloat(step), y: y))
            }
        }
        
        context?.strokePath()
    }
    
}

//protocol AudioWaveformViewDelegate: AnyObject {
//    func didUpdateSelection(startTime: TimeInterval, endTime: TimeInterval)
//}
//
//class AudioWaveformView: UIView {
//    
//    // MARK: - Properties
//    weak var delegate: AudioWaveformViewDelegate?
//    private var selectionStart: CGFloat = 0
//    private var selectionEnd: CGFloat = 0
//    private var isSelecting: Bool = false
//
//    // 其他属性
//    var samples: [Float] = []
//    var audioURL: URL!
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        self.preSetupSubViews()
//        self.preSetupContains()
//        self.preSetupHandleBuness()
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    private func preSetupSubViews() {
//        // 添加手势识别
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
//        self.addGestureRecognizer(panGesture)
//    }
//
//    private func preSetupContains() {
//        // 其他初始化代码
//    }
//
//    private func preSetupHandleBuness() {
//        // 其他业务逻辑
//    }
//
//    // MARK: - Get & Set
//    func setSamples(_ samples: [Float], audioURL: URL) {
//        self.samples = samples
//        self.audioURL = audioURL
//        self.setNeedsDisplay()  // 触发重新绘制
//    }
//
//    // MARK: - Draw
//    override func draw(_ rect: CGRect) {
//        super.draw(rect)
//        
//        // 先绘制波形
//        self.drawWaveform(rect)
//        
//        // 绘制选择框
//        self.drawSelectionBox(rect)
//    }
//    
//    func drawWaveform(_ rect: CGRect) {
//        guard samples.count > 0 else { return }
//        
//        let context = UIGraphicsGetCurrentContext()
//        context?.setLineWidth(1.0)
//        context?.setStrokeColor(appMainColor.cgColor)
//        
//        let middleY = rect.height / 2
//        let step = max(1, samples.count / Int(rect.width))
//        
//        for x in stride(from: 0, to: samples.count, by: step) {
//            let sample = samples[x]
//            let scaledSample = CGFloat(sample) * middleY  // 缩放样本
//            let y = middleY - scaledSample
//            
//            if x == 0 {
//                context?.move(to: CGPoint(x: CGFloat(x) / CGFloat(step), y: y))
//            } else {
//                context?.addLine(to: CGPoint(x: CGFloat(x) / CGFloat(step), y: y))
//            }
//        }
//        
//        context?.strokePath()
//    }
//    
//    func drawSelectionBox(_ rect: CGRect) {
//        guard isSelecting else { return }
//        
//        let selectionRect = CGRect(x: selectionStart, y: 0, width: selectionEnd - selectionStart, height: rect.height)
//        let context = UIGraphicsGetCurrentContext()
//        context?.setFillColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
//        context?.fill(selectionRect)
//    }
//
//    // MARK: - Gesture Handling
//    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
//        let location = gesture.location(in: self)
//        
//        switch gesture.state {
//        case .began:
//            isSelecting = true
//            selectionStart = location.x
//            selectionEnd = location.x
//        case .changed:
//            selectionEnd = location.x
//            delegate?.didUpdateSelection(startTime: timeForPosition(selectionStart), endTime: timeForPosition(selectionEnd))
//            setNeedsDisplay()  // 触发重新绘制
//        case .ended:
//            isSelecting = false
//            setNeedsDisplay()  // 触发重新绘制
//        default:
//            break
//        }
//    }
//    
//    // MARK: - Helper Methods
//    private func timeForPosition(_ position: CGFloat) -> TimeInterval {
//        let totalWidth = self.bounds.width
//        let totalSamples = samples.count
//        let sampleIndex = Int((position / totalWidth) * CGFloat(totalSamples))
//        return TimeInterval(sampleIndex) / 44100.0  // 假设采样率为44100Hz
//    }
//    
//}
