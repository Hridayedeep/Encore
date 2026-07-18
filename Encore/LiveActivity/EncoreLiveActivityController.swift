//
//  EncoreLiveActivityController.swift
//  Encore (Flow A) — app-side Live Activity lifecycle (see claude.md §10.5)
//
//  APP TARGET ONLY (ActivityKit request/update must run in the app, not the
//  extension). Starts the activity on booking and drives it locally (no server /
//  pushType: nil) through: upcoming → get essentials → live now → post-show.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
public final class EncoreLiveActivityController {
    public static let shared = EncoreLiveActivityController()
    private init() {}

    #if canImport(ActivityKit)
    // Fully qualified: the host app defines its own `struct Activity`, which would
    // otherwise shadow ActivityKit's generic Activity type.
    private var activity: ActivityKit.Activity<EncoreActivityAttributes>?
    #endif

    public var isSupported: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) { return ActivityAuthorizationInfo().areActivitiesEnabled }
        #endif
        return false
    }

    /// Start the persistent "6-hour occasion" spine at booking success.
    public func start(plan: OccasionPlan) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), isSupported else { return }
        end()   // ensure only one

        let attributes = EncoreActivityAttributes(
            eventID: plan.event.id,
            eventTitle: plan.event.title,
            venueName: plan.event.venue.name)

        let readyBy = plan.postEvent.map { Self.timeString($0.computedReadyBy) }
        let state = EncoreActivityAttributes.ContentState(
            phase: .getEssentials,
            statusMessage: "Heading out soon? Pre-order your pre-show essentials.",
            countdownTarget: plan.event.startTime,
            readyByText: readyBy)

        do {
            activity = try ActivityKit.Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)     // entirely local
        } catch {
            activity = nil
        }
        #endif
    }

    /// Move the activity to a new phase (from timing changes / demo panel).
    public func update(phase: EncoreActivityAttributes.ContentState.Phase,
                       message: String, countdownTarget: Date, readyByText: String? = nil) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = EncoreActivityAttributes.ContentState(
            phase: phase, statusMessage: message,
            countdownTarget: countdownTarget, readyByText: readyByText)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        #endif
    }

    public func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let final = activity
        self.activity = nil
        Task { await final.end(nil, dismissalPolicy: .immediate) }
        #endif
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }
}
