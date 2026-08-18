//
//  DonateViewController.swift
//  Mobie
//
//  Created by 张文 on 10/8/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import ProgressHUD
import StoreKit
import RevenueCat

/// 捐赠
class DonateViewController: SuperViewController {
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
        self.title = "Donate".localStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
//        self.selectModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.option3.rawValue }).first
//        
//        AppStoreKitManager.shared.refresDonationPrice(productIds: [.option1, .option2, .option3]) { models in
//            self.priceArray = models
//            self.selectModel = self.priceArray.filter({ $0.productIdentifier == PurchaseStoreID.option3.rawValue }).first
//            self.tableView.reloadData()
//        }
        
        // 监听网络变化
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilitySwiftChanged, object: reachability)
        
        try? self.reachability.startNotifier()
    }
    
    // 网络状态变化了
    @objc func reachabilityChanged(note: Notification) {
        guard let reachability = note.object as? ReachabilitySwift else { return }
        
        debugPrint("当前网络授权状况 = \(reachability.connection.description)")
        
        self.netConnect = reachability.connection
    }
    
    // MARK:  GET && SET
    var selectModel: StoreProduct?
    
    var netConnect: ReachabilitySwift.Connection = .unavailable
    
    // MARK:  懒加载
    lazy var reachability: ReachabilitySwift = {
        return try! ReachabilitySwift()
    }()
    
    lazy var tableView: UITableView = {
        let tabheight = self.tabBarController?.tabBar.height ?? 0
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = 50.ckValue()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: tabheight + 30.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(DonateHeadCell.self, forCellReuseIdentifier: "DonateHeadCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PriceTableViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PurchageViewCell")
        return view
    }()
    
    lazy var priceArray: [StoreProduct] = {
        return AppStoreKitManager.shared.donationArray
    }()
    
}

extension DonateViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return priceArray.count + 1
        }else{
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DonateHeadCell", for: indexPath) as! DonateHeadCell
            
            return cell
        }else if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PriceTableViewCell", for: indexPath)
            let isLast = priceArray.count == indexPath.row
            var cellConfig = UIListContentConfiguration.cell()

            if isLast {
                cellConfig.text = "Rate Us 5 Stars".localStr()
                cellConfig.textProperties.color = UIColor.systemRed
                cellConfig.textProperties.alignment = .center
            }else{
                let model = priceArray[indexPath.row]
                let isSelect = model.productIdentifier == self.selectModel?.productIdentifier
                
                cellConfig.text = model.localizedPriceString
                cellConfig.image = UIImage(systemName: isSelect ? "checkmark.circle.fill" : "circle")
                cellConfig.imageProperties.maximumSize = CGSize(width: 30.ckValue(), height: 30.ckValue())
            }
            
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            cellConfig.imageToTextPadding = 15
            
            cell.accessoryType = isLast ? .none : .disclosureIndicator
            cell.contentConfiguration = cellConfig
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "PurchageViewCell", for: indexPath)
            cell.backgroundColor = appMainColor
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = "Support Us".localStr()
            cellConfig.textProperties.alignment = .center
            cellConfig.textProperties.color = UIColor.deAccent
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            cellConfig.axesPreservingSuperviewLayoutMargins = .horizontal
            cell.contentConfiguration = cellConfig
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            let isLast = priceArray.count == indexPath.row
            if isLast {
                let vUrl = Application.wakeMusic.appstoreWriteURL()
                UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
            }else{
                self.selectModel = self.priceArray[indexPath.row]
                self.tableView.reloadData()
            }
        }
        
        if indexPath.section == 2 {
            self.startPurchageAction()
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return UITableView.automaticDimension
        } else if indexPath.section == 1 {
            return 50.ckValue()
        } else {
            return 50.ckValue()
        }
    }

}

class DonateHeadCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(starImgView)
        self.addSubview(premiumLabel)
        self.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
        }
        
        premiumLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descLabel.snp.top).offset(-6.ckValue())
            make.leading.equalToSuperview()
            make.height.greaterThanOrEqualTo(0)
            make.centerX.equalToSuperview()
        }
        
        starImgView.snp.makeConstraints { make in
            make.bottom.equalTo(premiumLabel.snp.top).offset(-10.ckValue())
            make.centerX.equalToSuperview()
            make.size.equalTo(135.ckValue())
            make.top.equalToSuperview()
        }
        
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    // MARK:  GET && SET
    
    
    // MARK:  懒加载
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("heart.fill"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var premiumLabel: UILabel = {
        let view = UILabel()
        view.text = "We need your help".localStr()
        view.font = UIFontBold(20.ckValue())
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textColor = .label
        view.text = "This is a large project, and we're committed to providing you with the best possible music experience. Your donation not only supports our work, but also helps us continue improving the app and bringing you new features. Thank you for your support!".localStr()
        view.font = UIFontLight(15.ckValue())
        view.textAlignment = .center
        return view
    }()
    
}
