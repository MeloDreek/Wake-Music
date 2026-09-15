import UIKit
import AppGroupKit

final class GenreDetialViewController: CollectionDetailViewController {
    init(genre: MusicGenreType, viewModel: MusicViewModel) {
        super.init(kind: .genre(genre), viewModel: viewModel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
