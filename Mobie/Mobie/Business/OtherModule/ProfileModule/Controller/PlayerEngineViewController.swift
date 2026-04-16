//
//  PlayerEngineViewController.swift
//  Mobie
//
//  Created by 张文 on 5/14/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import SafariServices
import Combine

/// 选择播放器引擎
class PlayerEngineViewController: SuperViewController {
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
        self.title = SettingCellItemType.selectPlayer.titleStr()
        
        if self.isPresent() && self.splitViewController == nil {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarClick))
        }
        
        // 播放引擎切换了
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlayerEngine), name: Notification.Name(rawValue: kPlayerEngineChangedKey), object: nil)
        
        self.navigationItem.largeTitleDisplayMode = .never
        
    }
    
    @objc func updatePlayerEngine() {
        self.tableView.reloadData()
    }
    
    @objc func cancelBarClick() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    // MARK:  GET && SET
    var cancellables = Set<AnyCancellable>()
    
    // MARK:  懒加载
    lazy var dataArray: [PlayerEngineType] = {
        return [.avPlayer, .wakePlayer, .autoPlayer]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.tableHeaderView = self.headView
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: kaka_IsiPhone() ? 0 : 5.ckValue(), left: 0, bottom: playingHeight + kaka_safeAreaInsets().bottom / 2 + 30.ckValue(), right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ExportTableViewCell")
        view.register(PlayerEngineViewCell.self, forCellReuseIdentifier: "PlayerEngineViewCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        let iconImage = SettingCellItemType.selectPlayer.cellImage()
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 100
        }
        
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

extension PlayerEngineViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count + 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == dataArray.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = "Supports All Formats".localStr()
            #if !targetEnvironment(macCatalyst)
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
            #endif
            cellConfig.textProperties.color = UIColor.deAccent
            cellConfig.textProperties.alignment = .center
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
            cell.backgroundColor = appMainColor
            cell.accessoryType = .none
            cell.contentConfiguration = cellConfig
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerEngineViewCell", for: indexPath) as! PlayerEngineViewCell
            cell.updatePlayerEngine(dataArray[indexPath.section])
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == dataArray.count {
            self.jumpSupportAppAction()
            return
        }
        
        let playerEngine = dataArray[indexPath.section]

        if !UserInfoManager.shared.isVIP() && playerEngine != .avPlayer {
            self.vipCenterClick()
            return
        }
        
        MusicConfigManager.shared.playerEngine = playerEngine
        
        self.cancelBarClick()
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == dataArray.count {
            return nil
        } else {
            let playerEngine = dataArray[section]
            return playerEngine.descStr()
        }
    }

    
    @objc func jumpSupportAppAction() {
        let mediaVC = SupportTypeViewController()
        self.navigationController?.pushViewController(mediaVC, animated: true)
    }
    
    
    

}

class PlayerEngineViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePlayerEngine(_ playerEngine: PlayerEngineType) {
        var cellConfig = UIListContentConfiguration.cell()
        if !UserInfoManager.shared.isVIP() && playerEngine != .avPlayer {
            cellConfig.text = nil
            cellConfig.attributedText = self.createAttributedString(withText: playerEngine.titleStr(), andImage: UIImage(named: "pro_crown")!)
        }else{
            cellConfig.text = playerEngine.titleStr()
            cellConfig.attributedText = nil
        }
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        self.contentConfiguration = cellConfig
        
        let isSelect = MusicConfigManager.shared.playerEngine == playerEngine
        self.accessoryType = .none
        self.accessoryView = isSelect ? self.selectImgView() : self.unselectImgView()
        
    }
    
    func selectImgView() -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", compatibleWith: .current))
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.tintColor = appMainColor
        view.contentMode = .scaleAspectFit
        return view
    }
    
    func unselectImgView() -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: "circle", compatibleWith: .current))
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.tintColor = UIColor.tertiaryLabel
        view.contentMode = .scaleAspectFit
        return view
    }
    
    func createAttributedString(withText text: String, andImage image: UIImage) -> NSAttributedString {
        
        let spaceText = text + "  "
        let imageValue = image.size.height / image.size.width
        let textFont = UIListContentConfiguration.cell().textProperties.font
        
        // 创建一个可变的属性字符串
        let attributedString = NSMutableAttributedString(string: spaceText)

        // 设置文本的属性，例如字体和颜色
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.label
        ]
        attributedString.addAttributes(textAttributes, range: NSRange(location: 0, length: spaceText.count))

        // 创建一个 NSTextAttachment 来存放图片
        let textAttachment = NSTextAttachment()
        textAttachment.image = image

        // 设置图片的大小
        let imageSize = CGSize(width: textFont.lineHeight / imageValue, height: textFont.lineHeight)
        textAttachment.bounds = CGRect(x: 0, y: -3.ckValue(), width: imageSize.width, height: imageSize.height)

        // 将图片转换为 NSAttributedString
        let imageAttributedString = NSAttributedString(attachment: textAttachment)

        // 将图片添加到属性字符串的末尾
        attributedString.append(imageAttributedString)

        return attributedString
    }
    
}
