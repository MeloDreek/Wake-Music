import UIKit
import KakaFoundation

/// Search each category independently so a large song result never hides artists/albums.
final class MusicServerSearchViewController: SuperViewController, UISearchResultsUpdating, UISearchBarDelegate {
    private let session: MusicServerSession
    private let searchController = UISearchController(searchResultsController: nil)
    private let messageLabel = UILabel()
    private var results: MusicServerBrowseViewController?
    private var pendingSearch: Task<Void, Never>?
    private var displayedQuery: String?
    private var displayedKind: MusicServerSearchKind?

    init(session: MusicServerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { pendingSearch?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search".localStr()
        view.backgroundColor = .systemGroupedBackground
        definesPresentationContext = true
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.searchBar.placeholder = "Search songs, artists, or albums.".localStr()
        searchController.searchBar.scopeButtonTitles = ["Songs".localStr(), "Artists".localStr(), "Albums".localStr()]
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        messageLabel.text = "Search songs, artists, or albums.".localStr()
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30)
        ])
    }

    func cancelPendingRequests() {
        pendingSearch?.cancel()
        pendingSearch = nil
        results?.cancelPendingRequests()
    }

    func updateSearchResults(for searchController: UISearchController) { scheduleSearch() }
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) { scheduleSearch(immediately: true) }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        scheduleSearch(immediately: true)
        searchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        scheduleSearch(immediately: true)
    }

    private func scheduleSearch(immediately: Bool = false) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = MusicServerSearchKind(rawValue: searchController.searchBar.selectedScopeButtonIndex) ?? .songs
        guard query != displayedQuery || kind != displayedKind else { return }
        pendingSearch?.cancel()
        // Remove stale results immediately; the user must never tap a result from the previous query.
        removeResults()
        displayedQuery = nil
        displayedKind = nil
        messageLabel.isHidden = !query.isEmpty
        guard !query.isEmpty else { return }
        pendingSearch = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(nanoseconds: 300_000_000) }
                try Task.checkCancellation()
                guard let self else { return }
                self.displayedQuery = query
                self.displayedKind = kind
                let controller = MusicServerBrowseViewController(session: self.session, route: .search(query: query, kind: kind), title: "Search".localStr())
                self.addChild(controller)
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                self.contentView.addSubview(controller.view)
                NSLayoutConstraint.activate([
                    controller.view.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
                    controller.view.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
                    controller.view.topAnchor.constraint(equalTo: self.contentView.topAnchor),
                    controller.view.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
                ])
                controller.didMove(toParent: self)
                self.results = controller
            } catch { /* A superseded query must not display an error. */ }
        }
    }

    private func removeResults() {
        guard let controller = results else { return }
        controller.cancelPendingRequests()
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        results = nil
    }
}
