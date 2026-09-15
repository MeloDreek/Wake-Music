import UIKit
import AppGroupKit

final class ArtistDetialViewController: CollectionDetailViewController {
    init(singer: String, viewModel: MusicViewModel) {
        super.init(kind: .artist(singer), viewModel: viewModel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
