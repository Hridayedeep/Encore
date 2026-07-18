//
//  Venue.swift
//  EveningPlanner
//
//  vibeTags are plain strings matching the questionnaire's vibe option
//  values (see plan_my_evening_questionnaire.json) — no enum bridging,
//  so a new vibe tag never needs a Swift change on this side either.
//

import Foundation

enum VenueCategory: String, Codable {
    case activity
    case food
}

struct Venue: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let location: String
    let category: VenueCategory
    let vibeTags: [String]
    var pricePerHour: Int?
    var pricePerHead: Int?

    var priceLabel: String {
        if let pricePerHour { return "\(PriceFormatter.rupees(pricePerHour))/hr" }
        if let pricePerHead { return "\(PriceFormatter.rupees(pricePerHead))/person" }
        return "Free"
    }

    var representativePrice: Int {
        pricePerHour ?? pricePerHead ?? 0
    }

    /// Per-head venues scale with the group; per-hour venues (a court/room
    /// booking) don't — the booking costs the same whether 2 or 8 people show up.
    func cost(forGroupSize groupSize: Int) -> Int {
        if let pricePerHead { return pricePerHead * max(groupSize, 1) }
        return pricePerHour ?? 0
    }

    /// "🧍" for a solo booking, "👥" for a group — the emoji carries the
    /// per-person-total context that used to be spelled out in words.
    func priceLabel(forGroupSize groupSize: Int) -> String {
        if let pricePerHour { return "\(PriceFormatter.rupees(pricePerHour))/hr" }
        if let pricePerHead {
            guard groupSize > 1 else { return "\(PriceFormatter.rupees(pricePerHead)) 🧍" }
            return "\(PriceFormatter.rupees(pricePerHead * groupSize)) 👥"
        }
        return "Free"
    }
}
