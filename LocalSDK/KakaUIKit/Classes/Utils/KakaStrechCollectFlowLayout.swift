//
//  KakaStrechCollectFlowLayout.swift
//  KakaUIKit
//
//  Created by Kaka Inc.on 2021/10/23.
//

import UIKit

//MARK: - 🍌🚗🍌 处理CollectionView拉伸效果 🍌🚗🍌
public class KakaStrechCollectFlowLayout: UICollectionViewFlowLayout {
    
    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
  
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let collectionView = self.collectionView
        let insets = collectionView?.contentInset
        let offset = collectionView?.contentOffset
        let minY = -(insets?.top ?? 0)
            
        let attributes = super.layoutAttributesForElements(in: rect)
        let offsetY = offset?.y ?? 0
        
        if offsetY < minY && collectionView?.indexPathsForVisibleItems.first?.section == 0 {
            let headerSize = self.headerReferenceSize
            let deltaY = CGFloat(fabsf(Float(offsetY)) - Float(minY))
            attributes?.forEach({ (attrs) in
                if attrs.representedElementKind == UICollectionView.elementKindSectionHeader {
                    var headerRect = attrs.frame
                    headerRect.size.height = max(minY, headerSize.height + deltaY)
                    headerRect.origin.y = headerRect.origin.y - deltaY
                    
                    headerRect.size.width = headerSize.width + deltaY
                    headerRect.origin.x = (headerRect.origin.x - deltaY) / 2
                    
                    attrs.frame = headerRect
                }
            })
        }
        
        return attributes
    }
}
