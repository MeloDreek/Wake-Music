import Foundation

@main
struct WebDAVAddressTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ label: String) {
            precondition(condition, label)
            checks += 1
        }
        let full = WebDAVAddress.parse(" https://nas.local:5006/dav/music/ ", defaultScheme: "http")!
        check(full.scheme == "https", "HTTPS")
        check(full.host == "nas.local", "hostname")
        check(full.port == "5006", "port")
        check(full.path == "/dav/music/", "trailing slash")
        check(full.replacesEndpoint, "full URLs replace stale fields")
        let bare = WebDAVAddress.parse("nas.local", defaultScheme: "https")!
        check(bare.scheme == "https" && !bare.replacesEndpoint, "bare host retains form protocol")
        check(bare.port == nil && bare.path == nil, "bare host retains manual port/path")
        let partial = WebDAVAddress.parse("192.168.1.2:5005/music", defaultScheme: "http")!
        check(partial.port == "5005" && partial.path == "/music", "scheme-less endpoint")
        let root = WebDAVAddress.parse("HTTPS://nas.local", defaultScheme: "http")!
        check(root.replacesEndpoint && root.port == nil && root.path == nil, "reset URL without port/path")
        let ipv6 = WebDAVAddress.parse("https://[2001:db8::1]:5006/dav", defaultScheme: "http")!
        check(ipv6.port == "5006" && ipv6.host.contains("2001:db8::1"), "IPv6")
        check(WebDAVAddress.parse("https://nas.local/音乐/My Album", defaultScheme: "http")?.path == "/音乐/My Album", "Unicode and spaces")
        check(WebDAVAddress.parse("https://nas.local/%E9%9F%B3%E4%B9%90/My%20Album", defaultScheme: "http")?.path == "/音乐/My Album", "decode path once")
        check(WebDAVAddress.parse("https://nas.local/a%2520b", defaultScheme: "http")?.path == "/a%20b", "preserve literal percent")
        check(WebDAVAddress.parse("//nas.local:443/dav", defaultScheme: "https")?.scheme == "https", "protocol-relative")
        for input in ["", "https://", "ftp://nas.local", "https://nas.local:0", "https://nas.local:65536",
                      "https://nas.local:abc", "https://nas.local:", "https://nas.local:-1",
                      "https://user:pass@nas.local", "https://nas.local/dav?token=abc",
                      "https://nas.local/dav#fragment", "bad host", "https:///music"] {
            check(WebDAVAddress.parse(input, defaultScheme: "http") == nil, "reject invalid endpoint")
        }
        print("WebDAV address tests: \(checks) passed")
    }
}
