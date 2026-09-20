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

@main enum HomeLayoutProbe {
    @MainActor static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let variants: [(String, CGFloat, UIUserInterfaceLayoutDirection, UIContentSizeCategory)] = [
            ("phone-compact", 320, .leftToRight, .large),
            ("phone-ltr", 393, .leftToRight, .large),
            ("phone-rtl", 393, .rightToLeft, .large),
            ("phone-large-type", 393, .leftToRight, .accessibilityExtraExtraExtraLarge),
            ("ipad-split", 600, .leftToRight, .large),
            ("ipad", 820, .leftToRight, .large),
            ("ipad-rtl", 820, .rightToLeft, .large)
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
            child.view.backgroundColor = .systemGroupedBackground
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
            carousel.configure(items: items, session: session, onSongAction: { _, _ in }, onSelect: { _ in songActivationCount += 1 })
            place(carousel, minHeight: MusicServerCarouselCell.preferredHeight(for: traits, width: width))
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
            func visiblePages() -> [UICollectionViewLayoutAttributes] {
                (collection.collectionViewLayout.layoutAttributesForElements(in: collection.bounds) ?? [])
                    .filter { $0.representedElementCategory == .cell && $0.frame.intersection(collection.bounds).width > 0.5 }
            }
            let visibleColumns = visiblePages()
            precondition(collection.isPagingEnabled, "Grid must use whole-page paging")
            precondition(visibleColumns.count == 1 && visibleColumns.first?.indexPath.item == 0,
                         "A parked grid must expose only its first logical page: \(name) \(visibleColumns.map(\.frame))")
            precondition(abs((visibleColumns.first?.frame.width ?? 0) - collection.bounds.width) < 0.5,
                         "Grid page must fill the table cell width")
            guard let firstPage = collection.cellForItem(at: IndexPath(item: 0, section: 0)) else { fatalError("Missing first page") }
            let pageViews = descendants(firstPage)
            precondition(pageViews.compactMap { $0 as? UITableView }.isEmpty, "Artwork grid must not wrap nested song tables")
            let renderedTitles = pageViews.compactMap { ($0 as? UILabel)?.text }
            precondition(renderedTitles.contains("Song 1 — A Little Longer"), "RTL must start at the first song page")
            let playAreas = pageViews.filter { $0.accessibilityIdentifier == "music.server.grid.play" }
            let expectedColumns = min(4, max(2, Int((width - 16) / 176)))
            precondition(playAreas.count == expectedColumns * 2, "Grid must contain two rows and width-adaptive columns")
            let cardFrames = playAreas.map { $0.convert($0.bounds, to: firstPage) }
            precondition(Set(cardFrames.map { Int($0.minX.rounded()) }).count == expectedColumns &&
                         Set(cardFrames.map { Int($0.minY.rounded()) }).count == 2, "Songs are not laid out as a true grid")
            for area in playAreas {
                for label in descendants(area).compactMap({ $0 as? UILabel }) {
                    let labelFrame = label.convert(label.bounds, to: area)
                    precondition(labelFrame.minX >= -0.5 && labelFrame.maxX <= area.bounds.width + 0.5,
                                 "Song text overflows its grid card in \(name): \(labelFrame) within \(area.bounds)")
                }
            }
            precondition(collection.touchesShouldCancel(in: UIControl()), "Horizontal scroll must cancel button tracking")
            guard let firstPlay = playAreas.first(where: { $0.accessibilityLabel?.hasPrefix("Song 1 —") == true }) else {
                fatalError("First song activation area missing")
            }
            precondition(firstPlay.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) == true,
                         "Song cards need a pan-dependent tap recognizer")
            collection.delegate?.collectionView?(collection, didSelectItemAt: IndexPath(item: 0, section: 0))
            precondition(songActivationCount == 0, "Collection selection after a drag must never start playback")
            precondition(firstPlay.accessibilityActivate() && songActivationCount == 1, "VoiceOver activation must still play")
            guard let keyboardAction = firstPlay.keyCommands?.first?.action else { fatalError("Missing keyboard activation") }
            firstPlay.perform(keyboardAction)
            precondition(songActivationCount == 2, "Keyboard activation must still play")
            let menuButtons = pageViews.compactMap { $0 as? UIButton }.filter { $0.accessibilityIdentifier == "music.server.grid.more" }
            precondition(menuButtons.count == playAreas.count && menuButtons.allSatisfy { $0.isEnabled && $0.showsMenuAsPrimaryAction },
                         "Each song needs its own working more-menu entry")
            let menuActions = menuButtons[0].menu?.children.compactMap { $0 as? UIMenu }.flatMap(\.children) ?? []
            precondition(menuActions.count == 5, "Grid menu must preserve favorite/playlist/artist/album/download actions")
            guard let pageControl = descendants(carousel).compactMap({ $0 as? UIPageControl }).first else { fatalError("Missing page dots") }
            let itemsPerPage = expectedColumns * 2
            precondition(pageControl.numberOfPages == (items.count + itemsPerPage - 1) / itemsPerPage && pageControl.currentPage == 0,
                         "Page dots must describe the full song count")
            let oldOffset = collection.contentOffset
            if case .song(let song) = items[0] {
                KakaMusicPlayer.shared.playingMusic = session.musicItem(for: song)
                KakaMusicPlayer.shared.isPlaying = true
            }
            carousel.refreshPlaybackState()
            precondition(collection.contentOffset == oldOffset, "Playback refresh must not move/reload the grid")
            let firstTitle = descendants(firstPlay).compactMap { $0 as? UILabel }.first(where: { $0.text == "Song 1 — A Little Longer" })
            precondition(firstTitle?.textColor == firstPlay.tintColor, "Playing song should inherit the accent color")

            // Snap to a whole second page in either direction, then resize without losing its first song.
            let secondPage = IndexPath(item: 1, section: 0)
            collection.scrollToItem(at: secondPage, at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded()
            collection.delegate?.scrollViewDidScroll?(collection)
            precondition(visiblePages().map(\.indexPath.item) == [1] && pageControl.currentPage == 1, "Second page must be full-width and update dots")
            let snap = collection.collectionViewLayout.targetContentOffset(forProposedContentOffset: CGPoint(x: width * 1.35, y: 0), withScrollingVelocity: .zero)
            precondition(abs(snap.x.truncatingRemainder(dividingBy: width)) < 0.5, "Snap offset must align to an entire page")
            let resizedWidth = width > 700 ? 700.0 : width - 34
            carousel.frame.size = CGSize(width: resizedWidth, height: MusicServerCarouselCell.preferredHeight(for: traits, width: resizedWidth))
            carousel.setNeedsLayout(); carousel.layoutIfNeeded(); carousel.layoutIfNeeded()
            let resizedColumns = min(4, max(2, Int((resizedWidth - 16) / 176)))
            let expectedResizedPage = itemsPerPage / (resizedColumns * 2)
            precondition(visiblePages().map(\.indexPath.item) == [expectedResizedPage],
                         "Rotation/split-view resize must keep the previously visible song's logical page: \(name) expected=\(expectedResizedPage) actual=\(visiblePages().map(\.indexPath.item)) offset=\(collection.contentOffset) bounds=\(collection.bounds) dots=\(pageControl.currentPage)")
            carousel.frame.size = CGSize(width: width, height: MusicServerCarouselCell.preferredHeight(for: traits, width: width))
            carousel.setNeedsLayout(); carousel.layoutIfNeeded(); carousel.layoutIfNeeded()
            collection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded()
            collection.delegate?.scrollViewDidScroll?(collection)
            precondition(pageControl.currentPage == 0, "Restored first page must reset its logical dot")
            let rowHeight = MusicServerCarouselCell.preferredHeight(for: traits, width: width)
            precondition(carousel.bounds.height >= rowHeight, "Dynamic Type grid clipped")
            let format = UIGraphicsImageRendererFormat(); format.scale = 2; format.opaque = true
            let size = CGSize(width: width, height: min(y + 20, 2200))
            let image = UIGraphicsImageRenderer(size: size, format: format).image { child.view.layer.render(in: $0.cgContext) }
            let output = destination.appendingPathComponent("home-\(name).png")
            try image.pngData()!.write(to: output)
            carousel.configure(items: Array(items.prefix(5)), session: session, onSongAction: { _, _ in }, onSelect: { _ in })
            carousel.setNeedsLayout(); carousel.layoutIfNeeded(); collection.layoutIfNeeded()
            let lastPageIndex = (5 - 1) / itemsPerPage
            collection.scrollToItem(at: IndexPath(item: lastPageIndex, section: 0), at: .centeredHorizontally, animated: false)
            collection.layoutIfNeeded()
            guard let lastPage = collection.cellForItem(at: IndexPath(item: lastPageIndex, section: 0)) else { fatalError("Missing partial last page") }
            let lastCards = descendants(lastPage).filter { $0.accessibilityIdentifier == "music.server.grid.play" }
            precondition(lastCards.count == 5 - lastPageIndex * itemsPerPage, "Incomplete pages must not duplicate songs or expose empty tappable cards")
            print("PASS_HOME_LAYOUT \(name) height=\(y) visibleColumns=\(visibleColumns.count) \(output.path)")
        }
    }
}
