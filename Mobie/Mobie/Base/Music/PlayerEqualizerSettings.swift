import Foundation

/// Portable, versioned EQ values. No player, entitlement or UI state is persisted here.
struct PlayerEqualizerSettings: Codable, Equatable {
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    var isEnabled = false
    var gains = PlayerEqualizerPreset.bass.curve!
    var preamp: Float = 0
    var preset: PlayerEqualizerPreset = .bass
    /// Separate from the active factory preset, so trying a preset is reversible.
    /// Optional for compatibility with saved v1 settings that predate custom recall.
    var customCurve: CustomCurve?

    struct CustomCurve: Codable, Equatable {
        var gains: [Float]
        var preamp: Float

        func normalized() -> Self {
            Self(gains: PlayerEqualizerSettings.normalizedGains(gains),
                 preamp: PlayerEqualizerSettings.normalizedPreamp(preamp))
        }
    }

    func normalized() -> Self {
        var copy = self
        copy.gains = Self.normalizedGains(gains)
        copy.preamp = Self.normalizedPreamp(preamp)
        copy.customCurve = customCurve?.normalized()
        // Previously offered genre presets remain decodable. Keep their actual
        // sound rather than silently substituting one of the new choices.
        if !PlayerEqualizerPreset.displayedPresets.contains(copy.preset) {
            copy.preset = .custom
            copy.customCurve = CustomCurve(gains: copy.gains, preamp: copy.preamp)
        } else if copy.preset == .custom {
            // Older manual settings have no snapshot; their active values win.
            copy.customCurve = CustomCurve(gains: copy.gains, preamp: copy.preamp)
        }
        return copy
    }

    private static func normalizedGains(_ values: [Float]) -> [Float] {
        frequencies.indices.map { index in
            guard values.indices.contains(index), values[index].isFinite else { return 0 }
            return min(12, max(-12, values[index]))
        }
    }

    private static func normalizedPreamp(_ value: Float) -> Float {
        value.isFinite ? min(0, max(-12, value)) : 0
    }

    /// Boosts consume headroom rather than increasing the output's peak level.
    /// This reduces clipping risk; it is not a brick-wall limiter.
    var outputGain: Float {
        let valid = normalized()
        return valid.preamp - max(0, valid.gains.max() ?? 0)
    }

    mutating func selectPreset(_ preset: PlayerEqualizerPreset) {
        // Remember the last manual curve before leaving it, including its preamp.
        if self.preset == .custom { saveCustomCurve() }
        if preset == .custom {
            if let saved = customCurve?.normalized() {
                gains = saved.gains
                preamp = saved.preamp
            }
            saveCustomCurve()
            return
        }
        self.preset = preset
        if let curve = preset.curve { gains = curve }
        // Calls restoring an old hidden preset retain its sound as Custom too.
        if !PlayerEqualizerPreset.factoryPresets.contains(preset) { saveCustomCurve() }
    }

    /// Call after a manual band or preamp edit. Does not enable EQ or change access.
    mutating func saveCustomCurve() {
        gains = Self.normalizedGains(gains)
        preamp = Self.normalizedPreamp(preamp)
        preset = .custom
        customCurve = CustomCurve(gains: gains, preamp: preamp)
    }
}

extension PlayerEqualizerSettings {
    private enum CodingKeys: String, CodingKey {
        case isEnabled, gains, preamp, preset, customCurve
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        // Missing fields in an older saved record retain the old flat fallback.
        // Only a genuinely new settings instance starts with Bass Boost.
        gains = try values.decodeIfPresent([Float].self, forKey: .gains)
            ?? Array(repeating: Float(0), count: Self.frequencies.count)
        preamp = try values.decodeIfPresent(Float.self, forKey: .preamp) ?? 0
        preset = .flat
        if let rawPreset = try values.decodeIfPresent(String.self, forKey: .preset) {
            preset = PlayerEqualizerPreset(rawValue: rawPreset) ?? .custom
        }
        // Damage to this optional recall slot must not discard the active EQ.
        customCurve = try? values.decodeIfPresent(CustomCurve.self, forKey: .customCurve)
    }
}

enum PlayerEqualizerPreset: String, Codable, CaseIterable {
    // Keep the original raw values stable so saved curves remain readable.
    case flat, bass, vocal, rock, jazz, acoustic
    case classical, pop, hipHop, rnb, electronic, blues, country, metal
    case reggae, soul, punk, folk, latin, ambient, soundtrack, disco
    case bassReduction, treble, trebleReduction, warmth, clarity, soft
    case custom

    /// Intent-based choices first, followed by a small set of musical starting points.
    /// Legacy cases stay in the enum for decoding, not in the preset picker.
    static let factoryPresets: [Self] = [
        .flat, .bass, .bassReduction, .treble, .trebleReduction,
        .vocal, .warmth, .clarity, .soft, .rock, .pop, .jazz, .acoustic, .classical
    ]
    /// Three rows of five: custom recall first, then tone controls and listening profiles.
    static let displayedPresetRows: [[Self]] = [
        [.custom, .bass, .bassReduction, .treble, .trebleReduction],
        [.flat, .vocal, .warmth, .clarity, .soft],
        [.rock, .pop, .jazz, .acoustic, .classical],
    ]
    static var displayedPresets: [Self] { displayedPresetRows.flatMap { $0 } }

    var localizationKey: String {
        switch self {
        case .flat, .bass, .vocal, .rock, .jazz, .acoustic, .custom,
             .bassReduction, .treble, .trebleReduction, .warmth, .clarity, .soft:
            return "EQ." + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        case .hipHop: return "hip-hop"
        case .rnb: return "r&b"
        default: return rawValue
        }
    }

    var curve: [Float]? {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .vocal: return [-3, -2, -1, 0, 2, 3, 3, 2, 0, -1]
        case .rock: return [4, 3, 2, -1, -2, 0, 2, 3, 4, 3]
        case .jazz: return [3, 2, 1, 2, -1, -1, 0, 2, 3, 3]
        case .acoustic: return [2, 2, 1, 0, 1, 2, 2, 3, 2, 1]
        // Gentle starting points, not loudness targets or replicas of another player's curves.
        // Frequencies: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz.
        case .classical: return [2, 1, 0, -1, -1, 0, 0, 1, 2, 2]
        case .pop: return [-1, 1, 2, 1, 0, 1, 2, 3, 2, 0]
        case .bassReduction: return [-5, -4, -3, -1, 0, 0, 0, 0, 0, 0]
        case .treble: return [0, 0, 0, 0, 0, 0, 1, 2, 3, 3]
        case .trebleReduction: return [0, 0, 0, 0, 0, 0, -1, -2, -3, -4]
        case .warmth: return [1, 2, 2, 1, 0, 0, -1, -1, -1, -2]
        case .clarity: return [-1, -1, -2, -2, -1, 0, 1, 2, 1, 0]
        case .soft: return [0, 0, 0, 1, 1, 0, -1, -2, -2, -3]
        case .hipHop: return [5, 4, 3, 1, -1, 0, 1, 2, 1, 0]
        case .rnb: return [4, 3, 2, 0, -1, 1, 2, 1, 2, 1]
        case .electronic: return [4, 4, 2, 0, -2, -1, 1, 3, 4, 2]
        case .blues: return [1, 2, 1, 0, 1, 2, 2, 1, 0, -1]
        case .country: return [-1, 0, 1, 1, 0, 2, 3, 2, 1, 0]
        case .metal: return [3, 3, 2, -1, -2, 1, 3, 2, 1, 0]
        case .reggae: return [4, 5, 3, 1, 0, -1, 1, 1, 0, -1]
        case .soul: return [2, 3, 2, 1, 0, 2, 2, 1, 0, -1]
        case .punk: return [1, 2, 1, -1, 0, 2, 3, 2, 1, -1]
        case .folk: return [-1, 0, 1, 0, 1, 2, 2, 1, 1, 0]
        case .latin: return [2, 3, 2, 0, -1, 1, 2, 3, 2, 1]
        case .ambient: return [3, 2, 1, 0, -1, -1, 0, 1, 2, 3]
        case .soundtrack: return [3, 2, 1, -1, 0, 1, 1, 2, 2, 1]
        case .disco: return [3, 4, 2, -1, -2, 0, 2, 3, 3, 1]
        case .custom: return nil
        }
    }
}
