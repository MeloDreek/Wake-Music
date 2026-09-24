import Foundation
import Combine

// Only external boundaries are doubled. Store, reload, retire, pause and seek
// implementations are extracted from the app by extract-integration.rb.
@MainActor enum UserDefaults {
    static let suite = "Wake.Equalizer.Tests.\(UUID().uuidString)"
    static let standard = Foundation.UserDefaults(suiteName: suite)!
}
struct UIApplication {
    static let didBecomeActiveNotification = Notification.Name("EqualizerTestDidBecomeActive")
    static let shared = UIApplication()
    let connectedScenes: [AnyObject] = []
}
class UIWindowScene {}
enum SKStoreReviewController { static func requestReview(in scene: UIWindowScene) {} }
extension String { func localStr() -> String { self } }
@MainActor final class UserInfoManager {
    static let shared = UserInfoManager()
    @Published var payStatus = 0
    var premium = false
    func isPremium() -> Bool { premium }
    func isVIP() -> Bool { premium }
}
enum TestEngine { case system, wakePlayer }
enum TestOrder { case single, list }
@MainActor final class MusicConfigManager {
    static let shared = MusicConfigManager()
    var playerEngine = TestEngine.system {
        didSet { engineObserverWasSuppressed = KakaMusicPlayer.shared.isSwitchingEngineForEqualizer }
    }
    var engineObserverWasSuppressed = false
    var lastPlayTime: TimeInterval = 0
    var orderType = TestOrder.list
}
struct MusicItemModel {}
public enum TestPlaybackState { case paused, buffering, error, readyToPlay, playedToTheEnd, bufferFinished }
public enum KSPlayer { public typealias KSPlayerState = TestPlaybackState }
@MainActor class TestMediaPlayer {
    var delegate: AnyObject?
    var playbackVolume: Float = 1
    var playbackRate: Float = 1
    var currentPlaybackTime: TimeInterval = 0
    var isReadyToPlay = false
    var seekable = true
    var isPlaying = false
}
final class AudioEngineDynamicsPlayer {}
@MainActor final class KSMEPlayer: TestMediaPlayer {
    let audioOutput: AnyObject = AudioEngineDynamicsPlayer()
}
@MainActor final class TestOptions {
    var isAutoPlay = true
    var startPlayTime: TimeInterval = 0
    var startPlayRate: Float = 1
    var isAccurateSeek = false
}
@MainActor final class TestLayer {
    var player: TestMediaPlayer
    var delegate: AnyObject?
    let url: URL
    var options: TestOptions?
    var prepares = 0
    var plays = 0
    var seeks: [TimeInterval] = []
    var seekCompletion: ((Bool) -> Void)?
    init(player: TestMediaPlayer, url: URL = URL(string: "https://example.invalid/resolved-token.mp3")!) {
        self.player = player
        self.url = url
    }
    func pause() { player.isPlaying = false }
    func play() { plays += 1; player.isPlaying = true }
    func prepareToPlay() { prepares += 1 }
    func seek(time: TimeInterval, autoPlay: Bool, completion: @escaping (Bool) -> Void) {
        precondition(!autoPlay, "SDK seek must not own playback intent")
        seeks.append(time)
        seekCompletion = completion
    }
}
@MainActor final class TestPlayerView {
    var playerLayer: TestLayer?
    var setCount = 0
    func set(url: URL, options: TestOptions) {
        setCount += 1
        let player = KSMEPlayer()
        player.playbackRate = options.startPlayRate
        let layer = TestLayer(player: player, url: url)
        layer.options = options
        playerLayer = layer
    }
    func resetPlayer() { playerLayer = nil }
    func pause() { playerLayer?.pause() }
    func play() { playerLayer?.play() }
}
@MainActor final class KakaMusicPlayer {
    static let shared = KakaMusicPlayer()
    let playerView = TestPlayerView()
    var playingMusic: MusicItemModel? = MusicItemModel()
    var wantsPlayback = false
    var playbackRequestID = UUID()
    var seekRequestID = UUID()
    var pendingSeekTime: TimeInterval?
    var isSeeking = false
    var isSwitchingEngineForEqualizer = false
    var currentTime: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    var playbackRate: Float = 1
    var playbackStatus = TestPlaybackState.paused
    var configurations = 0
    var lastConfiguredActive = false
    var playbackUpdates = 0
    var isRetry = false
    var isDecodingError = false
    func replaySingleItem() {}
    func playNextItem() {}
    func configureCurrentEqualizer() {
        configurations += 1
        lastConfiguredActive = PlayerEqualizerStore.shared.isActive
    }
    func audioOption(_ model: MusicItemModel) -> TestOptions {
        let options = TestOptions()
        options.startPlayRate = playbackRate
        return options
    }
    func updatePlaybackState() { playbackUpdates += 1 }
}

@main @MainActor struct EqualizerIntegrationTests {
    static var assertions = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        precondition(condition(), message)
    }

    static func main() throws {
        defer { UserDefaults.standard.removePersistentDomain(forName: UserDefaults.suite) }
        try testSettings()
        try testCustomRecallAndMigration()
        try testStoreAndReload()
        print("PASS_EQUALIZER_SETTINGS_STORE_RELOAD assertions=\(assertions)")
    }

    static func testSettings() throws {
        let blank = PlayerEqualizerSettings()
        expect(!blank.isEnabled && blank.preset == .bass && blank.outputGain == -6, "new settings select Bass Boost without enabling EQ")
        expect(blank.gains == [6, 5, 4, 2, 0, 0, 0, 0, 0, 0], "Bass Boost retains its original curve and applies it by default")
        let legacyEmpty = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: Data("{}".utf8))
        expect(legacyEmpty.preset == .flat && legacyEmpty.gains.allSatisfy { $0 == 0 }, "old incomplete records keep their flat fallback")
        var bad = blank
        bad.gains = [.nan, .infinity, -.infinity, 30, -30, 2]
        bad.preamp = .nan
        let normal = bad.normalized()
        expect(normal.gains == [0, 0, 0, 12, -12, 2, 0, 0, 0, 0], "invalid gains clamp/pad")
        expect(normal.preamp == 0 && normal.outputGain == -12, "invalid preamp and positive headroom")
        bad.preamp = 5
        expect(bad.normalized().preamp == 0, "preamp cannot add unprotected gain")
        bad.preamp = -99
        expect(bad.normalized().preamp == -12 && bad.outputGain == -24, "minimum combined gain")
        bad.gains = Array(repeating: -6, count: 13)
        expect(bad.normalized().gains.count == 10 && bad.outputGain == -12, "cuts do not require extra headroom")
        let expectedPresets: [PlayerEqualizerPreset] = [
            .flat, .bass, .bassReduction, .treble, .trebleReduction,
            .vocal, .warmth, .clarity, .soft, .rock, .pop, .jazz, .acoustic, .classical
        ]
        expect(PlayerEqualizerPreset.factoryPresets == expectedPresets, "curated listening goals before selected musical starting points")
        expect(!PlayerEqualizerPreset.factoryPresets.contains(.custom), "custom is not a factory preset")
        expect(PlayerEqualizerPreset.displayedPresetRows.count == 3, "picker retains exactly three horizontal rows")
        expect(PlayerEqualizerPreset.displayedPresetRows.allSatisfy { $0.count == 5 }, "each preset row has five choices")
        expect(PlayerEqualizerPreset.displayedPresetRows[0] == [.custom, .bass, .bassReduction, .treble, .trebleReduction], "custom starts the first row before bass and treble boosts/cuts")
        expect(PlayerEqualizerPreset.displayedPresets.filter { $0 == .custom }.count == 1, "custom recall remains available once")
        expect(Set(PlayerEqualizerPreset.displayedPresets) == Set(expectedPresets + [.custom]), "all curated presets remain available")
        expect(Set(PlayerEqualizerPreset.displayedPresets).count == PlayerEqualizerPreset.displayedPresets.count, "no duplicate presets")
        let curves = PlayerEqualizerPreset.factoryPresets.compactMap(\.curve)
        expect(Set(curves).count == curves.count, "factory presets have distinct curves")
        for raw in ["flat", "bass", "vocal", "rock", "jazz", "acoustic", "custom"] {
            expect(PlayerEqualizerPreset(rawValue: raw) != nil, "legacy preset IDs remain readable")
        }
        for preset in PlayerEqualizerPreset.allCases {
            var settings = blank
            settings.isEnabled = true
            settings.preamp = -3
            settings.selectPreset(preset)
            if let curve = preset.curve {
                expect(curve.count == 10 && curve.allSatisfy { $0.isFinite && abs($0) <= 12 }, "valid preset curve")
                expect(settings.gains == curve, "preset applies its curve")
            }
            let data = try JSONEncoder().encode(settings)
            let decoded = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: data)
            expect(decoded == settings, "preset JSON round trip")
            expect(settings.outputGain <= settings.preamp, "headroom never boosts master output")
        }
        var custom = blank
        custom.gains[3] = 7
        custom.selectPreset(.custom)
        expect(custom.gains[3] == 7, "custom retains manual curve")
        custom.selectPreset(.flat)
        expect(custom.gains.allSatisfy { $0 == 0 }, "flat resets band gains")
    }

    static func testCustomRecallAndMigration() throws {
        var manual = PlayerEqualizerSettings()
        manual.gains = [1, -2, 3, -4, 5, -6, 4, -3, 2, -1]
        manual.preamp = -4.5
        manual.saveCustomCurve()
        let remembered = manual
        expect(manual.preset == .custom && manual.customCurve?.gains == manual.gains, "manual edit saves and marks custom")
        expect(!manual.isEnabled, "manual edit does not enable EQ")
        manual.selectPreset(.jazz)
        expect(manual.gains == PlayerEqualizerPreset.jazz.curve && manual.customCurve == remembered.customCurve, "factory preset leaves custom memory untouched")
        expect(manual.preamp == -4.5 && !manual.isEnabled, "factory selection retains preamp and disabled state")
        manual.selectPreset(.rock)
        manual.selectPreset(.custom)
        expect(manual == remembered, "custom restores complete manual curve and preamp after multiple factories")
        manual.selectPreset(.flat)
        manual.preamp = 0 // Reset action clears active EQ, not the recall slot.
        manual.selectPreset(.custom)
        expect(manual == remembered, "custom can be recalled after flat reset including preamp")
        manual.selectPreset(.pop)
        let disk = try JSONEncoder().encode(manual)
        var recalled = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: disk).normalized()
        expect(recalled == manual, "custom slot persists while a factory preset is active")
        recalled.selectPreset(.custom)
        expect(recalled == remembered, "custom recall survives relaunch")
        recalled.gains[0] = -5
        recalled.preamp = -2
        recalled.saveCustomCurve()
        recalled.selectPreset(.treble)
        recalled.selectPreset(.custom)
        expect(recalled.gains[0] == -5 && recalled.preamp == -2, "latest manual band and preamp edits replace the recalled values")

        var first = PlayerEqualizerSettings()
        first.selectPreset(.acoustic)
        first.preamp = -1.5
        first.selectPreset(.custom)
        expect(first.gains == PlayerEqualizerPreset.acoustic.curve && first.preamp == -1.5, "first custom selection starts at current values")
        expect(first.customCurve != nil && !first.isEnabled, "first custom selection remembers values without enabling")

        let legacyCases: [PlayerEqualizerPreset] = [.flat, .bass, .vocal, .rock, .jazz, .acoustic,
            .classical, .pop, .hipHop, .rnb, .electronic, .blues, .country, .metal,
            .reggae, .soul, .punk, .folk, .latin, .ambient, .soundtrack, .disco, .custom]
        for preset in legacyCases {
            let oldGains = preset.curve ?? remembered.gains
            // Genuine old v1 JSON with no customCurve field.
            let oldData = try JSONSerialization.data(withJSONObject: [
                "isEnabled": true, "gains": oldGains, "preamp": -3, "preset": preset.rawValue
            ])
            let migrated = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: oldData).normalized()
            expect(migrated.isEnabled && migrated.gains == oldGains && migrated.preamp == -3, "legacy JSON keeps exact active audio values")
            if PlayerEqualizerPreset.factoryPresets.contains(preset) {
                expect(migrated.preset == preset, "visible legacy factory choice retained")
            } else {
                expect(migrated.preset == .custom && migrated.customCurve?.gains == oldGains && migrated.customCurve?.preamp == -3,
                       "hidden legacy or manual curve migrates to recoverable custom")
                var migratedRecall = migrated
                migratedRecall.selectPreset(.flat)
                migratedRecall.selectPreset(.custom)
                expect(migratedRecall == migrated, "migrated legacy sound can be recalled")
            }
        }
        let malformedSnapshot = Data("""
        {"isEnabled":true,"gains":[1,2,3],"preamp":-2,"preset":"bass","customCurve":{"gains":"broken","preamp":{}}}
        """.utf8)
        let repaired = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: malformedSnapshot).normalized()
        expect(repaired.isEnabled && repaired.gains == [1,2,3,0,0,0,0,0,0,0] && repaired.preamp == -2 && repaired.preset == .bass,
               "malformed optional snapshot does not discard active EQ")
        expect(repaired.customCurve == nil, "malformed optional snapshot is discarded alone")
        var invalidRecall = PlayerEqualizerSettings()
        invalidRecall.customCurve = .init(gains: [.nan, .infinity, -99, 99], preamp: -.infinity)
        invalidRecall.selectPreset(.custom)
        expect(invalidRecall.gains == [0,0,-12,12,0,0,0,0,0,0] && invalidRecall.preamp == 0, "recall normalizes short nonfinite and excessive data")
        expect(invalidRecall.customCurve?.gains == invalidRecall.gains, "repaired recall is stored as safe values")
    }

    static func testStoreAndReload() throws {
        let key = "PlayerEqualizerSettings.v1"
        var saved = PlayerEqualizerSettings()
        saved.gains = [99]
        saved.preamp = 8
        UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key)
        let store = PlayerEqualizerStore.shared
        expect(store.settings.gains[0] == 12 && store.settings.gains.count == 10 && store.settings.preamp == 0, "saved settings normalize on load")
        let original = UserDefaults.standard.data(forKey: key)
        var notifications = 0
        let subscription = NotificationCenter.default.publisher(for: .playerEqualizerChanged).sink { _ in notifications += 1 }
        defer { subscription.cancel() }
        var enabled = PlayerEqualizerSettings()
        enabled.isEnabled = true
        enabled.selectPreset(.bass)
        expect(!store.update(enabled), "non-premium mutation rejected")
        var forbiddenCustom = enabled
        forbiddenCustom.gains[0] = 3
        forbiddenCustom.preamp = -6
        forbiddenCustom.saveCustomCurve()
        expect(!store.update(forbiddenCustom) && store.settings.customCurve == nil, "non-premium custom edit and recall slot mutation rejected")
        expect(UserDefaults.standard.data(forKey: key) == original && notifications == 0, "rejection has no persistent or notification side effects")
        UserInfoManager.shared.premium = true
        expect(store.update(enabled) && store.isActive, "premium enables DSP")
        expect(notifications == 1, "successful update notifies once")
        expect(MusicConfigManager.shared.playerEngine == .wakePlayer && MusicConfigManager.shared.engineObserverWasSuppressed, "EQ engine migration suppresses legacy zero-time observer")
        let persisted = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: UserDefaults.standard.data(forKey: key)!)
        expect(persisted == enabled, "accepted settings persisted")
        var acceptedCustom = enabled
        acceptedCustom.gains[0] = 2.5
        acceptedCustom.preamp = -5
        acceptedCustom.saveCustomCurve()
        expect(store.update(acceptedCustom), "premium custom edit accepted")
        var factory = store.settings
        factory.selectPreset(.vocal)
        expect(store.update(factory), "factory change with saved custom accepted")
        var persistedCustom = try JSONDecoder().decode(PlayerEqualizerSettings.self, from: UserDefaults.standard.data(forKey: key)!)
        persistedCustom.selectPreset(.custom)
        expect(persistedCustom == acceptedCustom, "store persists custom gains and preamp across factory selection")

        let player = KakaMusicPlayer.shared
        let old = TestLayer(player: TestMediaPlayer())
        old.player.isReadyToPlay = true
        old.player.playbackVolume = 0.37
        old.player.playbackRate = 1.5
        old.player.currentPlaybackTime = 123.456
        player.playerView.playerLayer = old
        player.currentTime = 123.4
        player.playbackRate = 1.2
        player.wantsPlayback = false
        let oldGeneration = player.playbackRequestID
        player.equalizerSettingsDidChange()
        let paused = player.playerView.playerLayer!
        expect(paused !== old && paused.url == old.url, "reload uses resolved URL and fresh engine")
        expect(old.player.playbackVolume == 0 && !old.player.isPlaying, "retired engine silenced")
        expect(player.playbackRequestID != oldGeneration, "reload invalidates old playback generation")
        expect(!player.wantsPlayback && player.playbackStatus == .paused && paused.plays == 0, "paused reload never auto-plays")
        expect(paused.prepares == 1 && paused.options?.isAutoPlay == false, "reload explicitly prepares with auto-play disabled")
        expect(paused.options?.startPlayTime == 0 && player.pendingSeekTime == 123.456 && paused.options?.isAccurateSeek == true, "one accurate readiness seek restores precise engine time without competing startup seek")
        expect(paused.player.playbackVolume == 0.37 && paused.player.playbackRate == 1.5, "volume and rate retained")
        paused.player.isReadyToPlay = true
        player.playerController(state: .readyToPlay)
        expect(paused.seeks == [123.456] && player.pendingSeekTime == nil && !player.wantsPlayback, "paused readiness configures and seeks without resume")
        paused.seekCompletion?(true)
        expect(paused.plays == 0 && player.playbackStatus == .paused, "paused readiness seek completion remains paused")
        let count = player.playerView.setCount
        let configurations = player.configurations
        player.equalizerSettingsDidChange()
        expect(player.playerView.playerLayer === paused && player.playerView.setCount == count && player.configurations == configurations + 1, "native slider updates never reload")

        let preparing = TestLayer(player: TestMediaPlayer())
        player.playerView.playerLayer = preparing
        player.wantsPlayback = true
        player.currentTime = 22
        player.pendingSeekTime = 77
        player.isSeeking = true
        player.equalizerSettingsDidChange()
        let migrated = player.playerView.playerLayer!
        expect(player.pendingSeekTime == 77 && migrated.options?.startPlayTime == 0 && player.wantsPlayback, "pending seek wins during migration")
        expect(!player.isSeeking && migrated.plays == 0 && player.playbackStatus == .buffering, "old seek cancelled; resume waits for readiness")
        migrated.player.isReadyToPlay = true
        player.playerController(state: .readyToPlay)
        expect(migrated.seeks == [77] && player.isSeeking, "readiness seek goes through real seek gate")
        let completion = migrated.seekCompletion!
        player.pause()
        completion(true)
        expect(!player.wantsPlayback && migrated.plays == 0 && player.playbackStatus == .paused, "pause during seek prevents late completion restart")
        player.seek(time: 90, resumePlayback: true)
        migrated.seekCompletion?(true)
        expect(player.wantsPlayback && migrated.plays == 1 && !player.isSeeking, "successful explicit resume plays once")

        let live = TestLayer(player: TestMediaPlayer())
        live.player.isReadyToPlay = true
        live.player.seekable = false
        player.playerView.playerLayer = live
        player.currentTime = 900
        player.pendingSeekTime = nil
        player.equalizerSettingsDidChange()
        expect(player.pendingSeekTime == 0 && player.playerView.playerLayer?.options?.startPlayTime == 0, "unseekable source restarts without invalid timestamp")
        let liveReplacement = player.playerView.playerLayer!
        liveReplacement.player.isReadyToPlay = true
        liveReplacement.player.seekable = false
        player.playerController(state: .readyToPlay)
        expect(liveReplacement.seeks.isEmpty && liveReplacement.plays == 1 && player.pendingSeekTime == nil, "live readiness resumes directly without seek zero")
        player.pause()
        player.pendingSeekTime = 0
        player.playerController(state: .readyToPlay)
        expect(liveReplacement.seeks.isEmpty && liveReplacement.plays == 1 && player.pendingSeekTime == nil && !player.wantsPlayback, "paused live readiness clears pending seek without resuming")
        let retainedCurve = store.settings
        UserInfoManager.shared.premium = false
        UserInfoManager.shared.payStatus += 1
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        expect(!store.isActive && !player.lastConfiguredActive && store.settings == retainedCurve, "entitlement loss bypasses DSP and retains curve")
        UserInfoManager.shared.premium = true
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        expect(store.isActive && player.lastConfiguredActive, "foreground entitlement refresh reapplies saved curve")
    }
}
