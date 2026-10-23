//
//  LargeImageViewController.swift
//  Mobie
//
//  Created by 张文 on 5/7/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

public enum ApplicationType: Int {
    case MusicTag = 0
    case WakeMusic = 1
    case ScanWeixin = 2
    case ScanLine = 3
    case ScanTelegram = 4
    case ScanVK = 5
    case ScanRednote = 6
    
    func applicationTitle() -> String {
        switch self {
        case .MusicTag:
            return Application.wakeTag.appTitle()
        case .WakeMusic:
            return Application.wakeMusic.appTitle()
        default: return ""
        }
    }
    
    func titleStr() -> String {
        switch self {
        case .MusicTag:
            return "Download for iOS".localStr()
        case .WakeMusic:
            return "Download for iOS".localStr()
        default: return "Scan QR Code".localStr()
        }
    }
    
    func qrcodeImage() -> UIImage? {
        switch self {
        case .MusicTag:
            return UIImage(named: "musictag_qrcode")
        case .WakeMusic:
            return UIImage(named: "wakemusic_qrcode")
        case .ScanWeixin:
            return Reasource.named("qrcode_wechat")
        case .ScanLine:
            return Reasource.named("qrcode_line")
        case .ScanTelegram:
            let isChinese = PhoneSetManager.formatLanguage() == .chinese_simplified || PhoneSetManager.localPhoneCountry() == .chinese
            return Reasource.named(isChinese ? "tg_group_qrcode" : "tg_me_qrcode")
        case .ScanVK:
            return Reasource.named("vk_qrcode")
        case .ScanRednote:
            return Reasource.named("rednote_qrcode")
        }
    }
    
}

class LargeImageViewController: UIViewController {
    
    init(_ application: ApplicationType) {
        self.appType = application
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.systemBackground
        self.title = self.appType.titleStr()
        
        if self.isPresent() && self.splitViewController == nil {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarItemClick))
        }
                
        self.view.addSubview(qrcodeView)
        qrcodeView.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(-30.ckValue())
            make.size.equalTo(300)
        }
        
        self.view.addSubview(tipsLabel)
        tipsLabel.snp.makeConstraints { make in
            make.centerX.equalTo(qrcodeView)
            make.top.equalTo(qrcodeView.snp.bottom).offset(10)
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    var appType: ApplicationType = .MusicTag
    
    @objc func cancelBarItemClick() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    lazy var qrcodeView: UIImageView = {
        let view = UIImageView(image: self.appType.qrcodeImage())
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    lazy var tipsLabel: UILabel = {
        let view = UILabel()
        view.text = appType.applicationTitle()
        view.textColor = .label
        view.font = UIFontBold(15)
        view.textAlignment = .center
        return view
    }()
}
