import Foundation
import CryptoKit
import Security

enum GuangyaDriveError: Error, Equatable {
    case authorization, storage, invalidResponse, permission, notFound, rateLimited, network
    case clockSkew, signature, configuration, membership, restrictedFile, insecureDownload
}

struct GuangyaOAuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: String
}

struct GuangyaAPIUser: Decodable {
    let userId: String
    let nickName: String?
}

struct GuangyaAPIItem: Decodable {
    let fileId: String
    let fileName: String
    let resType: Int
    let fileSize: Int64?
    let ctime: TimeInterval?
    let mtime: TimeInterval?
}

private struct GuangyaAPIPage: Decodable { let total: Int; let list: [GuangyaAPIItem] }
private struct GuangyaEnvelope<Value: Decodable>: Decodable { let data: Value }
private struct GuangyaDownload: Decodable { let signedURL: String; let urlDuration: TimeInterval }

struct GuangyaPKCE {
    let verifier: String
    let state: String
    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    init?(verifier: String? = nil, state: String? = nil) {
        func random() -> String? {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
            return Self.base64URL(Data(bytes))
        }
        guard let verifier = verifier ?? random(), let state = state ?? random() else { return nil }
        self.verifier = verifier
        self.state = state
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// The private V1.3 specification: JSON OAuth; signed GET business calls, zero-based pages.
/// All public entry points and callbacks use the main queue. No upload/delete/publish endpoints.
final class GuangyaDriveAPI {
    typealias TokenResult = (Result<GuangyaOAuthToken, GuangyaDriveError>) -> Void
    let redirectURI: String
    private let clientID: String
    private let projectID: String
    private let secret: String
    private let deviceID: String
    private let load: (String) -> GuangyaOAuthToken?
    private let save: (String, GuangyaOAuthToken) -> Bool
    private let remove: (String) -> Void
    private let now: () -> Date
    private let throttle: Bool
    private let session: URLSession
    private var generations: [String: UUID] = [:]
    private var refreshing: [String: [TokenResult]] = [:]
    private var nextStarts: [String: Date] = [:]

    init(clientID: String, projectID: String, secret: String, deviceID: String, redirectURI: String,
         configuration: URLSessionConfiguration = .ephemeral, now: @escaping () -> Date = Date.init,
         throttle: Bool = true, load: @escaping (String) -> GuangyaOAuthToken?,
         save: @escaping (String, GuangyaOAuthToken) -> Bool, remove: @escaping (String) -> Void) {
        self.clientID = clientID; self.projectID = projectID; self.secret = secret
        self.deviceID = deviceID; self.redirectURI = redirectURI
        self.load = load; self.save = save; self.remove = remove; self.now = now; self.throttle = throttle
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: GuangyaRedirectBlocker(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }

    func authorizationURL(_ pkce: GuangyaPKCE) -> URL? {
        guard !clientID.isEmpty, !projectID.isEmpty, !secret.isEmpty, !deviceID.isEmpty, deviceID.count <= 40 else { return nil }
        var components = URLComponents(string: "https://www.guangyapan.com/oauth/")!
        components.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                                 URLQueryItem(name: "response_type", value: "code"),
                                 URLQueryItem(name: "scope", value: "user offline"),
                                 URLQueryItem(name: "code_challenge", value: pkce.challenge),
                                 URLQueryItem(name: "code_challenge_method", value: "S256"),
                                 URLQueryItem(name: "redirect_uri", value: redirectURI),
                                 URLQueryItem(name: "state", value: pkce.state)]
        // Keep the verifier local; state is a separate random CSRF value, never a returned verifier.
        return components.url
    }

    private func callbackValues(_ callback: URL, state: String) -> [String: [URLQueryItem]]? {
        guard let expected = URLComponents(string: redirectURI),
              let actual = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              actual.scheme == expected.scheme, actual.host == expected.host, actual.path == expected.path,
              actual.port == expected.port, actual.user == nil, actual.password == nil, actual.fragment == nil else { return nil }
        let values = Dictionary(grouping: actual.queryItems ?? [], by: \.name)
        guard values["state"]?.count == 1, values["state"]?.first?.value == state else { return nil }
        return values
    }
    func authorizationCode(from callback: URL, state: String) -> String? {
        guard let values = callbackValues(callback, state: state), values["error"] == nil,
              values["code"]?.count == 1, let code = values["code"]?.first?.value, !code.isEmpty else { return nil }
        return code
    }
    func authorizationWasDenied(_ callback: URL, state: String) -> Bool {
        guard let values = callbackValues(callback, state: state) else { return false }
        return values["error"]?.count == 1 && values["error"]?.first?.value == "access_denied"
    }
    func exchange(code: String, verifier: String, completion: @escaping TokenResult) {
        tokenRequest(["grant_type": "authorization_code", "code": code, "code_verifier": verifier], completion: completion)
    }
    func user(token: GuangyaOAuthToken, completion: @escaping (Result<GuangyaAPIUser, GuangyaDriveError>) -> Void) {
        business("user/get_user_info", parameters: [:], token: token.accessToken) { result in
            completion(result.flatMap { data in
                guard let user = try? JSONDecoder().decode(GuangyaEnvelope<GuangyaAPIUser>.self, from: data).data,
                      !user.userId.isEmpty, user.userId == token.userID else { return .failure(.invalidResponse) }
                return .success(user)
            })
        }
    }
    func install(_ token: GuangyaOAuthToken, accountID: String) -> Bool {
        guard token.userID == accountID else { return false }
        invalidate(accountID)
        guard save(accountID, token) else { remove(accountID); return false }
        return true
    }
    func unlink(_ accountID: String) { remove(accountID); invalidate(accountID) }
    private func invalidate(_ accountID: String) {
        generations[accountID] = UUID()
        let pending = refreshing.removeValue(forKey: accountID) ?? []
        pending.forEach { $0(.failure(.authorization)) }
    }
    private func generation(_ accountID: String) -> UUID {
        if let value = generations[accountID] { return value }
        let value = UUID(); generations[accountID] = value; return value
    }

    private func accessToken(_ accountID: String, rejected: String? = nil, completion: @escaping TokenResult) {
        guard let stored = load(accountID), stored.userID == accountID else { completion(.failure(.authorization)); return }
        #if DEBUG
        print("[Guangya] Token needsRefresh=\(stored.expiresAt.timeIntervalSince(now()) <= 60) rejected=\(rejected != nil)")
        #endif
        if refreshing[accountID] != nil { refreshing[accountID]?.append(completion); return }
        if stored.expiresAt.timeIntervalSince(now()) > 60 && stored.accessToken != rejected {
            completion(.success(stored)); return
        }
        let epoch = generation(accountID)
        refreshing[accountID] = [completion]
        tokenRequest(["grant_type": "refresh_token", "refresh_token": stored.refreshToken]) { result in
            guard self.generation(accountID) == epoch else { return }
            var final = result
            switch result {
            case .success(let token):
                if token.userID != accountID { self.remove(accountID); final = .failure(.authorization) }
                else if !self.save(accountID, token) { self.remove(accountID); final = .failure(.storage) }
            case .failure(.authorization): self.remove(accountID)
            case .failure: break
            }
            let waiting = self.refreshing.removeValue(forKey: accountID) ?? []
            waiting.forEach { $0(final) }
        }
    }

    func listFolder(accountID: String, folderID: String, completion: @escaping (Result<[GuangyaAPIItem], GuangyaDriveError>) -> Void) {
        guard folderID.isEmpty || Self.validID(folderID) else { completion(.failure(.invalidResponse)); return }
        let epoch = generation(accountID)
        var files = [GuangyaAPIItem](), seen = Set<String>()
        var received = 0
        func page(_ index: Int) {
            guard index < 10_000 else { completion(.failure(.invalidResponse)); return }
            var parameters = ["page": String(index), "pageSize": "100", "orderBy": "0", "sortType": "0"]
            if !folderID.isEmpty { parameters["parentId"] = folderID }
            // Do not filter fileTypes=3: that would hide folders needed to navigate the library.
            self.authorized("file/get_file_list", parameters: parameters, accountID: accountID) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let data):
                    guard let value = try? JSONDecoder().decode(GuangyaEnvelope<GuangyaAPIPage>.self, from: data).data,
                          value.total >= 0, value.list.count <= 100, received <= Int.max - value.list.count else {
                        completion(.failure(.invalidResponse)); return
                    }
                    let previous = files.count
                    for item in value.list {
                        guard Self.validID(item.fileId), !item.fileName.isEmpty, [1, 2].contains(item.resType) else {
                            completion(.failure(.invalidResponse)); return
                        }
                        if seen.insert(item.fileId).inserted { files.append(item) }
                    }
                    received += value.list.count
                    if !value.list.isEmpty && files.count == previous { completion(.failure(.invalidResponse)); return }
                    if received >= value.total {
                        guard files.count >= value.total else { completion(.failure(.invalidResponse)); return }
                        completion(.success(files)); return
                    }
                    guard files.count > previous else { completion(.failure(.invalidResponse)); return }
                    page(index + 1)
                }
            }
        }
        page(0)
    }

    func fileURL(accountID: String, fileID: String, completion: @escaping (Result<URL, GuangyaDriveError>) -> Void) {
        guard Self.validID(fileID) else { completion(.failure(.invalidResponse)); return }
        authorized("file/get_res_download_url", parameters: ["fileId": fileID], accountID: accountID) { result in
            completion(result.flatMap { data in
                guard let link = try? JSONDecoder().decode(GuangyaEnvelope<GuangyaDownload>.self, from: data).data,
                      link.urlDuration > 0, let url = URL(string: link.signedURL) else { return .failure(.invalidResponse) }
                guard Self.validDownloadURL(url) else { return .failure(.insecureDownload) }
                // The CDN uses its signed URL. Never forward OAuth, client ID or signing headers.
                return .success(url)
            })
        }
    }
    static func validID(_ id: String) -> Bool { !id.isEmpty && id.utf8.allSatisfy { (48...57).contains($0) } }
    static func validDownloadURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host?.lowercased() else { return false }
        return ["guangyacdn.com", "guangyapan.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
    static func signature(clientID: String, timestamp: String, secret: String) -> String {
        // MD5 is required by this provider's wire protocol, not used for password storage.
        Insecure.MD5.hash(data: Data("client_id=\(clientID)&timestamp=\(timestamp)&secret=\(secret)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
    static func traceparent() -> String {
        "00-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() + "-" +
            UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16) + "-01"
    }

    private func authorized(_ endpoint: String, parameters: [String: String], accountID: String, rejected: String? = nil,
                            completion: @escaping (Result<Data, GuangyaDriveError>) -> Void) {
        let epoch = generation(accountID)
        accessToken(accountID, rejected: rejected) { result in
            guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let token):
                self.business(endpoint, parameters: parameters, token: token.accessToken,
                              valid: { self.generation(accountID) == epoch }) { result in
                    guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                    if case .failure(.authorization) = result, rejected == nil {
                        self.authorized(endpoint, parameters: parameters, accountID: accountID, rejected: token.accessToken, completion: completion)
                    } else { completion(result) }
                }
            }
        }
    }

    private func business(_ endpoint: String, parameters: [String: String], token: String, attempt: Int = 0,
                          valid: @escaping () -> Bool = { true }, completion: @escaping (Result<Data, GuangyaDriveError>) -> Void) {
        let current = now()
        let start = throttle ? max(current, nextStarts[endpoint] ?? current) : current
        nextStarts[endpoint] = start.addingTimeInterval(endpoint == "file/get_file_list" ? 0.22 : 0.55)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, start.timeIntervalSince(current))) {
            guard valid() else { completion(.failure(.authorization)); return }
            var components = URLComponents(string: "https://openapi.guangyapan.com/openapi/v1/" + endpoint)!
            components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = components.url else { completion(.failure(.invalidResponse)); return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let timestamp = String(Int64(self.now().timeIntervalSince1970))
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue(self.clientID, forHTTPHeaderField: "client_id")
            request.setValue(timestamp, forHTTPHeaderField: "timestamp")
            request.setValue(Self.signature(clientID: self.clientID, timestamp: timestamp, secret: self.secret), forHTTPHeaderField: "sign")
            request.setValue(Self.traceparent(), forHTTPHeaderField: "traceparent")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            self.send(request) { result in
                guard valid() else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let (response, data)):
                    Self.diagnose(endpoint, response: response, data: data)
                    if response.statusCode == 429 {
                        let delay = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
                        guard attempt < 2, delay <= 10 else { completion(.failure(.rateLimited)); return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, delay)) {
                            self.business(endpoint, parameters: parameters, token: token, attempt: attempt + 1, valid: valid, completion: completion)
                        }
                        return
                    }
                    if let failure = Self.businessError(status: response.statusCode, data: data) { completion(.failure(failure)) }
                    else { completion(.success(data)) }
                }
            }
        }
    }
    static func businessError(status: Int, data: Data) -> GuangyaDriveError? {
        if status == 401 { return .authorization }
        if status == 429 { return .rateLimited }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return status >= 500 ? .network : (status == 403 ? .permission : .invalidResponse)
        }
        let code: Int
        if let raw = object["code"] {
            guard let value = raw as? Int ?? (raw as? String).flatMap(Int.init) else { return .invalidResponse }
            code = value
        } else { code = 0 }
        switch code {
        case 0: break
        case 111: return .permission
        case 113: return .clockSkew
        case 116: return .signature
        case 117: return .authorization
        case 120, 112: return .configuration
        case 146, 149: return .notFound
        case 164, 430: return .membership
        case 167: return .restrictedFile
        case 101: return .network
        default: return .invalidResponse
        }
        if status == 403 { return .permission }
        if status == 404 { return .notFound }
        if status >= 500 { return .network }
        guard (200..<300).contains(status), object["data"] != nil else { return .invalidResponse }
        return nil
    }

    private func tokenRequest(_ values: [String: String], completion: @escaping TokenResult) {
        var body = values; body["client_id"] = clientID
        var request = URLRequest(url: URL(string: "https://openapi-account.guangyapan.com/v1/auth/token")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientID, forHTTPHeaderField: "x-client-id")
        request.setValue(projectID, forHTTPHeaderField: "x-project-id")
        request.setValue(deviceID, forHTTPHeaderField: "x-device-id")
        send(request) { result in
            completion(result.flatMap { response, data in
                Self.diagnose("token/" + (values["grant_type"] ?? "unknown"), response: response, data: data)
                guard response.statusCode == 200 else {
                    if response.statusCode == 429 { return .failure(.rateLimited) }
                    return .failure([400, 401].contains(response.statusCode) ? .authorization : .network)
                }
                struct Token: Decodable { let token_type: String; let access_token: String; let refresh_token: String; let expires_in: Double; let sub: String }
                guard let value = try? JSONDecoder().decode(Token.self, from: data), value.token_type.lowercased() == "bearer",
                      !value.access_token.isEmpty, !value.refresh_token.isEmpty, !value.sub.isEmpty,
                      value.expires_in.isFinite, value.expires_in > 0 else { return .failure(.invalidResponse) }
                return .success(GuangyaOAuthToken(accessToken: value.access_token, refreshToken: value.refresh_token,
                                                  expiresAt: self.now().addingTimeInterval(value.expires_in), userID: value.sub))
            })
        }
    }
    private func send(_ request: URLRequest, completion: @escaping (Result<(HTTPURLResponse, Data), GuangyaDriveError>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let response = response as? HTTPURLResponse, let data = data else { completion(.failure(.network)); return }
                completion(.success((response, data)))
            }
        }.resume()
    }

    /// Only protocol status codes are logged, never URLs, bodies, account IDs,
    /// authorization headers, tokens, signing secrets, or error descriptions.
    private static func diagnose(_ endpoint: String, response: HTTPURLResponse, data: Data) {
        #if DEBUG
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let raw = object?["code"] ?? object?["error"]
        let value = raw.map { String(describing: $0) } ?? "none"
        let code = value.range(of: "^[A-Za-z0-9_.-]{1,64}$", options: .regularExpression) != nil ? value : "unrecognized"
        print("[Guangya] \(endpoint) HTTP=\(response.statusCode) code=\(code)")
        #endif
    }
}

private final class GuangyaRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
