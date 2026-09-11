import Foundation

@main
@MainActor
enum SMBRegression {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message)
        checks += 1
    }
    static func main() async throws {
        let server = try SMBAddress.parse(server: "192.168.1.177", port: "445", share: "WakeMusic-SMB-Test")
        check(server.host == "192.168.1.177" && server.share == "WakeMusic-SMB-Test", "host/share")
        for address in ["192.168.1.177", "smb://192.168.1.177"] {
            let parsed = try SMBAddress.parse(server: address, port: "445", share: "音乐")
            check(parsed.host == "192.168.1.177" && parsed.share == "音乐" && parsed.port == 445,
                  "bare and scheme-prefixed host: \(address)")
            let defaultPort = try SMBAddress.parse(server: address, port: "", share: "音乐")
            check(defaultPort.port == 445, "empty port defaults to SMB port")
            let customPort = try SMBAddress.parse(server: address, port: "1445", share: "音乐")
            check(customPort.port == 1445, "custom port field")
        }
        let url = try SMBAddress.parse(server: "smb://nas.local/音乐", port: "445", share: "")
        check(url.share == "音乐", "Chinese share")
        let unc = try SMBAddress.parse(server: "\\\\nas.local\\Music", port: "", share: "")
        check(unc.host == "nas.local" && unc.share == "Music", "UNC")
        let port = try SMBAddress.parse(server: "smb://nas.local:1445/Music", port: "445", share: "Music")
        check(port.port == 1445, "explicit URL port")
        for bad in ["https://nas.local/Music", "smb://user:password@nas.local/Music", "smb://nas.local/Music/sub", "smb://nas.local/Music?x=1", "smb://nas.local:0/Music"] {
            do { _ = try SMBAddress.parse(server: bad, port: "445", share: ""); preconditionFailure("accepted bad address") }
            catch { checks += 1 }
        }
        check(SMBHTTPRange.parse(nil, size: 100) == 0..<100, "full read")
        check(SMBHTTPRange.parse("bytes=0-0", size: 100) == 0..<1, "one byte")
        check(SMBHTTPRange.parse("bytes=50-", size: 100) == 50..<100, "open end")
        check(SMBHTTPRange.parse("bytes=-20", size: 100) == 80..<100, "suffix")
        check(SMBHTTPRange.parse("bytes=-200", size: 100) == 0..<100, "long suffix")
        check(SMBHTTPRange.parse("bytes=90-999", size: 100) == 90..<100, "clamped end")
        for bad in ["bytes=100-", "bytes=4-3", "bytes=-0", "bytes=0-1,4-5", "bytes=+1-2", "bytes=1-a", "bytes=", "bytes=999999999999999999999999-", "bytes=١-٢"] {
            check(SMBHTTPRange.parse(bad, size: 100) == nil, "invalid range: \(bad)")
        }
        check(SMBHTTPRange.parse(nil, size: 0) == nil, "empty file")
        let relative = try SMBPath.relative("/Music/曲目.wav")
        check(relative == "Music/曲目.wav", "relative path")
        do { _ = try SMBPath.relative("Music/../secret"); preconditionFailure("traversal") }
        catch { checks += 1 }
        var user = server
        user.username = "test"
        var other = user
        other.share = "Other"
        check(other.identity != user.identity, "share-scoped account")
        var file = SMBDriveFileModel()
        file.name = "曲目.wav"
        file.id = "Music/曲目.wav"
        file.smbUser = user
        var second = file
        second.id = "Elsewhere/曲目.wav"
        check(second.identity != file.identity, "same names do not collide")
        check(!file.identity.contains("/"), "safe cache key")

        let content = Data((0..<(1024 * 1024)).map { UInt8($0 % 251) })
        var largestRead = 0
        var reads = 0
        let streamURL = try await SMBHTTPBridge.shared.register(file: file, size: Int64(content.count)) { range in
            largestRead = max(largestRead, range.count)
            reads += 1
            return content.subdata(in: Int(range.lowerBound)..<Int(range.upperBound))
        }
        check(streamURL.host == "127.0.0.1" && streamURL.user == nil, "private credential-free loopback")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)
        func request(_ range: String? = nil, method: String = "GET", url: URL? = nil) async throws -> (Data, HTTPURLResponse) {
            var req = URLRequest(url: url ?? streamURL)
            req.httpMethod = method
            req.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await session.data(for: req)
            return (data, response as! HTTPURLResponse)
        }
        let full = try await request()
        check(full.0 == content && full.1.statusCode == 200, "full download exact bytes")
        check(largestRead <= 256 * 1024, "bounded read memory")
        let ranged = try await request("bytes=100-299")
        check(ranged.0 == content.subdata(in: 100..<300), "seek bytes exact")
        check(ranged.1.statusCode == 206 && ranged.1.value(forHTTPHeaderField: "Content-Range") == "bytes 100-299/1048576", "206 headers")
        let tail = try await request("bytes=-31")
        check(tail.0 == content.suffix(31), "suffix HTTP")
        let before = reads
        let head = try await request(method: "HEAD")
        check(head.0.isEmpty && reads == before, "HEAD never reads audio")
        let invalid = try await request("bytes=500-400")
        check(invalid.1.statusCode == 416 && reads == before, "invalid range never reads audio")
        let post = try await request(method: "POST")
        check(post.1.statusCode == 405, "remote writes unavailable")
        SMBHTTPBridge.shared.revoke(account: user.identity)
        let removed = try await request()
        check(removed.1.statusCode == 404, "unlink invalidates URLs")
        print("SMB regression checks passed: \(checks)")
    }
}
