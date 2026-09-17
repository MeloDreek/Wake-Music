//
//  NavidromeArtistListController.swift
//  Mobie
//
//  Created by 张文 on 3/2/25.
//

import KakaFoundation
import AppGroupKit
import Kingfisher
import NVActivityIndicatorView

class NavidromeArtistListController: SuperViewController {
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageCache.default.clearMemoryCache()
    }
    
    deinit {
        ImageCache.default.clearMemoryCache()
    }
    
    init(_ navUser: NavidromeUserModel) {
        self.navUser = navUser
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
        contentView.addSubview(loadingView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
        let size = loadingView.size.width
        loadingView.frame = CGRectMake((contentView.width - size) / 2, (contentView.height - size) / 2, size, size)
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = "Favorite Artists".localStr()
        self.configSearchBar()
        self.loadingView.startAnimating()
        self.perform(#selector(refreshDataAction), with: nil, afterDelay: 0.6)
        
        
    }
    
    @objc func refreshDataAction() {
                
        let params: [String: Any] = ["_start": 0, "_end": 0]
        APIManager.shared.requestNavidrome(navUser: self.navUser, endpoint: API.Navidrome.getArtists, method: .get, parameters: params) { [weak self] data in
            guard let wSelf = self else { return }
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]], jsonArray.count > 0 else {
                self?.kaka_header.endRefreshing()
                self?.loadingView.stopAnimating()
                self?.tableView.isHidden = false
                let jsonStr = String(data: data, encoding: .utf8) ?? ""
                wSelf.view.makeToast(jsonStr)
                return
            }
            
            let tempArray = [NavidromeArtist].deserialize(from: jsonArray) ?? []
            let artistArray = tempArray.map {
                var newModel = $0
                newModel.navUser = self?.navUser
                return newModel
            }
            
            self?.allArtists = artistArray
            self?.handleAllArtistArray(artistArray)
            
        } fail: { [weak self] error in
            self?.kaka_header.endRefreshing()
            self?.loadingView.stopAnimating()
            self?.tableView.isHidden = false
            self?.view.makeToast(error.localizedDescription)
        }
                
    }
    
    func handleAllArtistArray(_ allArtists: [NavidromeArtist]) {
        
        // 开始排序
        var groupedDictionary = [String: [NavidromeArtist]]()
        let sectionTitles = UILocalizedIndexedCollation.current().sectionTitles
        
        debugPrint("时间1 = \(Date())")
        groupedDictionary = Dictionary(grouping: allArtists, by: { $0.firstChar() })
        debugPrint("时间2 = \(Date())")
        
        let sortedDictory = groupedDictionary.sorted { element1, element2 in
            guard let index1 = sectionTitles.firstIndex(of: element1.key), let index2 = sectionTitles.firstIndex(of: element2.key) else {
                return false
            }
            
            return index1 < index2
        }
        
        var indexArr = sortedDictory.map({ $0.key })
        
        let starArray = allArtists.filter { $0.starred }
        if (starArray.count > 0) {
            indexArr.insert("♥", at: 0)
            groupedDictionary["♥"] = starArray
        }
        
        self.kaka_header.endRefreshing()
        self.loadingView.stopAnimating()
        self.tableView.isHidden = false
        self.dataArray.removeAll()
        
        for i in 0..<indexArr.count {
            let subKey = indexArr[i]
            var subModel = NavidromeNameArtists()
            subModel.name = subKey
            subModel.artist = groupedDictionary[subKey] ?? []
            
            self.dataArray.append(subModel)
        }
                
        self.tableView.reloadData()
        
    }
    
    // MARK:  GET && SET
    var searchKey: String?
    
    var onStarredBlock: (()->Void)?
    
    var navUser: NavidromeUserModel!
    
    lazy var allArtists: [NavidromeArtist] = {
        return [NavidromeArtist]()
    }()
    
    lazy var dataArray: [NavidromeNameArtists] = {
        return [NavidromeNameArtists]()
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.isHidden = true
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.rowHeight = UITableView.automaticDimension
        view.allowsMultipleSelection = true
        view.allowsMultipleSelectionDuringEditing = true
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(ConnectArtistTableCell.self, forCellReuseIdentifier: "ConnectArtistTableCell")
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
    
    lazy var searchController: UISearchController = {
        let searchVC = UISearchController()
        searchVC.searchBar.delegate = self
        return searchVC
    }()
    
    lazy var loadingView: NVActivityIndicatorView = {
        let frame = CGRectMake(0, 0, 30.ckValue(), 30.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        return view
    }()
    
}

extension NavidromeArtistListController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionModel = self.dataArray[section]
        return sectionModel.artist.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConnectArtistTableCell", for: indexPath) as! ConnectArtistTableCell
        let sectionModel = self.dataArray[indexPath.section]
        let artistModel = sectionModel.artist[indexPath.row]
        cell.navArtist = artistModel
        cell.onArtistBlock = { [weak self] (navArtist) in
            self?.likeNavArtistClick(navArtist: navArtist, indexPath: indexPath)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sectionModel = self.dataArray[indexPath.section]
        let artistModel = sectionModel.artist[indexPath.row]
        
        let artistVC = NavidromeArtistDetialController(navUser: self.navUser, model: artistModel)
        self.navigationController?.pushViewController(artistVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionModel = self.dataArray[section]
        return sectionModel.name
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return self.dataArray.map { $0.name }
    }
    
    func likeNavArtistClick(navArtist: NavidromeArtist, indexPath: IndexPath) {
        let params: [String: Any] = ["artistId": navArtist.id]
        APIManager.shared.requestSubsonic(navUser: self.navUser, endpoint: navArtist.starred ? API.Subsonic.unstar : API.Subsonic.star, parameters: params) { subsonic in
            var newArtist = navArtist
            newArtist.starred.toggle()
            
            var sectionModel1 = self.dataArray[indexPath.section]
            sectionModel1.artist[indexPath.row] = newArtist
            self.dataArray[indexPath.section].artist = sectionModel1.artist
            
            if self.dataArray.first?.name == "♥" {
                var sectionModel2 = self.dataArray[0]
                if let index = sectionModel2.artist.firstIndex(where: { subArtist in subArtist.id == newArtist.id }) {
                    if newArtist.starred {
                        sectionModel2.artist.insert(newArtist, at: 0)
                    }else{
                        sectionModel2.artist.remove(at: index)
                    }
                }
                self.dataArray[0].artist = sectionModel2.artist
            }
                        
            self.tableView.reloadData()
            
            self.view.makeToast("Successful".localStr())
            
            if self.allArtists.count <= 200 {
                self.refreshDataAction()
            }
                                                
            self.onStarredBlock?()
            
        } fail: { error in
            self.view.makeToast(error.localizedDescription)
        }
    }
    
}

extension NavidromeArtistListController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText = \(searchText)")
        
        self.searchWithKey(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }
        
        debugPrint("searchText = \(searchText)")
        
        if self.dataArray.isEmpty {
            self.searchController.searchBar.endEditing(true)
            self.tableView.kaka_playShakeAnim()
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
        self.searchKey = keyword

        if keyword.isEmpty {
            self.handleAllArtistArray(self.allArtists)
        }else{
            let searchArray = self.allArtists.filter {
                $0.name.lowercased().contains(keyword.lowercased()) ||
                ($0.fullText ?? "").lowercased().contains(keyword.lowercased())
            }
            
            self.handleAllArtistArray(searchArray)
        }
        
    }
    
    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
                
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardH, right: 0)
    }
    
    @objc func keyboardWillHidden(_ notify: Notification) {
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.searchKey = nil
        self.handleAllArtistArray(self.allArtists)
        
        self.searchController.dismiss(animated: animation)
    }
    
}
