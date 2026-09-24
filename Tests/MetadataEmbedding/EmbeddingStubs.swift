import Foundation
import ObjectiveC

final class UIImage: @unchecked Sendable { let id: String; init(_ id: String = "download") { self.id = id } }
enum MusicTagType: Equatable { case artWork, title, artist, album, lyrics, year, genre, trackNumber, comment }
enum FillModeType { case fillEmptyOnly, forceOverwrite }
enum FileNameType { case `default`, title, artist_title, title_artist }
struct AutoEditConfig { var fillMode = FillModeType.fillEmptyOnly; var fileName = FileNameType.default; var isSetInstrumental = false }
struct LyricInfoModel { var isSelected = false; var text: String?; var lyrics: [String]? { text.map { [$0] } }; func toLyricString() -> String? { text } }
final class LyricLine { var realLyric: String?; init(_ text: String) { realLyric = text } }
final class LyricLineModel { var lyrics: [LyricLine]?; init(_ text: String) { lyrics = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [LyricLine(text)] }; func convertSwiftModel() -> LyricInfoModel { LyricInfoModel(text: lyrics?.first?.realLyric) } }
struct MusicItemModel: @unchecked Sendable {
    var mediaPlayURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["EMBEDDING_TEST_DIR"]! + "/fake.mp3")
    var title: String?; var artist: String?; var album: String?; var genre: String?; var comment: String?
    var year: Int?; var track: Int?; var coverArt: UIImage?; var lyricModel: LyricInfoModel?
    func isFullMusicTag() -> Bool { title != nil && artist != nil && coverArt != nil && lyricModel != nil }
}
struct AudioFingerprintModel {
    var title: String?; var artist: String?; var album: String?; var genres: String?; var coverArt: String?
    var year: Int?; var trackNumber: Int?; var lyrics: [LyricInfoModel]?; var metadataSource: String?
    var isCatalogFallback: Bool { metadataSource?.hasPrefix("appleCatalog") == true }
}
final class MetadataTagModel {
    var title: String?; var artist: String?; var album: String?; var genre: String?; var comment: String?
    var year: UInt = 0; var track: UInt = 0; var coverArt: UIImage?; var coverArtData: Data?; var lyricModel: LyricLineModel?
    func mergeTagLibInfo(_ m: MusicItemModel) -> MusicItemModel { var n=m; n.title=title; n.artist=artist; n.album=album; n.genre=genre; n.comment=comment; n.year=Int(year); n.track=Int(track); n.lyricModel=lyricModel?.convertSwiftModel(); return n }
    func clone() -> MetadataTagModel { let n=MetadataTagModel(); n.title=title;n.artist=artist;n.album=album;n.genre=genre;n.comment=comment;n.year=year;n.track=track;n.coverArt=coverArt;n.coverArtData=coverArtData;n.lyricModel=lyricModel;return n }
}
enum TaglibReaderType { case all }
enum TaglibMetadataParser {
    static var disk: MetadataTagModel? = MetadataTagModel()
    static var writes: [MusicTagType] = []
    static var fail: MusicTagType?
    static var afterWrite: (() -> Void)?
    static func readMetadata(withFileURL: URL, read: TaglibReaderType) -> MetadataTagModel? { disk?.clone() }
    static func parseSynchronizedLyrics(_ text: String) -> LyricLineModel? { LyricLineModel(text) }
    static func write(_ kind: MusicTagType, _ change: () -> Void) -> Bool { if fail == kind { return false }; writes.append(kind); change(); afterWrite?(); return true }
    static func setTitle(_ v: String, toFileURL: URL) -> Bool { write(.title) { disk?.title=v } }
    static func setArtist(_ v: String, toFileURL: URL) -> Bool { write(.artist) { disk?.artist=v } }
    static func setAlbum(_ v: String, toFileURL: URL) -> Bool { write(.album) { disk?.album=v } }
    static func setGenre(_ v: String, toFileURL: URL) -> Bool { write(.genre) { disk?.genre=v } }
    static func setYear(_ v: Int32, toFileURL: URL) -> Bool { write(.year) { disk?.year=UInt(v) } }
    static func setTrack(_ v: Int32, toFileURL: URL) -> Bool { write(.trackNumber) { disk?.track=UInt(v) } }
    static func setLyrics(_ v: String, toFileURL: URL) -> Bool { write(.lyrics) { disk?.lyricModel=LyricLineModel(v) } }
    static func setCoverArt(_ v: UIImage, toFileURL: URL) -> Bool { write(.artWork) { disk?.coverArt=v;disk?.coverArtData=Data(v.id.utf8) } }
}
extension String { func localStr() -> String { self }; var standardFileName: String { replacingOccurrences(of: "/", with: "_") } }
enum KakaError: Error { case custom(String); var errorDescription: String { "failure" } }
class MusicTagEditor { static let shared=MusicTagEditor() }
final class AppLocalManager: @unchecked Sendable { static let shared=AppLocalManager(); var moves=0; func updateMediaURL(oldURL: URL,newURL: URL) { moves += 1 } }
final class SandboxFileManager { static let shared=SandboxFileManager(); var covers: [String] = []; func writeMusicthumbnailImage(model: MusicItemModel,image: UIImage) { covers.append(image.id) } }
enum MusicParseOperation { static func hasCurrentCachedArtwork(model: MusicItemModel) -> Bool { false } }
final class ImageCache { static let `default`=ImageCache(); struct Result { var image: UIImage?; var cacheType="none" }; func retrieveImage(forKey:String) async throws -> Result { Result() }; func store(_ image:UIImage,forKey:String) async throws {} }
final class ImageDownloader { static let `default`=ImageDownloader(); static var hook: (() -> Void)?; static var delay: UInt64=0; struct Result { var image=UIImage() }; func downloadImage(with:URL, options:Int?) async throws -> Result { if Self.delay>0 { try await Task.sleep(nanoseconds:Self.delay) }; Self.hook?(); return Result() } }
final class MetadataMatchRequest { func cancel() {} }
final class AudioFingerprintMatcher { static var result: Result<AudioFingerprintModel,KakaError>?; static var callback: ((Result<AudioFingerprintModel,KakaError>) -> Void)?; func matchLocalAudioMetadata(model:MusicItemModel,isRequestLyrics:Bool,completion:@escaping(Result<AudioFingerprintModel,KakaError>)->Void)->MetadataMatchRequest { Self.callback=completion; if let result=Self.result { completion(result) }; return MetadataMatchRequest() }; func cancelLocalMatching() {} }

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}
