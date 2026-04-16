//
//  SearchTagTipsViewCell.swift
//  Mobie
//
//  Created by 张文 on 6/11/25.
//

import KakaFoundation
import AppGroupKit
import NVActivityIndicatorView

class SearchTagTipsViewCell: UITableViewCell {
    
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        
        contentView.addSubview(searchView)
        searchView.addSubview(titleField)
        searchView.addSubview(lineView)
        searchView.addSubview(artistField)
        
        searchView.addSubview(searchButton)
        contentView.addSubview(loadingView)
        
    }
    
    private func setupAutoLayout() {
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5.ckValue())
            make.leading.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(5.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        
        searchView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(descLabel.snp.bottom).offset(20.ckValue())
            make.leading.equalToSuperview()
            make.height.equalTo(50.ckValue())
            make.bottom.equalToSuperview().inset(10.ckValue())
        }
        
        let searchBtn = 50.ckValue()
        searchButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(searchBtn)
            make.height.equalToSuperview()
        }
        
        loadingView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(searchButton)
            make.size.equalTo(30.ckValue())
        }
        
        lineView.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(-searchBtn / 2)
            make.centerY.equalToSuperview()
            make.width.equalTo(1.ckValue())
            make.height.equalToSuperview().multipliedBy(0.6)
        }
        
        titleField.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.trailing.equalTo(lineView.snp.leading).offset(-5.ckValue())
        }
        
        artistField.snp.makeConstraints { make in
            make.trailing.equalTo(searchButton.snp.leading)
            make.centerY.equalToSuperview()
            make.height.equalToSuperview()
            make.leading.equalTo(lineView.snp.trailing).offset(5.ckValue())
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
        
        let placeAttbute1 = NSAttributedString(string: MusicActionType.title.formatStr(), attributes: [.font: UIFontLight(15.ckValue()), .foregroundColor: UIColor.placeholderText])
        titleField.attributedPlaceholder = placeAttbute1
        
        let placeAttbute2 = NSAttributedString(string: MusicActionType.artist.formatStr(), attributes: [.font: UIFontLight(15.ckValue()), .foregroundColor: UIColor.placeholderText])
        artistField.attributedPlaceholder = placeAttbute2
    }
    
    // MARK:  GET && SET
    var model: MusicItemModel? {
        didSet {
            titleField.text = model?.title
            artistField.text = model?.artist
        }
    }
    
    var onClickBlock: ((SearchTagTipsViewCell)->Void)?
    
    
    // MARK:  懒加载
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Special Warning".localStr()
        view.font = UIFontBold(20.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.text = "The title of the file and the artist name determine the cover art and lyrics results. Due to the instability of AI search, this feature is only for reference. If you believe the data is incorrect, please modify the title and artist name, or manually paste the lyrics text.".localStr()
        view.font = UIFontLight(14.ckValue())
        view.textAlignment = .center
        return view
    }()
    
    lazy var searchView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.backgroundColor = .systemFill
        return view
    }()
    
    lazy var titleField: UITextField = {
        let view = UITextField()
        view.font = UIFontLight(13.ckValue())
        view.textAlignment = .center
        view.clearButtonMode = .whileEditing
        view.leftView = UIView(frame: CGRectMake(0, 0, 5.ckValue(), 20))
        view.leftViewMode = .always
        view.returnKeyType = .done
        return view
    }()
    
    lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        return view
    }()
    
    lazy var artistField: UITextField = {
        let view = UITextField()
        view.font = titleField.font
        view.textAlignment = .center
        view.clearButtonMode = .whileEditing
        view.leftView = UIView(frame: CGRectMake(0, 0, 5.ckValue(), 20))
        view.leftViewMode = .always
        view.returnKeyType = .done
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
    lazy var searchButton: UIButton = {
        let view = UIButton(type: .custom)
        view.backgroundColor = appMainColor
        view.frame = CGRectMake(0, 0, 40.ckValue(), 40.ckValue())
        view.setImage(Reasource.systemNamed("magnifyingglass", color: .deAccent), for: .normal)
        view.addTarget(self, action: #selector(searchButtonClick(_:)), for: .touchUpInside)
        return view
    }()
    
    @objc func searchButtonClick(_ sender: UIButton) {
        self.onClickBlock?(self)
    }
    
}

