import UIKit
import KakaFoundation

/// A category browser, not a second copy of the server's entire database.
final class MusicServerLibraryViewController: UITableViewController {
    private struct Entry {
        let title: String
        let symbol: String
        let route: MusicServerRoute
    }

    private let session: MusicServerSession
    private let sections: [[Entry]] = [
        [Entry(title: "Albums", symbol: "square.stack", route: .albums),
         Entry(title: "Artists", symbol: "person.2", route: .artists),
         Entry(title: "Songs", symbol: "music.note", route: .songs)],
        [Entry(title: "Favourite Songs", symbol: "heart", route: .favorites),
         Entry(title: "My Playlists", symbol: "music.note.list", route: .playlists),
         Entry(title: "Recently Played", symbol: "clock", route: .recent)],
        [Entry(title: "Radio Stations", symbol: "antenna.radiowaves.left.and.right", route: .radios),
         Entry(title: "Discover Music", symbol: "shuffle", route: .random)]
    ]

    init(session: MusicServerSession) {
        self.session = session
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library".localStr()
        navigationItem.largeTitleDisplayMode = .always
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "category") ?? UITableViewCell(style: .default, reuseIdentifier: "category")
        let entry = sections[indexPath.section][indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = entry.title.localStr()
        content.image = UIImage(systemName: entry.symbol)
        content.imageProperties.tintColor = view.tintColor
        content.directionalLayoutMargins.top = 16
        content.directionalLayoutMargins.bottom = 16
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = sections[indexPath.section][indexPath.row]
        MusicServerSelection.browse(entry.route, title: entry.title.localStr(), session: session, from: self)
    }
}
