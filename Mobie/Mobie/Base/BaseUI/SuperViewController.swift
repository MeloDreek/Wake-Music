//
//  SuperViewController.swift
//   PassLock
//
//  Created by Melo Dreek on 2023/2/2.
//

import KakaUIKit
import KakaFoundation
import AppGroupKit
import PanModal

/// Legacy top clearance. A status bar can be vertical on adaptive displays, so
/// statusBarFrame.height must not be treated as a top inset.
var kStatusBarHeight: CGFloat {
    get {
        if kaka_IsMacOS() {
            return 0
        }else{
            return kaka_safeAreaInsets().top
        }
    }
}


/// 导航栏高度
var app_navHeight: CGFloat {
    get {
        switch kaka_osType() {
        case .iOS: return 44 + kStatusBarHeight
        case .iPadOS: return 44.ckValue() + kStatusBarHeight
        case .macOS: return 50
        }
    }
}

/// Tabbar高度
var app_tabbarHeight: CGFloat {
    get {
        let isX = kaka_safeAreaInsets().bottom > 5
        switch kaka_osType() {
        case .iOS: return kaka_safeAreaInsets().bottom + (isX ? 49 : 44)
        case .iPadOS: return kaka_safeAreaInsets().bottom + (isX ? 44 : 44)
        case .macOS: return 50
        }
    }
}

/// 父控件
public class SuperViewController: UIViewController {
    
    deinit {
        debugPrint("### \(self.description) ###")
        NotificationCenter.default.removeObserver(self, name: Notification.Name(kAppearanceChangedKey), object: nil)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground

        self.preSetupSubViews()
        self.viewDidLayoutSubviews()
        self.preSetupHandleBuness()
    }
      
    // MARK:  三个方法，方便子类 
    public func preSetupSubViews() {
        view.addSubview(contentView)
        
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        let insets = view.safeAreaInsets
        contentView.frame = CGRect(
            x: insets.left,
            y: 0,
            width: max(0, view.bounds.width - insets.left - insets.right),
            height: view.bounds.height
        )
        
    }
    
    public func preSetupHandleBuness() {
        NotificationCenter.default.addObserver(self, selector: #selector(appearanceChanged), name: Notification.Name(kAppearanceChangedKey), object: nil)
        self.appearanceChanged()
    }
    
    
    @objc func appearanceChanged() {
        let overrideUserInterfaceStyle = AppLocalManager.shared.appearanceStyle.userInterfaceStyle()
        self.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        
        if let navVC = self.navigationController {
            navVC.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        }
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return AppLocalManager.shared.appearanceStyle.statusBarStyle()
    }
    
    // 暗黑模式切换
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    // 兼容iPad的PanModel
    public override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presentableController = viewControllerToPresent as? PanModalPresentable, let controller = presentableController as? UIViewController {
            controller.modalPresentationStyle = .custom
            controller.modalPresentationCapturesStatusBarAppearance = true
            controller.transitioningDelegate = PanModalPresentationDelegate.default
            super.present(controller, animated: flag, completion: completion)
            return
        }
        
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    // MARK:  GET && SET
    @objc func vipCenterClick() {
        AppStoreKitManager.presentPurcharseVC(self)
    }

    /// Saved accounts remain intact; an active entitlement is required to connect.
    @discardableResult
    func requireRemoteConnectionAccess() -> Bool {
        guard UserInfoManager.shared.isVIP() else {
            Self.showRemoteConnectionPaywall(on: self)
            return false
        }
        return true
    }

    static func showRemoteConnectionPaywall(on controller: UIViewController) {
        controller.showTwoAlert(message: "Purchase.RemoteAccessMessage".localStr(), confirm: "Unlock Premium".localStr()) { [weak controller] in
            guard let controller else { return }
            AppStoreKitManager.presentPurcharseVC(controller)
        }
    }

    func connectionFeedbackFooter(feedbackAction: Selector) -> UIView {
        let footer = UITableViewHeaderFooterView()
        let button = UIButton(type: .system)
        if kaka_IsMacOS() {
            // Keep this a text link rather than Catalyst's native push button.
            button.preferredBehavioralStyle = .pad
            button.backgroundColor = .clear
            footer.backgroundConfiguration = .clear()
        }
        button.setAttributedTitle(NSAttributedString(string: "Don't see your connection method? Tell us!".localStr(), attributes: [.font: UIFontLight(13.ckValue()), .foregroundColor: UIColor.systemBlue, .underlineStyle: 1]), for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: feedbackAction, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        footer.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: footer.contentView.layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: footer.contentView.layoutMarginsGuide.trailingAnchor),
            button.topAnchor.constraint(equalTo: footer.contentView.topAnchor, constant: 15),
            button.bottomAnchor.constraint(equalTo: footer.contentView.bottomAnchor, constant: -24)
        ])
        return footer
    }
    
    
    // MARK:  懒加载 
    
    /// 内容区域
    public lazy var contentView: UIView = {
        let view = UIView(frame: self.view.bounds)
        view.backgroundColor = .clear
        return view
    }()
      
    // MARK:  GET && SET 

    @objc func cancelButtonClick() {
        if self.isPresent() {
            (self.navigationController ?? self).dismiss(animated: true)
        }else{
            self.navigationController?.popViewController(animated: true)
        }
    }
}

extension SuperViewController {
    /// 屏幕旋转有关
    open override var prefersStatusBarHidden: Bool {
      return false
    }
    
    /// 是否需要自动旋转
    open override var shouldAutorotate: Bool {
      return false
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return kaka_IsiPhone() ? .portrait : .allButUpsideDown
    }
      
    /// 其他
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }
  
}
