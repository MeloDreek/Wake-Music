import Foundation

enum BoxDriveError: Error, Equatable {
    case authorization, storage, invalidResponse, permission, notFound, notReady, rateLimited, network
}

struct BoxOAuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct BoxAPIUser: Decodable {
    let id: String
    let login: String
    let name: String
}

struct BoxAPIItem: Decodable {
    let type: String
    let id: String
    let name: String
    let size: Int64?
    let created_at: String?
    let modified_at: String?
}

private struct BoxAPIPage: Decodable {
    let entries: [BoxAPIItem]
    let next_marker: String?
}

/// Foundation-only client. All entry points, storage and completions run on the main queue.
/// A single refresh per account is essential: Box refresh tokens are single-use.
final class BoxDriveAPI {
    typealias TokenResult = (Result<BoxOAuthToken, BoxDriveError>) -> Void
    private let clientID: String
    private let clientSecret: String
    private let redirectURI: String
    private let load: (String) -> BoxOAuthToken?
    private let save: (String, BoxOAuthToken) -> Bool
    private let remove: (String) -> Void
    private let redirectBlocker = BoxRedirectBlocker()
    private let session: URLSession
    private var generations: [String: UUID] = [:]
    private var refreshing: [String: [TokenResult]] = [:]

    init(clientID: String, clientSecret: String, redirectURI: String,
         configuration: URLSessionConfiguration = .ephemeral,
         load: @escaping (String) -> BoxOAuthToken?,
         save: @escaping (String, BoxOAuthToken) -> Bool,
         remove: @escaping (String) -> Void) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.load = load
        self.save = save
        self.remove = remove
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: redirectBlocker, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func authorizationURL(state: String) -> URL? {
        var url = URLComponents(string: "https://account.box.com/api/oauth2/authorize")!
        url.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                          URLQueryItem(name: "response_type", value: "code"),
                          URLQueryItem(name: "redirect_uri", value: redirectURI),
                          URLQueryItem(name: "scope", value: "root_readwrite"),
                          URLQueryItem(name: "state", value: state)]
        return url.url
    }

    func authorizationCode(from callback: URL, state: String) -> String? {
        guard let values = callbackParameters(callback, state: state),
              values["error"] == nil, values["code"]?.count == 1,
              let code = values["code"]?.first?.value, !code.isEmpty else { return nil }
        return code
    }

    func authorizationWasDenied(_ callback: URL, state: String) -> Bool {
        guard let values = callbackParameters(callback, state: state) else { return false }
        return values["error"]?.count == 1 && values["error"]?.first?.value == "access_denied"
    }

    private func callbackParameters(_ callback: URL, state: String) -> [String: [URLQueryItem]]? {
        guard let expected = URLComponents(string: redirectURI),
              let actual = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              actual.scheme == expected.scheme, actual.host == expected.host,
              actual.path == expected.path, actual.port == expected.port,
              actual.user == nil, actual.password == nil, actual.fragment == nil else { return nil }
        let values = Dictionary(grouping: actual.queryItems ?? [], by: \.name)
        guard values["state"]?.count == 1, values["state"]?.first?.value == state else { return nil }
        return values
    }

    func exchange(code: String, completion: @escaping TokenResult) {
        tokenRequest(["grant_type": "authorization_code", "code": code, "redirect_uri": redirectURI], completion: completion)
    }

    func user(token: BoxOAuthToken, completion: @escaping (Result<BoxAPIUser, BoxDriveError>) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.box.com/2.0/users/me?fields=id,login,name")!)
        request.setValue("Bearer " + token.accessToken, forHTTPHeaderField: "Authorization")
        send(request) { result in
            completion(result.flatMap { response, data in
                guard response.statusCode == 200 else { return .failure(Self.error(response.statusCode)) }
                guard let user = try? JSONDecoder().decode(BoxAPIUser.self, from: data), Self.validID(user.id) else {
                    return .failure(.invalidResponse)
                }
                return .success(user)
            })
        }
    }

    func install(_ token: BoxOAuthToken, accountID: String) -> Bool {
        invalidate(accountID)
        guard save(accountID, token) else { remove(accountID); return false }
        return true
    }

    func unlink(_ accountID: String) {
        remove(accountID)
        invalidate(accountID)
    }

    private func invalidate(_ accountID: String) {
        generations[accountID] = UUID()
        let waiting = refreshing.removeValue(forKey: accountID) ?? []
        waiting.forEach { $0(.failure(.authorization)) }
    }

    private func generation(_ accountID: String) -> UUID {
        if let value = generations[accountID] { return value }
        let value = UUID()
        generations[accountID] = value
        return value
    }

    private func accessToken(_ accountID: String, rejectedToken: String? = nil, completion: @escaping TokenResult) {
        guard let stored = load(accountID) else { completion(.failure(.authorization)); return }
        if refreshing[accountID] != nil {
            refreshing[accountID]?.append(completion)
            return
        }
        if stored.expiresAt.timeIntervalSinceNow > 60 && stored.accessToken != rejectedToken {
            completion(.success(stored))
            return
        }
        let epoch = generation(accountID)
        refreshing[accountID] = [completion]
        tokenRequest(["grant_type": "refresh_token", "refresh_token": stored.refreshToken]) { result in
            guard self.generation(accountID) == epoch else { return }
            var final = result
            switch result {
            case .success(let token):
                // Persist the rotated refresh token before letting any waiting request proceed.
                if !self.save(accountID, token) {
                    self.remove(accountID)
                    final = .failure(.storage)
                }
            case .failure(.authorization): self.remove(accountID)
            case .failure: break
            }
            let waiting = self.refreshing.removeValue(forKey: accountID) ?? []
            waiting.forEach { $0(final) }
        }
    }

    func listFolder(accountID: String, folderID: String, completion: @escaping (Result<[BoxAPIItem], BoxDriveError>) -> Void) {
        guard Self.validID(folderID) else { completion(.failure(.invalidResponse)); return }
        let epoch = generation(accountID)
        var items = [BoxAPIItem]()
        var seenItems = Set<String>()
        var seenMarkers = Set<String>()
        func page(_ marker: String?) {
            var url = URLComponents(string: "https://api.box.com/2.0/folders/\(folderID)/items")!
            url.queryItems = [URLQueryItem(name: "usemarker", value: "true"), URLQueryItem(name: "limit", value: "1000"),
                              URLQueryItem(name: "fields", value: "id,type,name,size,created_at,modified_at")]
            if let marker = marker { url.queryItems?.append(URLQueryItem(name: "marker", value: marker)) }
            self.authorized(URLRequest(url: url.url!), accountID: accountID) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let (response, data)):
                    guard response.statusCode == 200, let decoded = try? JSONDecoder().decode(BoxAPIPage.self, from: data) else {
                        completion(.failure(.invalidResponse)); return
                    }
                    for item in decoded.entries where (item.type == "file" || item.type == "folder") && Self.validID(item.id) {
                        if seenItems.insert(item.type + ":" + item.id).inserted { items.append(item) }
                    }
                    if let next = decoded.next_marker, !next.isEmpty {
                        guard seenMarkers.insert(next).inserted else { completion(.failure(.invalidResponse)); return }
                        page(next)
                    } else { completion(.success(items)) }
                }
            }
        }
        page(nil)
    }

    /// Read only the Location header. Never download the full audio into memory or forward OAuth to a CDN.
    func fileURL(accountID: String, fileID: String, completion: @escaping (Result<URL, BoxDriveError>) -> Void) {
        guard Self.validID(fileID) else { completion(.failure(.invalidResponse)); return }
        let epoch = generation(accountID)
        let request = URLRequest(url: URL(string: "https://api.box.com/2.0/files/\(fileID)/content")!)
        func attempt(_ retry: Int) {
            self.authorized(request, accountID: accountID) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let (response, _)):
                    if [302, 303, 307, 308].contains(response.statusCode),
                       let location = response.value(forHTTPHeaderField: "Location"), let url = URL(string: location),
                       Self.validDownloadURL(url) {
                        completion(.success(url))
                    } else if response.statusCode == 202 || response.statusCode == 429 {
                        // A freshly uploaded file may not be ready. Respect Retry-After with a bounded retry.
                        let delay = TimeInterval(response.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
                        guard retry < 2, delay <= 10 else {
                            completion(.failure(response.statusCode == 429 ? .rateLimited : .notReady)); return
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, delay)) {
                            guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                            attempt(retry + 1)
                        }
                    } else { completion(.failure(.invalidResponse)) }
                }
            }
        }
        attempt(0)
    }

    static func validID(_ id: String) -> Bool { !id.isEmpty && id.utf8.allSatisfy { (48...57).contains($0) } }
    static func validDownloadURL(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              let host = url.host?.lowercased() else { return false }
        return host.hasSuffix(".boxcloud.com") || host.hasSuffix(".box.com")
    }

    private func authorized(_ request: URLRequest, accountID: String, rejectedToken: String? = nil,
                            completion: @escaping (Result<(HTTPURLResponse, Data), BoxDriveError>) -> Void) {
        let epoch = generation(accountID)
        accessToken(accountID, rejectedToken: rejectedToken) { result in
            guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let token):
                var authenticated = request
                authenticated.setValue("Bearer " + token.accessToken, forHTTPHeaderField: "Authorization")
                self.send(authenticated) { result in
                    guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                    if case .success(let (response, _)) = result {
                        if response.statusCode == 401 && rejectedToken == nil {
                            self.authorized(request, accountID: accountID, rejectedToken: token.accessToken, completion: completion)
                            return
                        }
                        if response.statusCode >= 400 && response.statusCode != 429 {
                            completion(.failure(Self.error(response.statusCode))); return
                        }
                        if response.statusCode == 429 && !request.url!.path.hasSuffix("/content") {
                            completion(.failure(.rateLimited)); return
                        }
                    }
                    completion(result)
                }
            }
        }
    }

    private func tokenRequest(_ values: [String: String], completion: @escaping TokenResult) {
        var form = values
        form["client_id"] = clientID
        form["client_secret"] = clientSecret
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = form.sorted { $0.key < $1.key }.map {
            $0.key.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" + $0.value.addingPercentEncoding(withAllowedCharacters: allowed)!
        }.joined(separator: "&")
        var request = URLRequest(url: URL(string: "https://api.box.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        send(request) { result in
            completion(result.flatMap { response, data in
                guard response.statusCode == 200 else {
                    return .failure(response.statusCode == 400 || response.statusCode == 401 ? .authorization : Self.error(response.statusCode))
                }
                struct Response: Decodable { let access_token: String; let refresh_token: String; let expires_in: Double }
                guard let value = try? JSONDecoder().decode(Response.self, from: data),
                      !value.access_token.isEmpty, !value.refresh_token.isEmpty, value.expires_in > 0 else { return .failure(.invalidResponse) }
                return .success(BoxOAuthToken(accessToken: value.access_token, refreshToken: value.refresh_token,
                                              expiresAt: Date().addingTimeInterval(value.expires_in)))
            })
        }
    }

    private func send(_ request: URLRequest, completion: @escaping (Result<(HTTPURLResponse, Data), BoxDriveError>) -> Void) {
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let response = response as? HTTPURLResponse else {
                    completion(.failure(.network)); return
                }
                completion(.success((response, data ?? Data())))
            }
        }.resume()
    }

    private static func error(_ status: Int) -> BoxDriveError {
        switch status {
        case 401: return .authorization
        case 403: return .permission
        case 404: return .notFound
        case 429: return .rateLimited
        default: return .network
        }
    }
}

private final class BoxRedirectBlocker: NSObject, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // The resolver expects a redirect, never an audio body. Also bound JSON response sizes.
        if let response = response as? HTTPURLResponse,
           (response.url?.path.hasSuffix("/content") == true && response.statusCode == 200) || response.expectedContentLength > 16_000_000 {
            completionHandler(.cancel)
        } else { completionHandler(.allow) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
