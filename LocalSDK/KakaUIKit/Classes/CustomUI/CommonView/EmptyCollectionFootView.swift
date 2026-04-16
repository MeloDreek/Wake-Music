//
//  EmptyCollectionFootView.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2023/8/11.
//

import UIKit

public class EmptyCollectionFootView: UICollectionReusableView {
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
        
    }
    
    private func preSetupContains() {
        
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = UIColor.clear
    }
    
    // MARK:  GET && SET 
    
    
    // MARK:  懒加载 
    

}
