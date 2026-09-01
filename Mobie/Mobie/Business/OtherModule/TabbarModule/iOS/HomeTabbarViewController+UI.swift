//
//  HomeTabbarViewController+UI.swift
//  Wakemusic
//
//  Created by Kaka Inc. on 2024/1/19.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

extension HomeTabbarViewController {
    
    // 加载子控制器
    @objc func configChildController() {
        
        let musicType = KakaTabbarType.musics
        let baseURL = SandboxFileManager.shared.basePublicFileURL()
        self.createChildController(childVC: MusicsViewController(baseURL), title: musicType.formatStr(), image: musicType.normalImage(), selImage: musicType.selectImage(), tag: musicType.rawValue)
        
        let collectionType = KakaTabbarType.collection
        self.createChildController(childVC: CollectionViewController(), title: collectionType.formatStr(), image: collectionType.normalImage(), selImage: collectionType.selectImage(), tag: collectionType.rawValue)
        
        let connectType = KakaTabbarType.connect
        self.createChildController(childVC: ConnectListViewController(), title: connectType.formatStr(), image: connectType.normalImage(), selImage: connectType.selectImage(), tag: connectType.rawValue)

        let userType = KakaTabbarType.profile
        self.createChildController(childVC: ProfileViewController(), title: userType.formatStr(), image: userType.normalImage(), selImage: userType.selectImage(), tag: userType.rawValue)

        self.tabBar.tintColor = appMainColor
    }
    
    func createChildController(childVC: UIViewController, title: String, image: UIImage?, selImage: UIImage?, tag: Int) {
        childVC.tabBarItem.title = title
        childVC.tabBarItem.tag = tag
        
        // 普通图标
        childVC.tabBarItem.image = image?.withRenderingMode(.alwaysTemplate)
        var textAttres = [NSAttributedString.Key: Any]()
        textAttres[.font] = UIFont.systemFont(ofSize: 9.ckValue())
        textAttres[.foregroundColor] = UIColor.secondaryLabel
        
        // 高亮图标
        childVC.tabBarItem.selectedImage = selImage
        var selectTextAttres = [NSAttributedString.Key: Any]()
        selectTextAttres[.font] = UIFont.systemFont(ofSize: 9.ckValue())
        selectTextAttres[.foregroundColor] = appMainColor
        
        childVC.tabBarItem.setTitleTextAttributes(textAttres, for: .normal)
        childVC.tabBarItem.setTitleTextAttributes(selectTextAttres, for: .selected)
        
        self.addChild(KakaNavigationController(rootViewController: childVC))
    }
   
    @objc func addMoreMusicClick() {
        let addVC = ImportViewController()
        let navVC = KakaNavigationController(rootViewController: addVC)
        navVC.modalPresentationStyle = kaka_IsMacOS() ? .formSheet : .fullScreen
        self.present(navVC, animated: true)
    }
    
}
