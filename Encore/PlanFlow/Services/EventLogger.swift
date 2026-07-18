//
//  EventLogger.swift
//  EveningPlanner
//
//  Feedback taps just print today; swapping ConsoleEventLogger for a real
//  analytics SDK implementation is the entire migration later.
//

import Foundation

struct AnalyticsEvent {
    let name: String
    let properties: [String: String]

    static func itineraryFeedback(variantId: Int, liked: Bool) -> AnalyticsEvent {
        AnalyticsEvent(
            name: "itinerary_feedback",
            properties: ["variant_id": String(variantId), "liked": String(liked)]
        )
    }
}

protocol EventLogger {
    func log(_ event: AnalyticsEvent)
}

struct ConsoleEventLogger: EventLogger {
    func log(_ event: AnalyticsEvent) {
        print("[event] \(event.name) \(event.properties)")
    }
}
