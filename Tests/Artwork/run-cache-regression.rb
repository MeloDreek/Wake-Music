# Extract the production cache code; test without building or launching Wakemusic.
# Optional: --artwork /private/tmp/extracted-cover.png to test a real decoded cover.
require 'tmpdir'
require 'optparse'
require 'digest'

options = { simulator: true }
OptionParser.new do |parser|
  parser.on('--artwork PATH') { |path| options[:artwork] = File.expand_path(path) }
  parser.on('--audio PATH') { |path| options[:audio] = File.expand_path(path) }
  parser.on('--no-simulator') { options[:simulator] = false }
end.parse!

root = File.expand_path('../..', __dir__)
production = File.read(File.join(root, 'LocalSDK/AppGroupKit/Classes/CoreManager/Sandbox/SandboxFileManager+Music.swift'))
def block(source, signature)
  start = source.index(signature) or raise "Missing production declaration: #{signature}"
  opening = source.index('{', start)
  depth = 0
  source[opening..].each_char.with_index do |character, offset|
    depth += 1 if character == '{'
    depth -= 1 if character == '}'
    return source[start..opening + offset] if depth.zero?
  end
  raise "Unbalanced declaration: #{signature}"
end

cache = block(production, 'public enum MusicArtworkCache {')
model_methods = ['public func artworkCacheKey()', 'public func localArtworkCacheURL()', 'public func existingArtworkCacheURL()']
  .map { |signature| block(production, signature) }.join("\n")
writer = block(production, 'public func writeMusicthumbnailImage(')
notification = block(production, 'extension Notification.Name {')
build = Dir.mktmpdir('wake-artwork-cache-', '/private/tmp')
if options[:audio]
  # Read one embedded PICTURE block only. TagLib extraction is independently
  # exercised by the application's real-media probe; this reader supplies bytes.
  options[:audio_digest] = Digest::SHA256.file(options[:audio]).hexdigest
  File.open(options[:audio], 'rb') do |audio|
    abort 'Expected a native FLAC fixture' unless audio.read(4) == 'fLaC'
    loop do
      header = audio.read(4)
      abort 'No FLAC PICTURE block found' unless header && header.bytesize == 4
      last = header.getbyte(0) & 0x80 != 0
      kind = header.getbyte(0) & 0x7f
      length = (header.getbyte(1) << 16) | (header.getbyte(2) << 8) | header.getbyte(3)
      if kind == 6
        abort 'Unbounded FLAC artwork' if length > 16 * 1024 * 1024
        picture = audio.read(length)
        abort 'Truncated PICTURE block' unless picture && picture.bytesize == length
        mime_length = picture.byteslice(4, 4).unpack1('N')
        cursor = 8 + mime_length
        description_length = picture.byteslice(cursor, 4).unpack1('N')
        cursor += 4 + description_length + 16
        image_length = picture.byteslice(cursor, 4).unpack1('N')
        data = picture.byteslice(cursor + 4, image_length)
        abort 'Invalid embedded image size' unless data && data.bytesize == image_length
        options[:artwork] = File.join(build, 'actual-embedded-artwork.png')
        File.binwrite(options[:artwork], data)
        break
      end
      audio.seek(length, IO::SEEK_CUR)
      abort 'No FLAC PICTURE block found' if last
    end
  end
end

harness = <<~SWIFT
  import Foundation
  import CryptoKit
  #{cache}
  #{notification}
  public enum KakaError: Error { case custom(String) }
  public final class SandboxFileManager {
      public static let shared = SandboxFileManager()
      public var documents = URL(fileURLWithPath: "#{build}/Documents", isDirectory: true)
      public func basePublicFileURL() -> URL { documents }
      public func coverPathURL() -> URL { documents.appendingPathComponent(".Music_Cover", isDirectory: true) }
  }
  public struct MusicItemModel {
      public var mediaPlayURL: URL
      public var title = "你看到的我"
      public var artist = "黄勇/任浩铭"
      public var local = true
      public var directory = false
      public var remoteIdentity = "account-a:file-1"
      public var legacyName: String?
      public var smbFile: String?, megaFile: String?, yandexFile: String?, pan123File: String?
      public var guangyaFile: String?, boxFile: String?, pcloudFile: String?
      public func isLocalFile() -> Bool { local }
      public func isFolder() -> Bool { directory }
      // Account scoping in the real preDownloadIdentity has its own implementation;
      // here only the artwork key's use of the resulting identity is exercised.
      public func preDownloadIdentity() -> String { remoteIdentity }
      public func filePathName() -> String { legacyName ?? artist + " - " + title }
      #{model_methods}
  }
SWIFT

foundation_tests = <<~'SWIFT'
  @main enum CacheProbe {
      static var checks = 0
      static func check(_ value: @autoclosure () -> Bool, _ message: String) {
          precondition(value(), message)
          checks += 1
      }
      static func main() throws {
          let fm = FileManager.default
          let manager = SandboxFileManager.shared
          let documents = manager.documents
          try fm.createDirectory(at: manager.coverPathURL(), withIntermediateDirectories: true)
          let original = documents.appendingPathComponent("音乐/你看到的我-黄勇_任浩铭.flac")
          var model = MusicItemModel(mediaPlayURL: original)
          let key = model.artworkCacheKey()
          check(key.hasPrefix("artwork-v2-"), "versioned cache name")
          check(key.count == 75, "fixed-length digest")
          check(key.range(of: "^artwork-v2-[a-f0-9]{64}$", options: .regularExpression) != nil, "safe path component")
          check(!key.contains("黄勇") && !key.contains("/"), "metadata not used as filename")
          check(model.localArtworkCacheURL().deletingLastPathComponent() == manager.coverPathURL(), "cache cannot escape directory")
          check(model.localArtworkCacheURL().lastPathComponent == key + ".jpg", "reader and writer filename")
          try fm.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
          try Data([0x66, 0x4c, 0x61, 0x43]).write(to: original)
          check(model.artworkCacheKey() == key, "cache identity is stable before and after source file creation")
          for text in ["AC/DC", "../../其他/目录", "🎵مرحبا中文", "", String(repeating: "超长艺术家/", count: 2000)] {
              model.title = text
              model.artist = text
              check(model.artworkCacheKey() == key, "editable title/artist must not change artwork identity")
          }
          let oldDocuments = URL(fileURLWithPath: "/Containers/Data/Application/OLD-UUID/Documents", isDirectory: true)
          let newDocuments = URL(fileURLWithPath: "/Containers/Data/Application/NEW-UUID/Documents", isDirectory: true)
          let relative = "音乐/专辑/歌曲.flac"
          let oldIdentity = MusicArtworkCache.localIdentity(url: oldDocuments.appendingPathComponent(relative), documents: oldDocuments)
          let newIdentity = MusicArtworkCache.localIdentity(url: newDocuments.appendingPathComponent(relative), documents: newDocuments)
          check(oldIdentity == newIdentity, "sandbox relocation stable")
          check(MusicArtworkCache.key(identity: oldIdentity) == MusicArtworkCache.key(identity: newIdentity), "sandbox relocation keeps disk key")
          check(oldIdentity == "documents:" + relative, "full relative path preserved")
          let pathA = MusicItemModel(mediaPlayURL: documents.appendingPathComponent("A/同名.flac"))
          let pathB = MusicItemModel(mediaPlayURL: documents.appendingPathComponent("B/同名.flac"))
          check(pathA.artworkCacheKey() != pathB.artworkCacheKey(), "same basename in different folders cannot collide")
          let longModel = MusicItemModel(mediaPlayURL: documents.appendingPathComponent(String(repeating: "音乐", count: 1000) + ".flac"))
          check(longModel.artworkCacheKey().utf8.count == 75, "long source filename produces bounded cache name")
          let encoded = documents.appendingPathComponent("A%20B #1?.flac")
          let unencoded = documents.appendingPathComponent("A B #1?.flac")
          check(MusicArtworkCache.localIdentity(url: encoded, documents: documents) != MusicArtworkCache.localIdentity(url: unencoded, documents: documents), "literal percent text is not double decoded")
          let composed = documents.appendingPathComponent("café.flac")
          let decomposed = documents.appendingPathComponent("cafe\u{301}.flac")
          check(MusicArtworkCache.localIdentity(url: composed, documents: documents) == MusicArtworkCache.localIdentity(url: decomposed, documents: documents), "canonical Unicode filenames agree")
          let backup = URL(fileURLWithPath: documents.path + "Backup/歌曲.flac")
          check(MusicArtworkCache.localIdentity(url: backup, documents: documents).hasPrefix("file:"), "Documents sibling is not mistaken for child")
          let standardized = MusicArtworkCache.localIdentity(url: documents.appendingPathComponent("A/../B/file.flac"), documents: documents)
          check(standardized == "documents:B/file.flac", "standardized relative path: \(standardized)")
          var remote = MusicItemModel(mediaPlayURL: URL(string: "https://example.invalid/track?token=old")!)
          remote.local = false
          let remoteKey = remote.artworkCacheKey()
          remote.mediaPlayURL = URL(string: "https://example.invalid/track?token=new")!
          remote.title = "不同标题"
          check(remote.artworkCacheKey() == remoteKey, "remote temporary URL and tags do not change source identity")
          remote.remoteIdentity = "account-b:file-1"
          check(remote.artworkCacheKey() != remoteKey, "different upstream account identity remains distinct")
          check(remote.artworkCacheKey() != key, "remote and local namespaces differ")

          model = MusicItemModel(mediaPlayURL: original)
          check(model.existingArtworkCacheURL() == nil, "absent cache reported missing")
          let legacy = manager.coverPathURL().appendingPathComponent("safe-old-tags.jpg")
          model.legacyName = legacy.deletingPathExtension().lastPathComponent
          try Data([1, 2, 3]).write(to: legacy)
          check(model.existingArtworkCacheURL() == nil, "ambiguous local legacy names are not reused")
          remote.legacyName = model.legacyName
          check(remote.existingArtworkCacheURL() == nil, "ambiguous remote legacy names are not reused")
          remote.smbFile = "stable-source"
          check(remote.existingArtworkCacheURL() == legacy, "scoped provider legacy name remains readable")
          remote.legacyName = "nested/escape"
          check(remote.existingArtworkCacheURL() == nil, "unsafe legacy path rejected")
          remote.legacyName = String(repeating: "x", count: 240)
          check(remote.existingArtworkCacheURL() == nil, "overlong legacy path rejected")
          remote.legacyName = "bad\0name"
          check(remote.existingArtworkCacheURL() == nil, "NUL legacy path rejected")
          try Data([8, 9]).write(to: model.localArtworkCacheURL(), options: .atomic)
          check(model.existingArtworkCacheURL() == model.localArtworkCacheURL(), "new cache resolved")

          let revisionURL = manager.coverPathURL().appendingPathComponent("revision.jpg")
          try Data([1]).write(to: revisionURL, options: .atomic)
          let reusedRevisionURL = URL(fileURLWithPath: revisionURL.path)
          let reusedRevision1 = MusicArtworkCache.revision(at: reusedRevisionURL)
          let revision1 = MusicArtworkCache.revision(at: URL(fileURLWithPath: revisionURL.path))
          check(revision1 == MusicArtworkCache.revision(at: URL(fileURLWithPath: revisionURL.path)), "unchanged file revision is stable")
          try Data([1, 2]).write(to: revisionURL, options: .atomic)
          let revision2 = MusicArtworkCache.revision(at: URL(fileURLWithPath: revisionURL.path))
          check(revision1 != revision2, "replacing artwork changes revision")
          try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_000)], ofItemAtPath: revisionURL.path)
          let revision3 = MusicArtworkCache.revision(at: URL(fileURLWithPath: revisionURL.path))
          check(revision2 != revision3, "same-size update invalidated by timestamp")
          check(MusicArtworkCache.revision(at: reusedRevisionURL) != reusedRevision1, "reusing the same URL cannot return stale cached resource values")
          let absent = manager.coverPathURL().appendingPathComponent("absent.jpg")
          check(MusicArtworkCache.revision(at: absent) == "0.0-0", "missing revision is bounded and safe")
          print("PASS_ARTWORK_CACHE checks=\(checks) identity, migration, Unicode, revision")
      }
  }
SWIFT

writer_tests = <<~'SWIFT'
  final class NotificationRecorder: @unchecked Sendable {
      var count = 0
      var postedOnMain = false
      var key: String?
  }
  @MainActor @main enum WriterProbe {
      static var checks = 0
      static func check(_ value: @autoclosure () -> Bool, _ message: String) {
          precondition(value(), message)
          checks += 1
      }
      static func write(_ image: UIImage?, model: MusicItemModel) async -> Result<URL, KakaError> {
          await withCheckedContinuation { continuation in
              SandboxFileManager.shared.writeMusicthumbnailImage(model: model, image: image,
                  success: {
                      precondition(Thread.isMainThread, "writer success callback must execute on main thread")
                      continuation.resume(returning: .success($0))
                  },
                  fail: { continuation.resume(returning: .failure($0)) })
          }
      }
      static func main() async throws {
          let manager = SandboxFileManager.shared
          manager.documents = manager.documents.deletingLastPathComponent().appendingPathComponent("Writer-Documents", isDirectory: true)
          let source = manager.documents.appendingPathComponent("音乐/你看到的我-黄勇_任浩铭.flac")
          let notification = NotificationRecorder()
          let observer = NotificationCenter.default.addObserver(forName: .musicArtworkCacheDidChange, object: nil, queue: nil) {
              notification.count += 1
              notification.postedOnMain = Thread.isMainThread
              notification.key = $0.object as? String
          }
          defer { NotificationCenter.default.removeObserver(observer) }
          var model = MusicItemModel(mediaPlayURL: source)
          model.artist = "黄勇/任浩铭"
          model.title = "你看到的我"
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          let large = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600), format: format).image { _ in
              UIColor.red.setFill()
              UIRectFill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
          }
          let cacheURL = try await write(large, model: model).get()
          check(notification.count == 1 && notification.postedOnMain, "writer posts exactly one notification on main thread")
          check(notification.key == model.artworkCacheKey(), "notification carries source key")
          let decoded = UIImage(contentsOfFile: cacheURL.path)!
          check(decoded.cgImage?.width == 1200 && decoded.cgImage?.height == 800, "writer bounds full cache image to 1200 px")
          check(cacheURL == model.localArtworkCacheURL(), "writer matches reader cache location")
          check(cacheURL.deletingLastPathComponent() == manager.coverPathURL(), "slash in artist cannot create a subdirectory")
          let bytes = try Data(contentsOf: cacheURL)
          check(bytes.starts(with: [0xFF, 0xD8]), "writer stores JPEG")
          check(!FileManager.default.fileExists(atPath: source.path), "writer never creates or modifies source audio")
          model.artist = String(repeating: "超长/艺术家", count: 3000)
          model.title = String(repeating: "长标题/", count: 3000)
          let previous = MusicArtworkCache.revision(at: cacheURL)
          let small = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { _ in
              UIColor.blue.setFill()
              UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))
          }
          _ = try await write(small, model: model).get()
          check(cacheURL == model.localArtworkCacheURL(), "very long slash-containing metadata writes to the same safe key")
          check(MusicArtworkCache.revision(at: URL(fileURLWithPath: cacheURL.path)) != previous, "atomic overwrite changes revision")
          let smallDecoded = UIImage(contentsOfFile: cacheURL.path)!
          check(smallDecoded.cgImage?.width == 128, "small artwork is not upscaled")
          let oldData = try Data(contentsOf: cacheURL)
          if case .failure = await write(nil, model: model) { check(true, "nil image rejected") }
          else { preconditionFailure("nil image must fail") }
          check((try? Data(contentsOf: cacheURL)) == oldData, "invalid image cannot replace good cache")
          model.directory = true
          if case .failure = await write(small, model: model) { check(true, "folder rejected") }
          else { preconditionFailure("folder must fail") }
          check((try? Data(contentsOf: cacheURL)) == oldData, "folder cannot replace cache")
          if CommandLine.arguments.count > 1 {
              let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
              let fixtureData = try Data(contentsOf: fixtureURL)
              let before = SHA256.hash(data: fixtureData)
              guard let fixture = UIImage(data: fixtureData) else { preconditionFailure("fixture must decode") }
              model.directory = false
              model.mediaPlayURL = manager.documents.appendingPathComponent("真实样本/你看到的我-黄勇_任浩铭.flac")
              let saved = try await write(fixture, model: model).get()
              let result = UIImage(contentsOfFile: saved.path)!
              check((result.cgImage?.width ?? 0) <= 1200 && (result.cgImage?.height ?? 0) <= 1200, "real embedded PNG writes and decodes within bounds")
              check(result.cgImage?.width == fixture.cgImage?.width && result.cgImage?.height == fixture.cgImage?.height, "real 800 px cover retains dimensions")
              let after = SHA256.hash(data: try Data(contentsOf: fixtureURL))
              check(after == before, "real extracted fixture remains unchanged")
              print("REAL_ARTWORK_WRITTEN \(fixture.cgImage!.width)x\(fixture.cgImage!.height) -> \(saved.path)")
          }
          print("PASS_ARTWORK_WRITER checks=\(checks) actual UIKit renderer, disk JPEG, bounds, overwrite, invalid input")
      }
  }
SWIFT

ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
foundation_path = File.join(build, 'CacheProbe.swift')
File.write(foundation_path, harness + foundation_tests)
abort 'Foundation compile failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-parse-as-library',
  '-module-cache-path', File.join(build, 'modules'), foundation_path, '-o', File.join(build, 'cache-probe'))
abort 'Foundation cache regression failed' unless system(File.join(build, 'cache-probe'))

if options[:simulator]
  writer_path = File.join(build, 'WriterProbe.swift')
  File.write(writer_path, "import UIKit\n" + harness + "\nextension SandboxFileManager {\n#{writer}\n}\n" + writer_tests)
  sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
  executable = File.join(build, 'writer-probe')
  abort 'Simulator writer compile failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library',
    '-target', 'arm64-apple-ios16.0-simulator', '-sdk', sdk, '-module-cache-path', File.join(build, 'sim-modules'), writer_path, '-o', executable)
  arguments = ['xcrun', 'simctl', 'spawn', ENV.fetch('ARTWORK_SIMULATOR_UDID', 'booted'), executable]
  arguments << options[:artwork] if options[:artwork]
  abort 'Simulator writer regression failed' unless system(*arguments)
end
if options[:audio]
  abort 'Source audio changed unexpectedly' unless Digest::SHA256.file(options[:audio]).hexdigest == options[:audio_digest]
  puts 'PASS_SOURCE_AUDIO_UNCHANGED SHA256 verified before and after'
end
puts "Probe artifacts: #{build}"
