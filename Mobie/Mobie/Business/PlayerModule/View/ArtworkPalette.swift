import UIKit
import DominantColors

/// A bounded, contrast-safe palette shared by collection details and the player.
struct ArtworkPalette {
    let primary: UIColor
    let secondary: UIColor
    let base: UIColor
    static let neutral = ArtworkPalette(primary: UIColor(white: 0.27, alpha: 1),
                                        secondary: UIColor(white: 0.20, alpha: 1),
                                        base: UIColor(white: 0.13, alpha: 1))

    static func luminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func readable(_ color: UIColor, brightnessScale: CGFloat = 1) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        s = min(s, 0.72)
        b = min(max(b, 0.32), 0.65) * brightnessScale
        var result = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
        // Every gradient endpoint supports at least 4.5:1 contrast with white.
        while luminance(result) > 0.18 {
            b *= 0.96
            result = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
        }
        return result
    }

    static func make(colors: [CGColor]) -> ArtworkPalette {
        guard !colors.isEmpty else { return .neutral }
        // Frequency matters, but a black border or white typography should not
        // beat a substantial colored area. Rank rather than discard all neutrals.
        let ranked = colors.enumerated().map { index, cgColor -> (UIColor, CGFloat) in
            let color = UIColor(cgColor: cgColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let usable: CGFloat = b > 0.12 && b < 0.97 && s > 0.12 ? 1 : 0.15
            return (color, usable * (1 + min(s, 0.7)) / (1 + CGFloat(index) * 0.40))
        }.sorted { $0.1 > $1.1 }
        let primary = readable(ranked[0].0)
        let secondary = readable(ranked.dropFirst().first?.0 ?? ranked[0].0, brightnessScale: 0.86)
        return ArtworkPalette(primary: primary, secondary: secondary,
                              base: readable(primary, brightnessScale: 0.70))
    }
}

final class ArtworkPaletteProvider {
    static let shared = ArtworkPaletteProvider()
    private let queue = DispatchQueue(label: "com.wakemusic.artwork-palette", qos: .userInitiated)
    private final class Box: NSObject {
        let value: ArtworkPalette
        init(_ value: ArtworkPalette) { self.value = value }
    }
    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 64
        return cache
    }()

    func palette(for image: UIImage?, completion: @escaping (ArtworkPalette) -> Void) {
        // All pixel processing and clustering happen off the main thread.
        let source = image?.cgImage
        queue.async {
            guard let source,
                  let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8,
                                          bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let bytes = context.data else {
                DispatchQueue.main.async { completion(.neutral) }
                return
            }
            context.interpolationQuality = .low
            context.setFillColor(UIColor(white: 0.2, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            context.draw(source, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            let pixels = bytes.assumingMemoryBound(to: UInt8.self)
            var hash: UInt64 = 14695981039346656037
            for i in 0..<(64 * 64 * 4) { hash = (hash ^ UInt64(pixels[i])) &* 1099511628211 }
            let key = String(hash) as NSString
            if let cached = self.cache.object(forKey: key) {
                DispatchQueue.main.async { completion(cached.value) }
                return
            }
            let colors = context.makeImage().flatMap {
                try? DominantColors.dominantColors(image: $0, quality: .fair,
                                                  algorithm: .CIE76, maxCount: 6, sorting: .frequency)
            } ?? []
            let palette = ArtworkPalette.make(colors: colors)
            self.cache.setObject(Box(palette), forKey: key)
            DispatchQueue.main.async { completion(palette) }
        }
    }
}

/// Soft, cover-derived color fields. No perpetual blur rendering or animation;
/// crossfades honor Reduce Motion and the opaque colors honor Reduce Transparency.
final class ArtworkBackgroundView: UIView {
    private let baseLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()
    private let sideLayer = CAGradientLayer()
    private var request = UUID()
    private(set) var palette = ArtworkPalette.neutral

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(baseLayer)
        layer.addSublayer(glowLayer)
        layer.addSublayer(sideLayer)
        baseLayer.startPoint = CGPoint(x: 0.25, y: 0)
        baseLayer.endPoint = CGPoint(x: 0.75, y: 1)
        for glow in [glowLayer, sideLayer] {
            glow.type = .radial
            glow.startPoint = CGPoint(x: 0.5, y: 0.5)
            glow.endPoint = CGPoint(x: 1, y: 1)
        }
        apply(.neutral, animated: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseLayer.frame = bounds
        glowLayer.frame = CGRect(x: -bounds.width * 0.4, y: -bounds.height * 0.3,
                                 width: bounds.width * 1.7, height: bounds.height * 1.2)
        sideLayer.frame = CGRect(x: bounds.width * 0.25, y: bounds.height * 0.18,
                                 width: bounds.width * 1.3, height: bounds.height * 0.9)
        CATransaction.commit()
    }

    func setArtwork(_ image: UIImage?, completion: ((ArtworkPalette) -> Void)? = nil) {
        let token = UUID()
        request = token
        ArtworkPaletteProvider.shared.palette(for: image) { [weak self] palette in
            guard let self, self.request == token else { return }
            self.apply(palette, animated: self.window != nil)
            completion?(palette)
        }
    }

    func apply(_ palette: ArtworkPalette, animated: Bool) {
        self.palette = palette
        let changes = {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.backgroundColor = palette.base
            self.baseLayer.colors = [palette.primary.cgColor, palette.base.cgColor]
            self.glowLayer.colors = [palette.primary.cgColor, palette.primary.withAlphaComponent(0).cgColor]
            self.sideLayer.colors = [palette.secondary.withAlphaComponent(0.65).cgColor,
                                     palette.secondary.withAlphaComponent(0).cgColor]
            CATransaction.commit()
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: self, duration: 0.45, options: [.transitionCrossDissolve, .beginFromCurrentState], animations: changes)
        } else { changes() }
    }
}
