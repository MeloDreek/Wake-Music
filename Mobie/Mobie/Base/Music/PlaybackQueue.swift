import Foundation

/// Identity-based queue operations, independent of UI, decoding and temporary playback URLs.
enum PlaybackQueue {
    /// Previewing repeatedly never consumes a song or reshuffles a prepared next round.
    static func nextID(in ids: [String], current: String?, shuffle: Bool,
                       pendingRound: inout [String]?) -> String? {
        guard !ids.isEmpty else { pendingRound = nil; return nil }
        guard let index = ids.firstIndex(where: { $0 == current }) else {
            pendingRound = nil
            return ids.first
        }
        if index + 1 < ids.count { pendingRound = nil; return ids[index + 1] }
        guard shuffle else { pendingRound = nil; return ids.first }
        if pendingRound == nil {
            pendingRound = shuffledRound(ids, current: current, keepingCurrentFirst: false, id: { $0 })
        }
        return pendingRound?.first
    }

    /// Each identity occurs once per round. At the boundary, do not repeat the last song.
    static func shuffledRound<Item>(_ items: [Item], current: String?, keepingCurrentFirst: Bool,
                                    id: (Item) -> String) -> [Item] {
        var result = unique(items, id: id).shuffled()
        if keepingCurrentFirst, let index = result.firstIndex(where: { id($0) == current }) {
            result.insert(result.remove(at: index), at: 0)
        } else if result.count > 1, result.first.map(id) == current {
            result.swapAt(0, Int.random(in: 1..<result.count))
        }
        return result
    }

    static func matchesSnapshot<Item>(_ items: [Item], current: String?, expectedIDs: [String],
                                      expectedCurrent: String?, id: (Item) -> String) -> Bool {
        current == expectedCurrent && items.map(id) == expectedIDs
    }
    static func unique<Item>(_ items: [Item], id: (Item) -> String) -> [Item] {
        var seen = Set<String>()
        return items.filter { seen.insert(id($0)).inserted }
    }

    /// One cycle after the current item. The current song lives in the header, not a second row.
    static func upcoming<Item>(_ items: [Item], current: String?, id: (Item) -> String) -> [Item] {
        let items = unique(items, id: id)
        guard let current, let index = items.firstIndex(where: { id($0) == current }) else { return items }
        return Array(items.dropFirst(index + 1)) + Array(items.prefix(index))
    }

    static func moving<Item>(_ items: [Item], current: String?, source: String, destination: Int,
                             id: (Item) -> String) -> [Item]? {
        var remaining = upcoming(items, current: current, id: id)
        guard let from = remaining.firstIndex(where: { id($0) == source }),
              remaining.indices.contains(destination) else { return nil }
        let item = remaining.remove(at: from)
        remaining.insert(item, at: destination)
        let base = unique(items, id: id)
        guard let index = base.firstIndex(where: { id($0) == current }) else { return remaining }
        // Keep the current track's position in the underlying cycle. Moving it to index zero
        // would silently change the existing Previous-button behavior after every drag.
        let split = remaining.count - index
        return Array(remaining.suffix(index)) + [base[index]] + Array(remaining.prefix(split))
    }
}
