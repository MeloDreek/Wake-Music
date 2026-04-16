//
//  GradientLabel.swift
//  KakaUIKit
//
//  Created by Melo Dreek on 2023/5/7.
//

import KakaFoundation

/// 渐变色Label
public class GradientLabel: UILabel {
    
    private var colors: [UIColor] = [UIColor.systemBlue, KakaColor.hexColor("#FF00FF")]
    
    private var startPoint: CGPoint = CGPoint(x: 0.0, y: 0)
    
    private var endPoint: CGPoint = CGPoint(x: 1.0, y: 1)
    
    private var textColorLayer: CAGradientLayer = CAGradientLayer()
    
    // MARK: - Life cycle
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        applyColors()
    }
    
    // MARK: - Public functions
    public func update(colors: [KakaColor], startPoint: CGPoint, endPoint: CGPoint) {
        
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
        applyColors()
    }
    
    // MARK: - Private functions
    private func setup() {
        
        isAccessibilityElement = true
        applyColors()
    }
    
    private func applyColors() {
        
        let gradient = getGradientLayer(bounds: self.bounds)
        self.textColor = gradientColor(bounds: self.bounds, gradientLayer: gradient)
    }
    
    private func getGradientLayer(bounds: CGRect) -> CAGradientLayer {
        
        textColorLayer.frame = bounds
        textColorLayer.colors = colors.map{ $0.cgColor }
        textColorLayer.startPoint = startPoint
        textColorLayer.endPoint = endPoint
        return textColorLayer
    }
    
}

extension UIView {

    fileprivate func gradientColor(bounds: CGRect, gradientLayer: CAGradientLayer) -> UIColor? {
        
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        gradientLayer.render(in: context)
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        UIGraphicsEndImageContext()
        return UIColor(patternImage: image)
    }
    
}
