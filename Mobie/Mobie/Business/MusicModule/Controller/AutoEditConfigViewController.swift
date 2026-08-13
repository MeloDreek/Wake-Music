//
//  AutoEditConfigViewController.swift
//  Mobie
//
//  Created by kaka on 2026/8/13.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

/*
 自动编辑配置
 1、填充模式：强制覆盖/仅填写空白
 2、歌词：无歌词时设置为纯音乐
 3、文件名称：不修改/艺术家-标题/标题-艺术家/标题

 4、批量自动编辑按钮
 5、试用期间：升级为终身会员
 */

/// 编辑前的配置弹窗
final class AutoEditConfigViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .clear
        
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + (kaka_IsMacOS() ? 0.1 : 0)) {
            self.setupUI()
            self.setupLayout()
            self.handleBueeness()
        }
    }

    // MARK: - Setup UI

    @objc func setupUI() {

        // 背景遮罩
        view.addSubview(mengView)

        // 弹窗容器
        view.addSubview(containerView)
        
        // 成就卡片图片
        containerView.addSubview(achieveCardView)
        
        // 配置列表
        containerView.addSubview(tableView)
        
        // 标题
        containerView.addSubview(titleLabel)
                
        // 关闭按钮
        containerView.addSubview(closeButton)
    }

    // MARK: - Layout
    @objc func setupLayout() {
        
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15.ckValue())
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        achieveCardView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.height.equalTo(achieveCardView.height)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
        
        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
    }
    
    @objc func handleBueeness() {
        self.perform(#selector(animateAction), with: nil, afterDelay: kaka_IsMacOS() ? 0 : 0.02)
    }
    
    // MARK:  GET && SET

    let duration = kaka_IsMacOS() ? 0 :  0.32
    
    var otherHeight: CGFloat {
        get {
            let isFreeTrail = UserInfoManager.shared.isFreeTrail
            let oneHeight = 20.ckValue() + (isFreeTrail ? 48.ckValue() : 15.ckValue())
            return oneHeight * 2 + 20.ckValue()
        }
    }
        
    var configModel = AutoEditConfig()
    
    var onSelectBlock: ((AutoEditConfig)->Void)?
        
    
    // MARK: 懒加载
    private var confettiLayer: CAEmitterLayer?
    
    lazy var mengView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.isHidden = kaka_IsMacOS()
        view.alpha = 1
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var closeButton: UIButton = {
        let view = UIButton(type: .custom)
        view.setTitle("Cancel".localStr(), for: .normal)
        view.titleLabel?.font = UIFontLight(15.ckValue())
        view.setTitleColor(appMainColor, for: .normal)
        view.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        return view
    }()
    
    lazy var containerView: UIView = {
#if targetEnvironment(macCatalyst)
        let view = UIView(frame: self.view.bounds)
#else
        let width = self.view.width * 0.88
        let height = achieveCardView.height + otherHeight
        let view = UIView(frame: CGRectMake((self.view.width - width) / 2, (self.view.height - height) / 2, width, height))
#endif
        view.alpha = 0
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20.ckValue()
        view.clipsToBounds = true
        return view
    }()
    
    lazy var achieveCardView: UIView = {
        let height = kaka_IsMacOS() ? self.view.height - otherHeight : (kaka_IsiPhone() ? 400 : 600)
        let view = UIView(frame: CGRectMake(0, 0, self.view.width, height))
        view.backgroundColor = .systemBackground
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.text = "Settings".localStr()
        view.font = UIFontBold(16.ckValue())
        view.textColor = UIColor.label
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = self.headView
        view.contentInset = UIEdgeInsets(top: 35.ckValue(), left: 0, bottom: 20.ckValue(), right: 0)
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(AutoEditConfigTableCell.self, forCellReuseIdentifier: "AutoEditConfigTableCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 80
        case .iPadOS: height = 100
        case .macOS: height = 100
        }
        
        let iconImage = UIImage(systemName: "slider.horizontal.3")
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
    
    lazy var dataArray: [[AutoEditConfigType]] = {
        let isFreeTrail = UserInfoManager.shared.isFreeTrail
        var basicArray: [AutoEditConfigType] = [.fillmodeType, .fileNameType, .lyricEditType]
        let editArray: [AutoEditConfigType] = [.batchAutoEditBtn]
        let payArray: [AutoEditConfigType] = [.upgradeLifetime]
                
        if isFreeTrail {
            return [basicArray] + [editArray] + [payArray]
        }else{
            return [basicArray] + [editArray]
        }
    }()
    
    // 填充模式
    func fillmodeView() -> UIView {
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.fillmodeMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = self.configModel.fillMode.titleStr()
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    
    func fillmodeMenu() -> UIMenu {
        let appearArray: [FillModeType] = [.fillEmptyOnly, .forceOverwrite]
        var actionArray = [UIAction]()
        for subType in appearArray {
            let action = UIAction(title: subType.titleStr(), image: nil, state: self.configModel.fillMode == subType ? .on : .off, handler: { [weak self] _ in
                self?.configModel.fillMode = subType
                self?.tableView.reloadData()
            })
            actionArray.append(action)
        }
        
        let menu = UIMenu(title: AutoEditConfigType.fillmodeType.titleStr(), children: actionArray)
        return menu
    }
    
    // 文件名称
    func filenameView() -> UIView {
        let view = UIMenuAccessView(frame: CGRectMake(0, 0, 100.ckValue(), 50.ckValue()))
        view.menu = self.filenameMenu()
        view.color = UIColor.secondaryLabel
        view.timeLabel.text = self.configModel.fileName.titleStr()
        view.contentHorizontalAlignment = .trailing
        view.showsMenuAsPrimaryAction = true
        return view
    }
    
    func filenameMenu() -> UIMenu {
        let appearArray = FileNameType.allCases
        var actionArray = [UIAction]()
        for subType in appearArray {
            let action = UIAction(title: subType.titleStr(), image: nil, state: self.configModel.fileName == subType ? .on : .off, handler: { [weak self] _ in
                if kaka_IsMacOS() && (subType != .default) {
                    let message1 = "Due to macOS privacy protections, apps from the App Store cannot be granted Full Disk Write Access.".localStr()
                    let message2 = "Waketag only has full read/write permissions for your system 【Music】 folder. Please ensure your audio files are inside the [Music] folder (~/Music) and try again.".localStr()
                    let message = message1 + "\r\r" + message2
                    self?.showTwoAlert(message: message, confirm: "Open the 【Music】 Folder".localStr(), cancle: "Continue".localStr()) {
                        self?.openSystemMusicFolder()
                    }
                }
                
                self?.configModel.fileName = subType
                self?.tableView.reloadData()
            })
            actionArray.append(action)
        }
        
        let menu = UIMenu(title: AutoEditConfigType.fileNameType.titleStr(), children: actionArray)
        return menu
    }
    
    func openSystemMusicFolder() {
        guard let musicURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first else {
                return
        }
            
        // Catalyst 会将 file:// 类型的文件夹 URL 交给系统的 Finder 响应打开
        UIApplication.shared.open(musicURL, options: [:]) { success in
            if !success {
                debugPrint("打开音乐文件夹失败")
            }
        }
    }
    
    // 歌词开关
    lazy var lyricSwitch: UISwitch = {
        let view = UISwitch(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        view.onTintColor = .systemGreen
        view.isOn = self.configModel.isSetInstrumental
        view.addTarget(self, action: #selector(switchViewClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func switchViewClick(_ sender: UISwitch) {
        self.configModel.isSetInstrumental = sender.isOn
    }
    
}

extension AutoEditConfigViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataArray[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellType = self.dataArray[indexPath.section][indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "AutoEditConfigTableCell", for: indexPath) as! AutoEditConfigTableCell
        cell.cellType = cellType
        switch cellType {
        case .fillmodeType:
            cell.accessoryView = self.fillmodeView()
            break
        case .fileNameType:
            cell.accessoryView = self.filenameView()
            break
        case .lyricEditType:
            cell.accessoryView = self.lyricSwitch
            break
        default:
            cell.accessoryView = nil
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cellType = self.dataArray[indexPath.section][indexPath.row]

        if cellType == .batchAutoEditBtn {
            
            if UserInfoManager.shared.isFreeTrail {
                if UserInfoManager.shared.autoEditFileCount >= 10 {
                    let message = "You have used your quota of 10 auto-edited audio fingerprint files during free trial, Lifetime Premium is recommended for unlimited access".localStr()
                    self.showTwoAlert(message: message, confirm: AutoEditConfigType.upgradeLifetime.titleStr()) {
                        self.vipButtonClick()
                    }
                    return
                }
            }
            
            self.onSelectBlock?(self.configModel)
            self.dismissAction()
        }
        if cellType == .upgradeLifetime {
            self.vipButtonClick()
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let cellType = self.dataArray[section].last
        return cellType?.footerStr()
    }
    
}

extension AutoEditConfigViewController {
    @objc func animateAction() {
        
        self.containerView.transform = CGAffineTransformMakeScale(0.01, 0.01)
        self.containerView.alpha = 0
        self.mengView.alpha = 0
        
        UIView.animate(withDuration: self.duration, animations: {
            self.containerView.alpha = 1
            self.mengView.alpha = 1
            self.containerView.transform = .identity
        }, completion: { finished in
        })
        
    }
    
    @objc func dismissAction() {
        
        self.containerView.transform = CGAffineTransformMakeScale(1, 1)
        self.containerView.alpha = 1
        self.mengView.alpha = 1
        
        UIView.animate(withDuration: duration, animations: {
            self.containerView.alpha = 0
            self.mengView.alpha = 0
            self.containerView.transform = CGAffineTransformMakeScale(0.01, 0.01)
        }) { finish in
            self.dismiss(animated: false)
        }
    }
    
    // 解锁VIP
    @objc func vipButtonClick() {
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
        }
        
        AppStoreKitManager.presentPurcharseVC(self)
    }
    
}

class AutoEditConfigTableCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var cellType: AutoEditConfigType? {
        didSet {
            guard let cellType = self.cellType else { return }
            
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.prefersSideBySideTextAndSecondaryText = true
            cellConfig.text = cellType.titleStr()
            cellConfig.secondaryText = cellType.secondsStr()
            self.accessoryType = .none
            
            switch cellType {
            case .fillmodeType:
                self.accessoryType = .none
                self.backgroundColor = .systemBackground
                break
            case .lyricEditType:
                self.accessoryType = .none
                self.backgroundColor = .systemBackground
                break
            case .fileNameType:
                self.accessoryType = .none
                self.backgroundColor = .systemBackground
                break
         
            case .batchAutoEditBtn:
                self.backgroundColor = UIColor.systemBlue
                cellConfig.textProperties.color = .white
                cellConfig.textProperties.alignment = .center
                cellConfig.textProperties.font = UIFontBold(15.ckValue())
                self.accessoryView = nil
                break
            case .upgradeLifetime:
                self.backgroundColor = UIColor.systemRed
                cellConfig.textProperties.color = .white
                cellConfig.textProperties.alignment = .center
                cellConfig.textProperties.font = UIFontBold(15.ckValue())
                self.accessoryView = nil
                break
            }
            
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: self.accessoryType == .disclosureIndicator ? 5 : 10)
            self.contentConfiguration = cellConfig
        }
    }
    
}

