import UIKit

extension String { func localStr() -> String { self } }
let appMainColor = UIColor.systemBlue
enum Reasource {
    static func named(_ name: String) -> UIImage {
        let path = "ASSET_DIRECTORY" + "/" + name + "@3x.png"
        guard let image = UIImage(contentsOfFile: path) else { fatalError("Missing service icon") }
        return image
    }
}

// PRODUCTION_ICON
// PRODUCTION_EMPTY_CELL

@main enum EntryRegression {
    @MainActor static func main() {
        let icon = MusicServerConnectionIcon.image
        precondition(icon.size == CGSize(width: 80, height: 80))
        precondition(icon.cgImage?.width == 240 && icon.cgImage?.height == 240)
        precondition(icon.renderingMode == .alwaysOriginal)
        precondition(icon === MusicServerConnectionIcon.image, "Cache the composed brand image")
        var checks = 4
        for style in [UIUserInterfaceStyle.light, .dark] {
            let cell = NavidromeDownloadEmptyCell(style: .default, reuseIdentifier: "empty")
            cell.overrideUserInterfaceStyle = style
            cell.frame = CGRect(x: 0, y: 0, width: 390, height: 650)
            cell.minimumHeight = 600
            for selected in [false, true] {
                cell.setSelected(selected, animated: false)
                cell.setHighlighted(selected, animated: false)
                cell.updateConfiguration(using: cell.configurationState)
                cell.layoutIfNeeded()
                precondition(cell.backgroundConfiguration?.resolvedBackgroundColor(for: cell.tintColor).cgColor.alpha == 0)
                precondition(cell.backgroundConfiguration?.visualEffect == nil)
                // UIKit clears the legacy backgroundColor when a configuration takes ownership.
                precondition(cell.backgroundColor == nil || cell.backgroundColor?.cgColor.alpha == 0)
                precondition(cell.contentView.backgroundColor?.cgColor.alpha == 0)
                precondition(cell.selectionStyle == .none)
                checks += 5
            }
            cell.prepareForReuse()
            precondition(cell.backgroundConfiguration?.resolvedBackgroundColor(for: cell.tintColor).cgColor.alpha == 0)
            precondition(cell.minimumHeight == 0)
            checks += 2
        }
        print("PASS_ENTRY_UIKIT: \(checks) shared-icon and transparent empty-cell checks")
    }
}
