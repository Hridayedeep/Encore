//
//  NudgeEngine.swift
//  Encore (Flow A) — nudge re-ranker/explainer (see claude.md §9)
//
//  Foundation Models produces the second-person hook over the real shortlist. It
//  never invents events. This file ships the MANDATORY template fallback (§9/§19)
//  so the demo never breaks when the model is unavailable; a LanguageModelSession
//  path drops in behind the same `EventNudge` shape when a device supports it.
//

import Foundation

public struct EventNudge: Equatable {
    public var headline: String   // one-line hook in second person naming the listening habit
    public var reason: String     // one sentence: why it matches + distance/day
    public var cta: String        // 2–4 word call to action
    public init(headline: String, reason: String, cta: String) {
        self.headline = headline; self.reason = reason; self.cta = cta
    }
}

public struct NudgeEngine {
    public init() {}

    /// Template nudge — always available, always correct. (FM re-ranker swaps in here.)
    public func nudge(for scored: ScoredEvent, taste: TasteProfile, now: Date) -> EventNudge {
        let event = scored.event
        let artistName = primaryArtistName(for: event)
        let km = Int(scored.distanceKm.rounded())
        let day = Self.relativeDay(event.startTime, now: now)
        let topReason = scored.reasons.first

        let headline: String
        switch topReason {
        case .onRepeat:
            headline = "You've had \(artistName) on repeat — they're \(km) km away \(day)."
        case .soundtrack:
            headline = "\(event.title) is scored by \(artistName) — right up your alley."
        case .topArtist:
            headline = "\(artistName) — one of your most-played — is \(km) km away \(day)."
        case .similarArtist:
            headline = "Loved by fans of your top artists: \(artistName), \(km) km away."
        case .newlyDiscovered:
            headline = "You just found \(artistName) — catch them live \(day)."
        default:
            headline = "\(event.title) — \(km) km away \(day)."
        }

        let reasonText = "\(reasonPhrase(topReason, artist: artistName)) · \(km) km · \(day) · from ₹\(event.priceFrom)"

        let cta = event.type == .movie ? "See the night" : "See the night"
        return EventNudge(headline: headline, reason: reasonText, cta: cta)
    }

    // MARK: - Helpers

    private func primaryArtistName(for event: Event) -> String {
        guard let first = event.artistIDs.first else { return event.title }
        return SeedData.artist(first).name
    }

    private func reasonPhrase(_ reason: MatchReason?, artist: String) -> String {
        guard let reason else { return "Near you soon" }
        switch reason {
        case .onRepeat:        return "On repeat lately"
        case .soundtrack:      return "Soundtrack you love"
        case .topArtist:       return "A top artist"
        case .similarArtist:   return "Sounds like your taste"
        case .newlyDiscovered: return "Newly discovered"
        case .youreFree:       return "You're free"
        case .weatherWatch:    return "Weather watch"
        }
    }

    static func relativeDay(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "tonight"
        case 1: return "tomorrow"
        case 2...6:
            let f = DateFormatter(); f.dateFormat = "EEEE"
            return "on \(f.string(from: date))"
        default:
            let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
            return "on \(f.string(from: date))"
        }
    }
}
