import UIKit

// Appended to the production EQPresetGrid class by run-layout-probe.sh.
@main
enum PresetLayoutProbe {
    @MainActor static func main() {
        var checks = 0
        for width: CGFloat in [240, 320, 600, 840] {
            for fontSize: CGFloat in [14, 30] {
                for rtl in [false, true] {
                    let grid = EQPresetGrid(frame: CGRect(x: 0, y: 0, width: width, height: 0))
                    grid.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
                    let names = ["Flat", "Bass Boost", "Vocal", "Rock", "Jazz", "Acoustic",
                                 "Classical", "Hip-Hop", "R&B", "Electronic", "Blues", "Country",
                                 "Metal", "Reggae", "Soul", "Punk", "Folk", "Latin", "Ambient",
                                 "Soundtrack", "Disco", "A very long localized preset name"]
                    var buttons: [UIButton] = []
                    for name in names {
                        let button = UIButton(type: .system)
                        var config = UIButton.Configuration.filled()
                        config.title = name
                        config.titleLineBreakMode = .byWordWrapping
                        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
                        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { values in
                            var values = values
                            values.font = UIFont.systemFont(ofSize: fontSize)
                            return values
                        }
                        button.configuration = config
                        button.titleLabel?.numberOfLines = 0
                        grid.addButton(button)
                        buttons.append(button)
                    }
                    grid.frame.size.height = grid.intrinsicContentSize.height
                    grid.setNeedsLayout()
                    grid.layoutIfNeeded()
                    for (index, button) in buttons.enumerated() {
                        precondition(button.frame.minX >= -0.1 && button.frame.maxX <= width + 0.1)
                        precondition(button.frame.height >= 44 && button.frame.width >= 44)
                        precondition(button.frame.maxY <= grid.intrinsicContentSize.height + 0.1)
                        for other in buttons.dropFirst(index + 1) {
                            precondition(!button.frame.intersects(other.frame), "Preset buttons overlap")
                        }
                        checks += 3
                    }
                    precondition(buttons.last!.frame.minY > 0, "Presets must wrap into rows")
                    let oldHeight = grid.intrinsicContentSize.height
                    grid.frame.size.width = width * 0.7
                    grid.setNeedsLayout()
                    grid.layoutIfNeeded()
                    precondition(grid.intrinsicContentSize.height >= oldHeight, "Narrower window must expand grid height")
                    checks += 2
                }
            }
        }
        print("PASS_EQ_PRESET_LAYOUT checks=\(checks)")
    }
}
