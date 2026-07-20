//
//  ConnectMyPlayListCell.swift
//  Mobie
//
//  Created by 张文 on 3/1/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

protocol ConnectMyPlayListCellDelegate: AnyObject {
    
    // 点击播放列表
    func connectMyPlayListCellDidClick(cell: ConnectMyPlayListCell, playlist: NavidromePlaylist)
    
    // 删除
    func connectMyPlayListCellDidDelete(cell: ConnectMyPlayListCell, playlist: NavidromePlaylist)
    
    // 重新命名
    func connectMyPlayListCellDidRename(cell: ConnectMyPlayListCell, playlist: NavidromePlaylist)

}

/// 我的歌单
class ConnectMyPlayListCell: UITableViewCell {
    
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
        self.selectionStyle = .none
    }
    
    // MARK:  GET && SET
    
    static func headHeight() -> CGFloat {
        return 120.ckValue() + 55.ckValue() + 20.ckValue()
    }
    
    weak var delegate: ConnectMyPlayListCellDelegate?
    
    
    var itemSpace: CGFloat {
        get {
            var space = 20.ckValue()
            switch kaka_osType() {
            case .iOS: space = 20.ckValue()
            case .iPadOS: space = 18.ckValue()
            case .macOS: space = 30.ckValue()
            }
            
            return space
        }
    }
    
    public var playlistArray: [NavidromePlaylist] = [] {
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
        view.contentInset = UIEdgeInsets(top: 0, left: itemSpace, bottom: 0, right: itemSpace)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(ConnectPlayListViewCell.self, forCellWithReuseIdentifier: "ConnectPlayListViewCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = itemSpace
        layout.minimumInteritemSpacing = itemSpace
        layout.itemSize = CGSizeMake(Self.headHeight() - 75.ckValue(), Self.headHeight())
        return layout
    }()
    
}

extension ConnectMyPlayListCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return playlistArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ConnectPlayListViewCell", for: indexPath) as! ConnectPlayListViewCell
        cell.model = playlistArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let subModel = self.playlistArray[indexPath.row]
        self.delegate?.connectMyPlayListCellDidClick(cell: self, playlist: subModel)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let firstIndex = indexPaths.first else { return nil }
        let subModel = self.playlistArray[firstIndex.row]
        // 重命名
        let renameAction = UIAction(title: "Rename".localStr(), image: UIImage(systemName: "at")) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.connectMyPlayListCellDidRename(cell: wSelf, playlist: subModel)
        }
        
        // 删除
        let deleteAction = UIAction(title: "Delete".localStr(), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self else { return }
            wSelf.delegate?.connectMyPlayListCellDidDelete(cell: wSelf, playlist: subModel)
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: .none, actionProvider: { _ in
            let actions = [renameAction, deleteAction]
            return UIMenu(title: "My Playlists".localStr(), children: actions)
        })
    }
    
}

class ConnectPlayListViewCell: UICollectionViewCell {
    
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
        contentView.addSubview(coverImgView)
        contentView.addSubview(middleView)
        middleView.addSubview(nameLabel)
        middleView.addSubview(countLabel)
    }
    
    private func setupAutoLayout() {
        
        let topSpace = 20.ckValue()
        middleView.snp.makeConstraints { make in
            make.height.equalTo(55.ckValue())
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        coverImgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(topSpace)
            make.leading.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(coverImgView.snp.width)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.bottom.equalTo(middleView.snp.centerY)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        countLabel.snp.makeConstraints { make in
            make.top.equalTo(middleView.snp.centerY)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    private func setupCusBuness() {

    }
    
    // MARK:  GET && SET
    var model: NavidromePlaylist? {
        didSet {
            guard let model = self.model else { return }

            nameLabel.text = model.name
            countLabel.text = String(format: "%d songs".localStr(), model.songCount)
            coverImgView.kf.setImage(with: model.coverImgURL(), placeholder: UIImage(named: "music_place"))
        }
    }
    
    
    // MARK:  懒加载
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var middleView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 1
        view.textAlignment = .center
        view.font = UIFontBold(13.ckValue())
        view.textColor = .label
        return view
    }()
    
    lazy var countLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 1
        view.textAlignment = nameLabel.textAlignment
        view.font = UIFontLight(13.ckValue())
        view.textColor = .secondaryLabel
        return view
    }()
    
}

