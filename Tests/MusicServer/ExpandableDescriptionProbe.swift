import UIKit

@main enum ExpandableDescriptionProbe {
    @MainActor static func main() {
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        for width: CGFloat in [280, 370, 600, 900] {
            let description = MusicServerExpandableTextView()
            let stack = UIStackView(arrangedSubviews: [description])
            stack.axis = .vertical
            stack.frame.size.width = width
            func layout() -> CGFloat {
                for _ in 0..<3 {
                    stack.frame.size.height = stack.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                        withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
                    stack.setNeedsLayout()
                    stack.layoutIfNeeded()
                }
                return stack.frame.height
            }
            let label = descendants(description).compactMap { $0 as? UILabel }.first!
            let button = descendants(description).compactMap { $0 as? UIButton }.first!
            // This CLI probe has no UIApplication event dispatcher. Invoke the actual
            // registered target/action directly after verifying the button wiring.
            let action = button.actions(forTarget: description, forControlEvent: .touchUpInside)!.first!
            description.configure(text: nil)
            precondition(layout() < 1 && description.isHidden, "No reserved biography space when absent")
            description.configure(text: "Short biography.")
            _ = layout()
            precondition(!description.isHidden && button.isHidden, "Short text has no expand control")
            description.configure(text: String(repeating: "The artist creates music from everyday stories. ", count: 45))
            let collapsed = layout()
            precondition(label.numberOfLines == 3 && !button.isHidden, "Long text initially has only three lines")
            let reference = UILabel()
            reference.font = label.font
            reference.text = label.text
            reference.numberOfLines = 3
            let nativeThreeLines = reference.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            precondition(label.frame.height <= nativeThreeLines + 1, "Three native UIKit lines, without stretching the label")
            description.perform(NSSelectorFromString(action))
            let expanded = layout()
            precondition(label.numberOfLines == 0 && expanded > collapsed + 100, "Expand increases measured header height: width=\(width), lines=\(label.numberOfLines), expanded=\(expanded), collapsed=\(collapsed)")
            description.perform(NSSelectorFromString(action))
            precondition(abs(layout() - collapsed) < 1, "Collapse restores original height")
            description.configure(text: nil)
            precondition(layout() < 1, "Reload without metadata removes the whole biography")
        }
        print("Expandable description UIKit probe passed: 4 widths, absent/short/3-line/expanded/re-collapsed/removed states.")
    }
}
