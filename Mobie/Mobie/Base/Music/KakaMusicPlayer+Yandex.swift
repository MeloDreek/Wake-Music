import AppGroupKit
import KakaFoundation
import KakaUIKit

extension KakaMusicPlayer {
    @MainActor
    func handleYandexStreaming(_ model: MusicItemModel, resumeTime: TimeInterval) {
        guard let file = model.yandexFile else { return }
        let requestID = playbackRequestID
        // Stop the previous track while resolving a different Yandex track.
        playerView.resetPlayer()
        playbackStatus = .buffering

        YandexDriveService.shared.fileSource(file) { [weak self] result in
            guard let self = self, self.playbackRequestID == requestID,
                  self.playingMusic?.uniqueID() == model.uniqueID() else { return }
            switch result {
            case .success(let source):
                let url = source.url
                var resolved = model
                resolved.mediaPlayURL = url
                self.playingMusic?.mediaPlayURL = url
                let options = self.audioOption(resolved)
                self.playerView.set(url: url, options: options)
                if resumeTime > 0 { self.seek(time: resumeTime) }
                self.continueToPlay(resolved)
            case .failure(let error):
                self.playbackStatus = .error
                self.currentViewController()?.showOneAlert(message: error.errorDescription)
            }
        }
    }
}
