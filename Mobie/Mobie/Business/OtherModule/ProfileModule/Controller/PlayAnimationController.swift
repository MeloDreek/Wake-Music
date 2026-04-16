//
//  PlayAnimationController.swift
//  Mobie
//
//  Created by 张文 on 10/24/24.
//

import KakaFoundation
import NVActivityIndicatorView
import AppGroupKit
import PanModal

class PlayAnimationController: SuperViewController, UITableViewDataSource, UITableViewDelegate {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(titleLabel)
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(25.ckValue())
            make.size.greaterThanOrEqualTo(0)
            make.top.equalToSuperview().offset(25.ckValue())
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20.ckValue())
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
    }
    
    // MARK:  GET && SET
    lazy var dataArray: [PlayAnimationType] = {
        return [.animation0, .animation1, .animation2, .animation3, .animation4]
    }()
    
    // MARK:  懒加载
    lazy var titleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.text = PlayConfigItemType.playAnimation.titleStr()
        view.textColor = .label
        view.font = UIFontBold(20.ckValue())
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .plain)
        view.delegate = self
        view.dataSource = self
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom, right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PlayAnimationViewCell.self, forCellReuseIdentifier: "PlayAnimationViewCell")
        return view
    }()
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayAnimationViewCell", for: indexPath) as! PlayAnimationViewCell
        let animation = dataArray[indexPath.row]
        cell.animationType = animation
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let animation = dataArray[indexPath.row]
        AppLocalManager.shared.playAnimation = animation
        
        (self.navigationController ?? self).dismiss(animated: true)
        NotificationCenter.default.post(name: Notification.Name(kAppThemeColorChangedKey), object: appMainColor)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.ckValue()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
}

extension PlayAnimationController: PanModalPresentable {
    
    var panScrollable: UIScrollView? {
        return self.tableView
    }

    var longForm: PanModalHeight {
        return .contentHeightIgnoringSafeArea(80.ckValue() * CGFloat(dataArray.count + 1) + 60.ckValue())
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
        return 25.ckValue()
    }

    var anchorModalToLongForm: Bool {
        return false
    }
}

class PlayAnimationViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var animationType: PlayAnimationType? {
        didSet {
            guard let animationType = self.animationType else { return }
            
            let frame = CGRectMake(0, 0, 28.ckValue(), 28.ckValue())
            let loadingView = NVActivityIndicatorView(frame: frame, type: animationType.nvType(), color: appMainColor)
            loadingView.tag = animationType.rawValue + 100
            loadingView.startAnimating()
            
            self.contentView.viewWithTag(animationType.rawValue + 100)?.removeFromSuperview()
            
            self.contentView.addSubview(loadingView)
            loadingView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.size.equalTo(frame.size)
                make.leading.equalTo(25.ckValue())
            }
            
            let isSelect = AppLocalManager.shared.playAnimation == animationType
            self.accessoryView = isSelect ? selectImgView() : self.unselectImgView()
            
        }
    }
    
    var loadingView: NVActivityIndicatorView?
    
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
}
