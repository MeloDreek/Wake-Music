import Foundation

/// Portable, versioned EQ values. No player, entitlement or UI state is persisted here.
struct PlayerEqualizerSettings: Codable, Equatable {
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    var isEnabled = false
    var gains = Array(repeating: Float(0), count: frequencies.count)
    var preamp: Float = 0
    var preset: PlayerEqualizerPreset = .flat

    func normalized() -> Self {
        var copy = self
        copy.gains = Self.frequencies.indices.map { index in
            guard gains.indices.contains(index), gains[index].isFinite else { return 0 }
            return min(12, max(-12, gains[index]))
        }
        copy.preamp = preamp.isFinite ? min(0, max(-12, preamp)) : 0
        return copy
    }

    /// Boosts consume headroom rather than increasing the output's peak level.
    /// This reduces clipping risk; it is not a brick-wall limiter.
    var outputGain: Float {
        let valid = normalized()
        return valid.preamp - max(0, valid.gains.max() ?? 0)
    }

    mutating func selectPreset(_ preset: PlayerEqualizerPreset) {
        self.preset = preset
        if let curve = preset.curve { gains = curve }
    }
}

enum PlayerEqualizerPreset: String, Codable, CaseIterable {
    case flat, bass, vocal, rock, jazz, acoustic, custom

    var curve: [Float]? {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .vocal: return [-3, -2, -1, 0, 2, 3, 3, 2, 0, -1]
        case .rock: return [4, 3, 2, -1, -2, 0, 2, 3, 4, 3]
        case .jazz: return [3, 2, 1, 2, -1, -1, 0, 2, 3, 3]
        case .acoustic: return [2, 2, 1, 0, 1, 2, 2, 3, 2, 1]
        case .custom: return nil
        }
    }
}
