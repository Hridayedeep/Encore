//
//  TasteStore.swift
//  Encore (Flow A) — the on-device "backend" (see ARCHITECTURE.md)
//
//  Apple Music gives no timestamps and no "newly discovered" endpoint, so WE
//  become the clock. This store keeps a KnownArtists baseline + a timestamped
//  observation log, ingests each poll's RawTasteSignals, and derives the
//  TasteProfile (incl. discovery via velocity). Persisted as a Codable JSON
//  snapshot in UserDefaults now; SwiftData is a drop-in upgrade later.
//

import Foundation

/// One artist we've observed listening to, with OUR timestamp (Apple gives none).
public struct ArtistObservation: Codable {
    public var artist: Artist
    public var firstSeenAt: Date        // device time on first sighting
    public var lastSeenAt: Date
    public var plays: Int               // cumulative weighted plays we've tallied
}

public struct TasteSnapshot: Codable {
    public var knownBaseline: [String]                  // artist ids captured at onboarding
    public var observations: [String: ArtistObservation]
    public var lastPolledAt: Date?
    public var feedback: [String: Double]               // artist/genre -> multiplier
    public init(knownBaseline: [String] = [], observations: [String: ArtistObservation] = [:],
                lastPolledAt: Date? = nil, feedback: [String: Double] = [:]) {
        self.knownBaseline = knownBaseline
        self.observations = observations
        self.lastPolledAt = lastPolledAt
        self.feedback = feedback
    }
}

public final class TasteStore {

    // Tunables
    public var discoveryWindowDays = 14
    public var velocityWindowHours = 72.0
    // Share of recent plays an unknown artist must reach to count as "discovered".
    // 0.15 is the production target; tuned lower here for the small demo catalog.
    public var velocityThreshold = 0.05

    private let defaultsKey: String
    private let defaults: UserDefaults
    public private(set) var snapshot: TasteSnapshot

    public init(namespace: String = "default", defaults: UserDefaults = .standard) {
        self.defaultsKey = "encore.taste.\(namespace)"
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(TasteSnapshot.self, from: data) {
            self.snapshot = decoded
        } else {
            self.snapshot = TasteSnapshot()
        }
    }

    // MARK: Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    public func reset() {
        snapshot = TasteSnapshot()
        persist()
    }

    // MARK: Baseline (once, at onboarding)

    /// Establish "Known Artists" — anyone here can never later be "newly discovered".
    public func establishBaselineIfNeeded(from signals: RawTasteSignals) {
        guard snapshot.knownBaseline.isEmpty else { return }
        let baseline = signals.heavyRotation + signals.topArtistsRanked
        snapshot.knownBaseline = Array(Set(baseline.map(\.id)))
        persist()
    }

    // MARK: Ingestion (each background/foreground poll)

    /// Diff this poll against what we've seen; stamp new artists with device time.
    public func ingest(_ signals: RawTasteSignals, now: Date) {
        establishBaselineIfNeeded(from: signals)

        // Weight each endpoint by intent (Data Ingestion Matrix).
        func record(_ artists: [Artist], weight: Int) {
            for artist in artists {
                if var obs = snapshot.observations[artist.id] {
                    obs.lastSeenAt = now
                    obs.plays += weight
                    snapshot.observations[artist.id] = obs
                } else {
                    snapshot.observations[artist.id] = ArtistObservation(
                        artist: artist, firstSeenAt: now, lastSeenAt: now, plays: weight)
                }
            }
        }
        record(signals.topArtistsRanked, weight: 5)   // Very High
        record(signals.heavyRotation,    weight: 4)   // High
        record(signals.recentlyPlayed,   weight: 2)   // Medium
        record(signals.recommendations,  weight: 1)   // Low

        snapshot.lastPolledAt = now
        persist()
    }

    // MARK: Derivation → TasteProfile

    public func deriveProfile(latest signals: RawTasteSignals, now: Date) -> TasteProfile {
        let onRepeat = signals.heavyRotation

        // Ranked top artists (Replay), scored by frequency*recency from our log.
        let topArtists: [ScoredArtist] = signals.topArtistsRanked.enumerated().map { idx, artist in
            let obs = snapshot.observations[artist.id]
            let frequency = Double(obs?.plays ?? (signals.topArtistsRanked.count - idx))
            let recency = recencyWeight(obs?.lastSeenAt, now: now)
            return ScoredArtist(artist: artist, frequency: frequency, recencyWeight: recency)
        }

        let discovered = detectDiscovered(now: now)
        let genreWeights = deriveGenreWeights(onRepeat: onRepeat, top: signals.topArtistsRanked)

        return TasteProfile(topArtists: topArtists, onRepeat: onRepeat,
                            discovered: discovered, genreWeights: genreWeights)
    }

    /// Newly-discovered = not in baseline, first seen inside the window, and its
    /// share of recent plays crosses the velocity threshold.
    private func detectDiscovered(now: Date) -> [Artist] {
        let baseline = Set(snapshot.knownBaseline)
        let windowStart = now.addingTimeInterval(-velocityWindowHours * 3600)
        let discoveryStart = now.addingTimeInterval(-Double(discoveryWindowDays) * 86_400)

        let recentObs = snapshot.observations.values.filter { $0.lastSeenAt >= windowStart }
        let totalRecentPlays = max(1, recentObs.reduce(0) { $0 + $1.plays })

        return snapshot.observations.values
            .filter { obs in
                !baseline.contains(obs.artist.id)
                && obs.firstSeenAt >= discoveryStart
                && Double(obs.plays) / Double(totalRecentPlays) >= velocityThreshold
            }
            .sorted { $0.firstSeenAt > $1.firstSeenAt }
            .map(\.artist)
    }

    private func deriveGenreWeights(onRepeat: [Artist], top: [Artist]) -> [String: Double] {
        var tally: [String: Double] = [:]
        for a in onRepeat { for g in a.genres { tally[g, default: 0] += 1.0 } }
        for a in top     { for g in a.genres { tally[g, default: 0] += 0.6 } }
        guard let maxVal = tally.values.max(), maxVal > 0 else { return [:] }
        return tally.mapValues { $0 / maxVal }   // normalize 0...1
    }

    private func recencyWeight(_ lastSeen: Date?, now: Date) -> Double {
        guard let lastSeen else { return 0.5 }
        let days = now.timeIntervalSince(lastSeen) / 86_400
        return max(0.3, 1.0 - days / 30.0)
    }

    // MARK: Feedback loop (dismiss/book weight nudging)

    public func nudgeFeedback(artistIDs: [String], genres: [String], factor: Double) {
        for id in artistIDs { snapshot.feedback[id, default: 1.0] *= factor }
        for g in genres     { snapshot.feedback[g, default: 1.0] *= factor }
        persist()
    }

    public var feedback: [String: Double] { snapshot.feedback }
}
