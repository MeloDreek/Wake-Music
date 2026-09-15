import UIKit

@main final class PaletteRegression: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var checks = 0
    var failures = [String]()
    func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !value() { failures.append(message) }
    }
    func image(_ colors: [UIColor]) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(x: CGFloat(index) * 64 / CGFloat(colors.count), y: 0,
                                    width: 64 / CGFloat(colors.count), height: 64))
            }
        }
    }
    func palette(_ image: UIImage?) async -> ArtworkPalette {
        await withCheckedContinuation { done in
            ArtworkPaletteProvider.shared.palette(for: image) { palette in
                self.check(Thread.isMainThread, "Palette callback stays on main thread")
                done.resume(returning: palette)
            }
        }
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UIViewController()
        window?.makeKeyAndVisible()
        Task { @MainActor in
            let fixtures: [UIImage?] = [nil, image([.black]), image([.white]), image([.gray]),
                image([UIColor(red: 1, green: 0.93, blue: 0.96, alpha: 1)]),
                image([.yellow]), image([.red]), image([.green]),
                image([.black, .black, .green, .green, .white]), image([.red, .green, .blue, .yellow])]
            for fixture in fixtures {
                let palette = await palette(fixture)
                for color in [palette.primary, palette.secondary, palette.base] {
                    check(ArtworkPalette.luminance(color) <= 0.18001, "White foreground contrast >= 4.5:1")
                    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                    check(s <= 0.721 && a == 1, "Saturation limited; opaque backdrop")
                }
            }
            let gray = await palette(image([.white]))
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            gray.primary.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            check(s < 0.02, "Monochrome cover does not invent a magenta theme")
            let green = await palette(image([.black, .black, .green, .green, .white]))
            green.primary.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            check(h > 0.25 && h < 0.42 && s > 0.2, "Colored artwork wins over black border and white text")
            let cached = await palette(image([.black, .black, .green, .green, .white]))
            check(cached.primary == green.primary, "Repeated content yields stable cached palette")

            let background = ArtworkBackgroundView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window?.rootViewController?.view.addSubview(background)
            var callbacks = 0
            background.setArtwork(image([.red])) { _ in callbacks += 1 }
            await withCheckedContinuation { done in
                background.setArtwork(image([.green])) { _ in callbacks += 1; done.resume() }
            }
            check(callbacks == 1, "Late previous-track palette is discarded")
            background.palette.primary.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            check(h > 0.25 && h < 0.42, "Rapid switch leaves latest artwork color")
            await withCheckedContinuation { done in background.setArtwork(nil) { _ in done.resume() } }
            check(background.palette.primary == ArtworkPalette.neutral.primary, "Removing artwork clears old theme")
            background.frame.size = CGSize(width: 800, height: 400)
            background.layoutIfNeeded()
            check(background.layer.sublayers?.first?.frame == background.bounds, "Backdrop adapts to rotation")
            let report = "\(checks) palette checks; \(failures.count) failures\n" + failures.joined(separator: "\n")
            print(report)
            try? report.write(to: URL.documentsDirectory.appendingPathComponent("palette-results.txt"), atomically: true, encoding: .utf8)
            exit(failures.isEmpty ? 0 : 1)
        }
        return true
    }
}
