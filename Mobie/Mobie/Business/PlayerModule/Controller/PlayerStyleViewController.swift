//
//  PlayerStyleViewController.swift
//  Mobie
//
//  Created by 张文 on 12/24/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import StoreKit
import Kingfisher
import SafariServices

/// 播放器样式
class PlayerStyleViewController: SuperViewController {
    
    deinit {
        
        ImageCache.default.clearMemoryCache()
#if !DEBUG
        if self.isChanged && self.currentViewController() is MusicPlayerViewController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
#endif
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = "Player Style".localStr()
        
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cancelButtonClick))
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "wand.and.rays"), style: .plain, target: self, action: #selector(playBackgroundAction))
    }
    
    
    @objc func playBackgroundAction() {
        let playbackground = PlayBackgroundListController()
        self.navigationController?.pushViewController(playbackground, animated: true)
    }
        
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { [weak self] context in
            self?.tableView.reloadData()
        } completion: {  context in
            
        }
    }
    
    // MARK:  GET && SET
    lazy var dataArray: [PlayerUICellModel] = {
        let model1 = PlayerUICellModel(group: .defaultGroup, headTitle: "Default".localStr(), itemArray: [.defaultRect, .defaultCircle, .default8Side], footTitle: nil)
        
        let model2 = PlayerUICellModel(group: .tapeGroup, headTitle: "Cassette Tape".localStr(), itemArray: [], footTitle: nil)
        
        let model3 = PlayerUICellModel(group: .vinylGroup, headTitle: "Vinyl".localStr(), itemArray: [], footTitle: nil)
        
        return [model1, model2, model3]
    }()
    
    var isChanged: Bool = false
    
    lazy var tapeArray: [PlayerUIStyle] = {
        return [.tape1, .tape2, .tape3, .tape4, .tape5, .tape6, .tape7, .tape8]
    }()
    
    lazy var vinyArray: [PlayerUIStyle] = {
        return [.Vinyl1, .Vinyl2, .Vinyl3, .Vinyl4, .Vinyl5, .Vinyl6, .Vinyl7, .Vinyl8]
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let tabheight = self.tabBarController?.tabBar.height ?? 0
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: tabheight + 30.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PlayerStyleDefaultTableCell.self, forCellReuseIdentifier: "PlayerStyleDefaultTableCell")
        view.register(PlayerStyleTapeTableCell.self, forCellReuseIdentifier: "PlayerStyleTapeTableCell")
        view.register(PlayerStyleVinylTableCell.self, forCellReuseIdentifier: "PlayerStyleVinylTableCell")
        return view
    }()
    
}

extension PlayerStyleViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let cellModel = dataArray[section]
        if cellModel.group == .defaultGroup {
            return cellModel.itemArray.count
        }else if cellModel.group == .tapeGroup {
            return 1
        }else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .defaultGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerStyleDefaultTableCell", for: indexPath) as! PlayerStyleDefaultTableCell
            cell.itemType = cellModel.itemArray[indexPath.row]
            return cell
        }else if cellModel.group == .tapeGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerStyleTapeTableCell", for: indexPath) as! PlayerStyleTapeTableCell
            cell.tapeArray = self.tapeArray
            cell.onClickCallBack = { [weak self] (style) in
                guard UserInfoManager.shared.isVIP() else {
                    self?.vipCenterClick()
                    return
                }
                
                MusicConfigManager.shared.playerStyle = style
                self?.isChanged = true
                self?.tableView.reloadData()
                
                let message = "Set successfully! Continue to customize your wallpaper and rendering effects?".localStr()
                self?.showTwoAlert(message: message, confirm: "Custom Wallpaper".localStr()) {
                    self?.playBackgroundAction()
                }
                
            }
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerStyleVinylTableCell", for: indexPath) as! PlayerStyleVinylTableCell
            cell.vinyArray = self.vinyArray
            cell.onClickCallBack = { [weak self] (style) in
                guard UserInfoManager.shared.isVIP() else {
                    self?.vipCenterClick()
                    return
                }
                
                MusicConfigManager.shared.playerStyle = style
                self?.isChanged = true
                self?.tableView.reloadData()
                
                let message = "Set successfully! Continue to customize your wallpaper and rendering effects?".localStr()
                self?.showTwoAlert(message: message, confirm: "Custom Wallpaper".localStr()) {
                    self?.playBackgroundAction()
                }
                
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .defaultGroup {
            let style = cellModel.itemArray[indexPath.row]
            
            MusicConfigManager.shared.playerStyle = style
            self.isChanged = true
            self.tableView.reloadData()
            
            let message = "Set successfully! Continue to customize your wallpaper and rendering effects?".localStr()
            self.showTwoAlert(message: message, confirm: "Custom Wallpaper".localStr()) {
                self.playBackgroundAction()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .vinylGroup {
            let cellWidth = (tableView.bounds.width - PlayerStyleVinylTableCell.itemSpace * 3) / 2 - 1
            let cellHeight = cellWidth * 0.88 + 80.ckValue()
            return CGFloat(self.vinyArray.count / 2) * cellHeight
        }else if cellModel.group == .tapeGroup {
            let tapeImage: UIImage = UIImage(named: "tape_back")!
            let tapeValue = tapeImage.size.height / tapeImage.size.width
            
            let cellWidth = (tableView.bounds.width - PlayerStyleTapeTableCell.itemSpace * 1 - 40.ckValue()) / 2 - 1
            let cellHeight = cellWidth * tapeValue + 30.ckValue() + PlayerStyleTapeTableCell.itemSpace
            return CGFloat(self.tapeArray.count / 2) * cellHeight + PlayerStyleTapeTableCell.itemSpace * 2
        }else{
            return UITableView.automaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.footTitle
    }
}
