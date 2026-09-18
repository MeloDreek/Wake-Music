import UIKit
import Combine
import AppGroupKit
import KakaFoundation

extension Notification.Name {
    static let playerEqualizerChanged = Notification.Name("PlayerEqualizerChanged")
}

extension PlayerEqualizerPreset {
    var title: String { ("EQ." + rawValue.prefix(1).uppercased() + rawValue.dropFirst()).localStr() }
}

@MainActor
final class PlayerEqualizerStore {
    static let shared = PlayerEqualizerStore()
    private static let defaultsKey = "PlayerEqualizerSettings.v1"
    private(set) var settings: PlayerEqualizerSettings
    private var cancellables = Set<AnyCancellable>()

    static var hasAccess: Bool {
        #if Target_Mobie_Pro
        return true
        #else
        // isVIP() currently contains a development bypass. DSP uses the real entitlement.
        return UserInfoManager.shared.isPremium()
        #endif
    }

    var isActive: Bool { Self.hasAccess && settings.isEnabled }

    private init() {
        let saved = UserDefaults.standard.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode(PlayerEqualizerSettings.self, from: $0) }
        settings = (saved ?? PlayerEqualizerSettings()).normalized()
        UserInfoManager.shared.$payStatus.dropFirst().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.entitlementChanged() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.entitlementChanged() }.store(in: &cancellables)
    }

    /// The store gates mutations too: VoiceOver, presets and future callers cannot bypass UI gates.
    @discardableResult
    func update(_ newSettings: PlayerEqualizerSettings) -> Bool {
        guard Self.hasAccess else { return false }
        settings = newSettings.normalized()
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        KakaMusicPlayer.shared.equalizerSettingsDidChange()
        NotificationCenter.default.post(name: .playerEqualizerChanged, object: nil)
        return true
    }

    private func entitlementChanged() {
        // Never leave paid DSP running after entitlement loss. Retain the user's curve.
        KakaMusicPlayer.shared.equalizerSettingsDidChange()
        NotificationCenter.default.post(name: .playerEqualizerChanged, object: nil)
    }
}
