require 'pathname'
root = Pathname.new(__dir__).join('../..').realpath
base = root.join('Mobie/Mobie/Business/MusicServerModule')
search = base.join('UI/NavidromeSearchViewController.swift').read
home = base.join('UI/NavidromeHomeViewController.swift').read
bridge = base.join('UI/NavidromeHomeViewController+Search.swift').read
roots = base.join('Navigation/MusicServerRootControllers.swift').read
checks = {
  'new home is the root' => roots.include?('return NavidromeHomeViewController(session: session, onExit: onExit)'),
  'independent download tab sharing the home exit flow' => roots.include?('case .download: return NavidromeDownloadViewController(onExit: onExit)'),
  'embedded search, not another tab' => bridge.include?('navigationItem.searchController = searchController') && !roots.include?('case search'),
  'all search scopes' => search.include?('["Songs", "Artists", "Albums"]'),
  'server search and pagination reuse' => search.include?('route: .search(query: query, kind: kind)'),
  'debounced queries' => search.include?('300_000_000'),
  'cancel and reject obsolete results' => search.include?('self.generation == requestGeneration') && search.include?('removeResults()'),
  'remove obsolete child controllers' => search.include?('controller.removeFromParent()'),
  'keyboard-safe results viewport' => search.include?('view.keyboardLayoutGuide.topAnchor'),
  'navigation after search dismissal' => search.include?('didDismissSearchController') && bridge.include?('dismissForSelection'),
  'cancel search on mode exit' => home.include?('searchController.cancelPendingRequests()'),
  'independent favorite shelf identity' => home.include?('"NavidromeFavoriteViewCell"'),
  'independent random shelf identity' => home.include?('"NavidromeRandomViewCell"')
}
checks.each { |message, valid| abort message unless valid }
puts "Homepage/search integration contracts passed (#{checks.size}); UI interactions still require Simulator checks."
