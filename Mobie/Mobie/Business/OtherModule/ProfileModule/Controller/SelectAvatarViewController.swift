//
//  SelectAvatarViewController.swift
//  Wake Music
//
//  Created by Kaka Inc. on 2024/1/24.
//

import KakaFoundation
import ZLImageEditor
import ProgressHUD
import KakaUIKit
import AppGroupKit
import Toast
import PhotosUI

class SelectAvatarViewController: SuperViewController, PHPickerViewControllerDelegate {
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        self.view.backgroundColor = UIColor.systemBackground
        contentView.addSubview(collectionView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        for index in 1...14 {
            avatarArray.append("avatar_\(index)")
        }
        
        avatarArray.append("take_camera")
        self.collectionView.reloadData()
    }
    
    // 上传远程头像
    func selectCustomAvatar(_ user: UserInfoManager) {
        
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        self.present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        results.first?.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] object, error in
            guard let image = object as? UIImage else { return }

            DispatchQueue.main.async {
                
                ZLImageEditorConfiguration.default()
                    .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                    .adjustTools([.brightness, .contrast, .saturation])
                    .clipRatios([.wh1x1, .wh4x3])
                    .showClipDirectlyIfOnlyHasClipTool(true)
                
                ZLEditImageViewController.showEditImageVC(parentVC: self, image: image) { [weak self] newImage, model in
                    guard let wSelf = self else { return }
                    let userModel = UserInfoManager.shared
                    guard SandboxFileManager.shared.saveAvatarImageSanbox(userModel: userModel, image: image) != nil else { return }

                    wSelf.onModifyCallBack?()
                    wSelf.dismiss(animated: false)
                }
                
            }
            
        })
    }
    
    // MARK:  GET && SET 
    
    let itemSpace = 0.0
    
    var onModifyCallBack: (()->Void)?
    
    var itemWidth: CGFloat {
        get {
            let columnCount: CGFloat = 4.0
            
            let totalW = self.preferredContentSize.width - (columnCount + 1) * itemSpace
            let singleW = totalW / CGFloat(columnCount) - 0.1
            
            return singleW
        }
    }
    
    // MARK:  懒加载 
    
    lazy var avatarArray: [String] = {
        return [String]()
    }()
    
    lazy var collectionView: UICollectionView = {
        
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = itemSpace
        layout.minimumInteritemSpacing = itemSpace
        layout.itemSize = CGSize(width: self.itemWidth, height: self.itemWidth)
        
        let view = UICollectionView(frame: CGRect(x: 0, y: 0, width: self.preferredContentSize.width, height: self.preferredContentSize.height), collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 0, right: 0)
        view.showsHorizontalScrollIndicator = false
        view.register(SelectAvatarViewCell.self, forCellWithReuseIdentifier: "SelectAvatarViewCell")
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? UISemanticContentAttribute.forceRightToLeft : UISemanticContentAttribute.forceLeftToRight
        view.alwaysBounceVertical = true
        return view
    }()
    
}

extension SelectAvatarViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return avatarArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectAvatarViewCell", for: indexPath) as! SelectAvatarViewCell
        let iconName = avatarArray[indexPath.row]
        let isLastCell = avatarArray.count - 1 == indexPath.row
        cell.avatarView.image = Reasource.named(iconName)
        cell.avatarView.backgroundColor = .clear
        cell.avatarView.layer.masksToBounds = isLastCell
        cell.avatarView.layer.cornerRadius = isLastCell ? self.itemWidth * 0.3 : 0
        cell.avatarView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(isLastCell ? 5 : 0)
            make.size.equalToSuperview().multipliedBy(isLastCell ? 0.7 : 0.8)
        }
        return cell
    }
    
    // 修改为本地图片
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let model = UserInfoManager.shared
        
        if indexPath.row == avatarArray.count - 1 {
            // 远程头像
            self.selectCustomAvatar(model)
        }else{
            // 先删除远程头像
            let iconName = self.avatarArray[indexPath.row]
            self.dismiss(animated: false)
            
            SandboxFileManager.shared.deleteRemoteAvatar(model)
            model.localAvatarName = iconName
            self.onModifyCallBack?()
        }
    }

}
