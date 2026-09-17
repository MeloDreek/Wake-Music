import AppGroupKit
import KakaFoundation
import KakaUIKit

extension KakaMusicPlayer {
    @MainActor
    func handleMEGAStreaming(_ model: MusicItemModel, resumeTime: TimeInterval) {
        guard let file = model.megaFile else { return }
        let requestID = playbackRequestID
        // Stop the previous track while resolving a different MEGA track.
        playerView.resetPlayer()
        playbackStatus = .buffering

        MEGADriveService.shared.fileURL(file) { [weak self] result in
            guard let self = self, self.playbackRequestID == requestID,
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
