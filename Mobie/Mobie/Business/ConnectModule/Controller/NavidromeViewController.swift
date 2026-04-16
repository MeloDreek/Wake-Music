//
//  NavidromeViewController.swift
//  Mobie
//
//  Created by 张文 on 12/12/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import FilesProvider
import Kingfisher
import NVActivityIndicatorView
import Alamofire
import Combine
import SafariServices

/// Navidrome
class NavidromeViewController: SuperViewController {
    
    init(navUser: NavidromeUserModel) {
        super.init(nibName: nil, bundle: nil)
        self.navUser = navUser
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        loadingView.frame = CGRectMake((contentView.width - loadingView.width) / 2, (contentView.height - loadingView.height) / 2, loadingView.width, loadingView.height)
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        if self.navUser.customName.count > 1 {
            self.title = self.navUser.username
        }else{
            self.title = ImportFileType.fromNavidrome.titleStr()
        }
        
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationItem.largeTitleDisplayMode = .never
                
        self.configSearchBar()
        self.addNotificationEvent()
        self.refreshDataAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.setupNavigationItem()

    }
    
    @objc func setupNavigationItem() {
        
#if targetEnvironment(macCatalyst)
        self.navigationItem.rightBarButtonItems = [self.loginBarItem, self.refreshBarItem]
#endif
        
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    var navUser: NavidromeUserModel!
    
    var isAuthenticated = true
    
    /// 重试登录
    public var isRetryLogin = false

    lazy var navsetModel: NavidromeSetModel = {
        return NavidromeSetModel()
    }()
    
    var sectionArray: [ConnectCellSection] {
        get {
            return self.navUser.isLargeServer ? [.topSection, .starredSongs, .myPlaylists, .todayRandom] : [.topSection, .todayRandom]
        }
    }
    
    // MARK:  懒加载
    
    
    

    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
#if !targetEnvironment(macCatalyst)
        view.refreshControl = self.kaka_header
#endif
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: 30.ckValue() + playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(ConnectNavidromeArtistCell.self, forCellReuseIdentifier: "ConnectNavidromeArtistCell")
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        view.register(ConnectMyPlayListCell.self, forCellReuseIdentifier: "ConnectMyPlayListCell")
        view.register(ConnectSectionHeadView.self, forHeaderFooterViewReuseIdentifier: "ConnectSectionHeadView")
        return view
    }()
#if targetEnvironment(macCatalyst)
    
    lazy var refreshBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Reload".localStr(), style: .done, target: self, action: #selector(refreshDataAction))
        return item
    }()
    
    lazy var loginBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Edit Config".localStr(), style: .done, target: self, action: #selector(reloginItemClick))
        return item
    }()
#endif
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
    lazy var searchController: NavidromeSearchViewController = {
        let searchVC = NavidromeSearchViewController()
        searchVC.navUser = self.navUser
        searchVC.searchBar.delegate = self
        return searchVC
    }()
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
}
