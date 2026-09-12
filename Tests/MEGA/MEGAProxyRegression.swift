import Foundation
import CFNetwork

@main
enum MEGAProxyRegression {
    static func main() throws {
        var checks = 0
        func check(_ condition: Bool) {
            precondition(condition)
            checks += 1
        }
        func entry(_ type: CFString, host: String = "localhost", port: Int = 8080) -> [String: Any] {
            [kCFProxyTypeKey as String: type, kCFProxyHostNameKey as String: host,
             kCFProxyPortNumberKey as String: port]
        }
        func rejects(_ entries: [[String: Any]]) {
            do { _ = try MEGASystemProxy.resolve(entries); preconditionFailure("Invalid proxy accepted") }
            catch { checks += 1 }
        }
        check(try MEGASystemProxy.resolve([]).url == nil)
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeNone)]).url == nil)
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeHTTPS)]).url == "http://localhost:8080")
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeHTTP)]).url == "http://localhost:8080")
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeSOCKS)]).url == "socks5h://localhost:8080")
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeHTTPS, host: "[::1]")]).url == "http://[::1]:8080")
        // CFNetwork ordering and exclusions must win over later fallback entries.
        check(try MEGASystemProxy.resolve([entry(kCFProxyTypeNone), entry(kCFProxyTypeHTTPS)]).url == nil)
        rejects([entry(kCFProxyTypeAutoConfigurationURL), entry(kCFProxyTypeNone)])
        rejects([entry(kCFProxyTypeAutoConfigurationJavaScript)])
        rejects([entry(kCFProxyTypeFTP)])
        rejects([entry(kCFProxyTypeHTTP, port: 0)])
        rejects([entry(kCFProxyTypeHTTP, port: 65536)])
        rejects([entry(kCFProxyTypeHTTP, host: "user@host")])
        rejects([entry(kCFProxyTypeHTTP, host: "")])
        rejects([[:]])
        var authenticated = entry(kCFProxyTypeHTTPS)
        authenticated[kCFProxyUsernameKey as String] = "test-user"
        authenticated[kCFProxyPasswordKey as String] = "dummy-proxy-password"
        let result = try MEGASystemProxy.resolve([authenticated])
        check(result.username == "test-user" && result.password == "dummy-proxy-password")
        check(result.url == "http://localhost:8080") // Never put credentials in the URL.
        print("MEGA proxy regression checks passed: \(checks)")
    }
}
