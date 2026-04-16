//
//  PlayerStyleVinylTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/23/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class PlayerStyleVinylTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(collectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var vinyArray: [PlayerUIStyle] = [] {
        didSet {
            collectionView.frame = contentView.bounds

            let width = (self.bounds.width - Self.itemSpace * 3) / 2 - 1
            self.flowLayout.itemSize = CGSizeMake(width, width * 0.88 + 80.ckValue())
            self.collectionView.reloadData()
        }
    }
    
    /// 间距
    static var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 15.ckValue()
            case .iPadOS: return 18.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    var onClickCallBack: ((PlayerUIStyle)->Void)?
    
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.isScrollEnabled = false
        view.alwaysBounceVertical = false
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: Self.itemSpace, left: Self.itemSpace, bottom: 0, right: Self.itemSpace)
        view.contentInsetAdjustmentBehavior = .automatic
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(SelectVinylCollectionCell.self, forCellWithReuseIdentifier: "SelectVinylCollectionCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = Self.itemSpace
        layout.minimumInteritemSpacing = Self.itemSpace
        return layout
    }()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.vinyArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectVinylCollectionCell", for: indexPath) as! SelectVinylCollectionCell
        cell.itemType = self.vinyArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let itemType = self.vinyArray[indexPath.row]
        self.onClickCallBack?(itemType)
    }
    
}


class SelectVinylCollectionCell: UICollectionViewCell {
    
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
        contentView.addSubview(vinylBackView)
        contentView.addSubview(selectIconBtn)
        
        vinylBackView.addSubview(coverImgView)
    }
    
    private func setupAutoLayout() {
        vinylBackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20.ckValue())
            make.width.equalToSuperview().multipliedBy(0.88)
            make.height.equalTo(vinylBackView.snp.width)
        }
        
        coverImgView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalToSuperview().multipliedBy(0.45)
        }
        
        selectIconBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20.ckValue())
            make.size.equalTo(selectIconBtn.size)
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    var itemType: PlayerUIStyle? {
        didSet {
            guard let itemType = self.itemType else { return }
            
            vinylBackView.image = itemType.iconImage()
            
            let isSelect = MusicConfigManager.shared.playerStyle == itemType
            self.selectIconBtn.isSelected = isSelect
        }
    }
    
    // MARK:  懒加载
    lazy var vinylBackView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "app_logo_circle"))
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var selectIconBtn: UIButton = {
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(20.ckValue(), 20.ckValue())
        view.setImage(UIImage(systemName: "circle"), for: .normal)
        view.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        return view
    }()
    
}

