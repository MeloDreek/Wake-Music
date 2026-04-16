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
    
    func applicationID() -> String {
        switch self {
        case .MusicTag:
            return Application.musicTag.appstoreID()
        case .WakeMusic:
            return Application.wakeMusic.appstoreID()
        default: return ""
        }
    }
    
    func titleStr() -> String {
        switch self {
        case .MusicTag:
            return "Download for iOS".localStr()
        case .WakeMusic:
            return "Download for iOS".localStr()
        default: return "Scanning QR code".localStr()
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

class LargeImageViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
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
        
//        self.view.addSubview(collectionView)
//        collectionView.snp.makeConstraints { make in
//            make.centerX.equalToSuperview()
//            make.top.equalTo(tipsLabel.snp.bottom).offset(30.ckValue())
//            make.width.equalToSuperview()
//            make.height.equalTo(self.flowLayout.itemSize.height + self.itemSpace)
//        }
                
        if self.appType == .MusicTag || self.appType == .WakeMusic {
            self.refreshDataAction()
        }
    }
    
    @objc func refreshDataAction() {
        APIManager.shared.requestApplication(appID: self.appType.applicationID()) { appModel in
            self.appModel = appModel
            self.tipsLabel.text = appModel.trackName
            self.collectionView.reloadData()
        } fail: { errorMsg in
            
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
        view.textColor = .label
        view.font = UIFontBold(15)
        view.textAlignment = .center
        return view
    }()
    
    lazy var appModel: AppStoreInfoModel = {
        return AppStoreInfoModel()
    }()
    
    let itemSpace = 20.ckValue()
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.view.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.contentInsetAdjustmentBehavior = .never
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(SingleImageCollectionCell.self, forCellWithReuseIdentifier: "SingleImageCollectionCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = itemSpace / 2
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSizeMake(100, 150)
        return layout
    }()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.appModel.screenshotUrls.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SingleImageCollectionCell", for: indexPath) as! SingleImageCollectionCell
        cell.coverImgUrl = self.appModel.screenshotUrls[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
}

class SingleImageCollectionCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(coverImgView)
    }
    
    private func setupAutoLayout() {
        coverImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupCusBuness() {
        
    }
    
    var coverImgUrl: String? {
        didSet {
            coverImgView.kf.setImage(with: URL(string: coverImgUrl ?? ""))
        }
    }
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.backgroundColor = UIColor.secondarySystemFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 5.ckValue()
        return view
    }()
    
}


