import Foundation

enum YandexDriveError: Error, Equatable {
    case authorization, storage, permission, notFound, rateLimited, network, invalidResponse
}

/// Used only for the current request; never encode this into a library or download model.
struct YandexDownloadSource {
    let url: URL
    let headers: [String: String]
}

struct YandexAPIUser: Decodable {
    let uid: String
    let login: String
    let display_name: String?
}

struct YandexAPIItem: Decodable {
    let resource_id: String?
    let path: String
    let name: String
    let type: String
    let size: Int64?
    let created: String?
    let modified: String?
}

private struct YandexDiskInfo: Decodable { let user: YandexAPIUser }
private struct YandexFolder: Decodable {
    struct Page: Decodable {
        let items: [YandexAPIItem]
        let offset: Int
        let limit: Int
        let total: Int
    }
    let type: String
    let _embedded: Page
}
private struct YandexDownloadLink: Decodable {
    let href: String
    let method: String
    let templated: Bool
}

/// GET-only Disk client. Call on the main queue; callbacks also run on the main queue.
/// Credentials remain in Keychain. Temporary, signed download URLs are resolved on demand.
final class YandexDriveAPI {
    private let load: (String) -> String?
    private let save: (String, String) -> Bool
    private let remove: (String) -> Void
    private let session: URLSession
    private var generations: [String: UUID] = [:]

    init(configuration: URLSessionConfiguration = .ephemeral,
         load: @escaping (String) -> String?,
         save: @escaping (String, String) -> Bool,
         remove: @escaping (String) -> Void) {
        self.load = load
        self.save = save
        self.remove = remove
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: YandexRedirectBlocker(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func install(_ token: String, accountID: String) -> Bool {
        guard !token.isEmpty, !accountID.isEmpty else { return false }
        generations[accountID] = UUID()
        return save(accountID, token)
    }

    func unlink(_ accountID: String) {
        generations[accountID] = UUID()
        remove(accountID)
    }

    private func generation(_ accountID: String) -> UUID {
        if let value = generations[accountID] { return value }
        let value = UUID()
        generations[accountID] = value
        return value
    }

    func user(token: String, completion: @escaping (Result<YandexAPIUser, YandexDriveError>) -> Void) {
        request(endpoint: "", parameters: ["fields": "user"], token: token) { result in
            completion(result.flatMap { data in
                guard let info = try? JSONDecoder().decode(YandexDiskInfo.self, from: data),
                      !info.user.uid.isEmpty, !info.user.login.isEmpty else { return .failure(.invalidResponse) }
                return .success(info.user)
            })
        }
    }

    func listFolder(accountID: String, folderID: String,
                    completion: @escaping (Result<[YandexAPIItem], YandexDriveError>) -> Void) {
        guard Self.validPath(folderID), let token = load(accountID), !token.isEmpty else {
            completion(.failure(.authorization)); return
        }
        let epoch = generation(accountID)
        var items = [YandexAPIItem]()
        var seen = Set<String>()
        func page(_ offset: Int, count: Int) {
            guard count < 10_000 else { completion(.failure(.invalidResponse)); return }
            self.request(endpoint: "/resources", parameters: [
                "path": folderID, "limit": "200", "offset": String(offset), "sort": "name",
                "fields": "type,_embedded.items.resource_id,_embedded.items.path,_embedded.items.name,_embedded.items.type,_embedded.items.size,_embedded.items.created,_embedded.items.modified,_embedded.offset,_embedded.limit,_embedded.total"
            ], token: token) { result in
                guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
                switch result {
                case .failure(let error): completion(.failure(error))
                case .success(let data):
                    guard let folder = try? JSONDecoder().decode(YandexFolder.self, from: data), folder.type == "dir" else {
                        completion(.failure(.invalidResponse)); return
                    }
                    let batch = folder._embedded
                    guard batch.offset == offset, batch.limit > 0, batch.total >= 0,
                          batch.items.count <= batch.limit, offset <= Int.max - batch.items.count else {
                        completion(.failure(.invalidResponse)); return
                    }
                    let previousCount = items.count
                    for item in batch.items {
                        guard Self.validPath(item.path), !item.name.isEmpty,
                              item.type == "dir" || item.type == "file" else {
                            completion(.failure(.invalidResponse)); return
                        }
                        if seen.insert(item.resource_id ?? item.path).inserted { items.append(item) }
                    }
                    let nextOffset = offset + batch.items.count
                    if nextOffset >= batch.total { completion(.success(items)); return }
                    guard items.count > previousCount else { completion(.failure(.invalidResponse)); return }
                    page(nextOffset, count: count + 1)
                }
            }
        }
        page(0, count: 0)
    }

    func fileSource(accountID: String, path: String, completion: @escaping (Result<YandexDownloadSource, YandexDriveError>) -> Void) {
        guard Self.validPath(path), let token = load(accountID), !token.isEmpty else {
            completion(.failure(.authorization)); return
        }
        let epoch = generation(accountID)
        request(endpoint: "/resources/download", parameters: ["path": path], token: token) { result in
            guard self.generation(accountID) == epoch else { completion(.failure(.authorization)); return }
            completion(result.flatMap { data in
                guard let link = try? JSONDecoder().decode(YandexDownloadLink.self, from: data),
                      link.method == "GET", !link.templated,
                      let url = URL(string: link.href), Self.validDownloadURL(url) else { return .failure(.invalidResponse) }
                // The Disk download API documents the same OAuth header on the returned href.
                // Validate the destination first and keep credentials out of the persisted URL.
                return .success(YandexDownloadSource(url: url, headers: ["Authorization": "OAuth " + token]))
            })
        }
    }

    static func validPath(_ path: String) -> Bool {
        path.hasPrefix("disk:/") && !path.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    static func validDownloadURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, let host = url.host?.lowercased() else { return false }
        return ["yandex.ru", "yandex.net", "yandex.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func request(endpoint: String, parameters: [String: String], token: String,
                         completion: @escaping (Result<Data, YandexDriveError>) -> Void) {
        guard !token.isEmpty else { completion(.failure(.authorization)); return }
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk" + endpoint)!
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { completion(.failure(.invalidResponse)); return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("OAuth " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil, let response = response as? HTTPURLResponse else {
                    completion(.failure(.network)); return
                }
                guard response.statusCode == 200 else {
#if DEBUG
                    // Diagnose backend scope/account errors without printing the token, URL query,
                    // file names, user profile or free-form response body.
                    let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                    let errorCode = object?["error"] as? String ?? ""
                    let knownCodes = ["ForbiddenError", "UnauthorizedError", "DiskNotFoundError", "DiskPathDoesntExistsError", "TooManyRequestsError", "ResourceNotFoundError"]
                    let safeCode = knownCodes.contains(errorCode) ? errorCode : "unrecognized"
                    print("Yandex Disk API: HTTP \(response.statusCode), endpoint=\(endpoint.isEmpty ? "disk-info" : endpoint), error=\(safeCode)")
#endif
                    let failure: YandexDriveError
                    switch response.statusCode {
                    case 401: failure = .authorization
                    case 403: failure = .permission
                    case 404: failure = .notFound
                    case 429: failure = .rateLimited
                    case 500...599: failure = .network
                    default: failure = .invalidResponse
                    }
                    completion(.failure(failure)); return
                }
                guard let data = data else { completion(.failure(.invalidResponse)); return }
                completion(.success(data))
            }
        }.resume()
    }
}

/// Do not forward the OAuth header if an API endpoint unexpectedly redirects.
private final class YandexRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
