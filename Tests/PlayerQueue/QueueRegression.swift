import Foundation

@main enum QueueRegression {
    static func main() {
        var checks = 0
        func check(_ value: Bool) { precondition(value); checks += 1 }
        let id: (String) -> String = { $0 }
        check(PlaybackQueue.unique(["a", "b", "a"], id: id) == ["a", "b"])
        // Regression: appending a duplicate to an unchanged queue must still normalize.
        var queue = ["a", "b"]
        queue = PlaybackQueue.unique(queue + ["a"], id: id)
        check(queue == ["a", "b"])
        check(PlaybackQueue.unique([String](), id: id).isEmpty)
        check(PlaybackQueue.unique(["server1/song", "server2/song"], id: id).count == 2)
        check(PlaybackQueue.upcoming(["a", "b", "c", "a"], current: "b", id: id) == ["c", "a"])
        check(PlaybackQueue.upcoming(["a"], current: "a", id: id).isEmpty)
        check(PlaybackQueue.upcoming(["a", "b"], current: nil, id: id) == ["a", "b"])
        check(PlaybackQueue.upcoming(["a", "b"], current: "missing", id: id) == ["a", "b"])
        check(PlaybackQueue.moving(["a", "b", "c", "d"], current: "b", source: "a", destination: 0, id: id) == ["d", "b", "a", "c"])
        check(PlaybackQueue.moving(["a", "b", "c"], current: "a", source: "b", destination: 1, id: id) == ["a", "c", "b"])
        check(PlaybackQueue.moving(["a", "b"], current: nil, source: "b", destination: 0, id: id) == ["b", "a"])
        check(PlaybackQueue.moving(["a", "b"], current: "a", source: "a", destination: 0, id: id) == nil)
        check(PlaybackQueue.moving(["a", "b"], current: "a", source: "b", destination: 99, id: id) == nil)
        check(PlaybackQueue.moving(["a", "b"], current: "a", source: "b", destination: -1, id: id) == nil)
        struct Song { let id: String; let title: String }
        let songs = [Song(id: "a", title: "same"), Song(id: "b", title: "same"), Song(id: "a", title: "different metadata")]
        check(PlaybackQueue.unique(songs, id: { $0.id }).map(\.id) == ["a", "b"])
        // Large library, first occurrence and input order remain stable.
        let large = (0..<10000).map(String.init)
        check(PlaybackQueue.unique(large + large, id: id) == large)
        check(PlaybackQueue.matchesSnapshot(["a", "b"], current: "a", expectedIDs: ["a", "b"], expectedCurrent: "a", id: id))
        check(!PlaybackQueue.matchesSnapshot(["a", "b"], current: "b", expectedIDs: ["a", "b"], expectedCurrent: "a", id: id))
        check(!PlaybackQueue.matchesSnapshot(["b", "a"], current: "a", expectedIDs: ["a", "b"], expectedCurrent: "a", id: id))
        check(!PlaybackQueue.matchesSnapshot(["a"], current: "a", expectedIDs: ["a", "b"], expectedCurrent: "a", id: id))
        for current in ["a", "b", "c", "d"] {
            for song in ["a", "b", "c", "d"] where song != current {
                for destination in 0..<3 {
                    let moved = PlaybackQueue.moving(["a", "b", "c", "d"], current: current,
                        source: song, destination: destination, id: id)!
                    check(moved.firstIndex(of: current) == ["a", "b", "c", "d"].firstIndex(of: current) && Set(moved).count == 4 && moved.count == 4)
                    check(PlaybackQueue.upcoming(moved, current: current, id: id)[destination] == song)
                }
            }
        }
        // Shuffle rounds: duplicates are normalized, current song starts the first round,
        // all five songs are eligible again next round, and the boundary never repeats.
        for size in [0, 1, 2, 5, 100] {
            let source = (0..<size).map(String.init)
            let first = PlaybackQueue.shuffledRound(source + source, current: source.last,
                keepingCurrentFirst: true, id: id)
            check(first.count == size && Set(first) == Set(source))
            check(first.first == source.last)
            var previous = first.last
            for _ in 0..<200 {
                let round = PlaybackQueue.shuffledRound(source + source, current: previous,
                    keepingCurrentFirst: false, id: id)
                check(round.count == size && Set(round) == Set(source))
                if size > 1 { check(round.first != previous) }
                previous = round.last
            }
        }
        let missing = PlaybackQueue.shuffledRound(["a", "b"], current: "removed",
            keepingCurrentFirst: true, id: id)
        check(Set(missing) == Set(["a", "b"]))
        // Exercise the exact planner used by both pre-download and Next for 100 rounds.
        var cycle = PlaybackQueue.shuffledRound(["a", "b", "c", "d", "e"], current: "c",
            keepingCurrentFirst: true, id: id)
        var current = cycle.first!
        var heard = [current]
        var pending: [String]?
        for _ in 0..<499 {
            let next = PlaybackQueue.nextID(in: cycle, current: current, shuffle: true, pendingRound: &pending)!
            let prepared = pending
            for _ in 0..<5 {
                check(PlaybackQueue.nextID(in: cycle, current: current, shuffle: true, pendingRound: &pending) == next)
                check(pending == prepared)
            }
            check(next != current)
            if let round = pending { cycle = round; pending = nil }
            current = next
            heard.append(next)
        }
        for offset in stride(from: 0, to: heard.count, by: 5) {
            check(Set(heard[offset..<(offset + 5)]) == Set(["a", "b", "c", "d", "e"]))
        }
        pending = nil
        check(PlaybackQueue.nextID(in: [], current: nil, shuffle: true, pendingRound: &pending) == nil)
        check(PlaybackQueue.nextID(in: ["a"], current: "a", shuffle: true, pendingRound: &pending) == "a")
        pending = nil // Membership/current/order changes invalidate a pending round in the player.
        check(PlaybackQueue.nextID(in: ["b", "c"], current: "removed", shuffle: true, pendingRound: &pending) == "b")
        check(PlaybackQueue.nextID(in: ["a", "b"], current: "b", shuffle: false, pendingRound: &pending) == "a")
        check(pending == nil)
        print("Player queue regression checks passed: \(checks)")
    }
}
