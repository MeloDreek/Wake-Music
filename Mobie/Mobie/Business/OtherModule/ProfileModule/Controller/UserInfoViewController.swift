//
//  UserInfoViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/20.
//

import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AppGroupKit
import RevenueCat
import ProgressHUD

class UserInfoViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.tableView.frame = self.view.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = "Account".localStr()
                
#if !Target_Mobie_Pro
        self.refreshDataAction()
#endif
    }
    
    @objc func userInfoChanged() {
        self.tableView.reloadData()
        self.headView.update()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.largeTitleDisplayMode = .never

        self.headView.update()
    }
    
    @objc func refreshDataAction() {
        Purchases.shared.getCustomerInfo(fetchPolicy: .default) { [weak self] customerInfo, error in
            guard let customerInfo = customerInfo else {
                self?.tryStatus = .tryed
                self?.kaka_header.endRefreshing()
                self?.allRecords = []
                self?.customerInfo = nil
                self?.tableView.reloadData()
                return
            }
            
            self?.customerInfo = customerInfo
            self?.tryStatus = .tryed
            self?.kaka_header.endRefreshing()
            self?.allRecords = customerInfo.nonSubscriptions
            
            if let weeklyModel = customerInfo.subscriptionsByProductIdentifier[PurchaseStoreID.weekly.rawValue] {
                self?.allRecords.insert(weeklyModel, at: 0)
            }
            
            if let yearlyModel = customerInfo.subscriptionsByProductIdentifier[PurchaseStoreID.yearly.rawValue] {
                self?.allRecords.insert(yearlyModel, at: 0)
            }
                        
            self?.tableView.reloadData()
        }
    }
    
    func restorePurchage() {
        AppStoreKitManager.shared.restorePurcharge { [weak self] () in
            self?.refreshDataAction()
        } fail: { [weak self] errorMsg in
            guard let wSelf = self else { return }
            wSelf.tryStatus = .tryed
            wSelf.tableView.reloadData()
            wSelf.view.makeToast(errorMsg)
        }
    }
    
    // MARK:  GET && SET 
    
    var tryStatus: PurchageOpsStatus = .normal
    
    var customerInfo: CustomerInfo?
    
    lazy var allRecords: [NSObject] = {
        return [NSObject]()
    }()
    
    lazy var dataArray: [UserInfoGroupCellModel] = {
        var tempArray = [UserInfoGroupCellModel]()
        
        var itemArray: [UserInfoCellItemType] = [.nickName, .endDate]
#if !Target_Mobie_Pro
        if let storeID = AppStoreKitManager.shared.currentStoreID(), storeID.productType == .autoRenewableSubscription {
            itemArray = [.nickName, .endDate, .premium]
        }else{
            if !UserInfoManager.shared.isVIP() {
                itemArray = [.nickName, .endDate, .premium]
            }
        }
        
#endif
        let model1 = UserInfoGroupCellModel(group: .info, headTitle: nil, itemArray: itemArray, footTitle: nil)
        let model2 = UserInfoGroupCellModel(group: .purchage, headTitle: UserInfoCellItemType.purchageList.titleStr(), itemArray: [], footTitle: "Purchase records is associated with the Apple Account you are currently signed in to on your device".localStr())
        
        tempArray.append(model1)
#if !Target_Mobie_Pro
        tempArray.append(model2)
#endif
        
        return tempArray
    }()
    
    // MARK:  懒加载 
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.tableHeaderView = self.headView
#if !Target_Mobie_Pro && !targetEnvironment(macCatalyst)
        view.refreshControl = self.kaka_header
#endif
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell1")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell2")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell3")
        view.register(PurchageListViewcell.self, forCellReuseIdentifier: "PurchageListViewcell")
        view.register(PurchageOpsViewcell.self, forCellReuseIdentifier: "PurchageOpsViewcell")
        return view
    }()
    
    func thisDeviceView() -> UIImageView {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle", color: UIColor.systemBlue))
        view.contentMode = .scaleAspectFit
        view.size = CGSize(width: 25.ckValue(), height: 25.ckValue())
        return view
    }
    
    lazy var kaka_header: UIRefreshControl = {
        let view = UIRefreshControl()
        view.top = self.navigationController?.navigationBar.height ?? app_navHeight
        view.size = CGSizeMake(30.ckValue(), 30.ckValue())
        view.tintColor = .label
        view.addTarget(self, action: #selector(refreshDataAction), for: .valueChanged)
        return view
    }()
    
    lazy var headView: UserInfoHeadView = {
        let view = UserInfoHeadView(frame: CGRectMake(0, 0, self.view.width, 200.ckValue()))
        view.delegate = self
        return view
    }()
}

extension UserInfoViewController: UITableViewDataSource, UITableViewDelegate, UserInfoHeadViewDelegate, UIPopoverPresentationControllerDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let group = dataArray[section].group
        if group == .info {
            return dataArray[section].itemArray.count
        }else if group == .purchage {
            return self.allRecords.count > 0 ? self.allRecords.count : 1
        }else{
            return dataArray[section].itemArray.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = dataArray[indexPath.section].group
        
        if group == .info {
            // 用户信息
            let item = dataArray[indexPath.section].itemArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell1", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.imageProperties.maximumSize = CGSize(width: 25.ckValue(), height: 25.ckValue())
            cellConfig.image = item.cellImage()
            cellConfig.text = item.titleStr()
            cellConfig.textProperties.color = UIColor.label
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
            if item == .endDate {
                let isVIP = UserInfoManager.shared.isVIP()
                cellConfig.secondaryTextProperties.color = isVIP ? self.view.tintColor : UIColor.red
                cellConfig.secondaryText = UserInfoManager.shared.vipExpirationDate()
            }
#if !DEBUG
            if item == .premium {
                cellConfig.prefersSideBySideTextAndSecondaryText = true
                cellConfig.secondaryTextProperties.color = .secondaryLabel
                cellConfig.secondaryText = UserInfoManager.shared.isVIP() ? "Beta" : nil
            }
#endif
            cell.contentConfiguration = cellConfig
            cell.accessoryType = .disclosureIndicator
            
            return cell
        } else {
            if self.allRecords.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "PurchageListViewcell", for: indexPath) as! PurchageListViewcell
                let subModel = self.allRecords[indexPath.row]
                if let customerInfo = self.customerInfo, let nonSubscript = subModel as? NonSubscriptionTransaction {
                    cell.updateRecord(allModel: customerInfo, nonSubModel: nonSubscript)
                }
                if let customerInfo = self.customerInfo, let subscriptModel = subModel as? SubscriptionInfo {
                    cell.updateRecord(allModel: customerInfo, subModel: subscriptModel)
                }
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "PurchageOpsViewcell") as! PurchageOpsViewcell
                cell.status = self.tryStatus
                cell.onClickCallBack = { [weak self] () in
                    self?.restorePurchage()
                }
                return cell
            }
        }
        
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let group = dataArray[indexPath.section].group
        if group == .info {
            let item = dataArray[indexPath.section].itemArray[indexPath.row]
            if item == .nickName {
                self.editNickAction()
            }
            
            if item == .premium {
                self.vipCenterClick()
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataArray[section].headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return dataArray[section].footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let group = dataArray[indexPath.section].group
        
        if group == .purchage {
            if self.allRecords.count > 0 {
                return 100.ckValue()
            }else{
                return 150.ckValue()
            }
        }else{
            return 50.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.ckValue()
    }
    
    // 点击头像
    func userHeadViewClickAVatar(view: UserInfoHeadView) {
        let avatarVC = SelectAvatarViewController()
        
        avatarVC.onModifyCallBack = { [weak self] () in
            self?.headView.update()
            self?.tableView.reloadData()
        }
        avatarVC.preferredContentSize = CGSize(width: 300.ckValue(), height: 330.ckValue())
        avatarVC.modalPresentationStyle = .popover
        let popVC = avatarVC.popoverPresentationController
        popVC?.delegate = self
        popVC?.backgroundColor = UIColor.clear
        popVC?.permittedArrowDirections = .up
        popVC?.sourceRect = view.avatarView.bounds
        popVC?.sourceView = view.avatarView
        self.present(avatarVC, animated: true)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    func editNickAction() {
                
        let editAlertVC = UIAlertController(title: "Nickname".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let placeText = "Nickname".localStr()
            let placeAttbute = NSAttributedString(string: placeText, attributes: [.font: UIFontLight(15.ckValue()), .foregroundColor: UIColor.placeholderText])
            textView.attributedPlaceholder = placeAttbute
            textView.text = UserInfoManager.shared.nickName
            textView.clearButtonMode = .always
        }
        
        editAlertVC.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil))
        editAlertVC.addAction(UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
                        
            UserInfoManager.shared.nickName = nameText
            
            self.tableView.reloadData()
            self.headView.update()
            
        }))
        self.present(editAlertVC, animated: true)
    }
}
