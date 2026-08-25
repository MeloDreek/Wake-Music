//
//  LoadingButton.swift
//  KakaUIKit
//
//  Created by kaka on 2026/8/24.
//

import KakaFoundation

public class LoadingButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(loadingView.size)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var buttonTitle: String?
    
    public var isLoading: Bool {
        get {
            return self.loadingView.isAnimating
        }
    }
        
    private lazy var loadingView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(frame: CGRectMake(0, 0, 30.ckValue(), 30.ckValue()))
        view.color = .white
        view.style = .medium
        return view
    }()
    
    public func startLoading() {
        self.buttonTitle = self.currentTitle
        self.setTitle(nil, for: .normal)
        self.loadingView.startAnimating()
    }
    
    public func stopLoading() {
        self.setTitle(self.buttonTitle, for: .normal)
        self.loadingView.stopAnimating()
    }
}

