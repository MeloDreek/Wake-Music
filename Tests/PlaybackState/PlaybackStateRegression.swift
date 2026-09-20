import Foundation

enum Status { case paused, buffering, error, playedToTheEnd }
struct MusicItemModel {
    let id: String
    var durationSeconds: Int { 35 }
    func uniqueID() -> String { id }
    static func demoMusicModel() -> MusicItemModel { MusicItemModel(id: "demo") }
}
@MainActor final class MusicConfigManager {
    static let shared = MusicConfigManager()
    var sleepTime: TimeInterval? = 30
    var lastPlayTime: TimeInterval = 90
    var lastTotalTime: TimeInterval = 100
    var lastPlayModel: MusicItemModel?
}
@MainActor final class ConnectConfigManager {
    static let shared = ConnectConfigManager()
    var lastPlaylist: [MusicItemModel] = [MusicItemModel(id: "remote")]
}
@MainActor final class DownloadManager {
    static let shared = DownloadManager()
    var cancelled = 0
    func cancelPreDownload() { cancelled += 1 }
}
@MainActor final class MetadataTask {
    var cancelled = false
    func cancel() { cancelled = true }
}
@MainActor final class SleepTimer {
    var stopped = false
    func stopTimer() { stopped = true }
}
let MPNowPlayingInfoPropertyPlaybackRate = "rate"
@MainActor final class MPNowPlayingInfoCenter {
    static let instance = MPNowPlayingInfoCenter()
    static func `default`() -> MPNowPlayingInfoCenter { instance }
    var nowPlayingInfo: [String: Any]?
}
@MainActor final class Engine {
    var delegate: AnyObject?
    var playbackVolume: Float = 1
    var isReadyToPlay = true
    var isPlaying = true
}
@MainActor final class Layer {
    var delegate: AnyObject?
    let player = Engine()
    var plays = 0
    var seekTargets: [TimeInterval] = []
    var completions: [@MainActor @Sendable (Bool) -> Void] = []
    func play() { plays += 1; player.isPlaying = true }
    func pause() { player.isPlaying = false }
    func seek(time: TimeInterval, autoPlay: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        precondition(!autoPlay, "SDK must not auto-resume an obsolete seek")
        seekTargets.append(time)
        completions.append(completion)
    }
}
@MainActor final class View {
    var playerLayer: Layer? = Layer()
    func pause() { playerLayer?.pause() }
    func resetPlayer() { playerLayer = nil }
}
@MainActor final class Player: NSObject {
    var playbackRequestID = UUID()
    var seekRequestID = UUID()
    var pendingSeekTime: TimeInterval?
    var isSeeking = false
    var wantsPlayback = true
    var playbackStatus = Status.buffering
    var playingMusic: MusicItemModel? = MusicItemModel(id: "A") {
        didSet { MusicConfigManager.shared.lastPlayModel = playingMusic }
    }
    let playerView = View()
    var currentTime: TimeInterval = 0
    var totalTime: TimeInterval = 100
    var lastUpdateTime: TimeInterval = 0
    var cacheCoverImage: String?
    var remoteMetadataTask: MetadataTask?
    var remoteMetadataGeneration = UUID()
    var remoteMetadataAttempted = true
    var nextPlayMusic: MusicItemModel?
    var pendingShuffleRound: [String]?
    var isRetry = true
    var isDecodingError = true
    let sleepTimer = SleepTimer()
    var sleepTime: TimeInterval = 30
    var musicArray: [MusicItemModel] = []
    var tempMusicArray: [MusicItemModel] = []
    @objc func prepareNextMusic() {}
    func setupRemoteTransportControls() {}
    func updateNowPlayingInfo(musicModel: MusicItemModel) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = ["id": musicModel.id]
    }
    func updateControlPlayTime(currentTime: TimeInterval, totalTime: TimeInterval) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?["time"] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?["duration"] = totalTime
    }
    func updatePlaybackState() {}
    func play() {
        playbackRequestID = UUID()
        wantsPlayback = true
        playbackStatus = .buffering
    }
    // APP_TRANSITION_METHODS
}

@main struct Regression {
    @MainActor static func main() {
        let a = MusicItemModel(id: "A")
        let b = MusicItemModel(id: "B")
        let p = Player()
        let first = p.playbackRequestID
        precondition(p.acceptsPlaybackRequest(first, model: a))
        p.pause()
        precondition(p.playbackStatus == .paused && !p.wantsPlayback)
        precondition(p.playerView.playerLayer?.player.isPlaying == false)
        precondition(!p.acceptsPlaybackRequest(first, model: a))
        p.play()
        precondition(!p.acceptsPlaybackRequest(first, model: a), "Pause/resume A must reject old A callback")
        let second = p.playbackRequestID
        p.playingMusic = b
        precondition(!p.acceptsPlaybackRequest(second, model: a))
        p.playingMusic = a
        let oldLayer = p.playerView.playerLayer!
        p.retirePlayback()
        precondition(oldLayer.player.playbackVolume == 0 && !oldLayer.player.isPlaying)
        precondition(p.playerView.playerLayer == nil && !p.acceptsPlaybackRequest(second, model: a))

        p.playerView.playerLayer = Layer()
        p.play()
        let layer = p.playerView.playerLayer!
        p.seek(time: 20)
        precondition(p.isSeeking)
        p.pause()
        layer.completions.removeFirst()(true)
        precondition(layer.plays == 0 && p.playbackStatus == .paused, "Late seek must not resume after pause")
        precondition(!p.isSeeking)
        p.play()
        p.seek(time: 30)
        p.seek(time: 40)
        layer.completions.removeFirst()(true)
        precondition(layer.plays == 0, "Older seek must not restart audio")
        layer.completions.removeFirst()(true)
        precondition(layer.plays == 1)
        precondition(!p.isSeeking)
        p.seek(time: 50)
        p.retirePlayback()
        p.playerView.playerLayer = Layer()
        p.play()
        layer.completions.removeFirst()(true)
        precondition(layer.plays == 1, "Retired engine must not resume after switching songs")
        p.pause()
        let pausedLayer = p.playerView.playerLayer!
        p.seek(time: 60)
        pausedLayer.completions.removeFirst()(true)
        precondition(pausedLayer.plays == 0 && p.playbackStatus == .paused)
        p.seek(time: 125, resumePlayback: true)
        precondition(p.wantsPlayback && p.isSeeking && p.currentTime == 125)
        precondition(p.playerView.playerLayer === pausedLayer && pausedLayer.plays == 0)
        precondition(pausedLayer.seekTargets.last == 125)
        pausedLayer.completions.removeFirst()(true)
        precondition(pausedLayer.plays == 1 && p.currentTime == 125, "Resume at the requested position without replacing the engine")
        p.pause()
        p.seek(time: 150, resumePlayback: true)
        p.pause()
        pausedLayer.completions.removeFirst()(true)
        precondition(pausedLayer.plays == 1 && !p.wantsPlayback, "A later pause must cancel scrub-and-resume")
        p.play()
        p.stop()
        precondition(p.currentTime == 0 && p.totalTime == 0 && p.playbackStatus == .paused)
        p.togglePlayback()
        precondition(p.wantsPlayback)
        p.togglePlayback()
        precondition(!p.wantsPlayback && p.playbackStatus == .paused)
        p.playerView.playerLayer = Layer()
        p.playerView.playerLayer?.player.isReadyToPlay = false
        p.seek(time: 70)
        precondition(p.pendingSeekTime == 70)
        p.retirePlayback()
        precondition(p.pendingSeekTime == nil)

        p.playerView.playerLayer = Layer()
        p.playingMusic = a
        p.musicArray = [a, b]
        p.tempMusicArray = [b, a]
        p.nextPlayMusic = b
        p.pendingShuffleRound = ["B", "A"]
        let metadata = MetadataTask()
        p.remoteMetadataTask = metadata
        let oldMetadataGeneration = p.remoteMetadataGeneration
        p.play()
        let serverRequest = p.playbackRequestID
        let exitingLayer = p.playerView.playerLayer!
        p.seek(time: 60)
        let cancellations = DownloadManager.shared.cancelled
        p.resetToPausedDemo()
        precondition(!p.wantsPlayback && p.playbackStatus == .paused)
        precondition(p.playerView.playerLayer == nil && !exitingLayer.player.isPlaying && exitingLayer.player.playbackVolume == 0)
        precondition(p.playingMusic?.id == "demo" && p.musicArray.map(\.id) == ["demo"] && p.tempMusicArray.map(\.id) == ["demo"])
        precondition(p.currentTime == 0 && p.totalTime == 35 && p.pendingSeekTime == nil && !p.isSeeking)
        precondition(p.nextPlayMusic == nil && p.pendingShuffleRound == nil)
        precondition(metadata.cancelled && p.remoteMetadataTask == nil && p.remoteMetadataGeneration != oldMetadataGeneration && !p.remoteMetadataAttempted)
        precondition(DownloadManager.shared.cancelled == cancellations + 1)
        precondition(p.sleepTimer.stopped && p.sleepTime == 0 && MusicConfigManager.shared.sleepTime == nil)
        precondition(!p.isRetry && !p.isDecodingError)
        precondition(MusicConfigManager.shared.lastPlayModel?.id == "demo" && MusicConfigManager.shared.lastPlayTime == 0 && MusicConfigManager.shared.lastTotalTime == 35)
        precondition(ConnectConfigManager.shared.lastPlaylist.isEmpty)
        precondition(MPNowPlayingInfoCenter.default().nowPlayingInfo?["id"] as? String == "demo")
        precondition(MPNowPlayingInfoCenter.default().nowPlayingInfo?["rate"] as? Int == 0)
        precondition(!p.acceptsPlaybackRequest(serverRequest, model: a), "Server callback cannot restore playback after confirmed exit")
        exitingLayer.completions.removeFirst()(true)
        precondition(exitingLayer.plays == 0 && p.playingMusic?.id == "demo", "Pending server seek cannot resume on Classic")
        p.resetToPausedDemo()
        precondition(p.playingMusic?.id == "demo" && !p.wantsPlayback && p.playerView.playerLayer == nil, "Reset is idempotent and never auto-starts Demo")
        print("PASS: playback requests, pause/stop, same-track resume, stale seeks, rapid toggles, and paused Demo reset/persistence after music-server exit")
    }
}
