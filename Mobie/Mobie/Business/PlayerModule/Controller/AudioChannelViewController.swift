//
//  AudioChannelViewController.swift
//  Mobie
//
//  Created by 张文 on 1/14/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import SafariServices

/// 定时器
class AudioChannelViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(titleLabel)
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalToSuperview().offset(25.ckValue())
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.overrideUserInterfaceStyle = .dark
        
        self.panModalSetNeedsLayoutUpdate()
        self.panModalTransition(to: .shortForm)
    }
    
    @objc func dismissAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    
    

    
    // MARK:  GET && SET
    
    lazy var dataArray: [AudioChannels] = {
        return [.mono, .stereo, .surround51, .surround71, .atmos]
    }()
    
    // MARK:  懒加载
    lazy var titleLabel: UILabel = {
        let sumStr = "Supported Channels".localStr()
                
        let attbuteStr = NSMutableAttributedString(string: sumStr, attributes: [.font: UIFontBold(18.ckValue()), .foregroundColor: UIColor.label])
        
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.attributedText = attbuteStr
        return view
    }()
    
    let footStr = "Audio formats with good multichannel support include DTS, as well as DSD, considered the ultimate audio format, with extensions usually being DSF and DFF.".localStr()
    
    var footHeight: CGFloat {
        get {
            let height = self.footStr.height(forWidth: self.view.width - 50.ckValue(), font: UIFontLight(12.ckValue()))
            return height
        }
    }
    
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 50.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PlayerTimerViewCell")
        return view
    }()
    
}

extension AudioChannelViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerTimerViewCell", for: indexPath)
        let channel = dataArray[indexPath.row]
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.image = channel.iconImage()
        cellConfig.text = channel.formatStr()
        cellConfig.imageProperties.maximumSize = CGSizeMake(30.ckValue(), 30.ckValue())
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        
        cell.accessoryView = selectImgView()

        cell.contentConfiguration = cellConfig
        
        return cell
    }
    
    func selectImgView() -> UIImageView {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle", color: UIColor.green))
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        view.contentMode = .scaleAspectFit
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let channel = dataArray[indexPath.row]
        
        let isClickVIP = !UserInfoManager.shared.isVIP() && (channel == .atmos || channel == .surround51 || channel == .surround71)
        
        if isClickVIP {
            self.vipCenterClick()
        }

    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.ckValue()
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.footStr
    }
    
}

extension AudioChannelViewController: PanModalPresentable {
    
    var panScrollable: UIScrollView? {
        return self.tableView
    }

    var longForm: PanModalHeight {
        return .contentHeightIgnoringSafeArea(55.ckValue() * CGFloat(dataArray.count + 1) + 200.ckValue())
    }
    
    var transitionAnimationOptions: UIView.AnimationOptions {
        return [.allowUserInteraction, .beginFromCurrentState]
    }
    
    var orientation: PanModalOrientation {
        return .vertical
    }
    
    var verticalOffset: CGFloat {
        return app_navHeight
    }
    
    var horizontalOffset: CGFloat {
        return 0
    }

    var shouldRoundTopCorners: Bool {
        return true
    }
    
    var cornerRadius: CGFloat {
        return 20.ckValue()
    }

    var anchorModalToLongForm: Bool {
        return false
    }
}
