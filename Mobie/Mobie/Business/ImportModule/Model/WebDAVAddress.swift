import Foundation

/// Separates an endpoint from the collection path passed to FilesProvider.
struct WebDAVAddress {
    let scheme: String
    let host: String
    let port: String?
    let path: String?
    let replacesEndpoint: Bool

    static func parse(_ text: String, defaultScheme: String) -> WebDAVAddress? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }
        let explicit = input.contains("://") || input.hasPrefix("//")
        let url = input.hasPrefix("//") ? defaultScheme + ":" + input :
            (input.contains("://") ? input : defaultScheme + "://" + input)
        // Encode Unicode/space without double-encoding existing escapes (iOS 16).
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%")
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: allowed),
              let components = URLComponents(string: encoded),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !host.contains("%"), components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.url != nil else { return nil }
        if let port = components.port, !(1...65535).contains(port) { return nil }
        // A trailing colon is not an explicitly valid port.
        let authority = url.components(separatedBy: "://").last?.components(separatedBy: "/").first ?? ""
        guard !authority.hasSuffix(":") else { return nil }
        return WebDAVAddress(scheme: scheme, host: host,
                             port: components.port.map(String.init),
                             path: components.path.isEmpty ? nil : components.path,
                             replacesEndpoint: explicit)
    }
}
