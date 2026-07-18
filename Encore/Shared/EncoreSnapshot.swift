//
//  EncoreSnapshot.swift
//  Encore (Flow A) — App Group shared surface (see ARCHITECTURE.md, XCODE_SETUP.md)
//
//  DUAL-TARGET: add this file to BOTH the app and the EncoreWidget targets.
//  It's the small, Codable slice the widget + Live Activity read, plus the route
//  hand-off App Intents / notifications use to deep-link into the app.
//

import Foundation

// MARK: - Routing (shared so App Intents, notifications, and the app agree)

public enum NotifStage: String, Codable { case match, preEvent, postEvent }

public struct NotifRoute: Equatable, Codable {
    public var eventID: String
    public var stage: NotifStage
    public init(eventID: String, stage: NotifStage) { self.eventID = eventID; self.stage = stage }
}

// MARK: - Snapshot the widget/Live Activity read

public struct EncoreSnapshot: Codable, Equatable {
    public var nextEventID: String?
    public var nextEventTitle: String?
    public var nextEventVenue: String?
    public var nextEventDate: Date?
    public var heroHeadline: String?
    public var planStatus: String?          // draft / booked / live / completed
    public var readyByText: String?         // post-event "hot food home ~11:48"
    public init(nextEventID: String? = nil, nextEventTitle: String? = nil,
                nextEventVenue: String? = nil, nextEventDate: Date? = nil,
                heroHeadline: String? = nil, planStatus: String? = nil,
                readyByText: String? = nil) {
        self.nextEventID = nextEventID; self.nextEventTitle = nextEventTitle
        self.nextEventVenue = nextEventVenue; self.nextEventDate = nextEventDate
        self.heroHeadline = heroHeadline; self.planStatus = planStatus
        self.readyByText = readyByText
    }
}

// MARK: - App Group store (falls back to standard defaults if group not configured)

public enum EncoreSharedStore {
    public static let appGroupID = "group.com.abhinav.Encore"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static let snapshotKey = "encore.snapshot"
    private static let pendingRouteKey = "encore.pendingRoute"

    // Snapshot
    public static func writeSnapshot(_ snapshot: EncoreSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    public static func readSnapshot() -> EncoreSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(EncoreSnapshot.self, from: data)
    }

    // Pending route (App Intents / widget → app)
    public static func setPendingRoute(_ route: NotifRoute) {
        if let data = try? JSONEncoder().encode(route) {
            defaults.set(data, forKey: pendingRouteKey)
        }
    }

    /// Read-and-clear the pending route (call on app foreground).
    public static func consumePendingRoute() -> NotifRoute? {
        guard let data = defaults.data(forKey: pendingRouteKey) else { return nil }
        defaults.removeObject(forKey: pendingRouteKey)
        return try? JSONDecoder().decode(NotifRoute.self, from: data)
    }
}
