//
//  ConnectNavidromeArtistCell.swift
//  Mobie
//
//  Created by 张文 on 7/11/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class ConnectNavidromeArtistCell: UITableViewCell {
    
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
            make.edges.equalToSuperview()
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    
    static func cellSize() -> CGSize {
        let headHeight = (kaka_IsiPhone() ? 125 : 160).ckValue() + 20.ckValue()
        
        return CGSizeMake(headHeight - 40.ckValue(), headHeight)
    }
    
    weak var delegate: MusicTopHeadViewDelegate?
    
    var itemSpace: CGFloat {
        get {
            var space = 20.ckValue()
            switch kaka_osType() {
            case .iOS: space = 5.ckValue()
            case .iPadOS: space = 10.ckValue()
            case .macOS: space = 5.ckValue()
            }
            
            return space
        }
    }
    
    var navModels: [NavidromeArtist] = [] {
        didSet {
            self.collectionView.reloadData()
        }
    }
    
    // MARK:  懒加载
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.contentInsetAdjustmentBehavior = .never
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: 0, right: 0)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell")
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell0")
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell1")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0 //itemSpace / 2
        layout.minimumInteritemSpacing = 0
        layout.itemSize = Self.cellSize()
        return layout
    }()
    
}

extension ConnectNavidromeArtistCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1 + navModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Navidrome歌手
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: indexPath.row == 0 ? "MusicTopFolderCell0" : "MusicTopFolderCell1", for: indexPath) as! MusicTopFolderCell
        if indexPath.row == 0 {
            cell.navArtist = nil
            return cell
        }else{
            let subModel = navModels[indexPath.row - 1]
            cell.navArtist = subModel
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            self.delegate?.musicTopHeadViewDidClickAdd(headView: self)
        }else{
            var subModel = navModels[indexPath.row - 1]
            subModel.starred = true
            self.delegate?.musicTopHeadViewDidClickArtist(headView: self, navArtist: subModel)
        }
    }
    
}
