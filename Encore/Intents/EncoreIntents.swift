//
//  EncoreIntents.swift
//  Encore (Flow A) — App Intents, the shared action layer (see claude.md §10.1)
//
//  DUAL-TARGET: add to BOTH the app and the EncoreWidget target (the widget's
//  interactive buttons instantiate these). Each opens the app and hands off a
//  route via the App Group; the app consumes it on foreground and navigates.
//

import Foundation
import AppIntents

// MARK: - Book the show (widget / Siri / notification)

@available(iOS 17.0, *)
public struct BookShowIntent: AppIntent {
    public static var title: LocalizedStringResource = "Book Show"
    public static var description = IntentDescription("Open Encore to book this show.")
    public static var openAppWhenRun = true

    @Parameter(title: "Event ID")
    public var eventID: String

    public init() {}
    public init(eventID: String) { self.eventID = eventID }

    public func perform() async throws -> some IntentResult {
        EncoreSharedStore.setPendingRoute(NotifRoute(eventID: eventID, stage: .match))
        return .result()
    }
}

// MARK: - Order pre-show essentials (Blinkit)

@available(iOS 17.0, *)
public struct OrderEssentialsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Order Essentials"
    public static var description = IntentDescription("Open Encore to order pre-show essentials.")
    public static var openAppWhenRun = true

    @Parameter(title: "Event ID")
    public var eventID: String

    public init() {}
    public init(eventID: String) { self.eventID = eventID }

    public func perform() async throws -> some IntentResult {
        EncoreSharedStore.setPendingRoute(NotifRoute(eventID: eventID, stage: .preEvent))
        return .result()
    }
}

// MARK: - Order post-show food (Zomato / Bistro)

@available(iOS 17.0, *)
public struct OrderFoodIntent: AppIntent {
    public static var title: LocalizedStringResource = "Order Food"
    public static var description = IntentDescription("Open Encore to order food after the show.")
    public static var openAppWhenRun = true

    @Parameter(title: "Event ID")
    public var eventID: String

    public init() {}
    public init(eventID: String) { self.eventID = eventID }

    public func perform() async throws -> some IntentResult {
        EncoreSharedStore.setPendingRoute(NotifRoute(eventID: eventID, stage: .postEvent))
        return .result()
    }
}

// MARK: - Find shows for my taste (Siri / Spotlight / Control Center)

@available(iOS 17.0, *)
public struct FindShowsForMyTasteIntent: AppIntent {
    public static var title: LocalizedStringResource = "Find Shows For My Taste"
    public static var description = IntentDescription("See concerts and movies matched to your music taste.")
    public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Route to the hero if we have a fresh snapshot; else just open the feed.
        if let id = EncoreSharedStore.readSnapshot()?.nextEventID {
            EncoreSharedStore.setPendingRoute(NotifRoute(eventID: id, stage: .match))
        }
        return .result(dialog: "Here are shows matched to your taste.")
    }
}
