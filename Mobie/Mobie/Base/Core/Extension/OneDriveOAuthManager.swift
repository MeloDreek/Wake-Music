import UIKit
import AuthenticationServices
import Security
import AppGroupKit
import KakaFoundation
import KakaUIKit

/// System browser authorization shared by iOS and Mac Catalyst. Tokens stay in Keychain.
final class OneDriveOAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OneDriveOAuthManager()
    private override init() { super.init() }
    private var authorizationSession: ASWebAuthenticationSession?
    private var authorizationWindow: UIWindow?
    private var authorizationID: UUID?
    private var handledCallback = false
    private let keychainService = (Bundle.main.bundleIdentifier ?? "Wakemusic") + ".onedrive.oauth"
    private lazy var client = OneDriveOAuthClient(clientID: OneDrive_ClientID, redirectURI: OneDrive_RedirectUri,
                                                 load: { [weak self] in self?.loadToken($0) },
                                                 save: { [weak self] in self?.storeToken($1, accountID: $0) ?? false },
                                                 remove: { [weak self] in self?.removeToken($0) })

    // ASWebAuthenticationSession handles live callbacks; never log stale authorization URLs.
    static func isCallback(_ url: URL) -> Bool { url.scheme == URL(string: OneDrive_RedirectUri)?.scheme }

    func authorize(from controller: UIViewController, replacing previous: OneDriveUserModel? = nil,
                   completion: @escaping (Result<OneDriveUserModel, KakaError>) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.authorize(from: controller, replacing: previous, completion: completion) }
            return
        }
        guard authorizationID == nil, let window = controller.view.window else { completion(.failure(.youhaveCanceled)); return }
        guard let scheme = URL(string: OneDrive_RedirectUri)?.scheme, let pkce = OneDrivePKCE(),
              let url = client.authorizationURL(pkce) else { completion(.failure(.tokenExpiredAuthAgain)); return }
        let attempt = UUID()
        authorizationID = attempt
        handledCallback = false
        authorizationWindow = window
        let finish: (Result<OneDriveUserModel, KakaError>) -> Void = { result in
            guard self.authorizationID == attempt else { return }
            self.authorizationSession = nil
            self.authorizationWindow = nil
            self.authorizationID = nil
            completion(result)
        }
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
            DispatchQueue.main.async {
                guard self.authorizationID == attempt, !self.handledCallback else { return }
                self.handledCallback = true
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    finish(.failure(.youhaveCanceled)); return
                }
                if error == nil, let callback = callback, self.client.authorizationWasDenied(callback, state: pkce.state) {
                    finish(.failure(.youhaveCanceled)); return
                }
                guard error == nil, let callback = callback,
                      let code = self.client.authorizationCode(from: callback, state: pkce.state) else {
                    finish(.failure(.tokenExpiredAuthAgain)); return
                }
                self.client.exchange(code: code, verifier: pkce.verifier) { result in
                    guard self.authorizationID == attempt else { return }
                    switch result {
                    case .failure(let error): finish(.failure(self.convert(error)))
                    case .success(let token):
                        self.client.user(token: token) { result in
                            guard self.authorizationID == attempt else { return }
                            switch result {
                            case .failure(let error): finish(.failure(self.convert(error)))
                            case .success(let profile):
                                // Removing the old connection while its login is open cancels replacement.
                                if let oldID = previous?.account?.msalID,
                                   !ConnectConfigManager.shared.connectedModels.contains(where: { $0.onedriveUser?.account?.msalID == oldID }) {
                                    finish(.failure(.youhaveCanceled)); return
                                }
                                let previousIdentityMatches = Self.matches(previous, profile: profile, token: token)
                                let existing = ConnectConfigManager.shared.connectedModels.compactMap(\.onedriveUser).first {
                                    Self.matches($0, profile: profile, token: token)
                                }
                                let retained = previousIdentityMatches ? previous : existing
                                let accountID = retained?.account?.msalID ?? profile.id
                                var account = OnedriveAccount(msalID: accountID, homeAccountId: token.homeAccountID,
                                                              username: profile.mail ?? profile.userPrincipalName,
                                                              nickName: profile.displayName,
                                                              environment: "login.microsoftonline.com", accountClaims: "")
                                account.graphUserID = profile.id
                                var user = OneDriveUserModel()
                                user.account = account
                                user.path = previousIdentityMatches ? previous?.path : nil
                                guard self.client.install(token, accountID: accountID) else {
                                    finish(.failure(self.convert(.storage))); return
                                }
                                // Store only identity metadata, never OAuth tokens, in shared models.
                                let server = ServerConfigModel(serverType: .fromOneDrive, isSelected: true, onedriveUser: user)
                                ConnectConfigManager.shared.addOrUpdateRemoteServer(serverModel: server) {
                                    finish(.success(user))
                                    if previous != nil && !previousIdentityMatches {
                                        controller.showOneAlert(message: "OneDrive.LegacyAccountKept".localStr())
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        authorizationSession = session
        if !session.start() { finish(.failure(.tokenExpiredAuthAgain)) }
    }

    private static func matches(_ previous: OneDriveUserModel?, profile: OneDriveOAuthUser, token: OneDriveOAuthToken) -> Bool {
        guard let account = previous?.account else { return false }
        if let graphID = account.graphUserID, !graphID.isEmpty { return graphID == profile.id }
        // Legacy identifiers are not Graph IDs. Only a verified token-endpoint home identity can bridge them.
        if let homeID = account.homeAccountId, !homeID.isEmpty, let received = token.homeAccountID {
            return homeID == received
        }
        return false
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        authorizationWindow ?? ASPresentationAnchor()
    }

    func request(user: OneDriveUserModel, url: URL, completion: @escaping (Result<Data, KakaError>) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.request(user: user, url: url, completion: completion) }
            return
        }
        guard let accountID = user.account?.msalID, !accountID.isEmpty,
              ConnectConfigManager.shared.connectedModels.contains(where: { $0.onedriveUser?.account?.msalID == accountID }) else {
            completion(.failure(.tokenExpiredAuthAgain)); return
        }
        client.authorizedGraphRequest(accountID: accountID, url: url) { result in
            completion(result.flatMap { response, data in
                guard (200..<300).contains(response.statusCode) else { return .failure(.invalidResponse) }
                return .success(data)
            }.mapError(self.convert))
        }
    }

    func unlink(_ user: OneDriveUserModel) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.unlink(user) }
            return
        }
        guard let accountID = user.account?.msalID, !accountID.isEmpty else { return }
        client.unlink(accountID)
    }

    private func convert(_ error: OneDriveOAuthError) -> KakaError {
        switch error {
        case .authorization, .accountMismatch, .configuration: return .tokenExpiredAuthAgain
        case .storage: return .custom("OneDrive.Storage".localStr())
        case .invalidResponse, .network: return .custom("OneDrive.RequestFailed".localStr())
        }
    }

    private func query(_ accountID: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
         kSecAttrAccount as String: accountID]
    }
    private func loadToken(_ accountID: String) -> OneDriveOAuthToken? {
        var query = query(accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(OneDriveOAuthToken.self, from: data)
    }
    private func storeToken(_ token: OneDriveOAuthToken, accountID: String) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }
        let query = query(accountID)
        let values: [String: Any] = [kSecValueData as String: data,
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil) == errSecSuccess
    }
    private func removeToken(_ accountID: String) { SecItemDelete(query(accountID) as CFDictionary) }
}
