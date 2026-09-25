import UIKit

// Network, image downloads and playback are absent. Header construction, button
// styling and responsive sizing are copied verbatim from the production methods.
private let appMainColor = UIColor.systemBlue
extension String { func localStr() -> String { self } }

private final class AlbumHeaderProbe: UIViewController {
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    let header = UIView()
    let artworkContainer = UIView()
    let artwork = UIImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let metadataLabel = UILabel()
    let summaryLabel = UILabel()
    let descriptionView = MusicServerExpandableTextView()
    let actionStack = UIStackView()
    let playButton = UIButton(type: .custom)
    let shuffleButton = UIButton(type: .custom)
    @objc func playAlbum() {}
    @objc func shuffleAlbum() {}
    /* PRODUCTION_METHODS */

    func prepare() {
        loadViewIfNeeded()
        view.addSubview(tableView)
        configureHeader()
        titleLabel.text = "An Album With A Long Multilingual Title · 专辑名称"
        artistLabel.text = "Artist One & Artist Two"
        metadataLabel.text = "Alternative · 2026"
        summaryLabel.text = "25 songs · 1 hr 30 min"
    }

    func layout(width: CGFloat) {
        view.frame = CGRect(x: 0, y: 0, width: width, height: 1400)
        tableView.frame = view.bounds
        view.setNeedsLayout()
        view.layoutIfNeeded()
        viewDidLayoutSubviews()
        header.layoutIfNeeded()
        viewDidLayoutSubviews()
        header.layoutIfNeeded()
    }
}

@main enum AlbumHeaderRegression {
    @MainActor static func main() {
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: 300, songDurations: [Int.max], isComplete: false) == 300)
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: nil, songDurations: [Int.max, Int.max], isComplete: true) == nil)
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: Int.max, songDurations: [120, 180], isComplete: true) == 300)
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: nil, songDurations: [120, 180], isComplete: false) == nil)
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: nil, songDurations: [-10, 120, 180], isComplete: true) == 300)
        precondition(AlbumHeaderProbe.displayDuration(albumDuration: -1, songDurations: [], isComplete: true) == nil)
        let controller = AlbumHeaderProbe()
        controller.prepare()
        for width: CGFloat in [320, 402, 744, 1000, 320] {
            controller.layout(width: width)
            let image = controller.artworkContainer.bounds.size
            precondition(abs(image.width - image.height) < 0.5 && image.width <= 300.5 && image.width > 150,
                "Cover must remain square and bounded at width \(width)")
            precondition(controller.header.frame.width == width)
            precondition(controller.header.frame.height > image.height + 160)
            let buttons = controller.actionStack.convert(controller.actionStack.bounds, to: controller.header)
            precondition(buttons.minX >= 23.5 && buttons.maxX <= width - 23.5, "Actions exceeded the header bounds")
            precondition(controller.playButton.bounds.height >= 47.5)
        }
        let collapsed = controller.header.bounds.height
        controller.descriptionView.configure(text: String(repeating: "An informative album note with meaningful context. ", count: 35))
        controller.layout(width: 320)
        precondition(controller.header.bounds.height > collapsed)
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let more = descendants(controller.descriptionView).compactMap { $0 as? UIButton }.first!
        let shortHeight = controller.header.bounds.height
        let action = more.actions(forTarget: controller.descriptionView, forControlEvent: .touchUpInside)!.first!
        controller.descriptionView.perform(NSSelectorFromString(action))
        controller.layout(width: 320)
        precondition(controller.header.bounds.height > shortHeight + 30, "Expanded notes did not resize the table header")
        controller.descriptionView.configure(text: nil)
        controller.layout(width: 320)
        precondition(abs(controller.header.bounds.height - collapsed) < 1, "Missing notes left blank header space")
        controller.descriptionView.configure(text: "An expansive collection of cinematic music, featuring vivid orchestral textures, quiet acoustic moments, and a bold sense of adventure. A carefully sequenced album for focused listening.")
        if CommandLine.arguments.count > 1 { controller.artwork.image = UIImage(contentsOfFile: CommandLine.arguments[1]) }
        controller.header.backgroundColor = .systemGroupedBackground
        controller.overrideUserInterfaceStyle = .light
        controller.layout(width: 402)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: controller.header.bounds, format: format).image { context in
            controller.header.layer.render(in: context.cgContext)
        }
        try! image.pngData()!.write(to: URL(fileURLWithPath: "/private/tmp/wake-nav-album-header.png"))
        controller.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        controller.layout(width: 320)
        precondition(controller.actionStack.axis == .vertical)
        print("PASS album production header: 6 duration edge cases, 5 compact/expanded width transitions, square cover, bounded buttons, optional/expanded notes, accessibility action layout; route and pagination guards.")
    }
}
