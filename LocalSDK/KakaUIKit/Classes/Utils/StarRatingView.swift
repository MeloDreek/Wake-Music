//
//  StarRatingView.swift
//  KakaUIKit
//
//  Created by 张文 on 11/20/24.
//

import KakaFoundation

public class StarRatingView: UIView {
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(stackView)
    }
    
    private func preSetupContains() {
        stackView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview()
            make.width.greaterThanOrEqualTo(0)
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    private func preSetupHandleBuness() {
        for _ in 0..<starCount {
            let imageView = UIImageView(image: Self.systemNamed("star", color: starColor))
            imageView.contentMode = .scaleAspectFit
            stackView.addArrangedSubview(imageView)
            stars.append(imageView)
        }
        
    }
    
    public func setRating(_ rating: Int) {
        for (index, imageView) in stars.enumerated() {
            if index < rating {
                imageView.image = Self.systemNamed("star.fill", color: starColor)
            } else {
                imageView.image = Self.systemNamed("star", color: starColor)
            }
        }
    }
    
    // MARK:  GET && SET
    private let starCount = 5
    private var stars = [UIImageView]()
    private let starColor = UIColor.hexColor("#FFA500")
    
    // MARK:  Lazy Init
    
    lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .leading
        view.distribution = .fillEqually
        view.spacing = 1.ckValue()
        return view
    }()
    
}

extension StarRatingView {
    public static func systemNamed(_ name: String, color: UIColor = UIColor.systemBlue) -> UIImage {
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let config = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        
        let image = UIImage(systemName: name, compatibleWith: config)
                
        return image?.withRenderingMode(.alwaysOriginal).withTintColor(color) ?? UIImage()
    }
}
