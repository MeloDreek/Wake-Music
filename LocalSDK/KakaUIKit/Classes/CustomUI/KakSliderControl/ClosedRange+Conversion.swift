//
//  ClosedRange+Conversion.swift
//  KakaUIKit
//
//  Created by 张文 on 5/19/25.
//

import Foundation

extension ClosedRange where Bound: BinaryFloatingPoint {
    func convert(value: Bound, to newRange: ClosedRange<Bound>) -> Bound {
        (((value - lowerBound) * (newRange.upperBound - newRange.lowerBound)) / (upperBound - lowerBound)) + newRange.lowerBound
    }
}

