import UIKit

// Only external dependencies are stubbed. All UIKit components and UIFontNumber are production source.
extension String { func localStr() -> String { self } }
struct HomeProbeRecord { let id: String; let title: String; let subtitle: String; let artworkID: String }
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

@main enum HomeLayoutProbe {
    @MainActor static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let variants: [(String, CGFloat, UIUserInterfaceLayoutDirection, UIContentSizeCategory)] = [
            ("phone-ltr", 393, .leftToRight, .large),
            ("phone-rtl", 393, .rightToLeft, .large),
            ("phone-large-type", 393, .leftToRight, .accessibilityExtraExtraExtraLarge),
            ("ipad", 820, .leftToRight, .large)
        ]
        for (name, width, direction, category) in variants {
            let traits = UITraitCollection(traitsFrom: [UITraitCollection(preferredContentSizeCategory: category),
                                                       UITraitCollection(layoutDirection: direction == .rightToLeft ? .rightToLeft : .leftToRight)])
            UITraitCollection.current = traits
            let root = UIViewController()
            let child = UIViewController()
            root.addChild(child)
            root.view.addSubview(child.view)
            child.didMove(toParent: root)
            root.setOverrideTraitCollection(traits, forChild: child)
            root.view.frame = CGRect(x: 0, y: 0, width: width, height: 2200)
            child.view.frame = root.view.bounds
            child.view.backgroundColor = .systemBackground
            let semantic: UISemanticContentAttribute = direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
            child.view.semanticContentAttribute = semantic
            let session = MusicServerSession()
            let items = (0..<12).map { MusicServerItem.song(HomeProbeRecord(id: "\($0)", title: "Song \($0 + 1) — A Little Longer", subtitle: "The Artist", artworkID: "")) }
            var y: CGFloat = 8
            func place(_ view: UIView, minHeight: CGFloat = 0) {
                func directionForSubviews(_ element: UIView) {
                    element.semanticContentAttribute = semantic
                    element.subviews.forEach(directionForSubviews)
                }
                directionForSubviews(view)
                child.view.addSubview(view)
                let container = (view as? UITableViewCell)?.contentView ?? (view as? UITableViewHeaderFooterView)?.contentView ?? view
                view.frame = CGRect(x: 0, y: y, width: width, height: max(44, minHeight))
                view.setNeedsLayout(); view.layoutIfNeeded()
                let fitting = container.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                    withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                let height = max(minHeight, ceil(fitting.height))
                precondition(height.isFinite && height > 0, "Invalid height \(name)")
                view.frame = CGRect(x: 0, y: y, width: width, height: height)
                view.setNeedsLayout(); view.layoutIfNeeded()
                y += height
            }
            let overview = MusicServerOverviewCell(style: .default, reuseIdentifier: nil)
            overview.configure(MusicServerOverview(songs: 456749, artists: 89440, albums: 72558, radios: 0), onSelect: { _ in })
            place(overview)
            let title = MusicServerSectionHeader(reuseIdentifier: nil)
            title.configure(title: direction == .rightToLeft ? "المقاطع الأخيرة" : "Recently Played", navigation: {})
            place(title)
            let carousel = MusicServerCarouselCell(style: .default, reuseIdentifier: nil)
            var songActivationCount = 0
            carousel.configure(items: items, session: session, onSelect: { _ in songActivationCount += 1 })
            place(carousel, minHeight: MusicServerCarouselCell.preferredHeight(for: traits))
            let playlistHeader = MusicServerSectionHeader(reuseIdentifier: nil)
            playlistHeader.configure(title: "My Playlists", actionTitle: "Create Playlist", actionSymbol: "plus", action: {})
            place(playlistHeader)
            let empty = MusicServerStatusCell(style: .default, reuseIdentifier: nil)
            empty.minimumHeight = 168
            empty.configure(.empty("Your playlists will appear here."))
            place(empty, minHeight: 168)
            let randomHeader = MusicServerSectionHeader(reuseIdentifier: nil)
            randomHeader.configure(title: "Discover", actionTitle: "Refresh", action: {})
            place(randomHeader)
            child.view.setNeedsLayout(); child.view.layoutIfNeeded()
            func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
            let overviewLabels = descendants(overview).compactMap { $0 as? UILabel }.compactMap(\.text)
            precondition(overviewLabels.contains("456,749") && overviewLabels.contains("89,440") && overviewLabels.contains("72,558"), "Overview lost counts")
            precondition(descendants(overview).compactMap { $0 as? UIImageView }.isEmpty, "Overview unexpectedly contains symbols")
            let allButtons = descendants(playlistHeader).compactMap { $0 as? UIButton }
            guard let plus = allButtons.first(where: { $0.accessibilityLabel == "Create Playlist" }) else { fatalError("Missing plus accessibility label") }
            precondition(plus.configuration?.image != nil && plus.configuration?.title == nil, "Plus should not show action text")
            precondition(plus.bounds.width >= 44 && plus.bounds.height >= 44, "Small plus target: \(plus.bounds)")
            precondition(empty.bounds.height >= 168, "Compact empty state")
            let navigationButtons = descendants(title).compactMap { $0 as? UIButton }.filter { $0.configuration?.image != nil }
            precondition(navigationButtons.count == 1, "Missing title arrow")
            guard let collection = descendants(carousel).compactMap({ $0 as? UICollectionView }).first else { fatalError("Missing carousel") }
            collection.layoutIfNeeded()
            let visibleColumns = collection.collectionViewLayout.layoutAttributesForElements(in: collection.bounds)?.filter { $0.representedElementCategory == .cell } ?? []
            precondition(visibleColumns.count >= 2, "Next carousel column is not visible: \(name) \(visibleColumns.map(\.frame))")
            let renderedTitles = collection.visibleCells.flatMap(descendants).compactMap { ($0 as? UILabel)?.text }
            precondition(renderedTitles.contains("Song 1 — A Little Longer"), "RTL must start at the first song column: \(name) direction=\(collection.effectiveUserInterfaceLayoutDirection.rawValue) semantics=\(collection.semanticContentAttribute.rawValue) offset=\(collection.contentOffset) indices=\(visibleColumns.map(\.indexPath)) titles=\(renderedTitles)")
            precondition(collection.touchesShouldCancel(in: UIControl()), "Horizontal scroll must cancel song taps")
            guard let firstSong = descendants(collection).compactMap({ $0 as? UIControl }).first(where: { $0.accessibilityLabel?.hasPrefix("Song 1 —") == true }) else {
                fatalError("First song control is missing")
            }
            precondition(firstSong.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) == true, "Song needs a tap recognizer")
            firstSong.sendActions(for: .touchUpInside)
            precondition(songActivationCount == 0, "A drag's touch-up must not activate a song")
            precondition(firstSong.accessibilityActivate() && songActivationCount == 1, "VoiceOver must still activate the song")
            let rowHeight = MusicServerCarouselCell.preferredHeight(for: traits)
            precondition(carousel.bounds.height >= rowHeight, "Dynamic Type carousel clipped")
            let format = UIGraphicsImageRendererFormat(); format.scale = 2; format.opaque = true
            let size = CGSize(width: width, height: min(y + 20, 2200))
            let image = UIGraphicsImageRenderer(size: size, format: format).image { child.view.layer.render(in: $0.cgContext) }
            let output = destination.appendingPathComponent("home-\(name).png")
            try image.pngData()!.write(to: output)
            print("PASS_HOME_LAYOUT \(name) height=\(y) visibleColumns=\(visibleColumns.count) \(output.path)")
        }
    }
}
