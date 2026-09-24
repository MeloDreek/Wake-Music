import UIKit

@main
enum HeaderResizeRegression {
    static func main() {
        let probe = HeaderResizeProbe(frame: CGRect(x: 0, y: 0, width: 900, height: 760))
        let queue = QueueHeaderResizeProbe(frame: probe.frame)
        // Start with a stale wide header, as observed after folding the player.
        probe.songHeader.frame = CGRect(x: 0, y: 0, width: 900, height: 300)
        for width: CGFloat in [450, 420, 900, 360, 760, 430] {
            probe.bounds.size.width = width
            probe.tableView.frame = probe.bounds
            probe.layoutSongHeader()
            probe.tableView.layoutIfNeeded()
            probe.layoutSongHeader()
            let center = probe.songHeader.contentView.convert(probe.artwork.center, to: probe.tableView)
            precondition(abs(center.x - width / 2) < 1, "Artwork center did not follow viewport: \(width), \(center)")
            precondition(abs(probe.songHeader.bounds.width - width) < 1, "Stale table header width")
            precondition(probe.songTitle.frame.maxX <= width, "Title is outside resized header")
            queue.frame.size.width = width
            queue.setNeedsLayout()
            queue.layoutIfNeeded()
            queue.tableView.layoutIfNeeded()
            let queueCenter = queue.queueHeader.contentView.convert(queue.modes.center, to: queue.tableView)
            precondition(abs(queueCenter.x - width / 2) < 1, "Queue buttons did not follow viewport")
            precondition(abs(queue.queueHeader.bounds.width - width) < 1, "Stale queue header width")
            precondition(queue.artwork.frame.minX >= 0 && queue.songTitle.frame.maxX <= width,
                         "Queue header content is outside resized viewport")
        }
        print("Passed 12 production More/Queue header width transitions.")
    }
}
