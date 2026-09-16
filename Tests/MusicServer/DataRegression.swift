import Foundation

@main
enum MusicServerDataRegression {
    static func main() async throws {
        var count = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
        }
        let base = MusicServerWire.normalizedBaseURL("  HTTPS://Music.Example.COM:443/music/  ")!
        expect(base.absoluteString == "https://music.example.com/music", "Canonical URL preserves deployment path")
        expect(MusicServerWire.normalizedBaseURL("ftp://example.com") == nil, "Reject non-HTTP schemes")
        expect(MusicServerWire.normalizedBaseURL("https://name:password@example.com") == nil, "Reject embedded credentials")
        expect(MusicServerWire.normalizedBaseURL("https://example.com/?token=secret") == nil, "Reject query-bearing server addresses")
        expect(MusicServerWire.normalizedBaseURL("https://example.com/#secret") == nil, "Reject fragments")
        expect(MusicServerWire.normalizedBaseURL("https://[::1]:8443/path/")?.port == 8443, "IPv6 and custom port retained")
        let url = MusicServerWire.url(base: base, path: "/rest/ping", query: [URLQueryItem(name: "u", value: "name+tag@example.com &音乐"), URLQueryItem(name: "id", value: "a?b#c/é")])!
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        expect(parts.path == "/music/rest/ping", "Reverse-proxy base path retained")
        expect(parts.queryItems?.first?.value == "name+tag@example.com &音乐", "Username round trips exactly")
        expect(parts.queryItems?.last?.value == "a?b#c/é", "Identifiers encoded independently")
        expect(url.absoluteString.contains("%2B"), "Literal plus survives form-style servers")
        expect(MusicServerWire.token(password: "test", salt: "salt") == "315240c61218a4a861ec949166a85ef0", "Subsonic MD5 password+salt")
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["X-Total-Count": "456749"])!
        expect(MusicServerWire.totalCount(response) == 456749, "Large server count taken from headers, not page size")
        let rangeResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Range": "items 0-39/500000"])!
        expect(MusicServerWire.totalCount(rangeResponse) == 500000, "Content-Range total supported")
        let unknownResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        expect(MusicServerWire.totalCount(unknownResponse) == nil, "Unknown counts never masquerade as zero")
        let native = try JSONDecoder().decode(MusicServerRecord.self, from: Data(#"{"id":"position-1","mediaFileId":"actual-song","title":"Track","duration":123.75,"sampleRate":96000,"channels":2,"trackNumber":3,"bitDepth":24,"starred":true,"playCount":1}"#.utf8))
        expect(native.mediaFileID == "actual-song", "Playlist IDs resolve actual media IDs")
        expect(native.duration == 123, "Floating duration tolerated")
        expect(native.sampleRate == 96000 && native.channels == 2 && native.bitDepth == 24, "Native metadata mapped")
        expect(native.starred && native.hasBeenPlayed, "Native annotation decoded")
        let standard = try JSONDecoder().decode(MusicServerRecord.self, from: Data(#"{"id":"2","track":4,"samplingRate":"44100","channelCount":1,"starred":"2026-09-17T00:00:00Z"}"#.utf8))
        expect(standard.track == 4 && standard.sampleRate == 44100 && standard.channels == 1, "Subsonic aliases decoded")
        expect(standard.starred && !standard.hasBeenPlayed, "Starred is not played")
        let empty = try JSONDecoder().decode(MusicServerRecord.self, from: Data(#"{"id":"3","playDate":"0001-01-01T00:00:00Z"}"#.utf8))
        expect(!empty.hasBeenPlayed && empty.songCount == nil && empty.albumCount == nil, "Empty history and unknown counts preserved")
        expect(MusicServerWire.maximumPageSize == 100, "Hard page limit enforced")
        count += try await testAuthenticationCancellation()
        print("MusicServer data regressions: \(count) checks passed")
    }

    @MainActor
    private static func testAuthenticationCancellation() async throws -> Int {
        let flight = MusicServerAuthenticationFlight<String>()
        let oldGate = AuthenticationGate()
        let newGate = AuthenticationGate()
        var oldID: UUID?
        var replacementID: UUID?
        let old = Task {
            try await flight.value { id in
                oldID = id
                return await oldGate.wait()
            }
        }
        while oldGate.continuation == nil { await Task.yield() }
        old.cancel()
        let replacement = Task {
            try await flight.value { id in
                replacementID = id
                return await newGate.wait()
            }
        }
        while newGate.continuation == nil { await Task.yield() }
        precondition(oldID != replacementID, "A new refresh cannot join the cancelled login")
        precondition(!flight.isCurrent(oldID!), "Stale generation cannot publish credentials")
        oldGate.finish("stale")
        do {
            _ = try await old.value
            preconditionFailure("Cancelled caller must not receive stale login success")
        } catch is CancellationError { }
        precondition(flight.isCurrent(replacementID!), "Old defer must not clear the replacement login")
        var joined = false
        var unexpectedOperationCount = 0
        let waiter = Task {
            joined = true
            return try await flight.value { _ in
                unexpectedOperationCount += 1
                return "unexpected"
            }
        }
        while !joined { await Task.yield() }
        precondition(unexpectedOperationCount == 0, "Concurrent request reuses live replacement")
        newGate.finish("fresh")
        let values = try await (replacement.value, waiter.value)
        precondition(values.0 == "fresh" && values.1 == "fresh", "Both live callers receive current credentials")
        return 6
    }
}

@MainActor
private final class AuthenticationGate {
    var continuation: CheckedContinuation<String, Never>?
    func wait() async -> String { await withCheckedContinuation { continuation = $0 } }
    func finish(_ value: String) { continuation?.resume(returning: value); continuation = nil }
}
