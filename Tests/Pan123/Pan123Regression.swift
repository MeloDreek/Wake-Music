import Foundation
import SmartCodable

private final class Pan123Stub: URLProtocol {
    struct Reply { var status = 200; var body = "{}"; var delay: TimeInterval = 0 }
    static var handler: ((URLRequest) -> Reply)!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        DispatchQueue.main.async {
            let reply = Self.handler(self.request)
            DispatchQueue.main.asyncAfter(deadline: .now() + reply.delay) {
                self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: nil)!, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {}
}

@main @MainActor enum Pan123Regression {
    static var checks = 0
    static func check(_ value: Bool, _ message: String) { precondition(value, message); checks += 1 }
    static let fresh = Pan123OAuthToken(accessToken: "fake-access", refreshToken: "fake-refresh", expiresAt: Date(timeIntervalSince1970: 5000))
    static let expired = Pan123OAuthToken(accessToken: "expired", refreshToken: "fake-refresh", expiresAt: Date(timeIntervalSince1970: 900))
    static let rotated = #"{"token_type":"Bearer","access_token":"rotated","refresh_token":"new-refresh","expires_in":7200}"#
    static let empty = #"{"code":0,"data":{"lastFileId":-1,"fileList":[]}}"#
    @MainActor final class Store { var tokens = ["123": fresh]; var saves = 0; var failSave = false }
    static func client(_ store: Store) -> Pan123DriveAPI {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [Pan123Stub.self]
        return Pan123DriveAPI(clientID: "test-client", secret: "test-secret", redirectURI: "wakemusic-123pan://oauth/callback",
                             configuration: config, now: { Date(timeIntervalSince1970: 1000) }, throttle: false,
                             load: { store.tokens[$0] }, save: { id, token in
            store.saves += 1
            if store.failSave { return false }; store.tokens[id] = token; return true
        }, remove: { store.tokens.removeValue(forKey: $0) })
    }
    static func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []).map { ($0.name,$0.value ?? "") })
    }
    static func list(_ api: Pan123DriveAPI) async -> Result<[Pan123APIItem], Pan123DriveError> {
        await withCheckedContinuation { c in api.listFolder(accountID: "123", folderID: "0") { c.resume(returning: $0) } }
    }
    static func link(_ api: Pan123DriveAPI) async -> Result<URL, Pan123DriveError> {
        await withCheckedContinuation { c in api.fileURL(accountID: "123", fileID: "9223372036854775806") { c.resume(returning: $0) } }
    }
    static func error<T>(_ result: Result<T, Pan123DriveError>) -> Pan123DriveError? {
        if case .failure(let error) = result { return error }; return nil
    }
    static func main() async throws {
        let store = Store(), api = client(store)
        let auth = api.authorizationURL(state: "random-state")!
        check(auth.host == "yun.123pan.com", "Official auth host")
        let authQuery = query(URLRequest(url: auth))
        check(authQuery["redirect_uri"] == api.redirectURI && authQuery["client_id"] == "test-client", "OAuth configuration")
        check(authQuery["client_secret"] == nil, "Secret absent from browser URL")
        check(api.authorizationCode(from: URL(string: api.redirectURI+"?state=random-state&code=ok")!, state: "random-state") == "ok", "Valid callback")
        for url in [api.redirectURI+"?state=bad&code=ok", api.redirectURI+"?state=random-state&state=random-state&code=ok",
                    api.redirectURI+"?state=random-state&code=a&code=b", "wakemusicpro-123pan://oauth/callback?state=random-state&code=ok",
                    "wakemusic-123pan://other/callback?state=random-state&code=ok", api.redirectURI+"?state=random-state&code=ok#fragment"] {
            check(api.authorizationCode(from: URL(string: url)!, state: "random-state") == nil, "Reject invalid callback")
        }
        Pan123Stub.handler = { request in
            check(request.httpMethod == "POST" && request.url?.path == "/api/v1/oauth2/access_token", "OAuth endpoint")
            let q = query(request)
            check(q["client_secret"] == "test-secret" && q["redirect_uri"] == api.redirectURI && q["code"] == "test+code", "Documented query parameters")
            check(request.url!.absoluteString.contains("test%2Bcode"), "Preserve plus in authorization code")
            check(request.value(forHTTPHeaderField: "Platform") == "open_platform", "Platform header")
            return .init(body: rotated)
        }
        let token: Pan123OAuthToken = try await withCheckedThrowingContinuation { c in api.exchange(code: "test+code") { c.resume(with: $0) } }
        check(token.refreshToken == "new-refresh" && token.expiresAt == Date(timeIntervalSince1970: 8200), "Rotation and lifetime")
        var calls = 0
        Pan123Stub.handler = { request in
            calls += 1
            check(request.httpMethod == "GET" && request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-access", "Read-only bearer API")
            check(query(request)["parentFileId"] == "0", "Root ID zero")
            if calls == 1 {
                check(query(request)["lastFileId"] == nil, "Initial cursor omitted")
                return .init(body: #"{"code":0,"data":{"lastFileId":30,"fileList":[{"fileId":9223372036854775806,"filename":"音乐.FLAC","type":0,"size":500,"status":0,"trashed":0},{"fileId":20,"filename":"trash.mp3","type":0,"size":50,"status":0,"trashed":1}]}}"#)
            }
            check(query(request)["lastFileId"] == "30", "Follow returned cursor")
            return .init(body: #"{"code":0,"data":{"lastFileId":-1,"fileList":[{"fileId":30,"filename":"专辑","type":1,"size":0,"status":0,"trashed":0}]}}"#)
        }
        let files = try await list(api).get()
        check(files.count == 2 && files[0].fileId == 9223372036854775806 && files[1].type == 1, "Trash filtering, folders and Int64 precision")
        Pan123Stub.handler = { _ in .init(body: #"{"code":0,"data":{"lastFileId":5,"fileList":[]}}"#) }
        check(await error(list(api)) == .invalidResponse, "Repeated cursor terminates")
        Pan123Stub.handler = { _ in .init(body: empty) }
        check(try await list(api).get().isEmpty, "Empty root succeeds")
        for (code, expected) in [(5113, Pan123DriveError.quota),(5066,.notFound),(429,.rateLimited)] {
            Pan123Stub.handler = { _ in .init(body: "{\"code\":\(code),\"data\":null}") }
            check(await error(link(api)) == expected, "Business error \(code)")
        }
        var links = 0
        Pan123Stub.handler = { request in
            links += 1
            check(query(request)["fileId"] == "9223372036854775806", "Download file ID")
            return .init(body: "{\"code\":0,\"data\":{\"downloadUrl\":\"https://download-cdn.cjjd19.com/music.flac?ticket=\(links)\"}}")
        }
        let first = try await link(api).get(), second = try await link(api).get()
        check(first != second && links == 2, "Resolve fresh signed URL each time")
        for url in ["http://cdn.example.org/a", "https://user:pass@cdn.example.org/a", "https://127.0.0.1/a", "https://localhost/a", "https://files.local/a"] {
            check(!Pan123DriveAPI.validDownloadURL(URL(string: url)!), "Reject unsafe URL")
        }
        store.tokens["123"] = expired
        var refreshes = 0
        Pan123Stub.handler = { request in
            if request.httpMethod == "POST" {
                refreshes += 1
                check(query(request)["grant_type"] == "refresh_token" && query(request)["refresh_token"] == "fake-refresh", "Single-use refresh")
                return .init(body: rotated, delay: 0.05)
            }
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer rotated", "Use refreshed token")
            return .init(body: empty)
        }
        async let a = list(api); async let b = list(api)
        _ = try await (a.get(), b.get())
        check(refreshes == 1 && store.tokens["123"]?.refreshToken == "new-refresh", "Concurrent refresh is coalesced and saved")
        store.tokens["123"] = expired; store.failSave = true
        check(await error(list(api)) == .storage && store.tokens["123"] == nil, "Failed persistence invalidates account")
        store.failSave = false; store.tokens["123"] = expired
        let pending = Task { await list(api) }
        try await Task.sleep(nanoseconds: 10_000_000)
        api.unlink("123")
        check(await error(pending.value) == .authorization, "Unlink cancels pending refresh")
        try await Task.sleep(nanoseconds: 80_000_000)
        check(store.tokens["123"] == nil, "Late refresh cannot resurrect unlinked account")
        var file = Pan123DriveFileModel(); file.id = "9223372036854775806"; file.name = "音乐.FLAC"
        file.pan123User = Pan123DriveUserModel(userID: "123", name: "Test")
        check(file.isMusic() && file.fileExtension() == "flac", "Audio classification")
        var other = file; other.name = "new.flac"
        check(other.identity == file.identity, "Rename keeps artwork identity")
        other.pan123User?.userID = "456"
        check(other.identity != file.identity, "Separate account caches")
        check(file.mediaPlayURL().scheme == "pan123", "Synthetic identity URL")
        let encoded = file.toJSONString()!
        check(!encoded.contains("accessToken") && !encoded.contains("refreshToken"), "Shared model excludes credentials")
        check(Pan123DriveFileModel.deserialize(from: encoded)?.id == file.id, "Model round trip")
        let oldUser = Pan123DriveUserModel.deserialize(from: #"{"userID":"123","name":"Old"}"#)!
        check(oldUser.email.isEmpty && oldUser.phone.isEmpty, "Existing account model remains compatible")
        let contactUser = Pan123DriveUserModel(userID: "123", name: "Test", email: "test@example.com", phone: "138****0000")
        let restored = Pan123DriveUserModel.deserialize(from: contactUser.toJSONString()!)!
        check(restored.email == contactUser.email && restored.phone == contactUser.phone && restored == oldUser, "Contacts persist without changing account identity")
        store.tokens["123"] = fresh
        Pan123Stub.handler = { request in
            check(request.url?.path == "/api/v1/user/info" && request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-access", "Existing account profile uses authenticated read API")
            return .init(body: #"{"code":0,"data":{"uid":123,"nickname":"Test","mail":"test@example.com","passport":"138****0000"}}"#)
        }
        let profile: Pan123APIUser = try await withCheckedThrowingContinuation { c in api.user(accountID: "123") { c.resume(with: $0) } }
        check(profile.mail == "test@example.com" && profile.passport == "138****0000", "Official contact fields are decoded")
        Pan123Stub.handler = { _ in .init(body: #"{"code":0,"data":{"uid":456,"nickname":"Other"}}"#) }
        let mismatched: Result<Pan123APIUser, Pan123DriveError> = await withCheckedContinuation { c in api.user(accountID: "123") { c.resume(returning: $0) } }
        check(error(mismatched) == .invalidResponse, "Reject profile for different account")
        print("\(checks) 123 Drive regression checks passed")
    }
}
