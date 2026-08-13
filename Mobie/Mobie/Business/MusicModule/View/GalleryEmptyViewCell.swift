//
//  GalleryEmptyViewCell.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView

class GalleryEmptyViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(emptyLabel)
        contentView.addSubview(loadingView)
    }
    
    func preSetupContains() {
        loadingView.snp.makeConstraints { make in
            make.top.equalTo(30.ckValue())
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(loadingView.size)
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.equalTo(10.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    func preSetupHandleBuness() {
        self.loadingView.startAnimating()
    }
    
    // MARK:  GET && SET
    var isRequesting: Bool = false {
        didSet {
            if isRequesting {
                self.loadingView.startAnimating()
            }else{
                self.loadingView.stopAnimating()
            }
            
            emptyLabel.isHidden = isRequesting
        }
    }
    
    // MARK:  懒加载
    
    lazy var emptyLabel: UILabel = {
        let view = UILabel()
        
        view.font = UIFontBold(16.ckValue())
        view.textAlignment = .center
        view.textColor = .secondaryLabel
        view.text = KakaError.emptyData.errorDescription
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
}

