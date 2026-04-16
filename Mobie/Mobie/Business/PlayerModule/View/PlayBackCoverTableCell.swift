//
//  PlayBackCoverTableCell.swift
//  Mobie
//
//  Created by 张文 on 5/25/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class PlayBackCoverTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(collectionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var modelArray: [PlayBackgroundModel] = [] {
        didSet {
            collectionView.frame = contentView.bounds

            let cellWidth = (self.bounds.width - Self.itemSpace * 3) / 2 - 1
            self.flowLayout.itemSize = CGSizeMake(cellWidth, kaka_IsMacOS() ? cellWidth * 0.5625 : cellWidth / 0.75)
            self.collectionView.reloadData()
        }
    }
    
    /// 间距
    static var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 8.ckValue()
            case .iPadOS: return 8.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    var onClickCallback: ((PlayBackgroundModel)->Void)?
    
    var onDeleteCallback: ((PlayBackgroundModel)->Void)?
    
    var onPreviewCallback: ((PlayBackgroundModel, SelectBackCoverCollectCell)->Void)?
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.isScrollEnabled = false
        view.alwaysBounceVertical = false
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.contentInset = UIEdgeInsets(top: Self.itemSpace * 2, left: Self.itemSpace, bottom: 0, right: Self.itemSpace)
        view.contentInsetAdjustmentBehavior = .automatic
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(SelectBackCoverCollectCell.self, forCellWithReuseIdentifier: "SelectBackCoverCollectCell")
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
        return self.modelArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectBackCoverCollectCell", for: indexPath) as! SelectBackCoverCollectCell
        cell.model = self.modelArray[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let itemType = self.modelArray[indexPath.row]
        if itemType.backgroundName == PlayBackgroundSystem.style1.systemImageName() {
            
            // 第一个系统背景不要黑色遮罩
            var model = MusicConfigManager.shared.playbackModel
            model.isShowAlphaMask = false
            
            MusicConfigManager.shared.playbackModel = model
        }
        
        self.onClickCallback?(itemType)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        if !UserInfoManager.shared.isVIP() {
            return nil
        }
        
        let model = self.modelArray[indexPath.row]
                
        let previewAction = UIAction(title: "Preview".localStr(), image: UIImage(systemName: "eye"), attributes: []) { [weak self] (_) in
            guard let wSelf = self, let curCell = collectionView.cellForItem(at: indexPath) as? SelectBackCoverCollectCell else { return }
            wSelf.onPreviewCallback?(model, curCell)
        }
        let deleteAction = UIAction(title: MusicActionType.deleteItem.formatStr(), image: MusicActionType.deleteItem.iconImage(), attributes: model.backgroundType == .customType ? .destructive : .disabled) { [weak self] (_) in
            self?.onDeleteCallback?(model)
        }
                
        return UIContextMenuConfiguration(identifier: nil, previewProvider: .none, actionProvider: { _ in
            return UIMenu(title: "", children: [previewAction, deleteAction])
        })
    }
    
}


class SelectBackCoverCollectCell: UICollectionViewCell {
    
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
        coverImgView.addSubview(mengView)
        mengView.addSubview(selectIconBtn)
    }
    
    private func setupAutoLayout() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        mengView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(50.ckValue())
        }
        
        selectIconBtn.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.size.equalTo(selectIconBtn.size)
        }
    }
    
    private func setupCusBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK:  GET && SET
    var model: PlayBackgroundModel? {
        didSet {
            guard let model = self.model else { return }
            
            coverImgView.image = model.backgroundImage()
            
            let isSelect = MusicConfigManager.shared.playbackModel.backgroundName == model.backgroundName
            self.selectIconBtn.isSelected = isSelect
        }
    }
    
    // MARK:  懒加载
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 10.ckValue()
        view.contentMode = .scaleAspectFill
        return view
    }()

    lazy var selectIconBtn: UIButton = {
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(20.ckValue(), 20.ckValue())
        view.setImage(Reasource.systemNamed("circle", color: .white), for: .normal)
        view.setImage(Reasource.systemNamed("checkmark.circle.fill", color: .white), for: .selected)
        return view
    }()
    
    lazy var mengView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "video_bottom_shadow"))
        view.contentMode = .scaleAspectFill
        return view
    }()
}

