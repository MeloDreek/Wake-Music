//
//  EmptyDataTableCell.swift
//  Mobie
//
//  Created by 张文 on 3/29/25.
//

import KakaFoundation

class EmptyDataTableCell: UITableViewCell {
    
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
        contentView.addSubview(emptyLabel)
    }
    
    private func setupAutoLayout() {
        emptyLabel.snp.makeConstraints { make in
            make.top.equalTo(45.ckValue())
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.greaterThanOrEqualTo(emptyLabel.font.lineHeight)
            make.centerY.equalToSuperview()
        }
    }
    
    private func setupCusBuness() {
        
    }
    
    func updateMessage(_ msg: String = "No data available".localStr()) {
        emptyLabel.text = msg
        self.contentView.layoutIfNeeded()
    }
    
    lazy var emptyLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.text = "No data available".localStr()
        view.font = UIFontBold(16.ckValue())
        view.textColor = .secondaryLabel
        view.textAlignment = .center
        return view
    }()
    
}

