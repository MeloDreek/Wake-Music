//
//  AppleMusicListController.swift
//  Mobie
//
//  Created by 张文 on 4/29/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MediaPlayer
import KakaObjcKit
import Combine

/// Apple Music本地音乐
class AppleMusicListController: SuperViewController {
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = ImportFileType.fromApple.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = self.questionItem
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.perform(#selector(self?.playingMusicChanged), with: nil, afterDelay: 0.2)
            }.store(in: &cancellables)
        
        self.refreshDataAction()
    }
    
    @objc func playingMusicChanged() {
        self.tableView.reloadData()
    }
    
    // 扫描Apple Music里的本地音乐
    @objc func refreshDataAction() {
        
        if !self.tableView.isDragging {
            if let emptyCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EmptyTableViewCell {
                emptyCell.startRefreshData("Processing...".localStr())
            }
        }
        
        // 请求授权
        self.requestMediaLibraryAccess { granted in
            
            AppLocalManager.shared.isGrantedAppleMusic = granted
            
            if granted {
                let musicItems = MPMediaQuery.songs().items?.filter({ $0.mediaType == .music && ($0.assetURL != nil) }) ?? []
                
                let tempArray = musicItems.map { MusicItemModel(appleMusic: $0) }
            
                self.dataArray = tempArray
                self.tableView.separatorStyle = tempArray.isEmpty ? .none : .singleLine
                self.tableView.reloadData()
                
                self.stopLoadingAction()
            } else {
                self.stopLoadingAction()
                self.tableView.separatorStyle = .none
                self.tableView.reloadData()
                self.showOneAlert(message: "You’ve denied access to your media library. Please grant access again.".localStr(), confirm: "Settings".localStr()) {
                    guard let vURL = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    
                    UIApplication.shared.open(vURL)
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
    func requestMediaLibraryAccess(completion: @escaping (Bool) -> Void) {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized)
                }
            }
        case .authorized:
            completion(true)
        default:
            completion(false)
        }
    }
    
    func stopLoadingAction() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] () in
            if let emptyCell = self?.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? EmptyTableViewCell {
                emptyCell.stopRefreshData()
            }
            
            self?.kaka_header.endRefreshing()
        }
    }
    
    @objc func showAppleMusicTips() {
        
        #if targetEnvironment(macCatalyst)
        self.showOneAlert(message: message)
        #else
        let popView = CMPopTipView(message: self.message)
        popView?.hasShadow = true
        popView?.has3DStyle = false
        popView?.borderColor = UIColor.label
        popView?.dismissTapAnywhere = true
        popView?.backgroundColor = UIColor.label
        popView?.textColor = UIColor.systemBackground
        popView?.presentPointing(at: self.questionItem, animated: true)
        #endif
        
    }
    
    lazy var questionItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain, target: self, action: #selector(showAppleMusicTips))
        return item
    }()
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
    
    let message = "Only downloaded Apple Music songs can be read. These files are encrypted and can only be played using Apple's built-in AVPlayer. Third-party apps cannot export the original files.".localStr()
    
    // MARK:  懒加载
    lazy var dataArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: kaka_IsMacOS() ? .insetGrouped : .plain)
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = self.headView
#if !targetEnvironment(macCatalyst)
view.refreshControl = self.kaka_header
#endif
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight + 30.ckValue(), right: 0)
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
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
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let iconImage = UIImage(named: "Apple_Music")
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height * 1.5))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: iconImage)
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(height)
        }
        return view
    }()
}

extension AppleMusicListController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataArray.isEmpty ? 1 : self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.dataArray.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.updateMessage(KakaError.emptyData.errorDescription + "\r\n" + self.message)
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
            let model = self.dataArray[indexPath.row]
            cell.update(musicModel: model, cellType: .none)
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.dataArray.isEmpty { return }
        
        let model = self.dataArray[indexPath.row]

        let isPlaying: Bool = KakaMusicPlayer.shared.playingMusic == model
                
        if isPlaying {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            KakaMusicPlayer.shared.startPlayMusic(musics: self.dataArray, itemIndex: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.dataArray.count == 0 {
            let navHeight = app_navHeight
            let tabHeight = self.tabBarController?.tabBar.bounds.height ?? 0
            
            let cellHeight = self.view.height - navHeight - kStatusBarHeight - tabHeight - 70.ckValue()
            return cellHeight * 0.6
        }else{
            return UITableView.automaticDimension
        }
                        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
}
