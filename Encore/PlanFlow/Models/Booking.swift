//
//  Booking.swift
//  EveningPlanner
//
//  Represents the single "upcoming event" the Welcome screen's sticky
//  banner points at. Only one at a time today (booking another evening
//  overwrites it) — matches the flow's current one-booking-at-a-time UX.
//

import Foundation

struct Booking: Identifiable {
    let id = UUID()
    let variant: ItineraryVariant
    let bookedAt: Date
    var calendarAdded: Bool = false

    var primaryLocation: String {
        variant.stops.first?.location ?? "Your evening"
    }

    var startTime: Date {
        variant.stops.first?.startTime ?? bookedAt
    }
}
