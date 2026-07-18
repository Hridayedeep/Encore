//
//  EncoreNotifications.swift
//  Encore (Flow A) — local notification pipeline (see claude.md §10.3, §21)
//
//  ALL local (no APNs / no server). The on-device engine decides to notify; these
//  are how that decision surfaces. Three moments:
//    1. Match found   — immediate, .timeSensitive  → tap opens Event Detail
//    2. Pre-event     — calendar trigger ~2h before → "grab Blinkit essentials"
//    3. Post-event    — calendar trigger at show end → "order Zomato/Bistro"
//  Scheduled local notifications (2 & 3) fire even if the app is killed.
//

import Foundation
import UserNotifications

// NotifStage + NotifRoute now live in Shared/EncoreSnapshot.swift (dual-targeted).

public final class EncoreNotifications: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = EncoreNotifications()

    /// Set by the root view; fires when a notification is tapped.
    public var onTap: ((NotifRoute) -> Void)?

    private let center = UNUserNotificationCenter.current()

    // Category + action identifiers
    private enum Category { static let match = "ENCORE_MATCH", pre = "ENCORE_PRE", post = "ENCORE_POST" }
    private enum Action {
        static let book = "ENCORE_BOOK", essentials = "ENCORE_ESSENTIALS"
        static let food = "ENCORE_FOOD", dismiss = "ENCORE_DISMISS"
    }

    // MARK: Bootstrap (call once at launch)

    public func bootstrap() {
        center.delegate = self
        registerCategories()
    }

    private func registerCategories() {
        let dismiss = UNNotificationAction(identifier: Action.dismiss, title: "Dismiss", options: [])
        let match = UNNotificationCategory(
            identifier: Category.match,
            actions: [UNNotificationAction(identifier: Action.book, title: "See the night", options: [.foreground]), dismiss],
            intentIdentifiers: [], options: [])
        let pre = UNNotificationCategory(
            identifier: Category.pre,
            actions: [UNNotificationAction(identifier: Action.essentials, title: "Order essentials", options: [.foreground]), dismiss],
            intentIdentifiers: [], options: [])
        let post = UNNotificationCategory(
            identifier: Category.post,
            actions: [UNNotificationAction(identifier: Action.food, title: "Order food", options: [.foreground]), dismiss],
            intentIdentifiers: [], options: [])
        center.setNotificationCategories([match, pre, post])
    }

    // MARK: Authorization

    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        } catch { return false }
    }

    public func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    // MARK: Fire / schedule

    /// Match found — immediate, time-sensitive. Great for the "busy user" story.
    public func fireMatchFound(eventID: String, title: String, body: String) {
        let content = base(title: title, body: body, category: Category.match,
                           eventID: eventID, stage: .match)
        content.interruptionLevel = .timeSensitive
        add(id: "match-\(eventID)", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
    }

    /// Pre-event Blinkit nudge, ~`hoursBefore` before showtime (fires app-killed).
    public func schedulePreEvent(eventID: String, venueName: String, start: Date, hoursBefore: Double = 2) {
        let when = start.addingTimeInterval(-hoursBefore * 3600)
        let content = base(title: "Pre-show check 🥤",
                           body: "Grab cold drinks & essentials from Blinkit before you leave for \(venueName).",
                           category: Category.pre, eventID: eventID, stage: .preEvent)
        schedule(id: "pre-\(eventID)", content: content, at: when)
    }

    /// Post-event food nudge at show end (fires app-killed).
    public func schedulePostEvent(eventID: String, end: Date) {
        let content = base(title: "Tired from all that dancing? 🍜",
                           body: "Order hot food home on Zomato — timed to land as you walk in.",
                           category: Category.post, eventID: eventID, stage: .postEvent)
        schedule(id: "post-\(eventID)", content: content, at: end)
    }

    public func cancel(eventID: String) {
        center.removePendingNotificationRequests(withIdentifiers:
            ["match-\(eventID)", "pre-\(eventID)", "post-\(eventID)"])
    }

    /// Demo helper: fire a stage's notification in `seconds` (can't wait on stage).
    public func fireDemo(stage: NotifStage, eventID: String, title: String, body: String, seconds: Double = 5) {
        let category: String
        switch stage { case .match: category = Category.match
                       case .preEvent: category = Category.pre
                       case .postEvent: category = Category.post }
        let content = base(title: title, body: body, category: category, eventID: eventID, stage: stage)
        if stage == .match { content.interruptionLevel = .timeSensitive }
        add(id: "demo-\(stage.rawValue)-\(eventID)", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false))
    }

    // MARK: Builders

    private func base(title: String, body: String, category: String,
                      eventID: String, stage: NotifStage) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["eventID": eventID, "stage": stage.rawValue]
        return content
    }

    private func schedule(id: String, content: UNMutableNotificationContent, at date: Date) {
        guard date > Date() else { return }   // don't schedule in the past
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        add(id: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }

    private func add(id: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger) {
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Delegate

    // Show banners even while the app is foregrounded.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // Handle taps + action buttons → route into the app.
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let eventID = info["eventID"] as? String,
              let stageRaw = info["stage"] as? String,
              let stage = NotifStage(rawValue: stageRaw) else { return }
        if response.actionIdentifier == Action.dismiss { return }
        let route = NotifRoute(eventID: eventID, stage: stage)
        await MainActor.run { onTap?(route) }
    }
}
