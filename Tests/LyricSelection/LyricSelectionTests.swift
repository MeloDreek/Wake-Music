import Foundation

// UIKit and matching doubles keep the controller's row and refresh logic runnable
// without linking the application, ShazamKit, or making network requests.
extension IndexPath {
    init(row: Int, section: Int) { self.init(indexes: [section, row]) }
    var row: Int { self[1] }
    var section: Int { self[0] }
}
extension String {
    func localStr() -> String { self }
}
struct LyricInfoModel: Equatable {
    let id: Int
}
struct AudioFingerprintModel {
    var lyrics: [LyricInfoModel]?
}
struct MusicItemModel {
    let mediaPlayURL = URL(fileURLWithPath: "/fixture.mp3")
}
enum MatchError: Error {
    case failed
    var errorDescription: String { "Matching failed" }
}
final class MetadataMatchRequest {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}
class AudioFingerprintMatcher {
    typealias Completion = (Result<AudioFingerprintModel, MatchError>) -> Void
    var completions: [Completion] = []
    var immediateResult: Result<AudioFingerprintModel, MatchError>?
    private(set) var requests: [MetadataMatchRequest] = []
    private(set) var cancellationCount = 0
    func cancelLocalMatching() { cancellationCount += 1 }
    func matchLocalAudioMetadata(model: MusicItemModel, isRequestLyrics: Bool = true,
                                completion: @escaping Completion) -> MetadataMatchRequest {
        let request = MetadataMatchRequest()
        requests.append(request)
        if let immediateResult = immediateResult {
            completion(immediateResult)
        } else {
            // Intentionally retain the raw callback even after cancellation.
            // This exercises the controller's generation guard independently
            // of the production matcher's own stale-result suppression.
            completions.append(completion)
        }
        return request
    }
}
enum TaglibMetadataParser {
    enum Read { case all }
    struct EmbeddedLyric {
        var lyrics: [String]? = nil
        func convertSwiftModel() -> LyricInfoModel { LyricInfoModel(id: 0) }
    }
    struct Metadata { var lyricModel: EmbeddedLyric? = nil }
    static func readMetadata(withFileURL: URL, read: Read) -> Metadata { Metadata() }
}
class View {
    var isHidden = false
}
class LoadingView: View {
    var isAnimating = false
    func startAnimating() { isAnimating = true }
    func stopAnimating() { isAnimating = false }
}
class UITableViewCell {
    enum AccessoryType { case none, disclosureIndicator }
    var accessoryType: AccessoryType = .none
    var accessoryView: View?
    var isSelected = false
}
class LRCLyricTableViewCell: UITableViewCell {
    var lyric: LyricInfoModel?
    let selectIconView = View()
    let nonSelectIconView = View()
    func updateLyric(lyricModel: LyricInfoModel, isSelect: Bool) {
        lyric = lyricModel
        isSelected = isSelect
    }
}
class EmptyDataTableCell: UITableViewCell {
    func updateMessage(_ message: String = "") {}
}
class UITableView: View {
    var reloadCount = 0
    var deselected: IndexPath?
    func reloadData() { reloadCount += 1 }
    func deselectRow(at indexPath: IndexPath, animated: Bool) { deselected = indexPath }
    func dequeueReusableCell(withIdentifier identifier: String, for indexPath: IndexPath) -> UITableViewCell {
        identifier == "LRCLyricTableViewCell" ? LRCLyricTableViewCell() : EmptyDataTableCell()
    }
}
class LyricSelectionTestDependencies {
    var music = MusicItemModel()
    var result: AudioFingerprintModel?
    var selectLyricModel: LyricInfoModel?
    var embeddedLyric: LyricInfoModel?
    var lyricArray: [LyricInfoModel] = []
    let musicMatcher = AudioFingerprintMatcher()
    let tableView = UITableView()
    let loadingView = LoadingView()
    let loadingLabel = View()
    let embeddedButton = View()
    var errors: [String] = []
    func showOneAlert(message: String) { errors.append(message) }
}

@main
struct LyricSelectionTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        let first = IndexPath(row: 0, section: 1)
        let second = IndexPath(row: 1, section: 1)
        let a = LyricInfoModel(id: 1)
        let b = LyricInfoModel(id: 2)
        let controller = SelectLyricViewController()
        let table = controller.tableView

        check(controller.tableView(table, numberOfRowsInSection: 1) == 1, "Empty results retain a placeholder")
        check(controller.tableView(table, cellForRowAt: first) is EmptyDataTableCell, "Empty row renders safely")
        check(controller.tableView(table, willSelectRowAt: first) == nil, "Empty placeholder cannot be selected")
        controller.tableView(table, didSelectRowAt: first)
        check(controller.selectLyricModel == nil && table.reloadCount == 0, "Direct empty-row callback is harmless")

        controller.result = AudioFingerprintModel(lyrics: [a, b])
        controller.refreshDataAction()
        check(controller.musicMatcher.cancellationCount == 1, "Cached refresh cancels prior acoustic work too")
        check(controller.tableView(table, numberOfRowsInSection: 1) == 2, "Cached lyrics supply their row count")
        check(controller.tableView(table, willSelectRowAt: second) == second, "Valid candidate is selectable")
        controller.tableView(table, didSelectRowAt: second)
        check(controller.selectLyricModel == b, "Valid selection chooses the expected lyric")
        let selectedCell = controller.tableView(table, cellForRowAt: second) as? LRCLyricTableViewCell
        check(selectedCell?.lyric == b && selectedCell?.isSelected == true, "Chosen lyric renders selected")
        for path in [IndexPath(row: 0, section: 0), IndexPath(row: 0, section: 2), IndexPath(row: -1, section: 1)] {
            check(controller.tableView(table, willSelectRowAt: path) == nil, "Reject non-candidate section or index")
            controller.tableView(table, didSelectRowAt: path)
            check(controller.selectLyricModel == b, "Invalid callbacks preserve the current selection")
        }

        // A tap can already be queued when a refresh removes or shrinks the rows.
        controller.result = nil
        controller.refreshDataAction()
        check(controller.selectLyricModel == nil && controller.lyricArray.isEmpty, "Starting refresh invalidates old rows and selection")
        check(controller.loadingView.isAnimating && table.isHidden, "Matching enters loading state")
        controller.tableView(table, didSelectRowAt: second)
        check(controller.selectLyricModel == nil, "Queued old tap while loading is ignored")
        controller.musicMatcher.completions[0](.success(AudioFingerprintModel(lyrics: [a])))
        check(!controller.loadingView.isAnimating && !table.isHidden, "Completion restores the list")
        check(controller.tableView(table, cellForRowAt: second) is EmptyDataTableCell, "Stale cell request after shrink is safe")
        controller.tableView(table, didSelectRowAt: second)
        check(controller.selectLyricModel == nil, "Queued out-of-range tap after shrink is ignored")
        controller.tableView(table, didSelectRowAt: first)
        check(controller.selectLyricModel == a, "Current rows remain selectable after refresh")

        controller.refreshDataAction()
        check(controller.musicMatcher.requests[0].isCancelled, "Refreshing cancels the retained metadata request")
        controller.musicMatcher.completions[1](.success(AudioFingerprintModel(lyrics: nil)))
        controller.tableView(table, didSelectRowAt: first)
        check(controller.lyricArray.isEmpty && controller.selectLyricModel == nil, "Successful match with nil lyrics is safe")
        controller.refreshDataAction()
        controller.musicMatcher.completions[2](.success(AudioFingerprintModel(lyrics: [])))
        controller.tableView(table, didSelectRowAt: first)
        check(controller.lyricArray.isEmpty && controller.selectLyricModel == nil, "Successful match with empty lyrics is safe")
        controller.refreshDataAction()
        controller.musicMatcher.completions[3](.failure(.failed))
        controller.tableView(table, didSelectRowAt: first)
        check(controller.selectLyricModel == nil && controller.errors.count == 1, "Failed match presents the error and safe placeholder")

        // A slower previous request must not overwrite a newer result or selection.
        controller.refreshDataAction()
        controller.refreshDataAction()
        check(controller.musicMatcher.requests[4].isCancelled && !controller.musicMatcher.requests[5].isCancelled,
              "New request cancels only the previous metadata request")
        controller.musicMatcher.completions[5](.success(AudioFingerprintModel(lyrics: [b])))
        controller.tableView(table, didSelectRowAt: first)
        controller.musicMatcher.completions[4](.success(AudioFingerprintModel(lyrics: [])))
        check(controller.lyricArray == [b] && controller.selectLyricModel == b, "Out-of-order previous response is ignored")
        controller.refreshDataAction()
        controller.result = AudioFingerprintModel(lyrics: [a])
        controller.refreshDataAction()
        check(controller.musicMatcher.requests[6].isCancelled, "Switching to cached lyrics cancels pending network metadata work")
        controller.musicMatcher.completions[6](.failure(.failed))
        check(controller.lyricArray == [a] && controller.errors.count == 1, "Cached refresh also invalidates previous failure")

        controller.result = nil
        controller.musicMatcher.immediateResult = .failure(.failed)
        controller.refreshDataAction()
        check(!table.isHidden && !controller.loadingView.isAnimating && controller.lyricArray.isEmpty, "Synchronous matcher failure completes loading")

        var released: SelectLyricViewController? = SelectLyricViewController()
        let matcher = released!.musicMatcher
        weak var weakController = released
        released?.refreshDataAction()
        released = nil
        check(weakController == nil, "Pending match does not retain the dismissed controller")
        check(matcher.requests[0].isCancelled, "Controller deinit cancels its metadata request")
        matcher.completions[0](.success(AudioFingerprintModel(lyrics: [a])))
        print("Lyric selection regression tests: \(checks) passed")
    }
}
