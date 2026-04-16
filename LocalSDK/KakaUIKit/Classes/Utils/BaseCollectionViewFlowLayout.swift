//
//  BaseCollectionViewFlowLayout.swift
//  KakaUIKit
//
//  Created by Kaka Inc. on 2023/12/6.
//

import KakaFoundation

public class BaseCollectionViewFlowLayout: UICollectionViewFlowLayout {
    public override var flipsHorizontallyInOppositeLayoutDirection: Bool {
        get {
            return PhoneSetManager.isArabicLanguage()
        }
    }
}
