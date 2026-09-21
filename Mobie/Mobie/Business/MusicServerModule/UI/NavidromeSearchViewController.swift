import UIKit
import KakaFoundation

/// Homepage-owned search; each scope queries the whole account, with automatic pagination.
final class NavidromeSearchViewController: UISearchController, UISearchResultsUpdating, UISearchBarDelegate, UISearchControllerDelegate {
    private let results: NavidromeSearchResultsController
    private var pendingSelection: (() -> Void)?
    var onSelection: ((MusicServerItem, [MusicServerItem]) -> Void)? {
        didSet { results.onSelection = onSelection }
    }

    init(session: MusicServerSession) {
        results = NavidromeSearchResultsController(session: session)
        super.init(searchResultsController: results)
        searchResultsUpdater = self
        searchBar.delegate = self
        delegate = self
        obscuresBackgroundDuringPresentation = true
        searchBar.placeholder = "Search songs, artists, or albums.".localStr()
        searchBar.scopeButtonTitles = ["Songs", "Artists", "Albums"].map { $0.localStr() }
        scopeBarActivation = .onSearchActivation
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateSearchResults(for searchController: UISearchController) { search() }
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        search(immediately: true)
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        search(immediately: true)
        searchBar.resignFirstResponder()
    }
    private func search(immediately: Bool = false) {
        guard isActive else { cancelPendingRequests(); return }
        results.search(query: searchBar.text ?? "",
                       kind: MusicServerSearchKind(rawValue: searchBar.selectedScopeButtonIndex) ?? .songs,
                       immediately: immediately)
    }
    func cancelPendingRequests() { results.cancelPendingRequests() }
    func dismissForSelection(_ action: @escaping () -> Void) {
        guard pendingSelection == nil else { return }
        guard isActive else { action(); return }
        pendingSelection = action
        isActive = false
    }
    func willDismissSearchController(_ searchController: UISearchController) { cancelPendingRequests() }
    func didDismissSearchController(_ searchController: UISearchController) {
        let action = pendingSelection
        pendingSelection = nil
        action?()
    }
}

private final class NavidromeSearchResultsController: UIViewController {
    private let session: MusicServerSession
    private let messageLabel = UILabel()
    private var results: MusicServerBrowseViewController?
    private var pendingSearch: Task<Void, Never>?
    private var displayedQuery: String?
    private var displayedKind: MusicServerSearchKind?
    private var generation = UUID()
    var onSelection: ((MusicServerItem, [MusicServerItem]) -> Void)?

    init(session: MusicServerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { pendingSearch?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = "Search songs, artists, or albums.".localStr()
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }

    func cancelPendingRequests() {
        generation = UUID()
        pendingSearch?.cancel()
        pendingSearch = nil
        removeResults()
        displayedQuery = nil
        displayedKind = nil
    }

    func search(query rawQuery: String, kind: MusicServerSearchKind, immediately: Bool) {
        loadViewIfNeeded()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != displayedQuery || kind != displayedKind else { return }
        cancelPendingRequests()
        messageLabel.isHidden = !query.isEmpty
        guard !query.isEmpty else { return }
        let requestGeneration = generation
        pendingSearch = Task { [weak self] in
            do {
                if !immediately { try await Task.sleep(nanoseconds: 300_000_000) }
                try Task.checkCancellation()
                guard let self, self.generation == requestGeneration else { return }
                self.displayedQuery = query
                self.displayedKind = kind
                let controller = MusicServerBrowseViewController(session: self.session, route: .search(query: query, kind: kind), title: "Search".localStr())
                controller.onSelection = { [weak self] item, items in self?.onSelection?(item, items) }
                self.addChild(controller)
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(controller.view)
                NSLayoutConstraint.activate([
                    controller.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                    controller.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                    controller.view.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                    controller.view.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor)
                ])
                controller.didMove(toParent: self)
                self.results = controller
            } catch { /* Superseded queries must not flash an error or old results. */ }
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
