import Foundation
import SmartCodable

// Every HTTP request is intercepted; no real account or file is accessed.
private final class YandexStub: URLProtocol {
    struct Reply {
        var status = 200
        var body = "{}"
        var delay: TimeInterval = 0
    }
    static var handler: ((URLRequest) -> Reply)!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        DispatchQueue.main.async {
            let reply = Self.handler(self.request)
            DispatchQueue.main.asyncAfter(deadline: .now() + reply.delay) {
                let response = HTTPURLResponse(url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: nil)!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {}
}

@main @MainActor
enum YandexRegression {
    static var checks = 0
    static func check(_ condition: Bool, _ description: String) {
        precondition(condition, description)
        checks += 1
    }
    final class Store {
        var tokens = ["1": "fake-token"]
        var failSave = false
    }
    static func client(_ store: Store) -> YandexDriveAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [YandexStub.self]
        return YandexDriveAPI(configuration: config, load: { store.tokens[$0] }, save: { id, token in
            guard !store.failSave else { return false }
            store.tokens[id] = token
            return true
        }, remove: { store.tokens.removeValue(forKey: $0) })
    }
    static func list(_ api: YandexDriveAPI, path: String = "disk:/") async -> Result<[YandexAPIItem], YandexDriveError> {
        await withCheckedContinuation { c in api.listFolder(accountID: "1", folderID: path) { c.resume(returning: $0) } }
    }
    static func source(_ api: YandexDriveAPI) async -> Result<YandexDownloadSource, YandexDriveError> {
        await withCheckedContinuation { c in api.fileSource(accountID: "1", path: "disk:/音乐/Песня #1 + 50%.FLAC") { c.resume(returning: $0) } }
    }
    static func failure<T>(_ result: Result<T, YandexDriveError>) -> YandexDriveError? {
        if case .failure(let error) = result { return error }; return nil
    }
    static func page(_ offset: Int, total: Int, ids: [Int]) -> String {
        let items = ids.map { ["resource_id": "id-\($0)", "path": "disk:/音乐/\($0).flac", "name": "\($0).flac", "type": "file", "size": 123] as [String: Any] }
        let data = try! JSONSerialization.data(withJSONObject: ["type": "dir", "_embedded": ["offset": offset, "limit": 200, "total": total, "items": items]])
        return String(decoding: data, as: UTF8.self)
    }
    static func main() async throws {
        let store = Store(), api = client(store)
        var file = YandexDriveFileModel()
        file.id = "stable-resource"
        file.path = "disk:/音乐/Песня #1 + 50%.FLAC"
        file.name = "Песня #1 + 50%.FLAC"
        file.yandexUser = YandexDriveUserModel(userID: "1", login: "tester", name: "Tester")
        check(file.isMusic() && !file.isVideo() && !file.isDirectory(), "Classify uppercase audio extension")
        check(file.mediaPlayURL().scheme == "yandex", "Persist a synthetic URL, not credentials")
        check(file.identity.count == 71 && !file.identity.contains("/"), "Filesystem-safe bounded cache identity")
        var other = file
        other.path = "disk:/renamed.flac"; other.name = "renamed.flac"
        check(other.identity == file.identity, "Rename does not invalidate resource-ID artwork")
        other.yandexUser?.userID = "2"
        check(other.identity != file.identity, "Same resource in different accounts never collides")
        other = file; other.isFolder = true
        check(other.identity != file.identity && !other.isMusic(), "Folder identity and classification")
        other = file; other.id = ""; other.path = "disk:/" + String(repeating: "目录", count: 200)
        check(other.identity.count == 71, "Long paths remain valid artwork filenames")
        let encoded = file.toJSONString() ?? ""
        check(!encoded.contains("fake-token") && !encoded.contains("Authorization"), "Library model has no credentials")
        check(YandexDriveFileModel.deserialize(from: encoded)?.identity == file.identity, "Model round-trip")

        var offsets = [Int]()
        YandexStub.handler = { request in
            check(request.httpMethod == "GET", "Disk API stays read-only")
            check(request.value(forHTTPHeaderField: "Authorization") == "OAuth fake-token", "Disk OAuth header")
            check(request.url?.host == "cloud-api.yandex.net", "Authenticated API host")
            let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            check(query["path"] == file.path, "Unicode, plus, percent and hash path survive encoding")
            let offset = Int(query["offset"]!)!
            offsets.append(offset)
            return .init(body: offset == 0 ? page(0, total: 3, ids: [1, 2]) : page(2, total: 3, ids: [3]))
        }
        let files = try await list(api, path: file.path).get()
        check(files.count == 3 && offsets == [0, 2], "Fetch all pages using returned item count")
        YandexStub.handler = { _ in .init(body: page(0, total: 0, ids: [])) }
        let empty = try await list(api).get()
        check(empty.isEmpty, "Empty root is success, not auth failure")
        check(YandexFileListEmptyState.empty(folderID: "disk:/", query: "") == .folder, "Empty folder guidance")
        check(YandexFileListEmptyState.empty(folderID: "disk:/", query: "song") == .search, "Search guidance")

        var call = 0
        YandexStub.handler = { _ in
            call += 1
            return .init(body: page(call == 1 ? 0 : 1, total: 5, ids: [1]))
        }
        let repeated = await list(api)
        check(failure(repeated) == .invalidResponse && call == 2, "Repeated pages terminate instead of looping")
        YandexStub.handler = { _ in .init(body: page(9, total: 10, ids: [1])) }
        check(failure(await list(api)) == .invalidResponse, "Reject wrong offsets")
        YandexStub.handler = { _ in .init(body: "{\"type\":\"dir\"}") }
        check(failure(await list(api)) == .invalidResponse, "Missing embedded data is not an empty folder")
        for (status, error) in [(401, YandexDriveError.authorization), (403, .permission), (404, .notFound), (429, .rateLimited), (503, .network)] {
            YandexStub.handler = { _ in .init(status: status) }
            check(failure(await list(api)) == error, "Distinct HTTP error \(status)")
        }

        call = 0
        YandexStub.handler = { request in
            call += 1
            check(request.url?.path == "/v1/disk/resources/download", "Resolve via download endpoint")
            return .init(body: "{\"href\":\"https://downloader.disk.yandex.ru/disk/signature-\(call)\",\"method\":\"GET\",\"templated\":false}")
        }
        let first = try await source(api).get(), second = try await source(api).get()
        check(first.url != second.url && call == 2, "Every playback/download obtains a fresh URL")
        check(first.headers["Authorization"] == "OAuth fake-token", "Download authorization stays in transient headers")
        check(first.url.query == nil && !first.url.absoluteString.contains("fake-token"), "Token is never appended to URL")
        for unsafe in ["http://downloader.disk.yandex.ru/a", "https://yandex.ru.evil.invalid/a", "https://evil.invalid/a", "https://user:password@yandex.ru/a", "https://yandex.ru:8443/a"] {
            check(!YandexDriveAPI.validDownloadURL(URL(string: unsafe)!), "Reject unsafe download destination")
        }
        YandexStub.handler = { _ in .init(body: #"{"href":"https://evil.invalid/a","method":"GET","templated":false}"#) }
        check(failure(await source(api)) == .invalidResponse, "No OAuth credentials sent to unexpected host")
        YandexStub.handler = { _ in .init(body: #"{"href":"https://downloader.disk.yandex.ru/a","method":"POST","templated":false}"#) }
        check(failure(await source(api)) == .invalidResponse, "Reject a non-read download operation")

        YandexStub.handler = { _ in .init(body: #"{"user":{"uid":"1","login":"tester","display_name":"Tester"}}"#) }
        let user: YandexAPIUser = try await withCheckedThrowingContinuation { c in api.user(token: "fake-token") { c.resume(with: $0) } }
        check(user.uid == "1" && user.login == "tester", "Account comes from disk information, not a guessed email")
        store.failSave = true
        check(!api.install("replacement", accountID: "1"), "Keychain failure is surfaced")
        store.failSave = false
        check(api.install("replacement", accountID: "1"), "Successful reauthorization installs token")
        YandexStub.handler = { _ in .init(body: page(0, total: 0, ids: []), delay: 0.05) }
        let pending: Result<[YandexAPIItem], YandexDriveError> = await withCheckedContinuation { c in
            api.listFolder(accountID: "1", folderID: "disk:/") { c.resume(returning: $0) }
            api.unlink("1")
        }
        check(failure(pending) == .authorization, "Unlink invalidates in-flight response")
        check(store.tokens["1"] == nil, "Unlink removes token")
        check(failure(await list(api)) == .authorization, "Unlinked account cannot start new requests")
        check(!YandexDriveAPI.validPath("https://evil.invalid"), "API only accepts disk paths")
        print("Yandex regressions passed: \(checks) assertions")
    }
}
