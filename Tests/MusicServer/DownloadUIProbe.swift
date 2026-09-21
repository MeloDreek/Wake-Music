import UIKit

extension String {
    func localStr() -> String {
        if self == "Back to Classic Mode" { return "返回经典模式" }
        return "从Navidrome下载的歌曲，您也可以直接切换到经典的离线模式，享受最顶级的离线音乐体验。"
    }
}
let appMainColor = UIColor.systemBlue
enum MusicServerDestination: Int { case home, library, download, profile }
@MainActor final class BadgeProbe: UITabBarController {
    // PRODUCTION_BADGE
}
// PRODUCTION_EMPTY_CELL

@main enum DownloadUIProbe {
    @MainActor static func main() {
        let tabs = BadgeProbe()
        tabs.viewControllers = (0..<4).map { _ in UIViewController() }
        for count in [0, 1, 12, 107, 0] {
            tabs.updateDownloadBadge(count)
            precondition(tabs.viewControllers![2].tabBarItem.badgeValue == (count > 0 ? String(count) : nil))
            for index in [0, 1, 3] { precondition(tabs.viewControllers![index].tabBarItem.badgeValue == nil) }
        }
        tabs.viewControllers = []
        tabs.updateDownloadBadge(2) // Safe during shell teardown.
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        for width: CGFloat in [280, 353, 560, 780] {
            let cell = NavidromeDownloadEmptyCell(style: .default, reuseIdentifier: nil)
            cell.minimumHeight = 550
            var exits = 0
            cell.onExit = { exits += 1 }
            let size = cell.contentView.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            cell.frame = CGRect(x: 0, y: 0, width: width, height: ceil(size.height))
            cell.layoutIfNeeded()
            let views = descendants(cell)
            let buttons = views.compactMap { $0 as? UIButton }
            precondition(buttons.count == 1, "Only a return action, never Import Music")
            precondition(buttons[0].bounds.height >= 44)
            // CLI UIKit has no UIApplication event dispatcher. Invoke the registered target/action.
            let actions = buttons[0].actions(forTarget: cell, forControlEvent: .touchUpInside) ?? []
            precondition(actions.count == 1)
            cell.perform(NSSelectorFromString(actions[0]))
            precondition(exits == 1, "Use the injected home exit flow")
            let image = views.compactMap { $0 as? UIImageView }.first { $0.image != nil }!
            let rect = image.convert(image.bounds, to: cell.contentView)
            precondition(rect.minX >= 19 && rect.maxX <= width - 19 && rect.minY >= 0, "Cassette needs horizontal breathing room")
            let buttonRect = buttons[0].convert(buttons[0].bounds, to: cell.contentView)
            precondition(buttonRect.maxY <= cell.bounds.height + 1, "Return button must not be clipped")
            cell.prepareForReuse()
            cell.perform(NSSelectorFromString(actions[0]))
            precondition(exits == 1)
            print("PASS_DOWNLOAD_EMPTY width=\(width) height=\(size.height)")
        }
        print("PASS_DOWNLOAD_BADGE 0→1→12→107→0; no changes to other tabs")
    }
}
