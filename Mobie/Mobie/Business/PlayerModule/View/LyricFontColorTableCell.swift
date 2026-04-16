//
//  LyricFontColorTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/28/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

/// 歌词字体颜色
class LyricFontColorTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
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
        contentView.addSubview(collectionView)
    }
    
    private func setupAutoLayout() {
        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.centerY.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(self.flowLayout.itemSize.height)
        }
    }
    
    private func setupCusBuness() {
        self.selectionStyle = .none
    }
    
    // MARK:  GET && SET
    var itemType: LyricSetCellGroup? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            self.colorArray = itemType.recommentColors()
            self.collectionView.reloadData()
        }
    }
    
    /// 间距
    var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 15.ckValue()
            case .iPadOS: return 18.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    lazy var colorArray: [String?] = {
        return [String?]()
    }()
    
    // MARK:  懒加载
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.alwaysBounceVertical = false
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: 0, left: self.itemSpace, bottom: 0, right: self.itemSpace)
        view.contentInsetAdjustmentBehavior = .automatic
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(SelectFontColorlCollectionCell.self, forCellWithReuseIdentifier: "SelectFontColorlCollectionCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = self.itemSpace
        layout.minimumInteritemSpacing = self.itemSpace
        layout.itemSize = CGSizeMake(50.ckValue(), 80.ckValue())
        return layout
    }()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.colorArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectFontColorlCollectionCell", for: indexPath) as! SelectFontColorlCollectionCell
        let subColor = self.colorArray[indexPath.row]
        var isSelect: Bool = false
        if self.itemType == .norColorGroup {
            isSelect = MusicConfigManager.shared.lyricConfig.norFontColor == subColor
        }else{
            isSelect = MusicConfigManager.shared.lyricConfig.selFontColor == subColor
        }
        cell.update(hex16String: subColor, isSelect: isSelect)
        cell.onClickBlock = { [weak self] (selColor) in
            self?.selectColor(selColor.hex16String)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let subColor = self.colorArray[indexPath.row] else {
            
            return
        }
        
        self.selectColor(subColor)
    }
    
    func selectColor(_ hexString: String) {
        var lyricCondig = MusicConfigManager.shared.lyricConfig
        if self.itemType == .norColorGroup {
            lyricCondig.norFontColor = hexString
        }else{
            lyricCondig.selFontColor = hexString
        }
        
        MusicConfigManager.shared.lyricConfig = lyricCondig
        self.collectionView.reloadData()
    }
}

class SelectFontColorlCollectionCell: UICollectionViewCell {
    
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
        contentView.addSubview(colorBackView)
        contentView.addSubview(selectIconView)
        contentView.addSubview(colorWell)
    }
    
    private func setupAutoLayout() {
        colorBackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(colorBackView.layer.cornerRadius * 2)
        }
        
        selectIconView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(selectIconView)
        }
        
        colorWell.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(colorWell.layer.cornerRadius * 2)
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    func update(hex16String: String?, isSelect: Bool) {
        selectIconView.isHidden = !isSelect
        if let hex16String = hex16String {
            colorBackView.backgroundColor = UIColor.hexColor(hex16String)
            colorWell.isHidden = true
        }else{
            colorBackView.backgroundColor = .clear
            colorWell.isHidden = false
        }
    }
    
    var onClickBlock: ((UIColor)->Void)?
    
    
    // MARK:  懒加载
    lazy var colorBackView: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 20.ckValue()
        return view
    }()
    
    lazy var selectIconView: UIImageView = {
        let iconSize = colorBackView.layer.cornerRadius * 2
        let graderLayerColors = [UIColor.systemGreen.cgColor, UIColor.black.cgColor]

        let view = UIImageView(image: Reasource.systemNamed("circle.circle.fill", color: .label))
        view.frame = CGRectMake(0, 0, iconSize * 0.5, iconSize * 0.5)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var colorWell: UIColorWell = {
        let view = UIColorWell(frame: CGRect(x: 0, y: 0, width: 50.ckValue(), height: 50.ckValue()))
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 25.ckValue()
        view.center = view.center
        view.addTarget(self, action: #selector(colorWellChanged(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func colorWellChanged(_ sender: UIColorWell) {
        guard let selColor = sender.selectedColor else {
            return
        }
        
        self.onClickBlock?(selColor)
    }
    
}

