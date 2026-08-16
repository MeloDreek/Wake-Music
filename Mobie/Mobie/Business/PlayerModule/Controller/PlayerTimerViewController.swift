//
//  PlayerTimerViewController.swift
//  Mobie
//
//  Created by 张文 on 11/13/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal

/// 定时器
class PlayerTimerViewController: SuperViewController {
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
        
    }
    
    @objc func dismissAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    // MARK:  GET && SET
    lazy var dataArray: [TimeInterval?] = {
        return [nil, 10.0 * 60.0, 20.0 * 60.0, 30.0 * 60.0, 60.0 * 60.0, 90.0 * 60.0, 120.0 * 60.0]
    }()
    
    // MARK:  懒加载
    lazy var titleLabel: UILabel = {
        let sumStr = "Sleep Timer".localStr()
                
        let attbuteStr = NSMutableAttributedString(string: sumStr, attributes: [.font: UIFontBold(18.ckValue()), .foregroundColor: UIColor.label])
        
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.attributedText = attbuteStr
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PlayerTimerViewCell")
        return view
    }()
    
}

extension PlayerTimerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerTimerViewCell", for: indexPath)
        let time = dataArray[indexPath.row]
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        if let time = time {
            let miniteStr = String(format: "%.0f", time / 60.0)
            cellConfig.text = String(format: "%@ mins".localStr(), miniteStr)
        }else{
            cellConfig.text = "Off".localStr()
        }

        let isSelect = MusicConfigManager.shared.sleepTime == time
        cell.accessoryView = isSelect ? selectImgView() : unselectImgView()
        cell.contentConfiguration = cellConfig
        
        return cell
    }
    
    func selectImgView() -> UIImageView {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle", color: UIColor.green))
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let time = dataArray[indexPath.row]
        MusicConfigManager.shared.sleepTime = time
        KakaMusicPlayer.shared.setupSleepTimer()
        self.dismissAction()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.ckValue()
    }

}

extension PlayerTimerViewController: PanModalPresentable {
    var panScrollable: UIScrollView? {
        return self.tableView
    }

    var shouldRoundTopCorners: Bool {
        return true
    }
    
    var longForm: PanModalHeight {
        return .contentHeightIgnoringSafeArea(55.ckValue() * CGFloat(dataArray.count + 1) + 80.ckValue() + kaka_safeAreaInsets().bottom)
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
    
    var cornerRadius: CGFloat {
        return 25.ckValue()
    }

    var anchorModalToLongForm: Bool {
        return false
    }
    
    var transitionAnimationOptions: UIView.AnimationOptions {
        return [.allowUserInteraction, .beginFromCurrentState]
    }
    
}
