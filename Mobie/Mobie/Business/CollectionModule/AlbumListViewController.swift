//
//  AlbumListViewController.swift
//  Wakemusic
//
//  Created by 张文 on 9/18/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import StoreKit

class AlbumListViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        
        contentView.addSubview(collectionView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let previousSize = collectionView.bounds.size
        collectionView.frame = contentView.bounds
        if previousSize != collectionView.bounds.size {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = CollectionType.album.titleStr()
        
        self.refreshDataAction()
                        
        self.fileWatcher.startWatching()
        
        // 文件信息有变化
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: Notification.Name(kLocalMusicChangedKey), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: .librarySnapshotDidChange, object: viewModel)
    }
    
    @objc func refreshDataAction() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.refreshDataAction() }
            return
        }
        viewModel.refreshAlbumDataAction(viewModel.allMusicArray)
        dataArray = viewModel.albumArray
        collectionView.reloadData()
        kaka_header.endRefreshing()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.collectionView.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in

        } completion: { [weak self] context in
            self?.collectionView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshDataAction()
    }
    
    // MARK:  GET && SET
    var pageIndex: Int = 0
    
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
    
    var isLandscape: Bool {
        get {
            let isLandscape = view.bounds.width > view.bounds.height
            return isLandscape
        }
    }
    
    var isNoneMusic: Bool {
        get {
            let dataArray = self.dataArray
            return dataArray.count == 0
        }
    }
    
    // MARK:  懒加载
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.view.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceVertical = true
#if !targetEnvironment(macCatalyst)
        view.refreshControl = self.kaka_header
#endif
        view.contentInsetAdjustmentBehavior = kaka_IsMacOS() ? .always : .automatic
        view.contentInset = UIEdgeInsets(top: 20.ckValue(), left: itemSpace, bottom: playingHeight + 30.ckValue(), right: itemSpace)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(AlbumCollectionCell.self, forCellWithReuseIdentifier: "AlbumCollectionCell")
        view.register(EmptyCollectViewCell.self, forCellWithReuseIdentifier: "EmptyCollectViewCell")
        return view
    }()
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var viewModel: MusicViewModel = {
        let musicVC: MusicsViewController?
        if kaka_IsMacOS() {
            musicVC = (self.splitViewController as? MacTabbarViewController)?.musicVC
        }else{
            musicVC = (self.tabBarController?.children[0] as? KakaNavigationController)?.viewControllers.first as? MusicsViewController
        }
        let vm = musicVC?.viewModel ?? MusicViewModel(SandboxFileManager.shared.basePublicFileURL())
        return vm
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = itemSpace
        layout.minimumInteritemSpacing = itemSpace
        return layout
    }()
    
    lazy var dataArray: [String] = {
        return [String]()
    }()
    
    lazy var fileWatcher: DocumentFolderWatcher = {
        let baseFileURL = SandboxFileManager.shared.basePublicFileURL()
        let watcher = DocumentFolderWatcher(baseFileURL)
        watcher.delegate = self
        return watcher
    }()
    
}

extension AlbumListViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, EmptyContentCellDelegate, UIScrollViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isNoneMusic ? 1 : dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isNoneMusic {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmptyCollectViewCell", for: indexPath) as! EmptyCollectViewCell
            cell.appearanceChanged()
            cell.delegate = self
            return cell
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionCell", for: indexPath) as! AlbumCollectionCell
            let albumName = dataArray[indexPath.row]
            
            let musics = viewModel.albumMusicArray(albumName)
            cell.update(album: albumName, musics: musics)
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard dataArray.indices.contains(indexPath.row) else { return }
        
        if isNoneMusic {
            return
        }

        let singerName = dataArray[indexPath.row]

        let detialVC = AlbumDetialViewController(album: singerName, viewModel: viewModel)
        self.navigationController?.pushViewController(detialVC, animated: true)
    }
     
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumLineSpacing
    }
    
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        
//        let navHeight = app_navHeight
//        let tabHeight = self.tabBarController?.tabBar.bounds.height ?? 0
//        
//        if isNoneMusic {
//            let emptyHeight = self.view.height - navHeight - kStatusBarHeight - tabHeight
//            return CGSize(width: self.view.width, height: emptyHeight)
//        }else{
//            var columnCount: Int = 2
//            if isLandscape || kaka_IsMacOS() {
//                columnCount += kaka_IsMacOS() ? 2 : 1
//            }
//            
//            let totalW = self.view.width - collectionView.contentInset.left * 2 - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
//            let singleW = totalW / CGFloat(columnCount) - 0.01
//            return CGSize(width: singleW, height: singleW * 0.8 + 50.ckValue())
//        }
//    }
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if isNoneMusic {
            return EmptyCollectViewCell.preferredSize(in: collectionView)
        } else {
            var columnCount: Int = 2
            if isLandscape || kaka_IsMacOS() {
                columnCount += kaka_IsMacOS() ? 2 : 1
            }
            
            // ✅ 用 collectionView 的可用宽度
            let safeInsets = collectionView.adjustedContentInset
            let availableWidth = max(1, EmptyContentLayout.availableLength(collectionView.bounds.width,
                                                                          leading: safeInsets.left,
                                                                          trailing: safeInsets.right))
            columnCount = max(1, min(columnCount, Int(availableWidth / 120)))
            let totalW = availableWidth - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
            let singleW = max(1, totalW / CGFloat(columnCount) - 0.01)
            return CGSize(width: singleW, height: singleW * 0.8 + 50.ckValue())
        }
    }
    
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        guard let collectionView = scrollView as? UICollectionView,
              collectionView.superview != nil else { return }
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let contentOffY = scrollView.contentOffset.y
                
        if contentOffY > -app_navHeight {
            let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
            barAppearance.configureWithDefaultBackground()
            self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
        }else{
            let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
            barAppearance.configureWithTransparentBackground()
            self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
        }
    }
    
    func emptyContentViewDidClickImport(cell: UIView) {
        let formatsVC = SupportTypeViewController()
        self.navigationController?.pushViewController(formatsVC, animated: true)
    }
    
    func emptyContentViewDidClickFormats(cell: UIView) {
        self.importMusicClick()
    }
    
    func importMusicClick() {
        let importVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: importVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
    }
}

extension AlbumListViewController: DocumentFolderWatcherDelegate {
    // 新增了文件
    func documentFolderWatcherDidAddFiles(watcher: DocumentFolderWatcher, addFiles: [URL]) {
        DispatchQueue.main.async { [weak self] () in
            self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
        }
    }
    
    // 删除了文件
    func documentFolderWatcherDidDeleteFiles(watcher: DocumentFolderWatcher, deleteFiles: [URL]) {
        DispatchQueue.main.async { [weak self] () in
            self?.perform(#selector(self?.refreshDataAction), with: nil, afterDelay: 1)
        }
    }
}
