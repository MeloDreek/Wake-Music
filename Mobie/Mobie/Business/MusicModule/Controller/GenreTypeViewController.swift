//
//  GenreTypeViewController.swift
//  Mobie
//
//  Created by 张文 on 12/7/24.
//

import KakaFoundation
import KakaUIKit
import MessageUI
import AppGroupKit
import KakaObjcKit

class GenreTypeViewController: SuperViewController {
    
    init(_ selectGenre: String? = nil) {
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
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        }
        
        self.collectionView.reloadData()
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
    var onSelectCallback: ((String)->Void)?
    
    var selectGenre: String?
    
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
        view.register(CustomGenreCollectionHeadView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "CustomGenreCollectionHeadView")
        view.register(EmptyCollectionFootView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "EmptyCollectionFootView")
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
        var allArray = MusicGenreType.allGenreArray()
        allArray.removeLast()
        return allArray
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
        cell.selectBtn.isSelected = musicGenre.rawValue == self.selectGenre
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let subGenre = dataArray[indexPath.row]
        self.onSelectCallback?(subGenre.rawValue)
        self.cancelButtonClick()
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
            columnCount += kaka_IsMacOS() ? 1 : 1
        }
        
        let totalW = self.view.width - collectionView.contentInset.left * 2 - CGFloat(columnCount - 1) * self.flowLayout.minimumInteritemSpacing
        let singleW = totalW / CGFloat(columnCount) - 0.01
        return CGSize(width: singleW, height: singleW * 0.8 + 50.ckValue())
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.width - itemSpace * 2, height: 200.ckValue())
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "CustomGenreCollectionHeadView", for: indexPath) as! CustomGenreCollectionHeadView
            headView.onClickBlock = { [weak self] () in
                self?.customMusicGenreAction()
            }
            return headView
        }else{
            let footView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "EmptyCollectionFootView", for: indexPath) as! EmptyCollectionFootView
            return footView
        }
    }
    
    func customMusicGenreAction() {
        let editAlertVC = UIAlertController(title: "Custom Genre".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.keyboardType = .default
            textView.clearButtonMode = .always
            textView.text = self.selectGenre
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Embed".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let genreStr = nameField.text, !genreStr.isEmpty else {
                return
            }
            
            self?.onSelectCallback?(genreStr)
            self?.cancelButtonClick()
        })
                
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
}

public class CustomGenreCollectionHeadView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(backView)
        self.addSubview(customIconView)
        self.addSubview(customLabel)
    }
    
    private func preSetupContains() {
        backView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10.ckValue())
            make.bottom.equalToSuperview().offset(-23.ckValue())
        }
        
        customIconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backView).offset(-15.ckValue())
            make.width.equalTo(50.ckValue())
            make.size.equalTo(40.ckValue())
        }
        
        customLabel.snp.makeConstraints { make in
            make.centerX.equalTo(backView)
            make.top.equalTo(customIconView.snp.bottom).offset(5.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(clickTap(_:)))
        self.addGestureRecognizer(clickTap)
    }
    
    @objc func clickTap(_ sender: UITapGestureRecognizer) {
        self.onClickBlock?()
    }
    
    // MARK:  GET && SET
    var onClickBlock: (()->Void)?
    
    // MARK:  懒加载
    lazy var backView: UIView = {
        let view = UIView()
        view.backgroundColor = appMainColor
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 15.ckValue()
        return view
    }()
    
    lazy var customIconView: UIImageView = {
        let image = Reasource.systemNamed("rectangle.and.pencil.and.ellipsis", color: .systemBackground)
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var customLabel: UILabel = {
        let view = UILabel()
        view.text = "Custom Genre".localStr()
        view.numberOfLines = 0
        view.font = UIFontBold(15.ckValue())
        view.textAlignment = .center
        view.textColor = .systemBackground
        return view
    }()

}
