//
//  RecommendationEngine.swift
//  Encore (Flow A) — deterministic shortlist (see claude.md §7)
//
//  Transparent, tunable scoring over the tiny candidate set. No ML. Foundation
//  Models (template fallback here) only re-ranks/explains the top few — it never
//  invents an event. Constants are named + tunable.
//

import Foundation

public struct RecommendationEngine {

    // Tunable weights (named per §7).
    public struct Weights {
        public var onRepeat = 100.0
        public var topArtist = 70.0
        public var similarArtist = 40.0
        public var genreAffinity = 30.0
        public var newlyDiscovered = 25.0
        public var soundtrackMatch = 60.0
        public var filmGenreAffinity = 20.0
        public var youreFree = 15.0
        public var minScore = 20.0
        public init() {}
    }

    public var weights = Weights()
    /// Light feedback loop: per-artist/genre multipliers nudged on book/dismiss.
    public var feedbackMultipliers: [String: Double] = [:]

    public init(weights: Weights = Weights(), feedbackMultipliers: [String: Double] = [:]) {
        self.weights = weights
        self.feedbackMultipliers = feedbackMultipliers
    }

    public func rank(_ events: [Event], for taste: TasteProfile, context: MatchContext) -> [ScoredEvent] {
        events.map { e in
            var s = 0.0
            var reasons: [MatchReason] = []
            let performing = Set(e.artistIDs)

            let onRepeatIDs = Set(taste.onRepeat.map(\.id))
            let topIDs = Set(taste.topArtists.map(\.artist.id))
            let discoveredIDs = Set(taste.discovered.map(\.id))

            if !performing.isDisjoint(with: onRepeatIDs) {
                s += weights.onRepeat; reasons.append(.onRepeat)
            } else if !performing.isDisjoint(with: topIDs) {
                s += weights.topArtist; reasons.append(.topArtist)
            } else if !performing.isDisjoint(with: context.relatedIDs) {
                s += weights.similarArtist; reasons.append(.similarArtist)
            }

            s += genreAffinity(e, taste) * weights.genreAffinity
            if !performing.isDisjoint(with: discoveredIDs) {
                s += weights.newlyDiscovered; reasons.append(.newlyDiscovered)
            }

            if e.type == .movie {
                let sm = soundtrackMatch(e, taste)
                s += sm * weights.soundtrackMatch
                if sm > 0.3 { reasons.append(.soundtrack) }
                s += filmGenreAffinity(e, taste) * weights.filmGenreAffinity
            }

            // Per-artist/genre feedback nudging.
            s *= feedbackFactor(for: e)

            s *= distanceDecay(e.distanceKm(from: context.home))
            s *= timingCurve(e.startTime, now: context.now)

            if context.isFree(e.startTime) { s += weights.youreFree; reasons.append(.youreFree) }
            if e.isOutdoor && context.rainyEventIDs.contains(e.id) {
                s *= 0.85; reasons.append(.weatherWatch)
            }

            return ScoredEvent(event: e, score: s,
                               reasons: reasons.sorted { $0.strength > $1.strength },
                               distanceKm: e.distanceKm(from: context.home))
        }
        .filter { $0.score > weights.minScore }
        .sorted { $0.score > $1.score }
    }

    // MARK: - Scoring helpers

    /// Genre overlap weighted by the taste's genre weights, normalized 0...1.
    func genreAffinity(_ e: Event, _ taste: TasteProfile) -> Double {
        let eventGenres = Set(e.artistIDs.flatMap { SeedData.artist($0).genres })
        guard !eventGenres.isEmpty, !taste.genreWeights.isEmpty else { return 0 }
        let sum = eventGenres.reduce(0.0) { $0 + (taste.genreWeights[$1] ?? 0) }
        let maxPossible = taste.genreWeights.values.max() ?? 1
        return min(1, sum / (maxPossible * Double(max(1, eventGenres.count))) * Double(eventGenres.count))
            .clamped01()
    }

    /// How much a movie's soundtrack artists overlap the taste, 0...1.
    func soundtrackMatch(_ e: Event, _ taste: TasteProfile) -> Double {
        guard e.type == .movie, !e.artistIDs.isEmpty else { return 0 }
        let known = taste.allArtistIDs
        let onRepeat = Set(taste.onRepeat.map(\.id))
        let hits = e.artistIDs.reduce(0.0) { acc, id in
            if onRepeat.contains(id) { return acc + 1.0 }
            if known.contains(id) { return acc + 0.6 }
            return acc
        }
        return (hits / Double(e.artistIDs.count)).clamped01()
    }

    func filmGenreAffinity(_ e: Event, _ taste: TasteProfile) -> Double {
        guard let genres = e.filmGenres, !genres.isEmpty else { return 0 }
        let overlap = genres.reduce(0.0) { $0 + (taste.genreWeights[$1] ?? 0) }
        return (overlap / Double(genres.count)).clamped01()
    }

    /// max(0.4, 1 - km/100)
    func distanceDecay(_ km: Double) -> Double { max(0.4, 1 - km / 100) }

    /// <3h => 0.7 penalty; 1–10d => 1.0; >14d decays.
    func timingCurve(_ start: Date, now: Date) -> Double {
        let hours = start.timeIntervalSince(now) / 3600
        if hours < 0 { return 0.2 }                 // already passed
        if hours < 3 { return 0.7 }
        let days = hours / 24
        if days <= 10 { return 1.0 }
        if days <= 14 { return 0.9 }
        return max(0.4, 1 - (days - 14) / 30)
    }

    func feedbackFactor(for e: Event) -> Double {
        let ids = e.artistIDs + e.artistIDs.flatMap { SeedData.artist($0).genres }
        let factors = ids.compactMap { feedbackMultipliers[$0] }
        guard !factors.isEmpty else { return 1 }
        return factors.reduce(1, *)
    }
}

extension MatchContext {
    /// Is the evening of `date` calendar-free? Day-granularity.
    func isFree(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        // Default to "free" unless explicitly marked busy — demo-friendly.
        return freeNights.isEmpty || freeNights.contains(comps)
    }
}

private extension Double {
    func clamped01() -> Double { Swift.max(0, Swift.min(1, self)) }
}
