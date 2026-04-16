//
//  AboutAppViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import KakaUIKit
import KakaObjcKit
import AppGroupKit
import SafariServices
import AVFoundation
import AVKit

/// 关于APP信息
class AboutAppViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
        tableView.reloadData()
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = SettingCellItemType.abountUS.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.perform(#selector(getCacheSize), with: nil, afterDelay: 1)
    }
    
    @objc func getCacheSize() {
        DispatchQueue.global().sync {
            let cache = KakaCacheTools.getCacheSize()
            DispatchQueue.main.async {                
                self.cacheSize = cache
                self.tableView.reloadData()
            }
        }
    }
    
    var cacheSize: String = ""
    
    let nameStory = "In the summer of 2024, the first challenge I faced after deciding to develop this app was figuring out what to name it. One night, I heard the song 'Wake' by Hillsong Young & Free. It's an incredibly uplifting and energetic song. After reading the lyrics and learning about the band's story, the name for the app was born.".localStr()
    
    // MARK:  GET && SET 
    // App logo、隐私政策、服务条款，欢迎页、清理缓存
    lazy var dataArray: [[AboutAppCellType]] = {
        let section1: [AboutAppCellType] = [.crossSystem, .appStore, .nameStory]
        let section2: [AboutAppCellType] = [.privacy, .userMent]
        var section3: [AboutAppCellType] = [.systemSet, .cleanCache]
        if kaka_IsMacOS() {
            section3.removeFirst()
        }
        return [section1, section2, section3]
    }()
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight + 30.ckValue(), right: 0)
        view.register(AboutAppTableCell.self, forCellReuseIdentifier: "AboutAppTableCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "AboutTableViewCell")
        return view
    }()
    
}

extension AboutAppViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataArray[indexPath.section][indexPath.row]
        if item == .crossSystem {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutAppTableCell", for: indexPath) as! AboutAppTableCell
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutTableViewCell", for: indexPath)
            cell.accessoryType = .disclosureIndicator
            var cellConfig = UIListContentConfiguration.sidebarCell()
            cellConfig.text = item.titleStr()
            cellConfig.secondaryText = item.descStr()
            cellConfig.textProperties.color = UIColor.label
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 0)
            
            if item == .cleanCache {
                cellConfig.secondaryText = self.cacheSize
            }
            
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            
            cell.contentConfiguration = cellConfig
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = dataArray[indexPath.section][indexPath.row]
        if item == .appStore {
            let storeURL = Application.wakeMusic.appstoreURL()
            UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
        }
        
        if item == .nameStory {
            self.showOneAlert(title: "Reminder".localStr(), message: nameStory) {
                self.clickAppNameStory()
            }
        }
        
        if item == .systemSet {
            if let vURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(vURL)
            }
        }
        
        if item == .privacy {
            guard let vUrl = URL(string: kPrivacyUrl) else { return }
            
            if kaka_IsMacOS() {
                UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
            }else{
                let webVC = SFSafariViewController(url: vUrl)
                webVC.preferredControlTintColor = appMainColor
                self.present(webVC, animated: true)
            }
        }
        
        if item == .userMent {
            guard let vUrl = URL(string: kUseItemUrl) else { return }
            
            if kaka_IsMacOS() {
                UIApplication.shared.open(vUrl, options: [:], completionHandler: nil)
            }else{
                let webVC = SFSafariViewController(url: vUrl)
                webVC.preferredControlTintColor = appMainColor
                self.present(webVC, animated: true)
            }
        }
        
        if item == .cleanCache {
            KakaCacheTools.finishCacheCompletion { [weak self] () in
                self?.cacheSize = "0kb"
                self?.tableView.reloadData()
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = dataArray[indexPath.section][indexPath.row]
        return item == .crossSystem ? 220.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return 30.ckValue()
        }else if section == 2 {
            let image = Reasource.named("welcome_system")
            let imageValue = image.size.height / image.size.width
            
            return contentView.width * imageValue + 30.ckValue()
        }else{
            return 20.ckValue()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return self.createBeianView()
        }else if section == 2 {
            return self.createFootView()
        }else{
            return UIView()
        }
    }
    
    func createBeianView() -> UITableViewHeaderFooterView {
#if Target_Mobie_Pro
        let beianhao = "粤ICP备2023115933号-7A"
#else
        let beianhao = "粤ICP备2023115933号-5A"
#endif
        
        let footView = UITableViewHeaderFooterView()
        let footLabel = UILabel()
        footLabel.text = beianhao
        footLabel.textColor = .secondaryLabel
        footLabel.font = UIFontLight(12.ckValue())
        footLabel.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        footLabel.isHidden = PhoneSetManager.formatLanguage() != .chinese_simplified
        footView.contentView.addSubview(footLabel)
        footLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20.ckValue())
            make.top.equalTo(10.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        return footView
    }
    
    func createFootView() -> UITableViewHeaderFooterView {
        let image = Reasource.named("welcome_system")
        let imageValue = image.size.height / image.size.width
        
        let footView = UITableViewHeaderFooterView()
        let systemIconView = UIImageView(image: image)
        systemIconView.contentMode = .scaleAspectFit
        footView.contentView.addSubview(systemIconView)
        systemIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10.ckValue())
            make.width.equalToSuperview().multipliedBy(0.9)
            make.height.equalTo(systemIconView.snp.width).multipliedBy(imageValue)
        }
        return footView
    }
    
    func clickAppNameStory() {
        let fileURL = URL(fileURLWithPath: Reasource.fullFilePath("wake_music.mp4"))
        
        #if targetEnvironment(macCatalyst)
        UIApplication.shared.open(fileURL)
        #else
        let player = AVPlayer(url: fileURL)
        let playerViewController = KakaAVPlayerViewController()
        playerViewController.overrideUserInterfaceStyle = .dark
        playerViewController.player = player
        playerViewController.entersFullScreenWhenPlaybackBegins = true
        playerViewController.exitsFullScreenWhenPlaybackEnds = true
        self.present(playerViewController, animated: true)
        
        #endif
    }
    
}
