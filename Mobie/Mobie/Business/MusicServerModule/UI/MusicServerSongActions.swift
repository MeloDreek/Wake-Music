import UIKit
import AppGroupKit
import KakaUIKit
import KakaFoundation

/// Shared by paginated song lists and artist profiles. All mutations stay account-scoped.
@MainActor
final class MusicServerSongActions {
    private weak var controller: UIViewController?
    private let session: MusicServerSession
    private var tasks: [String: Task<Void, Never>] = [:]
    var onFavoriteChange: ((String, Bool) -> Void)?
    var onOpenItem: ((MusicServerItem) -> Void)?

    init(session: MusicServerSession, controller: UIViewController) {
        self.session = session
        self.controller = controller
    }

    deinit { tasks.values.forEach { $0.cancel() } }

    func handle(model: MusicItemModel, action: MusicActionType) {
        guard let controller, controller.viewIfLoaded?.window != nil,
              let song = model.navidromeSong, let user = song.navUser,
              MusicServerSession.identity(for: user) == session.accountID else { return }
        switch action {
        case .addFavirote, .removeFavirote:
            let favorite = action == .addFavirote
            run(key: "favorite:" + song.id) { [self] in
                try await session.setSongFavorite(id: song.id, isFavorite: favorite)
                onFavoriteChange?(song.id, favorite)
            }
        case .addPlaylist:
            guard controller.presentedViewController == nil else { return }
            let server = ServerConfigModel(serverType: .fromNavidrome, navUser: session.user)
            let picker = SelectPlaylistController(selectType: .navidromeList, serverModel: server)
            picker.onRemoteBlock = { [weak self] playlist in
                self?.run(key: "playlist:\(playlist.id):\(song.id)") { [weak self] in
                    try await self?.session.addSongToPlaylist(songID: song.id, playlistID: playlist.id)
                }
            }
            controller.present(KakaNavigationController(rootViewController: picker), animated: true)
        case .download:
            guard controller.presentedViewController == nil else { return }
            let picker = SelectPlaylistController(selectType: .downloadTask)
            picker.onLocalBlock = { [weak self] folder in
                guard let controller = self?.controller, controller.viewIfLoaded?.window != nil else { return }
                var download = model
                download.downloadFolderName = folder.lastPathComponent
                DownloadManager.shared.addMusicModel([download])
                controller.view.makeToast("Added to Downloads".localStr())
            }
            controller.present(KakaNavigationController(rootViewController: picker), animated: true)
        case .artistDetial:
            guard let id = song.artistId, !id.isEmpty else { return }
            open(.artist(MusicServerArtist(id: id, name: song.artist, albumCount: nil, songCount: nil, coverArt: "ar-" + id)))
        case .albumDetial:
            guard let id = song.albumId, !id.isEmpty else { return }
            open(.album(MusicServerAlbum(id: id, name: song.album, artist: song.artist, songCount: nil, coverArt: "al-" + id)))
        default: break
        }
    }

    private func open(_ item: MusicServerItem) {
        if let onOpenItem { onOpenItem(item) }
        else if let controller { MusicServerSelection.open(item, among: [item], session: session, from: controller) }
    }

    private func run(key: String, operation: @escaping @MainActor () async throws -> Void) {
        guard tasks[key] == nil else { return }
        tasks[key] = Task { [weak self] in
            defer { self?.tasks[key] = nil }
            do {
                try await operation()
                guard !Task.isCancelled, let controller = self?.controller, controller.viewIfLoaded?.window != nil else { return }
                controller.view.makeToast("Successful".localStr())
            } catch {
                guard !Task.isCancelled, let controller = self?.controller, controller.viewIfLoaded?.window != nil else { return }
                controller.view.makeToast((error as? MusicServerError)?.localizedDescription ?? "Unable to connect to the music server. Please try again.".localStr())
            }
        }
    }
}
