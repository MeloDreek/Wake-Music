//
//  NSLayoutConstraint+Multiplier.swift
//  KakaUIKit
//
//  Created by 张文 on 5/19/25.
//

import UIKit

extension NSLayoutConstraint {
    func constraintWithMultiplier(_ newMultiplier: CGFloat) -> NSLayoutConstraint {
        let normalizedMultiplier = max(0.0001, min(1, newMultiplier))

        let shouldActivate = isActive
        if shouldActivate {
            NSLayoutConstraint.deactivate([self])
        }

        let updatedConstraint = NSLayoutConstraint(
            item: firstItem as Any,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: normalizedMultiplier,
            constant: constant
        )
        updatedConstraint.priority = priority
        updatedConstraint.shouldBeArchived = shouldBeArchived
        updatedConstraint.identifier = identifier

        if shouldActivate {
            NSLayoutConstraint.activate([updatedConstraint])
        }

        return updatedConstraint
    }
}

