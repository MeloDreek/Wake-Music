//
//  ImpactSliderFeedbackGenerator.swift
//  KakaUIKit
//
//  Created by 张文 on 5/19/25.
//

import UIKit

/// Default implementation of `SliderFeedbackGenerator` that uses `UIImpactFeedbackGenerator`.
public class ImpactSliderFeedbackGenerator: SliderFeedbackGenerator {
    private let feedbackGenerator: UIImpactFeedbackGenerator = .init(style: .light)

    public init() {}

    public func preapre() {
        feedbackGenerator.prepare()
    }

    public func generateMinimumValueFeedback() {
        feedbackGenerator.impactOccurred(intensity: 0.75)
    }

    public func generateMaximumValueFeedback() {
        feedbackGenerator.impactOccurred(intensity: 1)
    }
}

