//
//  SliderFeedbackGenerator.swift
//  KakaUIKit
//
//  Created by 张文 on 5/19/25.
//

import UIKit

/// A protocol for haptic feedback generator implementations.
public protocol SliderFeedbackGenerator {
    /// This method is called when user starts interacting with the slider
    /// in anticipation of it reaching minimum or maximum value. If your
    /// implementation uses a subclass of `UIFeedbackGenerator` to generate
    /// haptic feedback, use this method to prepare the generator for possible
    /// activations.
    func preapre()
    /// This method is called when slider reaches its minimum value. Use this
    /// method to generate haptic feedback that gives user a feeling of lower bound.
    func generateMinimumValueFeedback()
    /// This method is called when slider reaches its maximum value. Use this
    /// method to generate haptic feedback that gives user a feeling of upper bound.
    func generateMaximumValueFeedback()
}

