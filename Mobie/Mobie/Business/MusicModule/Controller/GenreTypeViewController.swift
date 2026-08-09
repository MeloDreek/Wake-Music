//
//  GenreTypeViewController.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import KakaUIKit
import MessageUI
import SafariServices
import AppGroupKit

/// 选择音乐流派
class GenreTypeViewController: SuperViewController {
    
    init(_ selectGenre: MusicGenreType? = nil) {
        self.selectGenre = selectGenre
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.view.addSubview(collectionView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = "Music Genres".localStr()
        if self.isPresent() {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelBarItemClick))
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "envelope"), style: .plain, target: self, action: #selector(handleWithEmail))
        
    }
    
    @objc func cancelBarItemClick() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                        
        let scrollEdgeAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        scrollEdgeAppearance.configureWithDefaultBackground() // 底层透明，但内容穿透
        self.navigationController?.navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        
        let compactAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        compactAppearance.configureWithDefaultBackground() // 不透明，纯色
        self.navigationController?.navigationBar.compactAppearance = compactAppearance
        
        let standardAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        standardAppearance.configureWithDefaultBackground()  // 默认透明色
        self.navigationController?.navigationBar.standardAppearance = standardAppearance
        
    }
    
    // MARK:  GET && SET
    var onSelectCallback: ((MusicGenreType)->Void)?
    
    var selectGenre: MusicGenreType?
    
    var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 15.ckValue()
            case .iPadOS: return 18.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    // MARK:  懒加载
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = self.view.backgroundColor
        view.dataSource = self
        view.delegate = self
        view.selectionFollowsFocus = false
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 20.ckValue(), left: itemSpace, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: itemSpace)
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(GenreCollectionCell.self, forCellWithReuseIdentifier: "GenreCollectionCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = itemSpace
        layout.minimumInteritemSpacing = itemSpace
        return layout
    }()
    
    lazy var dataArray: [MusicGenreType] = {
        return MusicGenreType.allGenreArray()
    }()
    
    var isLandscape: Bool {
        get {
            let isLandscape = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation.isLandscape ?? false
            return isLandscape
        }
    }
    
}

extension GenreTypeViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GenreCollectionCell", for: indexPath) as! GenreCollectionCell
        let musicGenre = self.dataArray[indexPath.row]
        cell.update(genre: musicGenre)
        cell.coverView.isHidden = false
        cell.selectBtn.isSelected = musicGenre == self.selectGenre
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let subGenre = dataArray[indexPath.row]
        self.onSelectCallback?(subGenre)
        self.cancelBarItemClick()
    }
     
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.flowLayout.minimumLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var columnCount: Int = 2
        if isLandscape || kaka_IsMacOS() {
            columnCount += kaka_IsMacOS() ? 2 : 1
        }
        
        let totalW = self.view.width - collectionView.contentInset.left * 2 - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
        let singleW = totalW / CGFloat(columnCount) - 0.01
        return CGSize(width: singleW, height: singleW * 0.8 + 50.ckValue())
    }
    
}


// MARK:  邮箱联系
extension GenreTypeViewController: MFMailComposeViewControllerDelegate, SFSafariViewControllerDelegate {
    @objc func handleWithEmail() {
        self.view.endEditing(true)
        
        let subject = "\(kaka_osType().iconStr()) \("Wake Music".localStr()) Feedback"
        let messageBody = "\r\r\r\r\r-----------------------------" + "\r" + self.getDeviceInformation()
        
        let canOpenMailScheme = UIApplication.shared.canOpenURL(URL(string: "mailto:")!)
        let mailtoURL = URL(string: "mailto:\(companyEmail)?subject=\(subject)&body=\(messageBody)")!
        
        if !MFMailComposeViewController.canSendMail() {
            
            if canOpenMailScheme {
                // 2️⃣ 打开第三方邮件客户端
                UIApplication.shared.open(mailtoURL)
            }else{
                // 3️⃣ 用户没有任何邮件客户端
                if kaka_IsMacOS() {
                    UIApplication.shared.open(FeedbackURL)
                }else{
                    let feedbackVC = SFSafariViewController(url: FeedbackURL)
                    self.present(feedbackVC, animated: true)
                }
            }
            return
        }
        
        // 1️⃣ 优先使用Apple的邮件客户端
        if canOpenMailScheme && kaka_IsMacOS() {
            UIApplication.shared.open(mailtoURL)
        }else{
            let emailVC = MFMailComposeViewController()
            emailVC.mailComposeDelegate = self
            emailVC.setToRecipients([companyEmail])
            emailVC.setSubject(subject)
            emailVC.setMessageBody(messageBody, isHTML: false)
            self.present(emailVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        if result == .sent {
            self.view.makeToast("Thank you for your feedback".localStr())
        }
        
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
    }
    
    func getDeviceInformation() -> String {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = kaka_IsMacOS() ? "macOS" : device.model
        let appVersion = ((Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "") + "_" + "\(UserInfoManager.shared.isVIP() ? "1" : "0")"

        return """
        App Name: \("Wake Music".localStr())
        App Version: \(appVersion)
        Device Model: \(model)
        System Version: \(systemVersion)
        Language: \(PhoneSetManager.languge_region())
        """
    }
}
