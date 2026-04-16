//
//  ArtistListViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/18.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import StoreKit

/// 艺术家页面
class ArtistListViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        
        contentView.addSubview(collectionView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = CollectionType.artist.titleStr()
        
        self.refreshDataAction()
        
        self.fileWatcher.startWatching()
                        
        // 文件信息有变化
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDataAction), name: Notification.Name(kLocalMusicChangedKey), object: nil)
        
    }
    
    @objc func refreshDataAction() {
        self.viewModel.refreshSingerDataAction(self.viewModel.allMusicArray)
                
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.5) { [weak self] () in
            self?.dataArray = self?.viewModel.singerArray ?? []
            self?.collectionView.reloadData()
            self?.kaka_header.endRefreshing()
        }
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
        
        #if targetEnvironment(macCatalyst)
        self.collectionView.reloadData()
        #endif
    }
    
    // MARK:  GET && SET
    
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
            let isLandscape = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation.isLandscape ?? false
            return isLandscape
        }
    }
    
    var isNoneMusic: Bool {
        get {
#warning("模拟mock数据")
            let dataArray = self.viewModel.singerArray
            return dataArray.count == 0
//            return false
        }
    }
    
    // MARK:  懒加载
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
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
        view.register(ArtistCollectionCell.self, forCellWithReuseIdentifier: "ArtistCollectionCell")
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

extension ArtistListViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, EmptyContentCellDelegate, UIScrollViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
#warning("模拟mock数据")
//        return MusicGenreType.allCases.count
        return isNoneMusic ? 1 : dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isNoneMusic {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmptyCollectViewCell", for: indexPath) as! EmptyCollectViewCell
            cell.appearanceChanged()
            cell.delegate = self
            return cell
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ArtistCollectionCell", for: indexPath) as! ArtistCollectionCell
            let singerName = dataArray[indexPath.row]
            
            let musics = viewModel.singerMusicArray(singerName)
            cell.update(artist: singerName, musics: musics)
            return cell
        }
        
//#warning("模拟mock数据")
//#if DEBUG
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ArtistCollectionCell", for: indexPath) as! ArtistCollectionCell
//        var genreArray: [MusicGenreType] = [.gospel, .punk, .reggae, .hipHop, .house, .podcast, .disco, .country, .soul, .jazz] + MusicGenreType.allCases
//        let subGenre = genreArray[indexPath.row]
//        cell.artistLabel.text = subGenre.formatStr()
//        cell.coverImgView.image = subGenre.iconImage()
//        return cell
//#endif
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if isNoneMusic {
            return
        }
//        
//#warning("模拟mock数据")
//#if DEBUG
//        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
//            tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
//            tabbarVC.toolbarView.isHidden = !tabbarVC.toolbarView.isHidden
//        }
//        return
//#endif

        let singerName = dataArray[indexPath.row]

        let detialVC = ArtistDetialViewController(singer: singerName, viewModel: viewModel)
        self.navigationController?.pushViewController(detialVC, animated: true)
    }
     
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let navHeight = app_navHeight
        let tabHeight = self.tabBarController?.tabBar.bounds.height ?? 0
        
        if isNoneMusic {
            // 注意这里要减去 safeAreaInsets
            let safeInsets = collectionView.safeAreaInsets
            let emptyHeight = collectionView.bounds.height - navHeight - kStatusBarHeight - tabHeight - safeInsets.top - safeInsets.bottom
            return CGSize(width: collectionView.bounds.width - safeInsets.left - safeInsets.right, height: emptyHeight)
        } else {
            var columnCount: Int = 2
            if isLandscape || kaka_IsMacOS() {
                columnCount += kaka_IsMacOS() ? 2 : 1
            }
            
            // ✅ 用 collectionView 的可用宽度
            let safeInsets = collectionView.adjustedContentInset
            let availableWidth = collectionView.bounds.width - safeInsets.left - safeInsets.right
            let totalW = availableWidth - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
            let singleW = totalW / CGFloat(columnCount) - 0.01
            return CGSize(width: singleW, height: singleW * 0.8 + 50.ckValue())
        }
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

extension ArtistListViewController: DocumentFolderWatcherDelegate {
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
