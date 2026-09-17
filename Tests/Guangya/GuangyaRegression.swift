import Foundation
import SmartCodable

private final class GuangyaStub: URLProtocol {
    struct Reply { var status = 200; var body = "{}"; var delay: TimeInterval = 0; var headers: [String: String] = [:] }
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

@main @MainActor
enum GuangyaRegression {
    static var checks = 0
    static func check(_ value: Bool, _ message: String) { precondition(value, message); checks += 1 }
    static let fresh = GuangyaOAuthToken(accessToken: "fake-access", refreshToken: "fake-refresh", expiresAt: Date(timeIntervalSince1970: 5000), userID: "user-a")
    static let expired = GuangyaOAuthToken(accessToken: "expired-access", refreshToken: "fake-refresh", expiresAt: Date(timeIntervalSince1970: 900), userID: "user-a")
    static let rotated = #"{"token_type":"Bearer","access_token":"rotated-access","refresh_token":"rotated-refresh","expires_in":1200,"sub":"user-a"}"#
    static let empty = #"{"msg":"success[0]","data":{"total":0,"list":[]}}"#
    @MainActor final class Store { var tokens = ["user-a": fresh]; var saves = 0; var failSave = false }
    static func client(_ store: Store, redirectURI: String = "wakemusic-guangya://oauth/callback") -> GuangyaDriveAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GuangyaStub.self]
        return GuangyaDriveAPI(clientID: "test-client", projectID: "test-project", secret: "test-secret", deviceID: "test-device",
                               redirectURI: redirectURI, configuration: config,
                               now: { Date(timeIntervalSince1970: 1000) }, throttle: false,
                               load: { store.tokens[$0] }, save: { id, token in
            store.saves += 1
            if store.failSave { return false }; store.tokens[id] = token; return true
        }, remove: { store.tokens.removeValue(forKey: $0) })
    }
    static func list(_ api: GuangyaDriveAPI, folder: String = "") async -> Result<[GuangyaAPIItem], GuangyaDriveError> {
        await withCheckedContinuation { c in api.listFolder(accountID: "user-a", folderID: folder) { c.resume(returning: $0) } }
    }
    static func link(_ api: GuangyaDriveAPI) async -> Result<URL, GuangyaDriveError> {
        await withCheckedContinuation { c in api.fileURL(accountID: "user-a", fileID: "1835243138919944265") { c.resume(returning: $0) } }
    }
    static func failure<T>(_ result: Result<T, GuangyaDriveError>) -> GuangyaDriveError? {
        if case .failure(let error) = result { return error }; return nil
    }
    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { preconditionFailure("Missing request body") }
        stream.open(); defer { stream.close() }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            precondition(count >= 0, "Request body stream failed")
            if count == 0 { return result }
            result.append(contentsOf: buffer.prefix(count))
        }
    }
    static func page(_ ids: [Int], total: Int) -> String {
        let items = ids.map { ["fileId": String($0), "fileName": "音乐 # + % \($0).FLAC", "resType": 1, "fileSize": 50000000] as [String: Any] }
        return String(decoding: try! JSONSerialization.data(withJSONObject: ["data": ["total": total, "list": items]]), as: UTF8.self)
    }
    static func main() async throws {
        let store = Store(), api = client(store)
        let pkce = GuangyaPKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", state: "independent-state")!
        check(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC7636 S256 vector")
        let random = GuangyaPKCE()!, otherRandom = GuangyaPKCE()!
        check(random.verifier.count == 43 && random.state.count == 43, "256-bit random parameters")
        check(random.state != random.verifier && random.state != otherRandom.state, "Independent state per login")
        let url = api.authorizationURL(pkce)!
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        check(url.host == "www.guangyapan.com" && URLComponents(url: url, resolvingAgainstBaseURL: false)?.path == "/oauth/", "Official authorization page")
        check(GuangyaDriveAPI.signature(clientID: "test-client", timestamp: "1000", secret: "test-secret") == "6c689f009bd0ca863273631eeed445e3", "Independent MD5 signature fixture")
        check(query["scope"] == "user offline" && query["code_challenge_method"] == "S256", "Documented scopes and PKCE")
        check(query["state"] == pkce.state && !url.absoluteString.contains(pkce.verifier), "Verifier stays off browser URL")
        check(api.authorizationCode(from: URL(string: "wakemusic-guangya://oauth/callback?code=accepted&state=independent-state")!, state: pkce.state) == "accepted", "Valid callback")
        for callback in ["wakemusic-guangya://wrong/callback?code=a&state=independent-state", "wakemusic-guangya://oauth/callback?code=a&state=wrong", "wakemusic-guangya://oauth/callback?code=a&state=independent-state&state=independent-state", "wakemusic-guangya://oauth/callback?code=a&code=b&state=independent-state", "wakemusic-guangya://oauth/callback?code=a&state=independent-state#error=bad"] {
            check(api.authorizationCode(from: URL(string: callback)!, state: pkce.state) == nil, "Reject malformed or mismatched callback")
        }
        check(api.authorizationWasDenied(URL(string: "wakemusic-guangya://oauth/callback?error=access_denied&state=independent-state")!, state: pkce.state), "User denial is distinct")
        let pro = client(Store(), redirectURI: "wakemusic-pro-guangya://oauth/callback")
        let proQuery = URLComponents(url: pro.authorizationURL(pkce)!, resolvingAgainstBaseURL: false)!.queryItems!
        check(proQuery.first { $0.name == "redirect_uri" }?.value == "wakemusic-pro-guangya://oauth/callback", "Pro uses its registered callback")
        let proCallback = URL(string: "wakemusic-pro-guangya://oauth/callback?code=pro-code&state=independent-state")!
        check(pro.authorizationCode(from: proCallback, state: pkce.state) == "pro-code", "Pro callback accepted by Pro client")
        check(api.authorizationCode(from: proCallback, state: pkce.state) == nil, "Ordinary client rejects Pro callback")
        check(pro.authorizationCode(from: URL(string: "wakemusic-guangya://oauth/callback?code=ordinary-code&state=independent-state")!, state: pkce.state) == nil, "Pro client rejects old ordinary callback")
        GuangyaStub.handler = { request in
            check(request.url?.host == "openapi-account.guangyapan.com" && request.httpMethod == "POST", "OAuth server and JSON POST")
            check(request.value(forHTTPHeaderField: "x-project-id") == "test-project", "Project ID header")
            check(request.value(forHTTPHeaderField: "x-device-id") == "test-device", "Installation ID header")
            let body = try! JSONSerialization.jsonObject(with: body(request)) as! [String: String]
            check(body["code_verifier"] == pkce.verifier && body["code"] == "accepted", "Exchange uses locally retained verifier")
            check(body["client_secret"] == nil && request.value(forHTTPHeaderField: "sign") == nil, "No business secret in token request")
            return .init(body: rotated)
        }
        let exchanged: GuangyaOAuthToken = try await withCheckedThrowingContinuation { c in api.exchange(code: "accepted", verifier: pkce.verifier) { c.resume(with: $0) } }
        check(exchanged.expiresAt == Date(timeIntervalSince1970: 2200) && exchanged.userID == "user-a", "Token lifetime and account identity")

        var file = GuangyaDriveFileModel()
        file.id = "1835243138919944265"; file.name = "音乐 # + %.FLAC"
        file.guangyaUser = GuangyaDriveUserModel(userID: "user-a", name: "Tester")
        check(file.isMusic() && file.fileExtension() == "flac", "Case-insensitive audio classification")
        check(file.identity.count == 72 && !file.identity.contains("/"), "Bounded filesystem-safe artwork key")
        var renamed = file; renamed.name = "new.flac"
        check(file.identity == renamed.identity, "Stable identity after rename")
        renamed.guangyaUser?.userID = "user-b"
        check(renamed.identity != file.identity, "Account-isolated cache identity")
        renamed = file; renamed.isFolder = true
        check(!renamed.isMusic() && renamed.identity != file.identity, "Directory classification")
        check(file.mediaPlayURL().scheme == "guangya", "Persist synthetic media URL")
        let json = file.toJSONString()!
        check(!json.contains("fake-access") && !json.contains("refreshToken"), "No credentials in shared models")
        check(GuangyaDriveFileModel.deserialize(from: json)?.identity == file.identity, "File ID precision and model round-trip")

        var pages = [String]()
        GuangyaStub.handler = { request in
            check(request.url?.host == "openapi.guangyapan.com" && request.httpMethod == "GET", "Read-only business endpoint")
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-access", "Bearer authorization")
            check(request.value(forHTTPHeaderField: "timestamp") == "1000", "Unix seconds")
            check(request.value(forHTTPHeaderField: "sign") == GuangyaDriveAPI.signature(clientID: "test-client", timestamp: "1000", secret: "test-secret"), "Request signing")
            check(request.value(forHTTPHeaderField: "traceparent")?.range(of: "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$", options: .regularExpression) != nil, "W3C traceparent shape")
            let query = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
            check(query["parentId"] == nil && query["fileTypes"] == nil, "Root is omitted; directories are not filtered out")
            pages.append(query["page"]!)
            return .init(body: pages.count == 1 ? page([1, 2], total: 3) : page([3], total: 3))
        }
        check(try await list(api).get().count == 3 && pages == ["0", "1"], "Zero-based complete pagination")
        GuangyaStub.handler = { _ in .init(body: empty) }
        check(try await list(api).get().isEmpty, "Omitted code defaults to success, empty root is valid")
        let relaunched = client(store)
        check(try await list(relaunched).get().isEmpty, "A new API instance restores persisted credentials without an in-memory login session")
        var calls = 0
        GuangyaStub.handler = { _ in calls += 1; return .init(body: page([1], total: 3)) }
        check(failure(await list(api)) == .invalidResponse && calls == 2, "Repeated pages are bounded")
        check(GuangyaFileListEmptyState.empty(folderID: "", query: "") == .folder, "Empty-folder guidance")
        check(GuangyaFileListEmptyState.empty(folderID: "", query: "a") == .search, "Search guidance")
        check(GuangyaFileListEmptyState.membershipRequired.showsMembershipButton, "Show the membership link only for membership refusal")
        check(GuangyaFileListEmptyState.membershipRequired.isFailure && GuangyaFileListEmptyState.membershipRequired.action == .refresh, "Membership refusal keeps Retry as the primary action")
        check(GuangyaFileListEmptyState.membershipRequired.message { $0 } == "Guangya.Membership", "Membership message stays localized")
        for state in [GuangyaFileListEmptyState.folder, .search, .failure("Network error")] {
            check(!state.showsMembershipButton, "Never promote membership for empty folders, search, or unrelated errors")
        }
        for (code, expected) in [(111, GuangyaDriveError.permission), (113, .clockSkew), (116, .signature), (120, .configuration), (146, .notFound), (149, .notFound), (164, .membership), (167, .restrictedFile), (430, .membership)] {
            check(GuangyaDriveAPI.businessError(status: 200, data: Data("{\"code\":\(code),\"data\":null}".utf8)) == expected, "Business failure despite HTTP 200")
        }
        calls = 0
        GuangyaStub.handler = { request in
            calls += 1
            check(request.url?.path == "/openapi/v1/file/get_file_list", "Membership refusal does not trigger token refresh")
            return .init(body: #"{"code":430,"data":null}"#)
        }
        check(failure(await list(api)) == .membership && calls == 1, "Actual production code 430 remains a membership error, not expired authorization")
        check(store.tokens["user-a"] == fresh && store.saves == 0, "Membership refusal preserves the valid stored credential")
        check(GuangyaDriveAPI.businessError(status: 200, data: Data(#"{"code":"bad","data":{}}"#.utf8)) == .invalidResponse, "Malformed status isn't success")
        GuangyaStub.handler = { _ in .init(status: 429, headers: ["Retry-After": "15"]) }
        check(failure(await list(api)) == .rateLimited, "Respect excessive Retry-After without retry storm")

        calls = 0
        GuangyaStub.handler = { request in
            calls += 1
            check(request.url?.path == "/openapi/v1/file/get_res_download_url", "Audio uses raw resource endpoint, never video VOD")
            return .init(body: "{\"data\":{\"signedURL\":\"https://sz-httpdown-test.guangyacdn.com/download/?signature=\(calls)\",\"urlDuration\":21600}}")
        }
        let first = try await link(api).get(), second = try await link(api).get()
        check(first != second && !first.absoluteString.contains("fake-access"), "Resolve fresh credential-free signed URL")
        for unsafe in ["http://sz-httpdown-test.guangyacdn.com/download/", "https://guangyacdn.com.evil.invalid/a", "http://127.0.0.1/a", "https://user:password@guangyacdn.com/a", "https://guangyacdn.com:8080/a"] {
            check(!GuangyaDriveAPI.validDownloadURL(URL(string: unsafe)!), "Reject unsafe or unrelated download destination")
        }

        store.tokens["user-a"] = expired; calls = 0
        GuangyaStub.handler = { request in
            if request.url?.path == "/v1/auth/token" { calls += 1; return .init(body: rotated, delay: 0.02) }
            check(request.value(forHTTPHeaderField: "Authorization") == "Bearer rotated-access", "Refreshed token used by queued callers")
            return .init(body: empty)
        }
        async let one = list(api); async let two = list(api)
        _ = try await (one.get(), two.get())
        check(calls == 1 && store.saves == 1, "Concurrent callers share one refresh")
        check(store.tokens["user-a"]?.refreshToken == "rotated-refresh", "Rotated refresh persisted before retry")
        store.tokens["user-a"] = fresh; calls = 0
        GuangyaStub.handler = { request in
            if request.url?.path == "/v1/auth/token" { calls += 1; return .init(body: rotated) }
            return .init(body: request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-access" ? #"{"code":117,"data":null}"# : empty)
        }
        _ = try await list(api).get()
        check(calls == 1, "Business code 117 triggers refresh, even with HTTP 200")
        store.tokens["user-a"] = expired; store.failSave = true
        check(failure(await list(api)) == .storage && store.tokens["user-a"] == nil, "Failed Keychain rotation removes unusable credentials")
        store.failSave = false; store.tokens["user-a"] = expired
        GuangyaStub.handler = { _ in .init(body: rotated, delay: 0.05) }
        let pending: Result<[GuangyaAPIItem], GuangyaDriveError> = await withCheckedContinuation { c in
            api.listFolder(accountID: "user-a", folderID: "") { c.resume(returning: $0) }; api.unlink("user-a")
        }
        check(failure(pending) == .authorization, "Unlink completes pending refresh callers")
        try await Task.sleep(nanoseconds: 100_000_000)
        check(store.tokens["user-a"] == nil, "Late refresh cannot resurrect an unlinked account")
        print("PASS: \(checks) Guangya API/OAuth/model regressions")
    }
}
