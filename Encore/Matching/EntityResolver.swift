//
//  EntityResolver.swift
//  Encore (Flow A) — Apple artist ⇆ District inventory (see ARCHITECTURE.md)
//
//  Apple Music artist ids never match a ticketing DB's ids. Resolve by normalized
//  name + genre overlap so a taste artist maps to a bookable District artist.
//  Protocol-shaped so a stronger matcher (or a server) drops in later.
//

import Foundation

public protocol EntityResolving {
    /// Map a taste artist to an artist present in the District inventory, if any.
    func resolve(_ tasteArtist: Artist, against inventory: [Artist]) -> Artist?
}

public struct EntityResolver: EntityResolving {
    /// Hand-curated aliases for the demo (Apple name → District id). Extend freely.
    public var aliasMap: [String: String]
    public var minSimilarity: Double

    public init(aliasMap: [String: String] = [:], minSimilarity: Double = 0.82) {
        self.aliasMap = aliasMap
        self.minSimilarity = minSimilarity
    }

    public func resolve(_ tasteArtist: Artist, against inventory: [Artist]) -> Artist? {
        // 1. Exact id (already-aligned in the hardcoded world).
        if let hit = inventory.first(where: { $0.id == tasteArtist.id }) { return hit }

        let key = Self.normalize(tasteArtist.name)

        // 2. Alias table.
        if let mappedID = aliasMap[key],
           let hit = inventory.first(where: { $0.id == mappedID }) { return hit }

        // 3. Normalized-name equality.
        if let hit = inventory.first(where: { Self.normalize($0.name) == key }) { return hit }

        // 4. Fuzzy name similarity, disambiguated by genre overlap.
        var best: (artist: Artist, score: Double)?
        for candidate in inventory {
            let nameScore = Self.similarity(key, Self.normalize(candidate.name))
            guard nameScore >= minSimilarity else { continue }
            let genreBoost = genreOverlap(tasteArtist.genres, candidate.genres) * 0.1
            let score = nameScore + genreBoost
            if best == nil || score > best!.score { best = (candidate, score) }
        }
        return best?.artist
    }

    // MARK: Normalization + similarity

    static func normalize(_ s: String) -> String {
        var out = s.lowercased()
        for token in [" feat.", " feat ", " ft.", " ft ", " x ", " & ", " and "] {
            out = out.replacingOccurrences(of: token, with: " ")
        }
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        out = String(out.unicodeScalars.filter { allowed.contains($0) })
        return out.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  ", with: " ")
    }

    private func genreOverlap(_ a: [String], _ b: [String]) -> Double {
        let sa = Set(a.map { $0.lowercased() }), sb = Set(b.map { $0.lowercased() })
        guard !sa.isEmpty, !sb.isEmpty else { return 0 }
        return Double(sa.intersection(sb).count) / Double(sa.union(sb).count)
    }

    /// Normalized Levenshtein similarity in 0...1.
    static func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }
        let distance = levenshtein(Array(a), Array(b))
        return 1.0 - Double(distance) / Double(max(a.count, b.count))
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = Swift.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
