#!/usr/bin/env ruby
# Executes the actual MusicParseOperation and parserManager implementations
# against small filesystem/TagLib doubles. Does not read or modify user media.
# Usage: ruby Tests/Artwork/check-library-artwork-scan.rb
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
model_path = File.join(root, 'Mobie/Mobie/Business/MusicModule/Model')
operation = File.read(File.join(model_path, 'MusicParseOperation.swift')).gsub(/^import .+\n/, '')
scan = File.read(File.join(model_path, 'MusicViewModel+Music.swift'))
change = File.read(File.join(model_path, 'MusicViewModel+Change.swift'))
abort 'scan must not create unbounded per-file queues' if scan.include?('attributes: .concurrent')
abort 'queue must not wait for work submitted to itself' if scan.include?('dispatchGroup.wait()')
[scan, change, operation].each { |source| abort 'missing per-file autorelease pool' unless source.include?('autoreleasepool {') }

start = scan.index('    public var parserManager: OperationQueue {') or abort 'missing queue'
finish = scan.index('    private struct MusicKeys', start) or abort 'missing queue end'
queue = scan[start...finish]

stubs = <<~'SWIFT'
import Foundation
import ObjectiveC

enum FileHandleType { case copy, move, link }
enum ImportFileType { case localFile }
enum KakaError: Error { case custom(String) }
enum TaglibReaderType { case all, basicLyrics }
final class MetadataTagModel {
    var coverArt: Data?
    var title = "Track"
    var lyric = "lyric"
}
struct MusicItemModel {
    var mediaPlayURL: URL
    var handleType = FileHandleType.link
    init(fileURL: URL, sourceType: ImportFileType) { mediaPlayURL = fileURL }
    func localArtworkCacheURL() -> URL {
        SandboxFileManager.shared.cache.appendingPathComponent(mediaPlayURL.lastPathComponent + ".jpg")
    }
    func isFolder() -> Bool { mediaPlayURL.hasDirectoryPath }
}
extension URL {
    func isLRCFile() -> Bool { pathExtension.lowercased() == "lrc" }
    func createMusicModel(handleType: FileHandleType, sourceType: ImportFileType, targetURL: URL,
                          metadata: MetadataTagModel?) -> MusicItemModel {
        var model = MusicItemModel(fileURL: self, sourceType: sourceType)
        model.handleType = handleType
        return model
    }
}
enum TaglibMetadataParser {
    static var reads = [TaglibReaderType]()
    static var hasCover = true
    static func readMetadata(withFileURL url: URL, read: TaglibReaderType) -> MetadataTagModel? {
        reads.append(read)
        let metadata = MetadataTagModel()
        metadata.coverArt = read == .all && hasCover ? Data([1,2,3]) : nil
        return metadata
    }
}
final class SandboxFileManager {
    static let shared = SandboxFileManager()
    var root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    var cache: URL { root.appendingPathComponent("covers", isDirectory: true) }
    var writes = [URL]()
    var events = [String]()
    var failWrite = false
    func basePublicFileURL() -> URL { root }
    func saveLrcFileToDocument(lrcPath: URL, handleType: FileHandleType, completion: ((URL) -> Void)? = nil) {
        completion?(lrcPath)
    }
    func saveMusicToDocument(sourceURL: URL, targetFolderURL: URL, model: MusicItemModel,
                             completion: ((MusicItemModel) -> Void)? = nil) {
        var newModel = model
        newModel.mediaPlayURL = targetFolderURL.appendingPathComponent("imported-" + sourceURL.lastPathComponent)
        // Only test-owned tiny fixtures are ever copied/moved by this double.
        if model.handleType == .move { try! FileManager.default.moveItem(at: sourceURL, to: newModel.mediaPlayURL) }
        else { try! FileManager.default.copyItem(at: sourceURL, to: newModel.mediaPlayURL) }
        events.append("file")
        completion?(newModel)
    }
    func writeMusicthumbnailImage(model: MusicItemModel, image: Data?) {
        guard let image, !failWrite else { return }
        let url = model.localArtworkCacheURL()
        try! image.write(to: url)
        writes.append(url)
        events.append("artwork")
    }
}
class MusicViewModel: NSObject {
    private struct MusicKeys { static var kTaskKey: Void? }
SWIFT

tests = <<~'SWIFT'
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    precondition(condition(), label)
    checks += 1
}
let sandbox = SandboxFileManager.shared
let fm = FileManager.default
try! fm.createDirectory(at: sandbox.cache, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: sandbox.root) }
func fixture(_ name: String) -> URL {
    let url = sandbox.root.appendingPathComponent(name)
    try! Data([8,9,10]).write(to: url)
    try! fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: url.path)
    return url
}
func metadata(_ url: URL, reuse: Bool = true) -> MetadataTagModel? {
    MusicParseOperation.readMetadata(fileURL: url, sourceType: .localFile, reuseCachedArtwork: reuse)
}
let source = fixture("source.flac")
let sourceModel = MusicItemModel(fileURL: source, sourceType: .localFile)
check(!MusicParseOperation.hasCurrentCachedArtwork(model: sourceModel), "cache miss")
check(metadata(source)?.coverArt != nil && TaglibMetadataParser.reads.last == .all, "miss decodes artwork")
sandbox.writeMusicthumbnailImage(model: sourceModel, image: Data([1]))
check(MusicParseOperation.hasCurrentCachedArtwork(model: sourceModel), "new cache current")
let current = metadata(source)
check(TaglibMetadataParser.reads.last == .basicLyrics && current?.coverArt == nil, "hit skips artwork")
check(current?.lyric == "lyric", "hit keeps lyrics")
check(metadata(source, reuse: false)?.coverArt != nil && TaglibMetadataParser.reads.last == .all, "copy parses source cover")
try! fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 60)], ofItemAtPath: source.path)
check(!MusicParseOperation.hasCurrentCachedArtwork(model: sourceModel), "same model observes source modification")
check(metadata(source)?.coverArt != nil && TaglibMetadataParser.reads.last == .all, "updated source rereads artwork")
try! fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: source.path)
try! fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -120)], ofItemAtPath: sourceModel.localArtworkCacheURL().path)
check(!MusicParseOperation.hasCurrentCachedArtwork(model: sourceModel), "older cache invalid")
check(metadata(source)?.coverArt != nil && TaglibMetadataParser.reads.last == .all, "external edit rereads cover")
try! Data().write(to: sourceModel.localArtworkCacheURL())
check(!MusicParseOperation.hasCurrentCachedArtwork(model: sourceModel), "zero byte cache invalid")
let absent = MusicItemModel(fileURL: sandbox.root.appendingPathComponent("absent.flac"), sourceType: .localFile)
sandbox.writeMusicthumbnailImage(model: absent, image: Data([1]))
check(!MusicParseOperation.hasCurrentCachedArtwork(model: absent), "missing source not cache hit")
let directory = sandbox.root.appendingPathComponent("folder", isDirectory: true)
try! fm.createDirectory(at: directory, withIntermediateDirectories: true)
let readCount = TaglibMetadataParser.reads.count
check(metadata(directory) == nil && TaglibMetadataParser.reads.count == readCount, "folder never TagLib read")

for handle: FileHandleType in [.copy, .move, .link] {
    let file = fixture("\(handle).flac")
    sandbox.events = []
    var results = [MusicItemModel]()
    let task = MusicParseOperation(fileURL: file, sourceType: .localFile, targetFolderURL: sandbox.root,
                                   handleType: handle) { result in
        if case .success(let model) = result {
            check(fm.fileExists(atPath: model.localArtworkCacheURL().path), "cover exists before completion")
            sandbox.events.append("completion")
            results.append(model)
        } else { preconditionFailure("unexpected failure") }
    }
    task.start()
    check(results.count == 1, "exactly one completion")
    check(sandbox.events == (handle == .link ? ["artwork", "completion"] : ["file", "artwork", "completion"]), "write after final URL")
    check(sandbox.writes.last == results[0].localArtworkCacheURL(), "final cache identity")
    if handle != .link {
        check(results[0].mediaPlayURL != file, "destination model returned")
        check(!fm.fileExists(atPath: MusicItemModel(fileURL: file, sourceType: .localFile).localArtworkCacheURL().path), "no source-key orphan cache")
    }
}
TaglibMetadataParser.hasCover = false
let noCover = fixture("noCover.flac")
var noCoverImported = false
MusicParseOperation(fileURL: noCover, sourceType: .localFile, handleType: .link) { result in
    if case .success = result { noCoverImported = true }
}.start()
check(noCoverImported, "cover missing does not drop audio")
TaglibMetadataParser.hasCover = true
sandbox.failWrite = true
var failedCoverImported = false
MusicParseOperation(fileURL: fixture("failedWrite.flac"), sourceType: .localFile, handleType: .link) { result in
    if case .success = result { failedCoverImported = true }
}.start()
check(failedCoverImported, "cover write failure does not drop audio")
sandbox.failWrite = false
var cancelled = false
let cancelledTask = MusicParseOperation(fileURL: source, sourceType: .localFile, handleType: .link) { result in
    if case .failure = result { cancelled = true }
}
cancelledTask.cancel()
cancelledTask.main()
check(cancelled, "cancelled processing exits safely")

let viewModel = MusicViewModel()
let queue = viewModel.parserManager
check(queue === viewModel.parserManager, "scan reuses shared parser queue")
check(queue.maxConcurrentOperationCount == 2 && queue.qualityOfService == .utility, "bounded memory budget")
let lock = NSLock()
var active = 0, peak = 0, completed = 0
for _ in 0..<1000 {
    queue.addOperation {
        lock.lock(); active += 1; peak = max(peak, active); lock.unlock()
        Thread.sleep(forTimeInterval: 0.001)
        lock.lock(); active -= 1; completed += 1; lock.unlock()
    }
}
queue.waitUntilAllOperationsAreFinished()
check(peak <= 2 && completed == 1000, "1,000-file concurrency limit")
print("PASS_LIBRARY_ARTWORK_SCAN checks=\(checks) peakConcurrent=\(peak) files=\(completed)")
SWIFT

Dir.mktmpdir('wake-artwork-scan-', '/private/tmp') do |dir|
  source = File.join(dir, 'Scan.swift')
  File.write(source, stubs + queue + "}\n" + operation + tests)
  env = { 'DEVELOPER_DIR' => '/Applications/Xcode.app/Contents/Developer' }
  output, status = Open3.capture2e(env, 'xcrun', '--sdk', 'macosx', 'swiftc', '-swift-version', '5',
                                 '-module-cache-path', File.join(dir, 'modules'), source, '-o', File.join(dir, 'scan'))
  abort output unless status.success?
  output, status = Open3.capture2e(File.join(dir, 'scan'))
  puts output
  abort 'artwork scan regression failed' unless status.success?
end
