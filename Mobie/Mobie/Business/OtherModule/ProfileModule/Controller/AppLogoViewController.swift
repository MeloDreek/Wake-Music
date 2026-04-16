//
//  AppLogoViewController.swift
//  Mobie
//
//  Created by 张文 on 12/4/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser
import SafariServices

/// 切换app图标
class AppLogoViewController: SuperViewController {
    
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
        self.title = SettingCellItemType.applogo.titleStr()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemAction))
        
        if AppLocalManager.shared.logoName == nil {
            AppLocalManager.shared.logoName = "logo0"
            self.tableView.reloadData()
        }
    }
    
    @objc func cancelItemAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    lazy var logoArray: [String] = {
        var tempArr = [String]()
        for index in 1..<10 {
            let name = "logo\(index)"
            tempArr.append(name)
        }
#if Target_Mobie_Pro
        tempArr.append("logo1")
#endif
        return tempArr
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .plain)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: kaka_IsiPhone() ? 0 : 5.ckValue(), left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.register(AppLogoTableViewCell.self, forCellReuseIdentifier: "AppLogoTableViewCell")
        return view
    }()
    
}

extension AppLogoViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logoArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppLogoTableViewCell", for: indexPath) as! AppLogoTableViewCell

        let selectName = logoArray[indexPath.row]
        var isSelect = selectName == AppLocalManager.shared.logoName
        if AppLocalManager.shared.logoName == nil && indexPath.row == 0 {
            isSelect = true
        }
        cell.onClickCallback = { [weak self] (coverImgView) in
            guard let wSelf = self else { return }
            if kaka_IsMacOS() { return }
            let photoItem = KakaPhotoItem(sourceView: coverImgView, image: coverImgView.image)
            let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
            photoBrowser.backgroundStyle = .blurPhoto
            photoBrowser.show(from: wSelf)
        }
        cell.updateLogo(logoName: selectName, isSelect: isSelect)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if !UserInfoManager.shared.isVIP() {
            self.vipCenterClick()
            return
        }
        
        let selectName = logoArray[indexPath.row]
        
        UIApplication.shared.setAlternateIconName(indexPath.row == 0 ? nil : selectName) { [weak self] error in
            guard let error = error else {
                AppLocalManager.shared.logoName = selectName
                self?.tableView.reloadData()
                return
            }
            
            self?.view.makeToast(error.localizedDescription)
        }
    }

    
    

}

class AppLogoTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(coverImgView)
    }
    
    func preSetupContains() {
        coverImgView.snp.makeConstraints { make in
            make.leading.equalTo(20.ckValue())
            make.top.equalTo(20.ckValue())
            make.size.equalTo(95.ckValue())
            make.centerY.equalToSuperview()
        }
    }
    
    func preSetupHandleBuness() {
        self.selectionStyle = .default

    }
    
    var onClickCallback: ((UIImageView)->Void)?
    
    func updateLogo(logoName: String, isSelect: Bool) {
        if logoName == "logo1" {
#if Target_Mobie_Pro
        let image = UIImage(named: "app_logo_pro")
#else
        let image = UIImage(named: "app_logo")
#endif
            coverImgView.image = image
        }else{
            coverImgView.image = UIImage(named: logoName)
        }
        self.accessoryType = .none
        self.accessoryView = isSelect ? self.selectImgView() : self.unselectImgView()
    }
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 20.ckValue()
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFill
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    @objc func coverImgViewClick() {
        self.onClickCallback?(self.coverImgView)
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
    
}
