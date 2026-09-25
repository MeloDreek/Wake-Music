import UIKit
import SnapKit

// Screenshot fixture only: no app services, saved settings, network, or audio I/O.
// The four production view classes are copied verbatim by the build script,
// except for replacing their umbrella imports with UIKit and SnapKit.
struct MusicItemModel { let mediaPlayURL: URL }

// AccentColor.colorset references labelColor in both appearances.
var appMainColor: UIColor { .label }
func kaka_IsMacOS() -> Bool { false }
func kaka_IsiPad() -> Bool { false }
enum PhoneSetManager { static func isArabicLanguage() -> Bool { false } }

extension Int { func ckValue() -> CGFloat { CGFloat(self) } }
extension Double { func ckValue() -> CGFloat { CGFloat(self) } }
extension CGFloat { func ckValue() -> CGFloat { self } }
extension UIView {
    var size: CGSize {
        get { frame.size }
        set { frame.size = newValue }
    }
}
extension String {
    func localStr() -> String { BatchHeaderCatalog.values[self] ?? self }
    func width(_ font: UIFont) -> CGFloat {
        (self as NSString).size(withAttributes: [.font: font]).width
    }
}
extension TimeInterval {
    func toLocalizedDurationString() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.calendar = Calendar.current
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: self) ?? "\(Int(self))s"
    }
}

// Same font helpers as ConfigInfoKey.swift.
func UIFontBold(_ value: CGFloat) -> UIFont {
    UIFont(name: "Arial Rounded MT Bold Regular", size: value) ?? UIFont.boldSystemFont(ofSize: value)
}
func UIFontLight(_ value: CGFloat) -> UIFont {
    UIFont(name: "Arial Regular", size: value) ?? UIFont.systemFont(ofSize: value)
}
func UIFontNumber(_ value: CGFloat) -> UIFont {
    UIFont(name: "Arial Rounded MT Bold", size: value) ?? UIFont.systemFont(ofSize: value)
}
enum Reasource {
    static func systemNamed(_ name: String, color: UIColor = appMainColor,
                            config: UIImage.SymbolConfiguration? = nil) -> UIImage {
        UIImage(systemName: name, withConfiguration: config)?
            .withRenderingMode(.alwaysOriginal).withTintColor(color) ?? UIImage()
    }
}
