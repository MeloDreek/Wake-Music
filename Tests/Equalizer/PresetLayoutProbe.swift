import UIKit

// Compiled with the production model and EQPresetGrid, plus catalog values.
@main
enum PresetLayoutProbe {
    @MainActor static func main() {
        var checks = 0
        let presets = PlayerEqualizerPreset.displayedPresets
        precondition(Array(presets.prefix(2)) == [.custom, .bass], "Custom and Bass Boost must lead the first row")
        precondition(presets.filter { $0 == .custom }.count == 1)
        precondition(Set(presets).count == presets.count, "Duplicate presets")
        for locale in EQLayoutLocalizations.labels.keys.sorted() {
            let labels = EQLayoutLocalizations.labels[locale]!
            for width: CGFloat in [240, 320, 600, 840] {
                for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
                    for rtl in [false, true] {
                        let (grid, buttons) = makeGrid(width: width, category: category, rtl: rtl, labels: labels)
                        checks += checkLayout(grid, buttons: buttons, rtl: rtl)
                        precondition(Set(buttons.map { $0.frame.minY }).count == 3, "Exactly three rows")
                        precondition(buttons[0].frame.minY == 0 && buttons[1].frame.minY == 0)
                        let scroll = grid.scrollView
                        let maximum = max(0, scroll.contentSize.width - scroll.bounds.width)
                        precondition(abs(scroll.contentOffset.x - (rtl ? maximum : 0)) < 0.1, "Start at reading-direction leading edge")
                        scroll.contentOffset.x = rtl ? 0 : maximum
                        let lastColumn = buttons[4].frame
                        precondition(lastColumn.minX >= scroll.contentOffset.x - 0.1 && lastColumn.maxX <= scroll.contentOffset.x + width + 0.1, "Last column reachable by scrolling")
                        grid.frame.size.width = width * 0.7
                        grid.frame.size.height = grid.intrinsicContentSize.height
                        grid.setNeedsLayout()
                        grid.layoutIfNeeded()
                        checks += checkLayout(grid, buttons: buttons, rtl: rtl)
                        precondition(Set(buttons.map { $0.frame.minY }).count == 3, "Resize must preserve three rows")
                        checks += 5
                    }
                }
            }
        }
        if CommandLine.arguments.count > 1 { renderPreview(to: CommandLine.arguments[1]) }
        print("PASS_EQ_PRESET_LAYOUT checks=\(checks) locales=\(EQLayoutLocalizations.labels.count) presets=\(presets.count)")
    }

    @MainActor private static func makeGrid(width: CGFloat, category: UIContentSizeCategory,
                                            rtl: Bool, labels: [String: String]) -> (EQPresetGrid, [UIButton]) {
        let grid = EQPresetGrid(frame: CGRect(x: 0, y: 0, width: width, height: 0))
        grid.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        var buttons: [UIButton] = []
        for preset in PlayerEqualizerPreset.displayedPresets {
            guard let name = labels[preset.localizationKey], !name.isEmpty else {
                preconditionFailure("Missing preset translation: \(preset.localizationKey)")
            }
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.filled()
            config.title = name
            config.titleLineBreakMode = .byWordWrapping
            config.baseBackgroundColor = UIColor(red: 0.075, green: 0.082, blue: 0.09, alpha: 1)
            config.baseForegroundColor = UIColor(red: 0.65, green: 0.68, blue: 0.71, alpha: 1)
            config.cornerStyle = .fixed
            config.background.cornerRadius = 9
            config.background.strokeWidth = 1
            config.background.strokeColor = UIColor(white: 0.26, alpha: 1)
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { values in
                var values = values
                values.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
                    for: .systemFont(ofSize: 14, weight: .semibold), compatibleWith: traits)
                return values
            }
            if preset == .bass {
                let amber = UIColor(red: 1, green: 0.72, blue: 0.33, alpha: 1)
                config.baseForegroundColor = amber
                config.baseBackgroundColor = amber.withAlphaComponent(0.15)
                config.background.strokeColor = amber.withAlphaComponent(0.6)
            }
            button.configuration = config
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            grid.addButton(button)
            buttons.append(button)
        }
        grid.frame.size.height = grid.intrinsicContentSize.height
        grid.setNeedsLayout()
        grid.layoutIfNeeded()
        return (grid, buttons)
    }

    @MainActor private static func checkLayout(_ grid: EQPresetGrid, buttons: [UIButton], rtl: Bool) -> Int {
        var checks = 0
        for (index, button) in buttons.enumerated() {
            precondition(button.frame.minX >= -0.1 && button.frame.maxX <= grid.scrollView.contentSize.width + 0.1)
            precondition(button.frame.height >= 44 && button.frame.width >= 44)
            precondition(button.frame.minY >= 0 && button.frame.maxY <= grid.intrinsicContentSize.height + 0.1)
            for other in buttons.dropFirst(index + 1) {
                precondition(!button.frame.intersects(other.frame), "Preset buttons overlap")
                precondition(other.frame.minY >= button.frame.minY, "Preset visual order must match model")
                if other.frame.minY == button.frame.minY {
                    precondition(rtl ? other.frame.maxX <= button.frame.minX : other.frame.minX >= button.frame.maxX,
                                 "Preset horizontal order must follow reading direction")
                }
                checks += 3
            }
            checks += 3
        }
        return checks
    }

    @MainActor private static func renderPreview(to path: String) {
        let (grid, _) = makeGrid(width: 350, category: .large, rtl: false,
                                 labels: EQLayoutLocalizations.labels["zh-Hans"]!)
        let background = UIView(frame: CGRect(x: 0, y: 0, width: 398, height: grid.bounds.height + 112))
        background.overrideUserInterfaceStyle = .dark
        background.backgroundColor = UIColor(red: 0.065, green: 0.071, blue: 0.079, alpha: 1)
        let title = UILabel(frame: CGRect(x: 24, y: 24, width: 350, height: 24))
        title.text = EQLayoutLocalizations.labels["zh-Hans"]!["EQ.Presets"]
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = UIColor(white: 0.9, alpha: 1)
        background.addSubview(title)
        grid.frame.origin = CGPoint(x: 24, y: 64)
        background.addSubview(grid)
        background.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: background.bounds.size)
        let image = renderer.image { context in background.layer.render(in: context.cgContext) }
        try! image.pngData()!.write(to: URL(fileURLWithPath: path))
        print("EQ_PRESET_PREVIEW \(path)")
    }
}
