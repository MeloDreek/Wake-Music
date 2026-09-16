import Foundation

enum Pan123DriveError: Error, Equatable {
    case authorization, storage, invalidResponse, permission, notFound, rateLimited, network
    case configuration, quota, restrictedFile, insecureDownload
}

struct Pan123OAuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}
struct Pan123APIUser: Decodable {
    let uid: Int64
    let nickname: String
    let mail: String?
    let passport: String?
}
struct Pan123APIItem: Decodable {
    let fileId: Int64
    let filename: String
    let type: Int
    let size: Int64
    let status: Int
    let trashed: Int
    let createAt: String?
    let updateAt: String?
}
private struct Pan123Page: Decodable { let lastFileId: Int64; let fileList: [Pan123APIItem] }
private struct Pan123Envelope<T: Decodable>: Decodable { let data: T }

/// Official third-party OAuth API. Main-queue entry points/callbacks; no mutation endpoints.
final class Pan123DriveAPI {
    typealias TokenResult = (Result<Pan123OAuthToken, Pan123DriveError>) -> Void
    let redirectURI: String
    private let clientID: String
    private let secret: String
    private let load: (String) -> Pan123OAuthToken?
    private let save: (String, Pan123OAuthToken) -> Bool
    private let remove: (String) -> Void
    private let now: () -> Date
    private let throttle: Bool
    private let session: URLSession
    private var generations: [String: UUID] = [:]
    private var refreshing: [String: [TokenResult]] = [:]
    private var nextStarts: [String: Date] = [:]

    init(clientID: String, secret: String, redirectURI: String,
         configuration: URLSessionConfiguration = .ephemeral, now: @escaping () -> Date = Date.init,
         throttle: Bool = true, load: @escaping (String) -> Pan123OAuthToken?,
         save: @escaping (String, Pan123OAuthToken) -> Bool, remove: @escaping (String) -> Void) {
        self.clientID = clientID; self.secret = secret; self.redirectURI = redirectURI
        self.load = load; self.save = save; self.remove = remove; self.now = now; self.throttle = throttle
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: Pan123RedirectBlocker(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }

    func authorizationURL(state: String) -> URL? {
        guard !clientID.isEmpty, !secret.isEmpty, !state.isEmpty else { return nil }
        var url = URLComponents(string: "https://yun.123pan.com/auth")!
        // This scope is fixed in the vendor specification. Only read operations are implemented.
        url.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                          URLQueryItem(name: "redirect_uri", value: redirectURI),
                          URLQueryItem(name: "scope", value: "user:base,file:all:read,file:all:write"),
                          URLQueryItem(name: "state", value: state)]
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return url.url
    }
    private func callbackValues(_ callback: URL, state: String) -> [String: [URLQueryItem]]? {
        guard !state.isEmpty, let expected = URLComponents(string: redirectURI),
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
    func exchange(code: String, completion: @escaping TokenResult) {
        tokenRequest(["grant_type": "authorization_code", "code": code, "redirect_uri": redirectURI], completion: completion)
    }
    func user(token: Pan123OAuthToken, completion: @escaping (Result<Pan123APIUser, Pan123DriveError>) -> Void) {
        business("/api/v1/user/info", parameters: [:], token: token.accessToken) { result in
            completion(result.flatMap { data in
                guard let user = try? JSONDecoder().decode(Pan123Envelope<Pan123APIUser>.self, from: data).data,
                      user.uid > 0 else { return .failure(.invalidResponse) }
                return .success(user)
            })
        }
    }
    func install(_ token: Pan123OAuthToken, accountID: String) -> Bool {
        guard Self.validID(accountID), !token.accessToken.isEmpty, !token.refreshToken.isEmpty else { return false }
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
        guard let stored = load(accountID) else { completion(.failure(.authorization)); return }
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
                if !self.save(accountID, token) { self.remove(accountID); final = .failure(.storage) }
            case .failure(.authorization): self.remove(accountID)
            case .failure: break
            }
            let waiting = self.refreshing.removeValue(forKey: accountID) ?? []
            waiting.forEach { $0(final) }
        }
    }
    func user(accountID: String, completion: @escaping (Result<Pan123APIUser, Pan123DriveError>) -> Void) {
        authorized("/api/v1/user/info", parameters: [:], accountID: accountID) { result in
            completion(result.flatMap { data in
                guard let user = try? JSONDecoder().decode(Pan123Envelope<Pan123APIUser>.self, from: data).data,
                      String(user.uid) == accountID else { return .failure(.invalidResponse) }
                return .success(user)
            })
        }
    }

    func listFolder(accountID: String, folderID: String, completion: @escaping (Result<[Pan123APIItem], Pan123DriveError>) -> Void) {
        guard Self.validID(folderID) else { completion(.failure(.invalidResponse)); return }
        let epoch = generation(accountID)
        var items = [Pan123APIItem](), seen = Set<Int64>(), cursors = Set<Int64>()
        func page(_ cursor: Int64?, count: Int) {
            guard count < 10_000 else { completion(.failure(.invalidResponse)); return }
            var parameters = ["parentFileId": folderID, "limit": "100"]
            if let cursor = cursor { parameters["lastFileId"] = String(cursor) }
            self.authorized("/api/v2/file/list", parameters: parameters, accountID: accountID) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let data):
                    guard let value = try? JSONDecoder().decode(Pan123Envelope<Pan123Page>.self, from: data).data,
                          value.fileList.count <= 100 else { completion(.failure(.invalidResponse)); return }
                    for item in value.fileList {
                        guard item.fileId > 0, !item.filename.isEmpty, [0, 1].contains(item.type),
                              item.size >= 0 else { completion(.failure(.invalidResponse)); return }
                        // V2 returns trashed items too. Do not expose them in the active library.
                        if seen.insert(item.fileId).inserted && item.trashed == 0 { items.append(item) }
                    }
                    if value.lastFileId == -1 { completion(.success(items)); return }
                    guard value.lastFileId >= 0, cursors.insert(value.lastFileId).inserted else {
                        completion(.failure(.invalidResponse)); return
                    }
                    page(value.lastFileId, count: count + 1)
                }
            }
        }
        page(nil, count: 0)
    }
    func fileURL(accountID: String, fileID: String, completion: @escaping (Result<URL, Pan123DriveError>) -> Void) {
        guard Self.validID(fileID) else { completion(.failure(.invalidResponse)); return }
        authorized("/api/v1/file/download_info", parameters: ["fileId": fileID], accountID: accountID) { result in
            completion(result.flatMap { data in
                struct Link: Decodable { let downloadUrl: String }
                guard let link = try? JSONDecoder().decode(Pan123Envelope<Link>.self, from: data).data,
                      let url = URL(string: link.downloadUrl) else { return .failure(.invalidResponse) }
                guard Self.validDownloadURL(url) else { return .failure(.insecureDownload) }
                return .success(url)
            })
        }
    }
    static func validID(_ id: String) -> Bool { !id.isEmpty && id.utf8.allSatisfy { (48...57).contains($0) } && Int64(id) != nil }
    static func validDownloadURL(_ url: URL) -> Bool {
        // The vendor returns signed links on multiple CDN families. No OAuth header is sent to them.
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host?.lowercased(),
              host.contains("."), !host.hasSuffix(".local"), !host.hasSuffix(".localhost"),
              !host.hasSuffix(".internal"), !host.contains(":"),
              !host.allSatisfy({ $0.isNumber || $0 == "." }) else { return false }
        return true
    }
    static func timestamp(_ text: String?) -> TimeInterval {
        guard let text = text else { return 0 }
        if let date = ISO8601DateFormatter().date(from: text) { return date.timeIntervalSince1970 }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return format.date(from: text)?.timeIntervalSince1970 ?? 0
    }
    private func authorized(_ endpoint: String, parameters: [String: String], accountID: String, rejected: String? = nil,
                            completion: @escaping (Result<Data, Pan123DriveError>) -> Void) {
        let epoch = generation(accountID)
        accessToken(accountID, rejected: rejected) { result in
            guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let token):
                self.business(endpoint, parameters: parameters, token: token.accessToken, valid: { self.generation(accountID) == epoch }) { result in
                    guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                    if case .failure(.authorization) = result, rejected == nil {
                        self.authorized(endpoint, parameters: parameters, accountID: accountID, rejected: token.accessToken, completion: completion)
                    } else { completion(result) }
                }
            }
        }
    }
    private func business(_ endpoint: String, parameters: [String: String], token: String,
                          valid: @escaping () -> Bool = { true }, completion: @escaping (Result<Data, Pan123DriveError>) -> Void) {
        let current = now()
        let start = throttle ? max(current, nextStarts[endpoint] ?? current) : current
        nextStarts[endpoint] = start.addingTimeInterval(endpoint == "/api/v2/file/list" ? 0.08 : 0.22)
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, start.timeIntervalSince(current))) {
            guard valid() else { completion(.failure(.authorization)); return }
            var components = URLComponents(string: "https://open-api.123pan.com" + endpoint)!
            components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let url = components.url else { completion(.failure(.invalidResponse)); return }
            var request = URLRequest(url: url)
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            request.setValue("open_platform", forHTTPHeaderField: "Platform")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            self.send(request) { result in
                guard valid() else { completion(.failure(.authorization)); return }
                completion(result.flatMap { response, data in
                    if let error = Self.businessError(status: response.statusCode, data: data) { return .failure(error) }
                    return .success(data)
                })
            }
        }
    }
    static func businessError(status: Int, data: Data) -> Pan123DriveError? {
        if status == 401 { return .authorization }
        if status == 429 { return .rateLimited }
        if status == 403 { return .permission }
        if status >= 500 { return .network }
        guard (200..<300).contains(status), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let code = object["code"] as? Int else { return .invalidResponse }
        switch code {
        case 0: return object["data"] == nil ? .invalidResponse : nil
        case 401: return .authorization
        case 429: return .rateLimited
        case 5066: return .notFound
        case 5113: return .quota
        default: return .invalidResponse
        }
    }
    private func tokenRequest(_ values: [String: String], completion: @escaping TokenResult) {
        var query = values; query["client_id"] = clientID; query["client_secret"] = secret
        // The official token endpoint requires POST with query parameters, not JSON fields.
        // Never log this URL; redirects are disabled so secrets cannot be forwarded.
        var components = URLComponents(string: "https://open-api.123pan.com/api/v1/oauth2/access_token")!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { completion(.failure(.configuration)); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("open_platform", forHTTPHeaderField: "Platform")
        send(request) { result in
            completion(result.flatMap { response, data in
                if response.statusCode == 429 { return .failure(.rateLimited) }
                guard response.statusCode == 200 else { return .failure([400,401].contains(response.statusCode) ? .authorization : .network) }
                struct Token: Decodable { let token_type: String; let access_token: String; let refresh_token: String; let expires_in: Double }
                guard let token = try? JSONDecoder().decode(Token.self, from: data), token.token_type.lowercased() == "bearer",
                      !token.access_token.isEmpty, !token.refresh_token.isEmpty, token.expires_in.isFinite, token.expires_in > 0 else {
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                    if object?["error"] as? String == "invalid_grant" { return .failure(.authorization) }
                    if object?["error"] as? String == "invalid_client" { return .failure(.configuration) }
                    return .failure(Self.businessError(status: response.statusCode, data: data) ?? .invalidResponse)
                }
                return .success(Pan123OAuthToken(accessToken: token.access_token, refreshToken: token.refresh_token,
                                                expiresAt: self.now().addingTimeInterval(token.expires_in)))
            })
        }
    }
    private func send(_ request: URLRequest, completion: @escaping (Result<(HTTPURLResponse, Data), Pan123DriveError>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let response = response as? HTTPURLResponse, let data = data else { completion(.failure(.network)); return }
                completion(.success((response, data)))
            }
        }.resume()
    }
}
private final class Pan123RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
