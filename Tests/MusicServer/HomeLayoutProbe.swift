import UIKit

// All UIKit grid/container components and UIFontNumber are production source.
// Server models, playback state, localization, action names and image IO are test stubs.
extension String { func localStr() -> String { self } }
struct HomeProbeRecord: Equatable { let id: String; let title: String; let subtitle: String; let artworkID: String }
enum MusicServerItem {
    case song(HomeProbeRecord), artist(HomeProbeRecord), album(HomeProbeRecord), playlist(HomeProbeRecord), radio(HomeProbeRecord)
    private var value: HomeProbeRecord {
        switch self { case .song(let x), .artist(let x), .album(let x), .playlist(let x), .radio(let x): return x }
    }
    var id: String { value.id }; var title: String { value.title }
    var subtitle: String { value.subtitle }; var artworkID: String { value.artworkID }
}
struct MusicServerOverview { var songs: Int?; var artists: Int?; var albums: Int?; var radios: Int? }
@MainActor final class MusicServerSession {
    var accountID = "layout-test"
    func artworkURL(id: String, size: Int) -> URL? { nil }
    func musicItem(for song: HomeProbeRecord) -> MusicItemModel { MusicItemModel(song: song) }
}
struct MusicItemModel: Equatable {
    let song: HomeProbeRecord
    func isFlagFavorite() -> Bool { false }
}
enum MusicActionType {
    case addFavirote, removeFavirote, addPlaylist, artistDetial, albumDetial, download
    func titleStr() -> String { String(describing: self) }
    func iconImage() -> UIImage? { UIImage(systemName: "music.note") }
}
@MainActor final class KakaMusicPlayer {
    static let shared = KakaMusicPlayer()
    var playingMusic: MusicItemModel?
    var isPlaying = false
}
enum KF { struct ImageResource { init(downloadURL: URL, cacheKey: String) {} } }
struct DownsamplingImageProcessor { init(size: CGSize) {} }
enum HomeProbeTransition { case fade(Double) }
enum HomeProbeImageOption { case processor(DownsamplingImageProcessor), scaleFactor(CGFloat), transition(HomeProbeTransition) }
struct HomeProbeImageLoader {
    func cancelDownloadTask() {}
    func setImage(with resource: KF.ImageResource, options: [HomeProbeImageOption]) {}
}
extension UIImageView { var kf: HomeProbeImageLoader { HomeProbeImageLoader() } }

// Supply deterministic traits to the production cell without bootstrapping UIApplication.
private final class HomeProbeListCell: NavidromeRecentViewCell {
    var probeTraits: UITraitCollection?
    override var traitCollection: UITraitCollection {
        guard let probeTraits else { return super.traitCollection }
        return UITraitCollection(traitsFrom: [super.traitCollection, probeTraits])
    }
}

@main enum HomeLayoutProbe {
    @MainActor static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let variants: [(String, CGFloat, UIUserInterfaceLayoutDirection, UIContentSizeCategory, UIUserInterfaceStyle)] = [
            ("phone-compact", 320, .leftToRight, .large, .light),
            ("phone-ltr", 393, .leftToRight, .large, .light),
            ("phone-rtl", 393, .rightToLeft, .large, .light),
            ("phone-large-type", 393, .leftToRight, .accessibilityExtraExtraExtraLarge, .light),
            ("ipad-split", 600, .leftToRight, .large, .light),
            ("ipad", 820, .leftToRight, .large, .light),
            ("ipad-rtl-dark", 820, .rightToLeft, .large, .dark)
        ]
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        for (name, width, direction, category, style) in variants {
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(preferredContentSizeCategory: category),
                UITraitCollection(layoutDirection: direction == .rightToLeft ? .rightToLeft : .leftToRight), UITraitCollection(userInterfaceStyle: style)])
            let root = UIViewController(), child = UIViewController()
            root.addChild(child); root.view.addSubview(child.view); child.didMove(toParent: root)
            root.setOverrideTraitCollection(traits, forChild: child)
            root.view.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
            child.view.frame = root.view.bounds
            child.view.backgroundColor = .systemGroupedBackground
            let semantic: UISemanticContentAttribute = direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
            child.view.semanticContentAttribute = semantic
            let session = MusicServerSession()
            let items = (0..<8).map { MusicServerItem.song(HomeProbeRecord(id: "\($0)", title: "Song \($0 + 1) — A Little Longer", subtitle: "The Artist", artworkID: "")) }
            let carousel = HomeProbeListCell(style: .default, reuseIdentifier: nil)
            carousel.probeTraits = traits
            child.view.addSubview(carousel)
            descendants(carousel).forEach { $0.semanticContentAttribute = semantic }
            var activations = 0
            carousel.configure(items: items, session: session, onSongAction: { _, _ in }, onSelect: { _ in activations += 1 })
            let height = NavidromeRecentViewCell.preferredHeight(for: traits, width: width, itemCount: items.count)
            carousel.frame = CGRect(x: 0, y: 30, width: width, height: height)
            carousel.setNeedsLayout(); carousel.layoutIfNeeded(); carousel.layoutIfNeeded()
            guard let collection = descendants(carousel).compactMap({ $0 as? UICollectionView }).first,
                  let dots = descendants(carousel).compactMap({ $0 as? UIPageControl }).first else { fatalError("Missing pager") }
            collection.layoutIfNeeded()
            func visibleIndices() -> [Int] {
                (collection.collectionViewLayout.layoutAttributesForElements(in: collection.bounds) ?? [])
                    .filter { $0.frame.intersection(collection.bounds).width > 0.5 }
                    .map(\.indexPath.item).sorted()
            }
            precondition(collection.numberOfItems(inSection: 0) == items.count, "Each collection cell must be ONE song")
            precondition(collection.isPagingEnabled && !collection.alwaysBounceVertical, "Only horizontal paging")
            precondition(visibleIndices() == [0, 1, 2], "First page must contain three rows in \(name): \(visibleIndices())")
            precondition(dots.numberOfPages == 3 && dots.currentPage == 0, "Three songs per page")
            let frames = (0..<3).map { collection.collectionViewLayout.layoutAttributesForItem(at: IndexPath(item: $0, section: 0))!.frame }
            precondition(Set(frames.map(\.minX)).count == 1 && Set(frames.map(\.minY)).count == 3, "Must be a vertical list, never a cover grid")
            precondition(frames.allSatisfy { abs($0.width - width) < 0.5 }, "Rows fill the contentView width")
            precondition(abs(frames[2].maxY - collection.bounds.height) <= 1, "Exactly three rows tall: \(name) rows=\(frames[2].maxY) viewport=\(collection.bounds.height) outer=\(height)")
            let baseline = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
            precondition(collection.backgroundColor == baseline.backgroundColor, "Do not override collection background")
            for index in 0..<3 {
                guard let cell = collection.cellForItem(at: IndexPath(item: index, section: 0)) else { fatalError("Missing song cell") }
                let views = descendants(cell)
                let areas = views.filter { $0.accessibilityIdentifier == "music.server.row.play" }
                precondition(areas.count == 1, "One song per UICollectionViewCell")
                let buttons = views.compactMap { $0 as? UIButton }.filter { $0.accessibilityIdentifier == "music.server.row.more" }
                precondition(buttons.count == 1 && buttons[0].showsMenuAsPrimaryAction, "Keep a working more menu")
                precondition(buttons[0].bounds.width >= 44 && buttons[0].bounds.height >= 44, "Menu hit target")
                let title = views.compactMap { $0 as? UILabel }.first { $0.text?.hasPrefix("Song ") == true }!
                let cover = views.compactMap { $0 as? UIImageView }.first { abs($0.bounds.width - 44) < 0.5 }!
                let coverFrame = cover.convert(cover.bounds, to: cell), titleFrame = title.convert(title.bounds, to: cell)
                precondition(titleFrame.midY < coverFrame.maxY && titleFrame.maxY > coverFrame.minY, "Title should sit beside artwork, not underneath")
                if direction == .leftToRight { precondition(titleFrame.minX >= coverFrame.maxX + 9, "LTR leading cover") }
                else { precondition(titleFrame.maxX <= coverFrame.minX - 9, "RTL leading cover") }
                precondition(titleFrame.width > 0, "Text has space")
                if index == 0 {
                    precondition(areas[0].accessibilityActivate() && activations == 1, "VoiceOver playback")
                    let menu = buttons[0].menu!.children.compactMap { $0 as? UIMenu }.flatMap(\.children)
                    precondition(menu.count == 5, "Preserve song menu actions")
                }
            }
            let offset = collection.contentOffset
            carousel.refreshPlaybackState()
            precondition(collection.contentOffset == offset, "Playback updates must not move pages")
            collection.scrollToItem(at: IndexPath(item: 3, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded(); collection.delegate?.scrollViewDidScroll?(collection)
            precondition(visibleIndices() == [3, 4, 5] && dots.currentPage == 1, "Next page must contain next three songs")
            carousel.frame.size.width = width - 34
            carousel.setNeedsLayout(); carousel.layoutIfNeeded(); carousel.layoutIfNeeded()
            precondition(visibleIndices() == [3, 4, 5], "Resize keeps logical page")
            collection.scrollToItem(at: IndexPath(item: 6, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded(); collection.delegate?.scrollViewDidScroll?(collection)
            precondition(visibleIndices() == [6, 7], "Last page must not duplicate songs or create empty interactive cells")
            carousel.frame.size.width = width
            carousel.configure(items: items, session: session, onSongAction: { _, _ in }, onSelect: { _ in })
            carousel.setNeedsLayout(); carousel.layoutIfNeeded()
            collection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height + 60)).image { child.view.layer.render(in: $0.cgContext) }
            try image.pngData()!.write(to: destination.appendingPathComponent("home-\(name).png"))
            for count in [0, 1, 2, 3] {
                carousel.configure(items: Array(items.prefix(count)), session: session, onSelect: { _ in })
                let compactHeight = NavidromeRecentViewCell.preferredHeight(for: traits, width: width, itemCount: count)
                carousel.frame.size.height = compactHeight
                carousel.setNeedsLayout(); carousel.layoutIfNeeded()
                precondition(dots.numberOfPages == (count == 0 ? 0 : 1), "Small lists have no extra pages")
                precondition(abs(collection.bounds.height - compactHeight) < 0.5, "Shrink to actual row count")
            }
            print("PASS_HOME_LIST \(name): three rows/page, RTL, menus, resize, 0–3 songs, unchanged background")
        }
    }
}
