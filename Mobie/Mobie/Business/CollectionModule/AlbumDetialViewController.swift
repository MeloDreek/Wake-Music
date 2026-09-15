import UIKit
import AppGroupKit

final class AlbumDetialViewController: CollectionDetailViewController {
    init(album: String, viewModel: MusicViewModel) {
        super.init(kind: .album(album), viewModel: viewModel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
