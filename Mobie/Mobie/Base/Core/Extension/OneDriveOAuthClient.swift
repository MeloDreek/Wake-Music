import Foundation
import CryptoKit
import Security

enum OneDriveOAuthError: Error, Equatable {
    case authorization, invalidResponse, network, storage, accountMismatch, configuration
}

struct OneDriveOAuthToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let homeAccountID: String?
}

struct OneDriveOAuthUser: Decodable {
    let id: String
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?
}

struct OneDrivePKCE {
    let verifier: String
    let state: String
    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    init?(verifier: String? = nil, state: String? = nil) {
        func random() -> String? {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
            return Self.base64URL(Data(bytes))
        }
        guard let verifier = verifier ?? random(), let state = state ?? random(),
              (43...128).contains(verifier.count), !state.isEmpty,
              verifier.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~").contains($0) }) else { return nil }
        self.verifier = verifier
        self.state = state
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// Public-client OAuth code + PKCE. No client secret, broker, password or ID-token parsing.
/// Public methods, token storage and completions are confined to the main queue.
final class OneDriveOAuthClient {
    typealias TokenResult = (Result<OneDriveOAuthToken, OneDriveOAuthError>) -> Void
    typealias ResponseResult = (Result<(HTTPURLResponse, Data), OneDriveOAuthError>) -> Void
    private let clientID: String
    let redirectURI: String
    private let load: (String) -> OneDriveOAuthToken?
    private let save: (String, OneDriveOAuthToken) -> Bool
    private let remove: (String) -> Void
    private let now: () -> Date
    private let session: URLSession
    private var generations: [String: UUID] = [:]
    private var refreshing: [String: [TokenResult]] = [:]
    private let scopes = "offline_access User.Read Files.Read"

    init(clientID: String, redirectURI: String, configuration: URLSessionConfiguration = .ephemeral,
         now: @escaping () -> Date = Date.init,
         load: @escaping (String) -> OneDriveOAuthToken?,
         save: @escaping (String, OneDriveOAuthToken) -> Bool,
         remove: @escaping (String) -> Void) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.load = load
        self.save = save
        self.remove = remove
        self.now = now
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: OneDriveOAuthRedirectBlocker(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func authorizationURL(_ pkce: OneDrivePKCE) -> URL? {
        guard !clientID.isEmpty, let redirect = URLComponents(string: redirectURI),
              let scheme = redirect.scheme, scheme != "http", scheme != "https", redirect.host != nil else { return nil }
        var url = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        url.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                          URLQueryItem(name: "response_type", value: "code"),
                          URLQueryItem(name: "response_mode", value: "query"),
                          URLQueryItem(name: "redirect_uri", value: redirectURI),
                          URLQueryItem(name: "scope", value: scopes),
                          URLQueryItem(name: "state", value: pkce.state),
                          URLQueryItem(name: "code_challenge", value: pkce.challenge),
                          URLQueryItem(name: "code_challenge_method", value: "S256"),
                          URLQueryItem(name: "prompt", value: "select_account")]
        return url.url
    }

    func authorizationCode(from callback: URL, state: String) -> String? {
        guard let values = callbackParameters(callback, state: state), values["error"] == nil,
              values["code"]?.count == 1, let code = values["code"]?.first?.value, !code.isEmpty else { return nil }
        return code
    }

    func authorizationWasDenied(_ callback: URL, state: String) -> Bool {
        guard let values = callbackParameters(callback, state: state) else { return false }
        return values["error"]?.count == 1 && values["error"]?.first?.value == "access_denied"
    }

    private func callbackParameters(_ callback: URL, state: String) -> [String: [URLQueryItem]]? {
        guard !state.isEmpty, let expected = URLComponents(string: redirectURI),
              let actual = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              actual.scheme == expected.scheme, actual.host == expected.host,
              actual.path == expected.path, actual.port == expected.port,
              actual.user == nil, actual.password == nil, actual.fragment == nil else { return nil }
        let values = Dictionary(grouping: actual.queryItems ?? [], by: \.name)
        guard values["state"]?.count == 1, values["state"]?.first?.value == state else { return nil }
        return values
    }

    func exchange(code: String, verifier: String, completion: @escaping TokenResult) {
        guard !code.isEmpty, OneDrivePKCE(verifier: verifier) != nil else { completion(.failure(.configuration)); return }
        tokenRequest(["grant_type": "authorization_code", "code": code, "code_verifier": verifier,
                      "redirect_uri": redirectURI], completion: completion)
    }

    func user(token: OneDriveOAuthToken, completion: @escaping (Result<OneDriveOAuthUser, OneDriveOAuthError>) -> Void) {
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me?$select=id,displayName,mail,userPrincipalName")!)
        request.setValue("Bearer " + token.accessToken, forHTTPHeaderField: "Authorization")
        send(request) { result in
            completion(result.flatMap { response, data in
                guard response.statusCode == 200 else { return .failure(.authorization) }
                guard let user = try? JSONDecoder().decode(OneDriveOAuthUser.self, from: data), !user.id.isEmpty else { return .failure(.invalidResponse) }
                return .success(user)
            })
        }
    }

    func install(_ token: OneDriveOAuthToken, accountID: String) -> Bool {
        guard !accountID.isEmpty else { return false }
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

    func accessToken(_ accountID: String, rejectedToken: String? = nil, completion: @escaping TokenResult) {
        guard !accountID.isEmpty, let stored = load(accountID), !stored.refreshToken.isEmpty else {
            completion(.failure(.authorization)); return
        }
        if refreshing[accountID] != nil { refreshing[accountID]?.append(completion); return }
        if stored.expiresAt.timeIntervalSince(now()) > 60 && stored.accessToken != rejectedToken {
            completion(.success(stored)); return
        }
        let epoch = generation(accountID)
        refreshing[accountID] = [completion]
        tokenRequest(["grant_type": "refresh_token", "refresh_token": stored.refreshToken], previous: stored) { result in
            guard self.generation(accountID) == epoch else { return }
            var final = result
            switch result {
            case .success(let token):
                if !self.save(accountID, token) { self.remove(accountID); final = .failure(.storage) }
            case .failure(.authorization), .failure(.accountMismatch): self.remove(accountID)
            case .failure: break
            }
            let waiting = self.refreshing.removeValue(forKey: accountID) ?? []
            waiting.forEach { $0(final) }
        }
    }

    /// Bearer tokens only go to Microsoft Graph. OAuth/API redirects are never followed.
    func authorizedGraphRequest(accountID: String, url: URL, completion: @escaping ResponseResult) {
        guard url.scheme == "https", url.host == "graph.microsoft.com", url.port == nil || url.port == 443,
              url.user == nil, url.password == nil, url.fragment == nil else { completion(.failure(.invalidResponse)); return }
        let epoch = generation(accountID)
        func attempt(rejectedToken: String? = nil) {
            accessToken(accountID, rejectedToken: rejectedToken) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let token):
                    var request = URLRequest(url: url)
                    request.setValue("Bearer " + token.accessToken, forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    self.send(request) { result in
                        guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                        if case .success(let (response, _)) = result, response.statusCode == 401 {
                            if rejectedToken == nil { attempt(rejectedToken: token.accessToken) }
                            else { completion(.failure(.authorization)) }
                        } else { completion(result) }
                    }
                }
            }
        }
        attempt()
    }

    private func tokenRequest(_ fields: [String: String], previous: OneDriveOAuthToken? = nil, completion: @escaping TokenResult) {
        var values = fields
        values["client_id"] = clientID
        values["scope"] = scopes
        values["client_info"] = "1"
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        request.httpBody = values.sorted(by: { $0.key < $1.key }).map {
            ($0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + "=" +
            ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&").data(using: .utf8)
        send(request) { result in
            completion(result.flatMap { response, data in
                guard response.statusCode == 200 else {
                    return .failure([400, 401, 403].contains(response.statusCode) ? .authorization : .network)
                }
                guard let body = try? JSONDecoder().decode(TokenResponse.self, from: data),
                      body.token_type.lowercased() == "bearer", !body.access_token.isEmpty,
                      body.expires_in > 0, body.expires_in.isFinite,
                      let refresh = body.refresh_token ?? previous?.refreshToken, !refresh.isEmpty else { return .failure(.invalidResponse) }
                if let priorHomeID = previous?.homeAccountID, let nextHomeID = body.homeAccountID,
                   priorHomeID != nextHomeID { return .failure(.accountMismatch) }
                return .success(OneDriveOAuthToken(accessToken: body.access_token, refreshToken: refresh,
                                                   expiresAt: self.now().addingTimeInterval(body.expires_in),
                                                   homeAccountID: body.homeAccountID ?? previous?.homeAccountID))
            })
        }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let token_type: String
        let expires_in: TimeInterval
        let client_info: String?
        var homeAccountID: String? {
            guard let text = client_info else { return nil }
            var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
            guard let data = Data(base64Encoded: base64), let info = try? JSONDecoder().decode(ClientInfo.self, from: data),
                  !info.uid.isEmpty, !info.utid.isEmpty else { return nil }
            return info.uid + "." + info.utid
        }
    }
    private struct ClientInfo: Decodable { let uid: String; let utid: String }

    private func send(_ request: URLRequest, completion: @escaping ResponseResult) {
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let response = response as? HTTPURLResponse, let data = data else {
                    completion(.failure(.network)); return
                }
                completion(.success((response, data)))
            }
        }.resume()
    }
}

private final class OneDriveOAuthRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
