//
//  ThemeColorViewController.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/21.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import StoreKit
import KakaTaglibKit
import SafariServices

/// 切换主题颜色
class ThemeColorViewController: SuperViewController {
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(collectionView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = SettingCellItemType.appTintColor.titleStr()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemAction))
    }
    
    @objc func cancelItemAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    
    

    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { context in

        } completion: { [weak self] context in
            guard let self = self else { return }
            self.collectionView.frame = self.contentView.bounds
        }
    }
    
    lazy var colorArray: [ThemeColorType] = {
        return ThemeColorType.allCases
    }()
    
    /// 间距
    var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 15.ckValue()
            case .iPadOS: return 18.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    var isLandscape: Bool {
        get {
            let isLandscape = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation.isLandscape ?? false
            return isLandscape
        }
    }
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.alwaysBounceVertical = true
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 20.ckValue(), left: itemSpace, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: itemSpace)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(ColorCollectViewCell.self, forCellWithReuseIdentifier: "ColorCollectViewCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = itemSpace
        layout.minimumInteritemSpacing = itemSpace
        return layout
    }()
    
}

extension ThemeColorViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colorArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCollectViewCell", for: indexPath) as! ColorCollectViewCell
        
        let selectColor = colorArray[indexPath.row]
        let isSelect = selectColor == ColorFontManager.shared.accentTyle
        cell.update(color: selectColor.color(), isSelect: isSelect)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let color = colorArray[indexPath.row]
        self.changeThemeColor(colorType: color)
    }
    
    func changeThemeColor(colorType: ThemeColorType) {
        // 动态修改主色调
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        let themeColor = colorType.color()
        ColorFontManager.shared.accentTyle = colorType
        if colorType == .color0 {
            ColorFontManager.shared.defaultType = .color3
        }else{
            ColorFontManager.shared.defaultType = colorType
        }
        UIView.appearance().tintColor = themeColor
        self.collectionView.reloadData()
                
        windowScene.windows.forEach { window in
            window.tintColor = themeColor
            window.tintAdjustmentMode = .automatic
            window.tintColorDidChange()
        }
        
        self.finishAllPage()
        
//        NotificationCenter.default.post(name: Notification.Name(kAppThemeColorChangedKey), object: themeColor)
//        
//        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    // 跳转
    @objc func finishAllPage() {
        self.view.isUserInteractionEnabled = false
        AppLocalManager.shared.isFirstLaunch = false

        let ani: CATransition = CATransition()
        ani.type = CATransitionType(rawValue: "cube")
        ani.subtype = CATransitionSubtype.fromRight
        ani.duration = 0.35
        ani.isRemovedOnCompletion = true
        appKeyWindow?.layer.add(ani, forKey: nil)
        
        self.perform(#selector(dismissAnimation), with: nil, afterDelay: ani.duration - 0.1)
    }
    
    @objc func dismissAnimation() {
        let homeVC = kaka_IsMacOS() ? MacTabbarViewController(style: .doubleColumn) : HomeTabbarViewController()
        let scene = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
        scene?.window?.rootViewController = homeVC
        scene?.window?.makeKeyAndVisible()
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var columnCount: Int = 2
        if isLandscape {
            columnCount += 1
        }
        
        let totalW = self.view.width - collectionView.contentInset.left * 2 - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
        let singleW = totalW / CGFloat(columnCount) - 0.01
        return CGSize(width: singleW, height: singleW)
    }
    
}

class ColorCollectViewCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        contentView.addSubview(selectBtn)
    }
    
    func preSetupContains() {
        selectBtn.snp.makeConstraints { make in
            if kaka_IsMacOS() {
                make.leading.equalToSuperview().offset(15.ckValue())
            }else{
                make.trailing.equalToSuperview().inset(15.ckValue())
            }
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.equalTo(selectBtn.size)
        }
    }
    
    func preSetupHandleBuness() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 10.ckValue()
    }
    
    func update(color: UIColor, isSelect: Bool) {
        self.backgroundColor = color
        self.selectBtn.isSelected = isSelect
    }
     
    lazy var selectBtn: UIButton = {
        let norImage = Reasource.systemNamed("circle", color: UIColor.deAccent)
        let selImage = Reasource.systemNamed("checkmark.circle.fill", color: UIColor.green)
        
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(25.ckValue(), 25.ckValue())
        view.setImage(norImage, for: .normal)
        view.setImage(selImage, for: .selected)
        return view
    }()
    
}
