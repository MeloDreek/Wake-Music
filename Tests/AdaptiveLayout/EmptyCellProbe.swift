import UIKit

protocol InsetInitializationProbe { var initializationCount: Int { get } }

// Non-layout dependencies only. Production EmptyTableViewCell,
// EmptyCollectViewCell, SnapKit constraints and UIKit fitting are compiled intact.
extension Int { func ckValue() -> CGFloat { CGFloat(self) } }
extension Double { func ckValue() -> CGFloat { CGFloat(self) } }
extension CGFloat { func ckValue() -> CGFloat { self } }
extension String { func localStr() -> String { self } }
extension UIView { var size: CGSize { bounds.size } }
extension UIDevice { func isSmalliPhone() -> Bool { false } }
extension UIColor { static var deAccent: UIColor { .white } }
func UIFontBold(_ size: CGFloat) -> UIFont { .boldSystemFont(ofSize: size) }
func UIFontLight(_ size: CGFloat) -> UIFont { .systemFont(ofSize: size, weight: .light) }
enum ProbeOS { case iOS, iPadOS, macOS }
func kaka_osType() -> ProbeOS { .iOS }
func kaka_IsiPhone() -> Bool { true }
func kaka_IsiPad() -> Bool { false }
let appMainColor = UIColor.systemBlue
let kAppThemeColorChangedKey = "probe.theme"
let kAppearanceChangedKey = "probe.appearance"
enum ProbeStyle { case light, dark, color0 }
class AppLocalManager { static let shared = AppLocalManager(); let appearanceStyle = ProbeStyle.light }
class ColorFontManager { static let shared = ColorFontManager(); let accentTyle = ProbeStyle.color0 }
enum KakaError { case tokenExpiredAuthAgain; var errorDescription: String { "Expired" } }
class NVActivityIndicatorView: UIView {
    enum Kind { case lineScalePulseOutRapid }
    init(frame: CGRect, type: Kind, color: UIColor) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    func startAnimating() {}
    func stopAnimating() {}
}

@main enum EmptyCellProbe {
    @MainActor static func main() {
        var checks = 0
        for controller in [MusicsInsetProbe(), DownloadInsetProbe(), ArtistInsetProbe(), AlbumInsetProbe(), GenreInsetProbe()] as [UIViewController] {
            controller.loadViewIfNeeded()
            precondition((controller as! InsetInitializationProbe).initializationCount == 1,
                         "Inset callback must not recursively initialize its lazy scroll view")
            checks += 1
        }
        for size in [CGSize(width: 240, height: 180), CGSize(width: 390, height: 844),
                     CGSize(width: 830, height: 600), CGSize(width: 600, height: 240)] {
            let table = UITableView(frame: CGRect(origin: .zero, size: size), style: .insetGrouped)
            table.contentInsetAdjustmentBehavior = .never
            table.contentInset = UIEdgeInsets(top: 96, left: 0, bottom: 100, right: 0)
            let height = EmptyTableViewCell.preferredHeight(in: table)
            let cell = EmptyTableViewCell(style: .default, reuseIdentifier: nil)
            let rowWidth = size.width - table.layoutMargins.left - table.layoutMargins.right
            cell.frame = CGRect(x: 0, y: 0, width: rowWidth, height: height)
            cell.layoutIfNeeded()
            precondition(height > 100 && height.isFinite, "Empty row needs content height")
            precondition(cell.middleView.frame.minY >= 19, "Artwork must be reachable")
            precondition(cell.middleView.frame.maxY <= cell.contentView.bounds.height - 19)
            precondition(cell.emptyImgView.frame.width <= cell.middleView.bounds.width + 0.1)
            precondition(cell.formatButton.bounds.height >= 49)
            print("EMPTY_TABLE width=\(rowWidth) viewport=\(size.height) height=\(height) content=\(cell.middleView.frame)")
            let collection = UICollectionView(frame: CGRect(origin: .zero, size: size), collectionViewLayout: UICollectionViewFlowLayout())
            collection.contentInsetAdjustmentBehavior = .never
            collection.contentInset = UIEdgeInsets(top: 96, left: 15, bottom: 100, right: 15)
            let itemSize = EmptyCollectViewCell.preferredSize(in: collection)
            let item = EmptyCollectViewCell(frame: CGRect(origin: .zero, size: itemSize))
            item.layoutIfNeeded()
            precondition(itemSize.width > 0 && itemSize.height > 100)
            precondition(item.middleView.frame.minY >= 19)
            precondition(item.middleView.frame.maxY <= item.contentView.bounds.height - 19)
            precondition(item.emptyImgView.frame.width <= item.middleView.bounds.width + 0.1)
            precondition(item.formatButton.bounds.height >= 49)
            print("EMPTY_COLLECTION size=\(itemSize) content=\(item.middleView.frame)")
            checks += 10
        }
        print("PASS_EMPTY_CELL_UIKIT \(checks) checks")
    }
}
