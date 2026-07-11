//
//  PrimaryToolViewController.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import AppGroupKit
import Combine

protocol PrimaryToolViewControllerDelegate: AnyObject {
    // 点击Cell
    func primaryControllerDidCellItem(controller: PrimaryToolViewController, itemType: PrimaryCellItemType)
    
}

class PrimaryToolViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.view.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        contentView.addSubview(tableView)
        contentView.addSubview(premiumView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        premiumView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-macTabbarHeight - 25.ckValue())
            make.centerX.equalToSuperview()
            make.width.equalTo(premiumView.width)
            make.height.equalTo(premiumView.height)
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.18) {
            self.tableView(self.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
            self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: true, scrollPosition: .middle)
        }
        
        // 前往连接页面
        NotificationCenter.default.addObserver(self, selector: #selector(jumpConnectPage), name: Notification.Name(kJumpConnectPageKey), object: nil)
                
        // 主题颜色已经变化
        NotificationCenter.default.addObserver(self, selector: #selector(appModeStyleChanged(_:)), name: Notification.Name(kAppThemeColorChangedKey), object: nil)
        
        // 播放引擎切换了
        NotificationCenter.default.addObserver(self, selector: #selector(updateDownloadCount), name: Notification.Name(kPlayerEngineChangedKey), object: nil)
        
        // 开始倒计时
        NotificationCenter.default.addObserver(self, selector: #selector(setupDiscountTimer), name: Notification.Name(rawValue: kStartDiscountPriceKey), object: nil)
        
        // 监听支付成功
        NotificationCenter.default.addObserver(self, selector: #selector(setupNavigationItem), name: Notification.Name(kPurchageSuccessKey), object: nil)
        
        self.setupNavigationItem()
        
        if DiscountIAPManager.shared.isShowDiscount() {
            self.perform(#selector(setupDiscountTimer), with: nil, afterDelay: 1)
        }
        
        // 新增了下载文件
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateDownloadCount()
            }.store(in: &cancellables)
        
    }
    
    @objc func setupDiscountTimer() {
        if !DiscountIAPManager.shared.isShowDiscount() {
            return
        }
        
        if UserInfoManager.shared.isVIP() {
            return
        }
        
        self.timer.startTimer(seconds: 1.0, repeats: true, callSoon: true) { [weak self] vTime in
            guard let wSelf = self else { return }
            guard let lastDiscountTime = DiscountIAPManager.shared.lastDiscountTime else {
                DiscountIAPManager.shared.lastDiscountTime = Date().timeIntervalSince1970
                return
            }
            
            let nowDate = Date()
            
            var leftTime = nowDate.timeIntervalSince1970 - lastDiscountTime
            leftTime = wSelf.maxDiscountTime - leftTime
            
            if leftTime < 0 {
                vTime.stopTimer()
            }
            
            NotificationCenter.default.post(name: Notification.Name(kDiscountLeftTimeKey), object: nil, userInfo: ["leftTime": leftTime])
            
        }
    }
    
    @objc func loginThirdServerSuccess(_ noti: Notification) {
        self.tableView(self.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        self.taskCount = DownloadManager.shared.taskArray.count
        self.tableView.reloadData()
    }
    
    @objc func updateDownloadCount() {
        let taskArray = DownloadManager.shared.taskArray
        self.taskCount = taskArray.count
        self.tableView.reloadData()
        
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(taskArray.count)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = taskArray.count
        }
    }
    
    @objc func jumpConnectPage() {
        self.tableView(self.tableView, didSelectRowAt: IndexPath(row: 0, section: 1))
        self.tableView.selectRow(at: IndexPath(row: 0, section: 1), animated: true, scrollPosition: .middle)
    }
    
    @objc func appModeStyleChanged(_ noti: Notification) {
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()

    // 默认倒计时3小时
    let maxDiscountTime: Double = DiscountIAPManager.shared.maxDiscountTime
    
    lazy var dataArray: [PrimaryCellGroupModel] = {
        let model1 = PrimaryCellGroupModel(group: .musicGroup, headTitle: "Offline".localStr(), itemArray: [.allMusics, .artist, .album, .genre], footTitle: nil)
        let model2 = PrimaryCellGroupModel(group: .connectGroup, headTitle: "Connect".localStr(), itemArray: [.connect, .download], footTitle: nil)
        let model3 = PrimaryCellGroupModel(group: .otherGroup, headTitle: "Others".localStr(), itemArray: [.selectEngine, .guideiOS, .settings], footTitle: nil)
        return [model1, model2, model3]
    }()
    
    var delegate: PrimaryToolViewControllerDelegate?
        
    var taskCount: Int = DownloadManager.shared.taskArray.count
        
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PrimaryToolViewCell")
        return view
    }()
    
    lazy var timer: KakaTimer = {
        let timer = KakaTimer()
        return timer
    }()
    
    lazy var premiumView: PremiumTimerView = {
        let view = PremiumTimerView(frame: CGRectMake(0, 0, PremiumTimerView.maxWidth(), 40.ckValue()))
        view.onStopCallback = { [weak self] () in
            self?.setupNavigationItem()
        }
        view.addTarget(self, action: #selector(vipCenterClick), for: .touchUpInside)
        return view
    }()
    
    @objc func setupNavigationItem() {
        self.premiumView.isHidden = UserInfoManager.shared.isVIP()
    }
    
    func countLabel(_ count: Int) -> UILabel? {
        
        if count == 0 { return nil }
        
        let text = "\(count)"
        let font = UIListContentConfiguration.cell().secondaryTextProperties.font
        
        let width = text.width(font) + 16.ckValue()
        let height = font.lineHeight + 6.ckValue()
        
        let label = UILabel(frame: CGRectMake(0, 24.ckValue(), width, height))
        label.text = text
        label.font = font
        label.textColor = .white
        label.backgroundColor = .red
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.layer.cornerRadius = height / 2
        return label
    }
    
    
    func warningView() -> UIImageView {
        let view = UIImageView(image: Reasource.systemNamed("exclamationmark.triangle.fill", color: .systemRed))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(20.ckValue(), 20.ckValue())
        return view
    }
    
    func getAccessoryView(_ itemType: PrimaryCellItemType) -> UIView? {
        if itemType == .download {
            return self.countLabel(self.taskCount)
        }else if itemType == .selectEngine {
            return MusicConfigManager.shared.playerEngine == .avPlayer ? self.warningView() : nil
        }else{
            return nil
        }
    }
    
}

extension PrimaryToolViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cellModel = dataArray[section]
        return cellModel.itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PrimaryToolViewCell", for: indexPath)
        var cellConfig = UIListContentConfiguration.cell()

        let cellModel = dataArray[indexPath.section]
        let itemType = cellModel.itemArray[indexPath.row]
        cellConfig.image = itemType.cellImage()
        cellConfig.text = itemType.titleStr()
        cell.accessoryView = self.getAccessoryView(itemType)
        
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        cell.accessoryType = .none
        cell.contentConfiguration = cellConfig
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = dataArray[indexPath.section]
        
        let itemType = cellModel.itemArray[indexPath.row]
        
        self.delegate?.primaryControllerDidCellItem(controller: self, itemType: itemType)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataArray[section].headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return dataArray[section].footTitle
    }
}
