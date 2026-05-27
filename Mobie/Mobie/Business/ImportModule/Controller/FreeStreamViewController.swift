////
////  FreeStreamViewController.swift
////  Wake Music
////
////  Created by Melo on 7/24/24.
////
//
//import KakaFoundation
//import AppGroupKit
//import StoreKit
//
//class FreeStreamViewController: SuperViewController {
//    
//    override func preSetupSubViews() {
//        super.preSetupSubViews()
//        contentView.addSubview(tableView)
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        tableView.frame = contentView.bounds
//    }
//    
//    override func preSetupHandleBuness() {
//        super.preSetupHandleBuness()
//        
////        self.title = self.tabBarItem.title ?? KakaTabbarType.radio.formatStr()
//                
//        if kaka_IsiPhone() {
//            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "crown"), style: .plain, target: self, action: #selector(vipCenterClick))
//        }
//                        
//        // 监听网络变化
//        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
//        
//        // 监听控制中心
//        NotificationCenter.default.addObserver(self, selector: #selector(playingMusicChanged), name: Notification.Name(kPlayCommandCenterKey), object: nil)
//        
//        try? self.reachability.startNotifier()
//    }
//    
//    @objc func playingMusicChanged() {
//        self.tableView.reloadData()
//        
//        if KakaMusicPlayer.shared.isPlayEnum != .stream {
//            return
//        }
//        
//        let playIndex = Int(KakaMusicPlayer.shared.player.currentPlaylistItemIndex)
//        let indexPath = IndexPath(row: 0, section: playIndex)
//        self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        
//        if kaka_safeAreaInsets().top > 20 {
//            self.navigationController?.navigationBar.prefersLargeTitles = true
//            self.navigationItem.largeTitleDisplayMode = .automatic
//        }else{
//            self.navigationController?.navigationBar.prefersLargeTitles = false
//            self.navigationItem.largeTitleDisplayMode = .never
//        }
//        
//        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
//        barAppearance.configureWithTransparentBackground()
//        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
//        
//        self.tableView.reloadData()
//        
//        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2) {
//            let musicPlayer = KakaMusicPlayer.shared
//            if musicPlayer.player.isPlaying() && musicPlayer.isPlayEnum == .stream {
//                let index = musicPlayer.player.currentPlaylistItemIndex
//                let indexPath = IndexPath(row: 0, section: Int(index))
//                if indexPath.section > self.tableView.numberOfSections {
//                    return
//                }
//                
//                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
//            }
//        }
//    }
//    
//    // 网络状态变化了
//    @objc func reachabilityChanged(note: Notification) {
//        guard let reachability = note.object as? ReachabilitySwift else { return }
//        
//        debugPrint("当前网络授权状况 = \(reachability.connection.description)")
//        
//        self.netConnect = reachability.connection
//        
//    }
//    
//    @objc func vipCenterClick() {
//        
//        if !DiscountIAPManager.shared.isShowDiscount() {
//            DiscountIAPManager.reset()
//        }
//        
//        AppStoreKitManager.presentPurcharseVC(self)
//    }
//    
//    // MARK:  GET && SET
//    lazy var dataArray: [BroadcastsType] = {
//        return BroadcastsType.allChannel()
//    }()
//    
//    var netConnect: ReachabilitySwift.Connection = .unavailable
//    
//    // MARK:  懒加载
//    lazy var tableView: UITableView = {
//        let view = UITableView(frame: self.contentView.bounds, style: .insetGrouped)
//        view.dataSource = self
//        view.delegate = self
//        view.backgroundColor = .systemBackground
//        view.rowHeight = UITableView.automaticDimension
//        view.contentInsetAdjustmentBehavior = .automatic
//        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
//        view.register(RadioTableViewCell.self, forCellReuseIdentifier: "RadioTableViewCell")
//        view.register(FreeStreamTableCell.self, forCellReuseIdentifier: "FreeStreamTableCell")
//        return view
//    }()
//    
//    lazy var reachability: ReachabilitySwift = {
//        return try! ReachabilitySwift()
//    }()
//    
//    lazy var headView: UIView = {
//        let view = UIView(frame: CGRectMake(0, 0, self.view.width, kaka_IsMacOS() ? 120.ckValue() : 150.ckValue()))
//        view.backgroundColor = .clear
//        let faceImgView = UIImageView(image: UIImage(systemName: "antenna.radiowaves.left.and.right"))
//        faceImgView.contentMode = .scaleAspectFit
//        view.addSubview(faceImgView)
//        faceImgView.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.centerY.equalToSuperview()
//            make.height.equalToSuperview().multipliedBy(kaka_IsiPhone() ? 0.68 : 0.82)
//            make.width.equalTo(faceImgView.snp.height)
//        }
//        return view
//    }()
//}
//
//extension FreeStreamViewController: UITableViewDataSource, UITableViewDelegate {
//    func numberOfSections(in tableView: UITableView) -> Int {
//        return dataArray.count
//    }
//    
//    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return 1
//    }
//    
//    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "FreeStreamTableCell", for: indexPath) as! FreeStreamTableCell
//        let audioType = dataArray[indexPath.section]
//
//        let isPlaying = KakaMusicPlayer.shared.playingRadio?.rawValue == audioType.rawValue
//        
//        cell.update(audioType: audioType, isPlaying: isPlaying)
//        return cell
//    }
//    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//                
//#warning("模拟mock数据")
////        #if DEBUG
////        if let tabbarVC = self.tabBarController as? HomeTabbarViewController {
////            tabbarVC.tabBar.isHidden = !tabbarVC.tabBar.isHidden
////            tabbarVC.playingView.isHidden = !tabbarVC.playingView.isHidden
////        }
////        return
////        #endif
//        
//        self.clickPlayWithIndex(indexPath.section)
//    }
//    
//    func clickPlayWithIndex(_ index: Int) {
//        if self.netConnect == .unavailable {
//            self.showTwoAlert(title: "Reminder".localStr(), message: "Although this is an offline music player, we need your network authorization to play radio music, please authorize the network permission.".localStr(), confirm: "Settings".localStr(), cancle: "Cancel".localStr()) {
//                guard let vURL = URL(string: UIApplication.openSettingsURLString) else { return }
//                UIApplication.shared.open(vURL)
//            }
//            return
//        }
//        
//        let indexPath = IndexPath(row: 0, section: index)
//        
//        KakaMusicPlayer.shared.orderType = .normal
//        
//        if KakaMusicPlayer.shared.isPlayEnum == .stream && KakaMusicPlayer.shared.player.isPlaying() && KakaMusicPlayer.shared.player.currentPlaylistItemIndex == indexPath.section {
//            // 正在播放此FM
//            KakaMusicPlayer.presentPlayController(fromVC: self)
//        }else{
//            KakaMusicPlayer.shared.autoPlayFM(audios: self.dataArray, itemIndex: indexPath.section)
//        }
//                        
//        self.playingMusicChanged()
//    }
//    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        var cellHeight = 150.ckValue()
//        switch kaka_osType() {
//        case .iOS: cellHeight = 150.ckValue()
//        case .iPadOS: cellHeight = 180.ckValue()
//        case .macOS: cellHeight = 250.ckValue()
//        }
//        
//        return cellHeight
//    }
//    
//}
