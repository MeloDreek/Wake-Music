import Foundation

// The helper is extracted from the production session; only this unrelated error case is stubbed.
enum MusicServerError: Error { case invalidAddress }

@main
enum MusicServerPlaylistRegression {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let base = MusicServerWire.normalizedBaseURL("https://music.example.com/library")!
        let parameters = [
            URLQueryItem(name: "u", value: "listener+test@example.com"),
            URLQueryItem(name: "t", value: "test-token"),
            URLQueryItem(name: "s", value: "test-salt"),
            URLQueryItem(name: "name", value: "放松 + Jazz & Soul = 100% 🎵")
        ]
        let url = MusicServerWire.url(base: base, path: "/rest/createPlaylist", query: parameters)!
        let request = try MusicServerPlaylistSupport.postRequest(url: url)
        expect(request.httpMethod == "POST", "Creation must not use GET")
        expect(request.url?.path == "/library/rest/createPlaylist", "Reverse-proxy deployment path preserved")
        expect(request.url?.query == nil, "Credentials and playlist name must not remain in URL")
        expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") == true,
               "Creation uses the documented form body")
        let body = String(data: request.httpBody!, encoding: .utf8)!
        expect(body.contains("%2B"), "Literal plus encoded instead of changing to a space")
        let decoded = URLComponents(string: "https://example.invalid/?" + body)!.queryItems!
        expect(decoded == parameters, "Unicode, emoji and form separators survive the round trip")
        expect(!decoded.contains(where: { $0.name == "playlistId" || $0.name == "songId" }),
               "New empty playlists cannot overwrite an existing playlist")

        let records = try JSONDecoder().decode([MusicServerRecord].self, from: Data(#"""
        [
            {"id":"b","name":"Jazz","songCount":2,"owner":"listener"},
            {"id":"a","name":"Acoustic","songCount":0},
            {"id":"b","name":"Duplicate Jazz"},
            {"name":"Invalid missing ID"},
            {"id":"c","name":"Rock","songCount":3,"owner":"friend"}
        ]
        """#.utf8))
        let playlists = MusicServerPlaylistSupport.uniquePlaylists(records)
        expect(playlists.map(\.id) == ["a", "b", "c"], "Complete list is sorted and duplicate/missing IDs removed")
        expect(playlists.first?.songCount == 0, "An empty playlist is a valid playlist")
        expect(playlists.last?.ownerName == "friend", "Accessible shared playlists are not silently dropped")
        expect(MusicServerPlaylistSupport.uniquePlaylists([]).isEmpty, "Empty response has an empty state")

        let many = (0..<250).map { ["id": String($0), "name": "Playlist \($0)"] }
        let manyRecords = try JSONDecoder().decode([MusicServerRecord].self, from: JSONSerialization.data(withJSONObject: many))
        expect(MusicServerPlaylistSupport.uniquePlaylists(manyRecords).count == 250,
               "Home list is not truncated to one 100-record page")
        do {
            _ = try MusicServerPlaylistSupport.postRequest(url: URL(string: "https://example.com/rest/createPlaylist")!)
            preconditionFailure("Missing form parameters should be rejected")
        } catch MusicServerError.invalidAddress { checks += 1 }
        print("MusicServer playlist regressions: \(checks) checks passed; no live server writes")
    }
}
