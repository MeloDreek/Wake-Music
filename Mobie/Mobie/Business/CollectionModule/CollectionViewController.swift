//
//  CollectionViewController.swift
//  Mobie
//
//  Created by 张文 on 12/12/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import JXSegmentedView

enum CollectionType: Int {
    case artist = 0
    case album = 1
    case genre = 2
    
    func titleStr() -> String {
        switch self {
        case .artist:
            return MeteDataCellItemType.artist.titleStr() ?? ""
        case .album:
            return MeteDataCellItemType.album.titleStr() ?? ""
        case .genre:
            return MeteDataCellItemType.genre.titleStr() ?? ""
        }
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .artist:
            return MusicActionType.artist.iconImage()
        case .album:
            return MusicActionType.album.iconImage()
        case .genre:
            return UIImage(systemName: "square.stack.3d.up.fill")
        }
    }
    
}

class CollectionViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
            
        contentView.addSubview(segmentedView)

        contentView.addSubview(listContainerView)

    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        segmentedView.frame = CGRect(x: 0, y: 0, width: totalItemWidth, height: totalItemHeight)
        listContainerView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = self.tabBarItem.title ?? KakaTabbarType.collection.formatStr()
        self.updateNavigationItem()
        
        self.navigationItem.titleView = self.segmentedView
        
        // 主题色
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.appearanceChanged()
    }

    @objc func appModeStyleChanged(_ noti: Notification) {
        guard let newColor = noti.object as? UIColor else { return }
        segmentedView.layer.borderColor = newColor.cgColor
        indicator.indicatorColor = newColor
        segmentedDataSource.titleNormalColor = newColor
        segmentedDataSource.titleSelectedColor = UIColor.deAccent
        
        segmentedView.reloadData()
    }
    
    @objc override func appearanceChanged() {
        
        let isDark = AppLocalManager.shared.appearanceStyle == .dark || self.overrideUserInterfaceStyle == .dark

        segmentedView.layer.borderColor = (ColorFontManager.shared.accentTyle == .color0 && isDark) ? UIColor.white.cgColor : appMainColor.cgColor
        segmentedDataSource.titleSelectedColor = UIColor.deAccent
    }
    
    @objc func updateNavigationItem() {
        
        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        barAppearance.configureWithTransparentBackground()
        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in

        } completion: { [weak self] context in
            self?.segmentedView.reloadData()
            self?.listContainerView.reloadData()
        }
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        //处于第一个item的时候，才允许屏幕边缘手势返回
//        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = (self.segmentedView.selectedIndex == 0)
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        //离开页面的时候，需要恢复屏幕边缘手势，不能影响其他页面
//        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
//    }
    
    // MARK:  GET && SET
    let totalItemWidth: CGFloat = 250.ckValue()
    
    let totalItemHeight = 36.ckValue()
    
//#if DEBUG
//    let dataArray: [CollectionType] = [.album, .genre, .artist]
//#else
    let dataArray: [CollectionType] = [.album, .artist, .genre]
//#endif
    
    // MARK:  懒加载
    
    lazy var segmentedDataSource: JXSegmentedTitleDataSource = {
        let titles = self.dataArray.map { $0.titleStr() }
        
        let titleDataSource = JXSegmentedTitleDataSource()
        titleDataSource.itemWidth = totalItemWidth/CGFloat(titles.count)
        titleDataSource.titles = titles
        titleDataSource.isTitleMaskEnabled = true
        titleDataSource.titleNormalColor = appMainColor
        titleDataSource.titleSelectedColor = UIColor.deAccent
        titleDataSource.itemSpacing = 0
        titleDataSource.isTitleColorGradientEnabled = true
        
        return titleDataSource
    }()
    
    lazy var segmentedView: JXSegmentedView = {
        let view = JXSegmentedView()
        view.frame = CGRect(x: 0, y: 0, width: totalItemWidth, height: totalItemHeight)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = totalItemHeight / 2
        view.layer.borderColor = appMainColor.cgColor
        view.layer.borderWidth = 1.ckValue()
        
        view.indicators = [self.indicator]
        view.dataSource = self.segmentedDataSource
        view.delegate = self
        view.defaultSelectedIndex = 1
        view.listContainer = self.listContainerView
        return view
    }()
    
    lazy var indicator: JXSegmentedIndicatorBackgroundView = {
        let view = JXSegmentedIndicatorBackgroundView()
        view.indicatorHeight = totalItemHeight
        view.indicatorWidthIncrement = 0
        view.indicatorColor = appMainColor
        return view
    }()
    
    lazy var listContainerView: JXSegmentedListContainerView = {
        return JXSegmentedListContainerView(dataSource: self)
    }()
    
    private lazy var artistlVC: ArtistListViewController = {
        let controller = ArtistListViewController()
        return controller
    }()
    
    private lazy var albumVC: AlbumListViewController = {
        let controller = AlbumListViewController()
        return controller
    }()
    
    private lazy var genreVC: GenreListViewController = {
        let controller = GenreListViewController()
        return controller
    }()
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()
    
}

extension CollectionViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText = \(searchText)")
        self.searchWithKey(searchText)
    }
    
    func searchBarResultsListButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.dismiss(animated: true)
            return
        }
        
        self.searchWithKey(searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.count == 0 && kaka_IsMacOS() {
            self.searchController.dismiss(animated: true)
        }
        
        self.stopSearchAction(false)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }
    
    func searchWithKey(_ keyword: String) {
        
    }
    
    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        }
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.searchController.dismiss(animated: animation)
    }
    
}


extension CollectionViewController: JXSegmentedViewDelegate {
    func segmentedView(_ segmentedView: JXSegmentedView, didSelectedItemAt index: Int) {
        if let dotDataSource = segmentedDataSource as? JXSegmentedDotDataSource {
            //先更新数据源的数据
            dotDataSource.dotStates[index] = false
            //再调用reloadItem(at: index)
            segmentedView.reloadItem(at: index)
        }

        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = (segmentedView.selectedIndex == 0)
    }
}

extension CollectionViewController: JXSegmentedListContainerViewDataSource {
    func numberOfLists(in listContainerView: JXSegmentedListContainerView) -> Int {
        if let titleDataSource = segmentedView.dataSource as? JXSegmentedBaseDataSource {
            return titleDataSource.dataSource.count
        }
        
        return 0
    }

    func listContainerView(_ listContainerView: JXSegmentedListContainerView, initListAt index: Int) -> JXSegmentedListContainerViewListDelegate {
        if index == 0 {
            return self.albumVC
        }else if index == 1{
            return self.artistlVC
        }else{
            return self.genreVC
        }
    }
}

extension GenreListViewController: JXSegmentedListContainerViewListDelegate {
    func listView() -> UIView {
        return view
    }
}

extension AlbumListViewController: JXSegmentedListContainerViewListDelegate {
    func listView() -> UIView {
        return view
    }
}

extension ArtistListViewController: JXSegmentedListContainerViewListDelegate {
    func listView() -> UIView {
        return view
    }
}
