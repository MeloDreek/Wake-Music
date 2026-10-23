import Foundation

/// Intercepts every URLSession request, including unexpected ones. Only fictional
/// credentials are used; this executable never contacts Microsoft or Keychain.
private final class OneDriveStub: URLProtocol {
    struct Reply {
        var status = 200
        var body = "{}"
        var headers: [String: String] = [:]
        var delay: TimeInterval = 0
        var error: Error?
    }
    static var handler: ((URLRequest) -> Reply)!
    private let lock = NSLock()
    private var stopped = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        DispatchQueue.main.async {
            let reply = Self.handler(self.request)
            DispatchQueue.main.asyncAfter(deadline: .now() + reply.delay) {
                self.lock.lock()
                let stopped = self.stopped
                self.lock.unlock()
                guard !stopped else { return }
                if let error = reply.error {
                    self.client?.urlProtocol(self, didFailWithError: error)
                    return
                }
                let response = HTTPURLResponse(url: self.request.url!, statusCode: reply.status,
                                               httpVersion: "HTTP/1.1", headerFields: reply.headers)!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {
        lock.lock(); stopped = true; lock.unlock()
    }
}

@main @MainActor
enum OneDriveOAuthRegression {
    static var checks = 0
    static let now = Date(timeIntervalSince1970: 1_000)
    static let fresh = OneDriveOAuthToken(accessToken: "fixture-access", refreshToken: "fixture-refresh",
                                         expiresAt: now.addingTimeInterval(3_600), homeAccountID: "uid.tenant")
    static let expired = OneDriveOAuthToken(accessToken: "expired-access", refreshToken: "fixture-refresh",
                                           expiresAt: now.addingTimeInterval(-1), homeAccountID: "uid.tenant")
    static let rotated = #"{"token_type":"Bearer","access_token":"rotated-access","refresh_token":"rotated-refresh","expires_in":3600}"#
    static let graphURL = URL(string: "https://graph.microsoft.com/v1.0/me/drive/root/children")!
    static let redirect = "msauth.com.OfflineMusic.www://auth"

    @MainActor final class Store {
        var tokens = ["account-a": fresh, "account-b": fresh]
        var saves = 0
        var failSave = false
    }
    static func check(_ value: Bool, _ message: String) {
        precondition(value, message)
        checks += 1
    }
    static func client(_ store: Store, redirectURI: String? = nil) -> OneDriveOAuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OneDriveStub.self]
        return OneDriveOAuthClient(clientID: "fixture-client", redirectURI: redirectURI ?? redirect,
                                   configuration: configuration, now: { now },
                                   load: { store.tokens[$0] }, save: { account, token in
            store.saves += 1
            if store.failSave { return false }
            store.tokens[account] = token
            return true
        }, remove: { store.tokens.removeValue(forKey: $0) })
    }
    static func token(_ api: OneDriveOAuthClient, account: String = "account-a", rejected: String? = nil) async -> Result<OneDriveOAuthToken, OneDriveOAuthError> {
        await withCheckedContinuation { continuation in
            api.accessToken(account, rejectedToken: rejected) { continuation.resume(returning: $0) }
        }
    }
    static func exchange(_ api: OneDriveOAuthClient, code: String, verifier: String) async -> Result<OneDriveOAuthToken, OneDriveOAuthError> {
        await withCheckedContinuation { continuation in
            api.exchange(code: code, verifier: verifier) { continuation.resume(returning: $0) }
        }
    }
    static func graph(_ api: OneDriveOAuthClient, account: String = "account-a", url: URL? = nil) async -> Result<(HTTPURLResponse, Data), OneDriveOAuthError> {
        await withCheckedContinuation { continuation in
            api.authorizedGraphRequest(accountID: account, url: url ?? graphURL) { continuation.resume(returning: $0) }
        }
    }
    static func failure<T>(_ result: Result<T, OneDriveOAuthError>) -> OneDriveOAuthError? {
        if case .failure(let error) = result { return error }
        return nil
    }
    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { preconditionFailure("Missing form body") }
        stream.open(); defer { stream.close() }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            precondition(count >= 0, "Body stream read failed")
            if count == 0 { return result }
            result.append(contentsOf: buffer.prefix(count))
        }
    }
    static func form(_ request: URLRequest) -> [String: String] {
        let text = String(decoding: body(request), as: UTF8.self)
        return Dictionary(uniqueKeysWithValues: text.split(separator: "&").map { field in
            let pieces = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            precondition(pieces.count == 2)
            func decode(_ text: Substring) -> String {
                String(text).replacingOccurrences(of: "+", with: " ").removingPercentEncoding!
            }
            return (decode(pieces[0]), decode(pieces[1]))
        })
    }

    static func main() async throws {
        let store = Store(), api = client(store)
        let pkce = OneDrivePKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", state: "independent-state")!
        check(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", "RFC7636 S256 known vector")
        let first = OneDrivePKCE()!, second = OneDrivePKCE()!
        check(first.verifier.count == 43 && first.state.count == 43, "256-bit random verifier and state")
        check(first.verifier != first.state && first.state != second.state && first.verifier != second.verifier,
              "Independent cryptographic nonces for every authorization")
        for bad in ["", String(repeating: "a", count: 42), String(repeating: "a", count: 129), String(repeating: "a", count: 42) + "+", String(repeating: "a", count: 42) + "中"] {
            check(OneDrivePKCE(verifier: bad, state: "state") == nil, "Reject non-RFC verifier")
        }
        check(OneDrivePKCE(verifier: pkce.verifier, state: "") == nil, "Reject empty state")
        check(OneDrivePKCE(verifier: String(repeating: "~", count: 128), state: "state") != nil, "RFC maximum verifier accepted")

        let authURL = api.authorizationURL(pkce)!
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: authURL, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        check(authURL.scheme == "https" && authURL.host == "login.microsoftonline.com" && authURL.path == "/common/oauth2/v2.0/authorize", "Official Microsoft authorize endpoint")
        check(query["scope"] == "offline_access User.Read Files.Read", "Read-only Graph scopes plus refresh permission")
        check(query["code_challenge_method"] == "S256" && query["code_challenge"] == pkce.challenge, "Authorization uses S256 PKCE")
        check(query["response_type"] == "code" && query["response_mode"] == "query", "Authorization code flow, not implicit flow")
        check(query["redirect_uri"] == redirect && query["state"] == pkce.state, "Expected callback and random state")
        check(!authURL.absoluteString.contains(pkce.verifier) && query["client_secret"] == nil, "Verifier and client secret absent from browser URL")
        check(api.authorizationCode(from: URL(string: redirect + "?code=accepted&state=independent-state")!, state: pkce.state) == "accepted", "Valid callback accepted")
        for callback in [
            "msauth.com.OfflineMusic.www.pro://auth?code=a&state=independent-state",
            "msauth.com.OfflineMusic.www://other?code=a&state=independent-state",
            redirect + "/wrong?code=a&state=independent-state",
            redirect + ":443?code=a&state=independent-state",
            "msauth.com.OfflineMusic.www://user:pass@auth?code=a&state=independent-state",
            redirect + "?code=a&state=wrong",
            redirect + "?code=a&state=independent-state&state=independent-state",
            redirect + "?code=a&code=b&state=independent-state",
            redirect + "?code=&state=independent-state",
            redirect + "?code=a&state=independent-state#ignored",
            redirect + "?code=a&state=independent-state&error=access_denied"
        ] {
            check(api.authorizationCode(from: URL(string: callback)!, state: pkce.state) == nil, "Reject callback target/state/fragment/duplicate ambiguity")
        }
        check(api.authorizationWasDenied(URL(string: redirect + "?error=access_denied&state=independent-state")!, state: pkce.state), "Explicit denial is identifiable")
        check(!api.authorizationWasDenied(URL(string: redirect + "?error=access_denied&state=wrong")!, state: pkce.state), "Denial still requires state")
        let pro = client(Store(), redirectURI: "msauth.com.OfflineMusic.www.pro://auth")
        check(pro.authorizationCode(from: URL(string: redirect + "?code=a&state=independent-state")!, state: pkce.state) == nil, "Pro rejects ordinary callback")
        check(pro.authorizationCode(from: URL(string: "msauth.com.OfflineMusic.www.pro://auth?code=pro-code&state=independent-state")!, state: pkce.state) == "pro-code", "Pro accepts registered callback")

        var calls = 0
        let specialCode = "a+b &=/# % 中文"
        OneDriveStub.handler = { request in
            calls += 1
            check(request.url?.host == "login.microsoftonline.com" && request.url?.path == "/common/oauth2/v2.0/token", "Token stays on official endpoint")
            check(request.httpMethod == "POST" && request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded", "Form POST token exchange")
            let fields = form(request)
            check(fields["code"] == specialCode && fields["code_verifier"] == pkce.verifier, "OAuth code survives plus/space/Unicode form encoding")
            check(fields["redirect_uri"] == redirect && fields["grant_type"] == "authorization_code", "Exchange binds callback and grant")
            check(fields["client_secret"] == nil && fields["client_id"] == "fixture-client", "Public client never sends a secret")
            check(String(decoding: body(request), as: UTF8.self).contains("%2B"), "Literal plus is percent encoded")
            return .init(body: rotated)
        }
        let exchanged = try await exchange(api, code: specialCode, verifier: pkce.verifier).get()
        check(exchanged.accessToken == "rotated-access" && exchanged.refreshToken == "rotated-refresh" && exchanged.expiresAt == now.addingTimeInterval(3_600), "Token lifetime is absolute and based on injected clock")
        check(store.saves == 0 && calls == 1, "Exchange does not persist before account identity is resolved")
        check(failure(await exchange(api, code: "", verifier: pkce.verifier)) == .configuration, "Empty code does not contact server")
        check(failure(await exchange(api, code: "valid", verifier: "bad")) == .configuration && calls == 1, "Invalid verifier does not contact server")

        OneDriveStub.handler = { _ in .init(body: #"{"token_type":"Bearer","access_token":"access","refresh_token":"refresh","expires_in":3600,"client_info":"eyJ1aWQiOiJ1aWQiLCJ1dGlkIjoidGVuYW50In0"}"#) }
        check(try await exchange(api, code: "valid", verifier: pkce.verifier).get().homeAccountID == "uid.tenant", "Microsoft home account identity decoded from client_info")
        for malformed in ["{}", #"{"token_type":"Bearer","access_token":"","refresh_token":"r","expires_in":3600}"#,
                          #"{"token_type":"PoP","access_token":"a","refresh_token":"r","expires_in":3600}"#,
                          #"{"token_type":"Bearer","access_token":"a","expires_in":3600}"#,
                          #"{"token_type":"Bearer","access_token":"a","refresh_token":"r","expires_in":0}"#] {
            OneDriveStub.handler = { _ in .init(body: malformed) }
            check(failure(await exchange(api, code: "valid", verifier: pkce.verifier)) == .invalidResponse, "Malformed token never installed")
        }

        store.tokens["account-a"] = expired
        var refreshes = 0
        OneDriveStub.handler = { request in
            refreshes += 1
            let fields = form(request)
            check(fields["grant_type"] == "refresh_token" && fields["refresh_token"] == "fixture-refresh", "Stored refresh token used")
            return .init(body: rotated, delay: 0.03)
        }
        async let refreshA = token(api)
        async let refreshB = token(api)
        let tokens = try await (refreshA.get(), refreshB.get())
        check(tokens.0 == tokens.1 && refreshes == 1 && store.saves == 1, "Concurrent requests share a single refresh")
        check(store.tokens["account-a"]?.refreshToken == "rotated-refresh" && store.tokens["account-b"] == fresh, "Rotation persisted only to correct account")
        check(try await token(api, rejected: "expired-access").get().accessToken == "rotated-access" && refreshes == 1, "Another request's newer token avoids duplicate refresh")

        store.tokens["account-a"] = expired
        OneDriveStub.handler = { _ in .init(body: #"{"token_type":"Bearer","access_token":"new-access","expires_in":3600}"#) }
        check(try await token(api).get().refreshToken == expired.refreshToken, "Refresh response may retain previous refresh token when omitted")
        store.tokens["account-a"] = expired
        let savesBeforeMismatch = store.saves
        let differentIdentity = Data(#"{"uid":"different-user","utid":"tenant"}"#.utf8).base64EncodedString()
        OneDriveStub.handler = { _ in
            .init(body: #"{"token_type":"Bearer","access_token":"wrong-account-access","refresh_token":"wrong-account-refresh","expires_in":3600,"client_info":""# + differentIdentity + #""}"#)
        }
        check(failure(await token(api)) == .accountMismatch && store.tokens["account-a"] == nil,
              "Refresh identity change invalidates the previous authorization")
        check(store.saves == savesBeforeMismatch && store.tokens["account-b"] == fresh,
              "Different user's refresh token is never saved or mapped onto another account")
        store.tokens["account-a"] = expired
        OneDriveStub.handler = { _ in .init(status: 400, body: #"{"error":"invalid_grant"}"#) }
        check(failure(await token(api)) == .authorization && store.tokens["account-a"] == nil, "Revoked refresh token requires sign-in and is removed")
        store.tokens["account-a"] = expired
        OneDriveStub.handler = { _ in .init(error: URLError(.notConnectedToInternet)) }
        check(failure(await token(api)) == .network && store.tokens["account-a"] == expired, "Transient network failure does not destroy saved authorization")
        store.failSave = true
        OneDriveStub.handler = { _ in .init(body: rotated) }
        check(failure(await token(api)) == .storage && store.tokens["account-a"] == nil, "Failed rotation persistence is surfaced and stale credential removed")
        store.failSave = false

        store.tokens["account-a"] = expired
        let savesBeforeUnlink = store.saves
        OneDriveStub.handler = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { api.unlink("account-a") }
            return .init(body: rotated, delay: 0.06)
        }
        check(failure(await token(api)) == .authorization, "Unlink immediately rejects pending refresh callers")
        try await Task.sleep(nanoseconds: 100_000_000)
        check(store.tokens["account-a"] == nil && store.saves == savesBeforeUnlink && store.tokens["account-b"] == fresh,
              "Late refresh cannot resurrect account or write after unlink")

        store.tokens["account-a"] = expired
        let replacement = OneDriveOAuthToken(accessToken: "replacement-access", refreshToken: "replacement-refresh", expiresAt: fresh.expiresAt, homeAccountID: "uid.tenant")
        OneDriveStub.handler = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { check(api.install(replacement, accountID: "account-a"), "Install replacement authorization") }
            return .init(body: rotated, delay: 0.06)
        }
        check(failure(await token(api)) == .authorization, "Reauthorization cancels obsolete refresh waiters")
        try await Task.sleep(nanoseconds: 100_000_000)
        check(store.tokens["account-a"] == replacement, "Stale refresh cannot overwrite reauthorization")

        store.tokens["account-a"] = fresh
        var graphCalls = 0
        refreshes = 0
        OneDriveStub.handler = { request in
            if request.url?.host == "login.microsoftonline.com" { refreshes += 1; return .init(body: rotated) }
            graphCalls += 1
            check(request.value(forHTTPHeaderField: "Authorization") == (graphCalls == 1 ? "Bearer fixture-access" : "Bearer rotated-access"), "Graph retries with rotated bearer")
            return graphCalls == 1 ? .init(status: 401) : .init(body: #"{"value":[]}"#)
        }
        check(try await graph(api).get().0.statusCode == 200 && graphCalls == 2 && refreshes == 1, "Graph 401 refreshes and retries once")
        store.tokens["account-a"] = fresh
        graphCalls = 0; refreshes = 0
        OneDriveStub.handler = { request in
            if request.url?.host == "login.microsoftonline.com" { refreshes += 1; return .init(body: rotated) }
            graphCalls += 1
            return .init(status: 401)
        }
        check(failure(await graph(api)) == .authorization && graphCalls == 2 && refreshes == 1, "Repeated 401 terminates without retry loop")
        store.tokens["account-a"] = fresh
        graphCalls = 0
        OneDriveStub.handler = { _ in graphCalls += 1; return .init(status: 403) }
        check(try await graph(api).get().0.statusCode == 403 && graphCalls == 1, "Permission failure is not mistaken for expired token")

        let beforeUnsafe = graphCalls
        for unsafe in ["http://graph.microsoft.com/v1.0/me", "https://graph.microsoft.com.evil.invalid/v1.0/me", "https://evil.invalid/v1.0/me",
                       "https://user:pass@graph.microsoft.com/v1.0/me", "https://graph.microsoft.com:444/v1.0/me", "https://graph.microsoft.com/v1.0/me#fragment"] {
            check(failure(await graph(api, url: URL(string: unsafe)!)) == .invalidResponse, "Never leak bearer to untrusted Graph URL")
        }
        check(graphCalls == beforeUnsafe, "Unsafe URL rejection happens before network")

        store.tokens["account-a"] = OneDriveOAuthToken(accessToken: "legacy-access", refreshToken: "", expiresAt: fresh.expiresAt, homeAccountID: nil)
        check(failure(await token(api)) == .authorization && graphCalls == beforeUnsafe, "Legacy access-only account explicitly requires sign-in")
        check(failure(await token(api, account: "unknown-account")) == .authorization, "Missing account requires sign-in without network")
        check(!api.install(fresh, accountID: ""), "Reject empty account identity")

        store.tokens["account-a"] = fresh
        OneDriveStub.handler = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { api.unlink("account-a") }
            return .init(body: #"{"value":[]}"#, delay: 0.06)
        }
        check(failure(await graph(api)) == .authorization && store.tokens["account-a"] == nil, "Unlink discards late Graph success")
        print("PASS: \(checks) OneDrive PKCE, callback, form, token rotation, concurrency, unlink and Graph authorization checks (offline fixtures only)")
    }
}
