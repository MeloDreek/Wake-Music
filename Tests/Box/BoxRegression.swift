import Foundation
import SmartCodable

/// Every request is intercepted. No real credentials, account, disk library or cloud file is touched.
private final class BoxStubProtocol: URLProtocol {
    struct Reply {
        var status = 200
        var headers: [String: String] = [:]
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
                let response = HTTPURLResponse(url: self.request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {}
}

@main
@MainActor
enum BoxRegression {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }
    static let fresh = BoxOAuthToken(accessToken: "test-access", refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600))
    static let expired = BoxOAuthToken(accessToken: "expired-access", refreshToken: "single-use-refresh", expiresAt: .distantPast)
    static let rotated = #"{"access_token":"new-access","refresh_token":"rotated-refresh","expires_in":3600}"#
    static let emptyPage = #"{"entries":[],"next_marker":null}"#

    @MainActor final class Store {
        var tokens = ["10": fresh, "20": fresh]
        var failSave = false
        var saves = 0
    }
    static func client(_ store: Store) -> BoxDriveAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BoxStubProtocol.self]
        return BoxDriveAPI(clientID: "test-client", clientSecret: "test-secret", redirectURI: "wakemusic-box://oauth/callback",
                           configuration: config, load: { store.tokens[$0] }, save: { id, token in
            store.saves += 1
            if store.failSave { return false }
            store.tokens[id] = token
            return true
        }, remove: { store.tokens.removeValue(forKey: $0) })
    }
    static func list(_ api: BoxDriveAPI, account: String = "10", folder: String = "0") async -> Result<[BoxAPIItem], BoxDriveError> {
        await withCheckedContinuation { c in api.listFolder(accountID: account, folderID: folder) { c.resume(returning: $0) } }
    }
    static func link(_ api: BoxDriveAPI, file: String = "123") async -> Result<URL, BoxDriveError> {
        await withCheckedContinuation { c in api.fileURL(accountID: "10", fileID: file) { c.resume(returning: $0) } }
    }
    static func main() async throws {
        let account = BoxDriveUserModel(userID: "10", email: "test@example.invalid", name: "Tester")
        var file = BoxDriveFileModel()
        file.id = "9007199254740993"
        file.name = "测试 #1 & Live.FLAC"
        file.boxUser = account
        check(file.isMusic() && !file.isDirectory() && !file.isVideo(), "Case-insensitive audio classification")
        check(file.mediaPlayURL().scheme == "box" && file.mediaPlayURL().lastPathComponent == file.name, "Safe placeholder retains filename")
        var other = file
        other.boxUser?.userID = "20"
        check(file != other, "Account cache separation")
        other = file; other.id = "9007199254740994"
        check(file != other, "Same-named songs have distinct IDs")
        other = file; other.isFolder = true
        check(!other.isMusic() && other != file, "Folder named FLAC is not music")
        other = file; other.name = "renamed.flac"
        check(Set([file, other]).count == 1, "Renaming preserves identity")
        let json = file.toJSONString()!
        let restored = BoxDriveFileModel.deserialize(from: json)!
        check(restored == file && restored.id == file.id && restored.name == file.name, "Serialization retains identity and 64-bit string IDs")
        check(!json.lowercased().contains("token"), "No tokens in persisted models")
        check(BoxDriveFileModel.deserialize(from: "{}")?.boxUser == nil, "Backward-compatible optional model")
        check(BoxDriveAPI.validID("0") && !BoxDriveAPI.validID("../0") && !BoxDriveAPI.validID("１２") && !BoxDriveAPI.validID(""), "IDs cannot inject API paths")
        check(BoxDriveAPI.validDownloadURL(URL(string: "https://dl.boxcloud.com/d/123")!), "Box CDN accepted")
        for value in ["http://dl.boxcloud.com/d/123", "https://boxcloud.com.evil.invalid/d", "https://evilboxcloud.com/d", "https://user:pass@dl.boxcloud.com/d", "https://dl.boxcloud.com:80/d"] {
            check(!BoxDriveAPI.validDownloadURL(URL(string: value)!), "Reject unsafe download endpoint")
        }

        let storage = Store()
        let api = client(storage)
        let url = api.authorizationURL(state: "nonce")!
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        check(query.contains(URLQueryItem(name: "scope", value: "root_readonly")), "Only read scope requested")
        check(!url.absoluteString.contains("test-secret"), "Client secret never appears in authorization URL")
        check(api.authorizationCode(from: URL(string: "wakemusic-box://oauth/callback?state=nonce&code=ok")!, state: "nonce") == "ok", "Valid callback accepted")
        check(api.authorizationWasDenied(URL(string: "wakemusic-box://oauth/callback?state=nonce&error=access_denied")!, state: "nonce"), "Explicit denial is cancellation")
        check(!api.authorizationWasDenied(URL(string: "wakemusic-box://oauth/callback?state=wrong&error=access_denied")!, state: "nonce"), "Denial still validates state")
        for value in ["wakemusic-box://other/callback?state=nonce&code=ok", "wakemusic-box://oauth/wrong?state=nonce&code=ok", "wakemusic-box://oauth/callback?state=wrong&code=ok", "wakemusic-box://oauth/callback?state=nonce&code=a&code=b", "wakemusic-box://oauth/callback?state=nonce&error=access_denied"] {
            check(api.authorizationCode(from: URL(string: value)!, state: "nonce") == nil, "Reject invalid callback")
        }

        var pages = 0
        BoxStubProtocol.handler = { request in
            pages += 1
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access", "Authenticated API request")
            if pages == 1 { return .init(body: #"{"entries":[{"type":"folder","id":"1","name":"Music"},{"type":"file","id":"2","name":"a.mp3","size":12},{"type":"web_link","id":"3","name":"Link"}],"next_marker":"a+b/="}"#) }
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            check(q.contains(URLQueryItem(name: "marker", value: "a+b/=")), "Opaque marker survives URL encoding")
            return .init(body: #"{"entries":[{"type":"file","id":"2","name":"a.mp3"},{"type":"file","id":"4","name":"b.mp3"}],"next_marker":null}"#)
        }
        let items = try await list(api).get()
        check(items.map(\.id) == ["1", "2", "4"] && pages == 2, "All pages read, deduplicated, web links excluded")
        BoxStubProtocol.handler = { _ in .init(body: #"{"entries":[],"next_marker":"loop"}"#) }
        if case .failure(.invalidResponse) = await list(api) { check(true, "Pagination loop rejected") } else { preconditionFailure("Loop was not rejected") }

        storage.tokens["10"] = expired
        var refreshes = 0
        BoxStubProtocol.handler = { request in
            if request.url!.path == "/oauth2/token" { refreshes += 1; return .init(body: rotated, delay: 0.02) }
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access", "Requests wait for rotated token")
            return .init(body: emptyPage)
        }
        async let first = list(api)
        async let second = list(api)
        _ = try await (first.get(), second.get())
        check(refreshes == 1 && storage.tokens["10"]?.refreshToken == "rotated-refresh", "Concurrent requests share one refresh and persist rotation")
        check(storage.tokens["20"] == fresh, "Other accounts unchanged")

        storage.tokens["10"] = fresh
        var attempts = 0
        BoxStubProtocol.handler = { request in
            if request.url!.path == "/oauth2/token" { return .init(body: rotated) }
            attempts += 1
            return attempts == 1 ? .init(status: 401) : .init(body: emptyPage)
        }
        _ = try await list(api).get()
        check(attempts == 2, "401 refreshes and retries once")
        BoxStubProtocol.handler = { request in request.url!.path == "/oauth2/token" ? .init(body: rotated) : .init(status: 401) }
        if case .failure(.authorization) = await list(api) { check(true, "Repeated 401 terminates") } else { preconditionFailure("401 not handled") }
        BoxStubProtocol.handler = { _ in .init(status: 403) }
        if case .failure(.permission) = await list(api) { check(true, "Permissions are not an empty folder") } else { preconditionFailure("403 not handled") }
        BoxStubProtocol.handler = { _ in .init(status: 404) }
        if case .failure(.notFound) = await link(api) { check(true, "Deleted file reports failure") } else { preconditionFailure("404 not handled") }

        storage.tokens["10"] = fresh
        BoxStubProtocol.handler = { request in
            check(request.url!.path == "/2.0/files/123/content", "Resolve Box content endpoint")
            return .init(status: 302, headers: ["Location": "https://dl.boxcloud.com/d/test"])
        }
        let resolvedURL = try await link(api).get()
        check(resolvedURL.host == "dl.boxcloud.com", "Resolve temporary signed URL without downloading")
        BoxStubProtocol.handler = { _ in .init(status: 302, headers: ["Location": "https://evil.invalid/file"]) }
        if case .failure(.invalidResponse) = await link(api) { check(true, "Unexpected redirect rejected") } else { preconditionFailure("Unsafe redirect") }
        var linkAttempts = 0
        BoxStubProtocol.handler = { _ in
            linkAttempts += 1
            return linkAttempts == 1 ? .init(status: 202, headers: ["Retry-After": "0"]) : .init(status: 302, headers: ["Location": "https://dl.boxcloud.com/d/test"])
        }
        _ = try await link(api).get()
        check(linkAttempts == 2, "Newly uploaded file is retried")
        BoxStubProtocol.handler = { _ in .init(status: 429, headers: ["Retry-After": "60"]) }
        if case .failure(.rateLimited) = await link(api) { check(true, "Long rate limit stops bounded retry") } else { preconditionFailure("Unbounded rate limit") }

        storage.tokens["10"] = expired
        storage.failSave = true
        BoxStubProtocol.handler = { _ in .init(body: rotated) }
        if case .failure(.storage) = await list(api) { check(true, "Keychain failure surfaced") } else { preconditionFailure("Storage failure hidden") }
        check(storage.tokens["10"] == nil, "Revoked refresh token not retained after failed rotation save")
        storage.failSave = false
        storage.tokens["10"] = expired
        BoxStubProtocol.handler = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { api.unlink("10") }
            return .init(body: rotated, delay: 0.05)
        }
        if case .failure(.authorization) = await list(api) { check(true, "Unlink cancels waiting requests") } else { preconditionFailure("Unlink race") }
        try await Task.sleep(nanoseconds: 100_000_000)
        check(storage.tokens["10"] == nil && storage.tokens["20"] == fresh, "Late refresh cannot resurrect an unlinked account")

        check(BoxFileListEmptyState.empty(folderID: "0", query: "") == .folder, "Root empty state has no pCloud scope limitation")
        check(BoxFileListEmptyState.empty(folderID: "1", query: "x") == .search, "Search distinguishes no matches")
        let root = CommandLine.arguments[1]
        let importTypes = try String(contentsOfFile: root + "/Mobie/Mobie/Business/ImportModule/Model/ImportFileType+Extension.swift", encoding: .utf8)
        let menus = importTypes.components(separatedBy: "\n").filter { $0.contains("let commonArray:") }
        check(menus.count == 2 && menus.allSatisfy { $0.contains(".fromBoxDrive") }, "Box is visible with and without MSAL")
        for plist in ["Mobie", "Mobie_Pro"] {
            let data = try Data(contentsOf: URL(fileURLWithPath: root + "/Mobie/Mobie/System/" + plist + ".plist"))
            let info = try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
            let types = info["CFBundleURLTypes"] as! [[String: Any]]
            check(types.contains { ($0["CFBundleURLSchemes"] as? [String])?.contains("wakemusic-box") == true }, "Both apps register Box callback")
        }
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root + "/Mobie/Mobie/System/Localizable.xcstrings"))) as! [String: Any]
        let strings = catalog["strings"] as! [String: [String: Any]]
        let locales = Set(strings.values.flatMap { ($0["localizations"] as? [String: Any] ?? [:]).keys })
        for key in ["Please sign in to the same Box account.", "Unable to save Box authorization. Please try again.", "Box request failed. Please check your connection and account permissions.", BoxFileListEmptyState.folderMessage] {
            let values = strings[key]!["localizations"] as! [String: [String: Any]]
            for locale in locales {
                let unit = values[locale]?["stringUnit"] as? [String: String]
                check(unit?["state"] == "translated" && unit?["value"]?.isEmpty == false, "Localized Box text: \(locale)")
            }
        }
        print("PASS: \(checks) Box model, API, OAuth, pagination, concurrency and localization checks")
    }
}
