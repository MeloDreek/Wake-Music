import AppGroupKit
import KakaFoundation
import KakaUIKit

extension KakaMusicPlayer {
    @MainActor
    func handlePan123Streaming(_ model: MusicItemModel, resumeTime: TimeInterval) {
        guard let file = model.pan123File else { return }
        let requestID = pcloudPlaybackRequestID
        // Stop the previous track while resolving a different Pan123 track.
        playerView.resetPlayer()
        playbackStatus = .buffering

        Pan123DriveService.shared.fileURL(file) { [weak self] result in
            guard let self = self, self.pcloudPlaybackRequestID == requestID,
                  self.playingMusic?.uniqueID() == model.uniqueID() else { return }
            switch result {
            case .success(let url):
                var resolved = model
                resolved.mediaPlayURL = url
                self.playingMusic?.mediaPlayURL = url
                self.playerView.set(url: url, options: self.audioOption(resolved))
                if resumeTime > 0 { self.seek(time: resumeTime) }
                self.continueToPlay(resolved)
            case .failure(let error):
                self.playbackStatus = .error
                self.currentViewController()?.showOneAlert(message: error.errorDescription)
            }
        }
    }
}
