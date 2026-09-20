import Foundation

@main
enum ArtistLocalIndexRegression {
    static func main() async throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        func record(_ id: String, _ name: String, section: Int) -> MusicServerArtistIndexRecord {
            MusicServerArtistIndexRecord(id: id, name: name, section: section)
        }
        let indexed = try await MusicServerArtistLocalIndex.prepare([
            record("10", "Artist 10", section: 0), record("2", "Artist 2", section: 0),
            record("b", "Beyoncé", section: 1), record("z", "周杰伦", section: 3),
            record("10", "Duplicate", section: 2), record("", "Invalid", section: 0)
        ])
        expect(indexed.map(\.id) == ["2", "10", "b", "z"], "Whole artist index deduplicates IDs and uses natural name ordering")
        let all = try await MusicServerArtistLocalIndex.filter(indexed, query: "", favoriteIDs: ["b", "z"])
        expect(all.groups.map(\.section) == [0, 1, 3], "All nonempty sections are available at once")
        expect(all.groups.flatMap(\.ids).count == 4, "Local artist list is not limited to a page")
        expect(all.favorites == ["b", "z"], "Pinned favorites preserve index order and coexist with alphabetical groups")
        let accent = try await MusicServerArtistLocalIndex.filter(indexed, query: "  BEYONCE  ", favoriteIDs: ["b"])
        expect(accent.groups.flatMap(\.ids) == ["b"] && accent.favorites == ["b"], "Local search is case/accent insensitive and trims whitespace")
        let chinese = try await MusicServerArtistLocalIndex.filter(indexed, query: "周杰", favoriteIDs: ["b", "z"])
        expect(chinese.groups.flatMap(\.ids) == ["z"] && chinese.favorites == ["z"], "Chinese search also filters the pinned favorites")
        let latin = try await MusicServerArtistLocalIndex.filter(indexed, query: "zhou", favoriteIDs: [])
        expect(latin.groups.flatMap(\.ids) == ["z"], "Latin/pinyin forms can find Chinese artist names locally")
        let noFavorites = try await MusicServerArtistLocalIndex.filter(indexed, query: "", favoriteIDs: [])
        expect(noFavorites.favorites.isEmpty && noFavorites.groups.flatMap(\.ids).count == 4, "Removing a favorite keeps the artist in the full list")
        let noMatches = try await MusicServerArtistLocalIndex.filter(indexed, query: "not found", favoriteIDs: ["b"])
        expect(noMatches.groups.isEmpty && noMatches.favorites.isEmpty, "No matches has a single full-screen empty state")
        let restored = try await MusicServerArtistLocalIndex.filter(indexed, query: "", favoriteIDs: [])
        expect(restored.groups.flatMap(\.ids) == all.groups.flatMap(\.ids), "Clearing search restores every artist without requesting the server")
        let large = (0..<90_000).map { record(String($0), "Artist \($0)", section: $0 % 26) }
        let largeIndex = try await MusicServerArtistLocalIndex.prepare(large)
        let complete = try await MusicServerArtistLocalIndex.filter(largeIndex, query: "", favoriteIDs: ["89999"])
        expect(complete.groups.flatMap(\.ids).count == 90_000, "A 90,000-artist library is never truncated")
        let last = try await MusicServerArtistLocalIndex.filter(largeIndex, query: "Artist 89999", favoriteIDs: ["89999"])
        expect(last.groups.flatMap(\.ids) == ["89999"] && last.favorites == ["89999"], "Search finds the last artist, beyond the former page boundary")
        let cancelled = Task { try await MusicServerArtistLocalIndex.prepare(large) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled work must not publish a complete local index")
        } catch is CancellationError { checks += 1 }
        print("Artist full/local index: \(checks) checks passed; includes 90,000 artists, no server mutations")
    }
}
