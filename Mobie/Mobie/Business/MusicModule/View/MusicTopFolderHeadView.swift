//
//  MusicTopFolderHeadView.swift
//  Wakemusic
//
//  Created by Melo on 9/1/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

enum MusicTopHeadClickType: Int {
    case clickFolder = 0    // 点击某个文件夹
    case clickRename = 1    // 文件夹重命名
    case clickExport = 2    // 导出文件夹
    case clickDelete = 3    // 删除文件夹
}

protocol MusicTopHeadViewDelegate: AnyObject {
    // 点击本地Item
    func musicTopHeadViewDidClickLocal(headView: UIView, clickType: MusicTopHeadClickType, folder: URL)
    
    // Navidrome-前往歌手列表
    func musicTopHeadViewDidClickAdd(headView: UIView)
    
    // 点击前往歌手详情页
    func musicTopHeadViewDidClickArtist(headView: UIView, navArtist: NavidromeArtist)
    
}

class MusicTopFolderHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(collectionView)
    }
    
    private func preSetupContains() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .random()
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
    }
    
    // 监听 tintColor 的变化
    @objc func appModeStyleChanged(_ noti: Notification) {
        self.collectionView.reloadData()
    }
    
    // MARK:  GET && SET
    
    static func cellSize() -> CGSize {
        let headHeight = (kaka_IsiPhone() ? 125 : 160).ckValue() + 20.ckValue()
        
        return CGSizeMake(headHeight - 40.ckValue(), headHeight)
    }
    
    weak var delegate: MusicTopHeadViewDelegate?
    
    /// 间距
    var itemSpace: CGFloat {
        get {
            var space = 20.ckValue()
            switch kaka_osType() {
            case .iOS: space = 15.ckValue()
            case .iPadOS: space = 18.ckValue()
            case .macOS: space = 10.ckValue()
            }
            
            return space
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
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: itemSpace, bottom: 0, right: itemSpace)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell")
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell0")
        view.register(MusicTopFolderCell.self, forCellWithReuseIdentifier: "MusicTopFolderCell1")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = itemSpace / 2
        layout.minimumInteritemSpacing = 0
        layout.itemSize = Self.cellSize()
        return layout
    }()
    
    // 本地文件夹
    func updateLocal(folders: [URL]) {
        
        self.localArray = folders.sorted(by: { url1, url2 in
            let count1 = SandboxFileManager.shared.getAllSubFiles(url1).count
            let count2 = SandboxFileManager.shared.getAllSubFiles(url2).count
            
            return count1 > count2
        })
        
        self.collectionView.reloadData()
    }
        
    private(set) lazy var localArray: [URL] = {
        return [URL]()
    }()
    
}

extension MusicTopFolderHeadView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return localArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // 本地文件夹
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MusicTopFolderCell", for: indexPath) as! MusicTopFolderCell
        let subURL = localArray[indexPath.row]
        cell.localFolderURL = subURL
#warning("模拟mock数据")
//#if DEBUG
//        cell.nameLabel.text = MusicGenreType.allCases.randomElement()?.formatStr()
//#endif
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let subURL = localArray[indexPath.row]
        self.delegate?.musicTopHeadViewDidClickLocal(headView: self, clickType: .clickFolder, folder: subURL)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let firstIndex = indexPaths.first else { return nil }
                
        let folderURL = self.localArray[firstIndex.row]
        
        if SandboxFileManager.shared.basePublicFileURL() == folderURL { return nil }
        
        // 重命名
        let editAction = UIAction(title: "Rename".localStr(), image: UIImage(systemName: "at")) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.musicTopHeadViewDidClickLocal(headView: wSelf, clickType: .clickRename, folder: folderURL)
        }
        
        // 导出
        let exportAction = UIAction(title: "Export".localStr(), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let wSelf = self else { return }
            wSelf.delegate?.musicTopHeadViewDidClickLocal(headView: wSelf, clickType: .clickExport, folder: folderURL)
        }
        
        // 删除
        let deleteAction = UIAction(title: "Delete".localStr(), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] (_) in
            guard let wSelf = self else { return }
            wSelf.delegate?.musicTopHeadViewDidClickLocal(headView: wSelf, clickType: .clickDelete, folder: folderURL)
        }
        
        let submenu = UIMenu(title: "", options: .displayInline, children: [deleteAction])
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: .none, actionProvider: { _ in
            let actions = [editAction, exportAction, submenu]
            return UIMenu(title: "", children: actions)
        })
        
    }
    
}
