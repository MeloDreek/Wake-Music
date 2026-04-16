//
//  PlayerStyleTapeTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/23/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class PlayerStyleTapeTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(collectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var tapeArray: [PlayerUIStyle] = [] {
        didSet {
            collectionView.frame = contentView.bounds

            let tapeWidth = (self.bounds.width - Self.itemSpace * 3) / 2 - 1
            let tapeImage: UIImage = UIImage(named: "tape_back")!
            let tapeValue = tapeImage.size.height / tapeImage.size.width
            let tapeHeight = tapeWidth * tapeValue + 30.ckValue()
            
            self.flowLayout.itemSize = CGSizeMake(tapeWidth, tapeHeight)
            self.collectionView.reloadData()
        }
    }
    
    /// 间距
    static var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 5.ckValue()
            case .iPadOS: return 8.ckValue()
            case .macOS: return 5.ckValue()
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
        view.register(SelectTapeCollectionCell.self, forCellWithReuseIdentifier: "SelectTapeCollectionCell")
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
        return self.tapeArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectTapeCollectionCell", for: indexPath) as! SelectTapeCollectionCell
        cell.itemType = self.tapeArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let itemType = self.tapeArray[indexPath.row]
        self.onClickCallBack?(itemType)
    }
    
}


class SelectTapeCollectionCell: UICollectionViewCell {
    
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
        contentView.addSubview(tapeView)
        contentView.addSubview(selectIconBtn)
    }
    
    private func setupAutoLayout() {
        
        tapeView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(30.ckValue())
        }
        
        selectIconBtn.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-8.ckValue())
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
            
            self.tapeView.playerStyle = itemType
            
            let isSelect = MusicConfigManager.shared.playerStyle == itemType
            self.selectIconBtn.isSelected = isSelect
        }
    }
    
    // MARK:  懒加载
    lazy var tapeView: TapePlayerView = {
        let view = TapePlayerView(frame: CGRectMake(0, 0, self.bounds.width, self.bounds.height - 30.ckValue()))
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
