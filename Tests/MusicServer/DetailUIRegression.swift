import UIKit

// Business services are intentionally offline; UI classes are extracted unchanged.
extension String { func localStr() -> String { self == "MusicServer.Song.AddedAt" ? "Added %@" : self } }
enum MusicCellType { case navidromeTrack }
struct MusicItemModel {
    let artist: String
    func showArtistName() -> String { artist }
}
struct MusicServerSong { let artist: String; var createdAt: Date? }
final class MusicServerSession {
    func musicItem(for song: MusicServerSong) -> MusicItemModel { .init(artist: song.artist) }
}
class MusicTableViewCell: UITableViewCell {
    let descLabel = UILabel()
    func update(musicModel: MusicItemModel, cellType: MusicCellType) { descLabel.text = musicModel.artist }
}

@main enum DetailUIRegression {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let session = MusicServerSession()
        let cell = MusicServerRecentUploadCell(style: .default, reuseIdentifier: "recent")
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        cell.configure(song: .init(artist: "Artist One", createdAt: date), session: session)
        let original = cell.descLabel.text!
        precondition(original.contains("Added ") && original.contains("Artist One"))
        cell.update(musicModel: .init(artist: "Artist One"), cellType: .navidromeTrack)
        precondition(cell.descLabel.text == original, "Playback refresh removed timestamp")
        cell.prepareForReuse()
        cell.configure(song: .init(artist: "Artist Two", createdAt: nil), session: session)
        precondition(cell.descLabel.text == "Artist Two", "Missing timestamp reused previous song's date")
        cell.configure(song: .init(artist: "", createdAt: date), session: session)
        precondition(!cell.descLabel.text!.contains(" · "), "Empty artist left a trailing separator")

        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let biography = MusicServerExpandableTextView(frame: .zero)
        let body = descendants(biography).compactMap { $0 as? UILabel }.first!
        let button = descendants(biography).compactMap { $0 as? UIButton }.first!
        // A command-line UIKit probe has no UIApplication event dispatch loop.
        // Invoke the real action registered on the button, not a test-only toggle.
        let actions = button.actions(forTarget: biography, forControlEvent: .touchUpInside)!
        precondition(actions.count == 1)
        func tapDescriptionButton() { biography.perform(NSSelectorFromString(actions[0])) }
        var changes = 0
        biography.onHeightChange = { changes += 1 }
        let long = String(repeating: "A long artist biography with natural spaces and album context. ", count: 40)
        biography.configure(text: long)
        func fit(_ width: CGFloat) -> CGFloat {
            biography.frame = CGRect(x: 0, y: 0, width: width, height: 100)
            biography.setNeedsLayout()
            biography.layoutIfNeeded()
            return biography.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        }
        for width: CGFloat in [300, 700, 280, 500] {
            let collapsed = fit(width)
            precondition(body.numberOfLines == 3 && !button.isHidden)
            tapDescriptionButton()
            let expanded = fit(width)
            precondition(body.numberOfLines == 0 && expanded > collapsed + 20, "Expanded description did not grow")
            tapDescriptionButton()
            precondition(body.numberOfLines == 3)
        }
        biography.configure(text: "Short biography.")
        _ = fit(300)
        precondition(!biography.isHidden && button.isHidden)
        biography.configure(text: "  \n ")
        precondition(biography.isHidden)
        precondition(changes > 0)
        print("PASS recent timestamp reuse/playback refresh/missing data; 4 biography width transitions, expand/collapse, short and empty descriptions.")
    }
}
