//
//  CalendarService.swift
//  EveningPlanner
//
//  Real EventKit integration: creates one calendar event per itinerary
//  stop. Requires NSCalendarsFullAccessUsageDescription in Info.plist.
//

import EventKit
import Foundation

struct CalendarService {
    enum CalendarServiceError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Calendar access was denied. Enable it in Settings to add these events."
            }
        }
    }

    func addEvents(for variant: ItineraryVariant) async throws {
        let store = EKEventStore()
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarServiceError.accessDenied }

        for stop in variant.stops {
            let event = EKEvent(eventStore: store)
            event.title = stop.venueName
            event.location = stop.location
            event.startDate = stop.startTime
            event.endDate = stop.endTime
            event.calendar = store.defaultCalendarForNewEvents
            try store.save(event, span: .thisEvent)
        }
    }
}
