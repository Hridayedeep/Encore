//
//  Itinerary.swift
//  EveningPlanner
//

import Foundation

struct ItineraryStop: Identifiable, Hashable {
    let id = UUID()
    let venueName: String
    let location: String
    let startTime: Date
    let durationMinutes: Int
    let priceLabel: String

    var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime) ?? startTime
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }
}

struct ItineraryVariant: Identifiable, Hashable {
    /// 1-based position among the generated candidates, for the "option X/N" label.
    let id: Int
    let stops: [ItineraryStop]
    let totalCost: Int
    /// Filled in lazily by ItineraryNarrationService once this variant is
    /// actually viewed — never blocks itinerary generation itself.
    var narration: String?
}
