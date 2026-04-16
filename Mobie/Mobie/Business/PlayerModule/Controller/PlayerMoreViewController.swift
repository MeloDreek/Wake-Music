//
//  PlayerMoreViewController.swift
//  Mobie
//
//  Created by 张文 on 6/5/25.
//

import KakaFoundation
import SmartCodable
import AppGroupKit
import PanModal
import KakaPhotoBrowser
import StoreKit
import KakaObjcKit

/// 更多
class PlayerMoreViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
    }
    
    // MARK:  GET && SET
    
    // MARK:  懒加载
    lazy var dataArray: [PlayerMoreCellModel] = {
        return [PlayerMoreCellModel]()
    }()
    
}
