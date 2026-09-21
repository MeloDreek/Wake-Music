import UIKit
import KakaFoundation

extension NavidromeHomeViewController {
    func configSearchBar() {
        definesPresentationContext = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        if #available(iOS 26.0, *) {
            navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        }
        searchController.onSelection = { [weak self] item, items in
            guard let self else { return }
            // Close the search presentation before pushing a detail or presenting the player.
            self.searchController.dismissForSelection { [weak self] in
                guard let self, self.viewIfLoaded?.window != nil else { return }
                MusicServerSelection.open(item, among: items, session: self.session, from: self)
            }
        }
    }
}
