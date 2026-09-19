import Foundation
import UIKit
import Kingfisher

/// Uses the actual production loadArtwork/cache/revision methods extracted by the runner.
/// Only the music model and layout-scale helpers are stubbed. Image decoding, async
/// providers, UIImageView task identity, cache, and downsampling are real Kingfisher.
@main @MainActor enum ListArtworkRegression {
    static var checks = 0
    static func check(_ result: @autoclosure () -> Bool, _ message: String) {
        precondition(result(), message)
        checks += 1
    }

    static func makeImage(_ color: UIColor, width: CGFloat = 800, height: CGFloat = 800) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    static func rgb(_ image: UIImage?) -> [UInt8]? {
        guard let image = image?.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }

    static func isColor(_ image: UIImage?, channel: Int) -> Bool {
        guard let pixel = rgb(image) else { return false }
        return pixel[channel] > 220 && (0..<3).filter { $0 != channel }.allSatisfy { pixel[$0] < 35 }
    }

    static func eventually(_ message: String, condition: () -> Bool) async {
        let end = Date().addingTimeInterval(5)
        while !condition(), Date() < end { try? await Task.sleep(nanoseconds: 10_000_000) }
        check(condition(), message)
    }

    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("list-artwork-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // A unique temporary fixture directory. Never reads or writes the user's music.
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("artist-title.jpg")
        let second = folder.appendingPathComponent("other.jpg")
        // Deliberate PNG bytes in a .jpg path: ImageIO must use data, not extension.
        try makeImage(.red).pngData()!.write(to: first, options: .atomic)
        try makeImage(.green, width: 1600, height: 800).jpegData(compressionQuality: 0.85)!.write(to: second, options: .atomic)
        let modelA = MusicItemModel(url: first, key: "song-a")
        let modelB = MusicItemModel(url: second, key: "song-b")
        let cell = ProbeCell(style: .default, reuseIdentifier: nil)
        let cache = ProbeCell.artworkCache
        check(cache.memoryStorage.config.totalCostLimit == 24 * 1024 * 1024, "24 MB RAM cache budget")
        check(cache.memoryStorage.config.countLimit == 200, "200-entry RAM cache budget")
        cache.clearMemoryCache()
        let oldRevision = MusicArtworkCache.revision(at: first)
        cell.loadArtwork(modelA)
        await eventually("local PNG loads asynchronously") { isColor(cell.coverImgView.image, channel: 0) }
        let thumbnail = cell.coverImgView.image!.cgImage!
        check(thumbnail.width <= 132 && thumbnail.height <= 132, "44 pt x 3 scale downsampling")
        check(thumbnail.width > 0 && thumbnail.height > 0, "nonempty decoded pixels")
        check(thumbnail.bytesPerRow * thumbnail.height < 128 * 1024, "decoded thumbnail stays small")
        let processor = DownsamplingImageProcessor(size: CGSize(width: 44, height: 44)).identifier
        let oldKey = modelA.key + ":" + oldRevision
        check(cache.imageCachedType(forKey: oldKey, processorIdentifier: processor) == .memory, "processed image cached in RAM")
        cache.clearMemoryCache()
        check(cache.imageCachedType(forKey: oldKey, processorIdentifier: processor) == .none, "no second disk-cache copy")

        cell.loadArtwork(modelA)
        await eventually("prime old same-URL image back into RAM") { isColor(cell.coverImgView.image, channel: 0) }
        check(cache.imageCachedType(forKey: oldKey, processorIdentifier: processor) == .memory, "old revision remains cached during replacement")

        try makeImage(.blue).jpegData(compressionQuality: 0.85)!.write(to: first, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)], ofItemAtPath: first.path)
        check(MusicArtworkCache.revision(at: first) != oldRevision, "same URL gets a new revision after atomic replacement")
        cell.loadArtwork(modelA)
        await eventually("updated JPEG replaces old same-URL PNG") { isColor(cell.coverImgView.image, channel: 2) }

        // Exercise actual local-file provider cancellation and image-view task IDs.
        for iteration in 0..<20 {
            cache.clearMemoryCache()
            cell.loadArtwork(modelA)
            cell.loadArtwork(modelB)
            await eventually("reuse A -> B \(iteration)") { isColor(cell.coverImgView.image, channel: 1) }
            try? await Task.sleep(nanoseconds: 20_000_000)
            check(isColor(cell.coverImgView.image, channel: 1), "late A cannot overwrite B")
        }
        let rectangular = cell.coverImgView.image!.cgImage!
        check(rectangular.width <= 132 && rectangular.height <= 66, "non-square source preserves aspect ratio")

        cache.clearMemoryCache()
        cell.loadArtwork(modelA)
        let missing = MusicItemModel(url: folder.appendingPathComponent("missing.jpg"), key: "missing")
        cell.loadArtwork(missing)
        try? await Task.sleep(nanoseconds: 150_000_000)
        check(!isColor(cell.coverImgView.image, channel: 2), "missing-file placeholder is not overwritten by canceled provider")
        cache.clearMemoryCache()
        print("PASS_LIST_ARTWORK checks=\(checks) PNG/JPEG,132px,revision,reuse,placeholder,memory-only,24MB/200")
    }
}
