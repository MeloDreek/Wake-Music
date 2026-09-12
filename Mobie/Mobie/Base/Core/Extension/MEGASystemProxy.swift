import Foundation
import CFNetwork

/// Resolve the user's existing network route, never the developer's proxy address.
/// MEGA's C++ HTTP layer does not discover system proxies on iOS/Simulator.
struct MEGASystemProxy {
    let url: String?
    let username: String?
    let password: String?

    enum ResolutionError: Error { case unsupportedConfiguration }

    static func current() throws -> Self {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return try resolve([])
        }
        let endpoint = URL(string: "https://g.api.mega.co.nz/")!
        let proxies = CFNetworkCopyProxiesForURL(endpoint as CFURL, settings).takeRetainedValue()
        return try resolve(proxies as? [[String: Any]] ?? [])
    }

    static func resolve(_ proxies: [[String: Any]]) throws -> Self {
        guard let first = proxies.first else { return Self(url: nil, username: nil, password: nil) }
        let type = first[kCFProxyTypeKey as String] as? String
        if type == kCFProxyTypeNone as String { return Self(url: nil, username: nil, password: nil) }
        let scheme: String
        if type == kCFProxyTypeHTTP as String || type == kCFProxyTypeHTTPS as String {
            // HTTPS describes the target; the proxy transports HTTPS with CONNECT.
            scheme = "http"
        } else if type == kCFProxyTypeSOCKS as String {
            scheme = "socks5h"
        } else {
            // Do not silently bypass PAC or an unknown proxy with a direct request.
            throw ResolutionError.unsupportedConfiguration
        }
        guard let host = first[kCFProxyHostNameKey as String] as? String, !host.isEmpty,
              !host.contains(where: { $0.isWhitespace || "/@?#".contains($0) }),
              let port = first[kCFProxyPortNumberKey as String] as? Int, (1...65535).contains(port) else {
            throw ResolutionError.unsupportedConfiguration
        }
        var address = URLComponents()
        address.scheme = scheme
        address.host = host
        address.port = port
        guard let url = address.url?.absoluteString else { throw ResolutionError.unsupportedConfiguration }
        return Self(url: url, username: first[kCFProxyUsernameKey as String] as? String,
                    password: first[kCFProxyPasswordKey as String] as? String)
    }
}
