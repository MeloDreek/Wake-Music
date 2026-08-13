//
//  SearchArtistTableCell.swift
//  Mobie
//
//  Created by kaka on 2026/4/27.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit


/// 横向的歌手
class SearchArtistTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
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
        contentView.addSubview(emptyLabel)
    }
    
    private func setupAutoLayout() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        emptyLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    private func setupCusBuness() {
        
    }
    
    // MARK:  GET && SET
    
    var onClickBlock: ((NavidromeArtist)->Void)?
    
    var artistArray: [NavidromeArtist] = [] {
        didSet {
            self.emptyLabel.isHidden = !artistArray.isEmpty
            self.collectionView.reloadData()
        }
    }
    
    static func headHeight() -> CGFloat {
        let headHeight = (kaka_IsiPhone() ? 125 : 150).ckValue() + 20.ckValue()
        
        return headHeight
    }
    
    var itemSpace: CGFloat {
        get {
            var space = 20.ckValue()
            switch kaka_osType() {
            case .iOS: space = 0
            case .iPadOS: space = 18.ckValue()
            case .macOS: space = 5.ckValue()
            }
            
            return space
        }
    }
    
    // MARK:  懒加载
    
    lazy var emptyLabel: UILabel = {
        let view = UILabel()
        view.isHidden = true
        view.text = KakaError.emptyData.errorDescription
        view.font = UIFontBold(16.ckValue())
        view.textColor = .secondaryLabel
        view.textAlignment = .center
        return view
    }()
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.contentInsetAdjustmentBehavior = .never
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let cellHeight = Self.headHeight()
        
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = itemSpace / 2
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSizeMake(cellHeight - 25.ckValue(), cellHeight)
        return layout
    }()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return artistArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MusicTopFolderCell", for: indexPath) as! MusicTopFolderCell
        cell.navArtist = artistArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = artistArray[indexPath.row]
        self.onClickBlock?(model)
    }
    
}

