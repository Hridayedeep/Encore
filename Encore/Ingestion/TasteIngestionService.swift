//
//  TasteIngestionService.swift
//  Encore (Flow A) — one poll cycle (see ARCHITECTURE.md)
//
//  Pulls raw signals from the MusicSource, feeds the on-device TasteStore (diff +
//  timestamp + velocity), and returns the derived TasteProfile. Called from the
//  foreground refresh AND from the BGAppRefreshTask handler — same code path, so
//  "the busy user who never opens the app" still gets fresh matches + a push.
//

import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

public struct TasteIngestionService {
    public let source: MusicSource
    public let store: TasteStore
    public init(source: MusicSource, store: TasteStore) {
        self.source = source
        self.store = store
    }

    /// Run one ingest cycle → the freshly derived profile. Falls back to whatever
    /// the persona/store already holds if the live source can't be reached.
    public func runCycle(now: Date, fallback: RawTasteSignals? = nil) async -> TasteProfile {
        let signals: RawTasteSignals
        do {
            signals = try await source.fetchSignals()
        } catch {
            // Live source unavailable (no auth / offline) — use the fallback so the
            // demo never breaks. The store still derives from what it knows.
            signals = fallback ?? RawTasteSignals()
        }
        store.ingest(signals, now: now)
        return store.deriveProfile(latest: signals, now: now)
    }
}

// MARK: - Background scheduling (human adds the plist identifier)

public enum EncoreBackground {
    /// Must also appear in Info.plist `BGTaskSchedulerPermittedIdentifiers`.
    public static let refreshTaskID = "com.encore.refresh"

    /// Ask iOS to wake us later to poll + match. Best-effort (iOS decides timing).
    public static func scheduleRefresh(earliestAfter seconds: TimeInterval = 4 * 3600) {
        #if canImport(BackgroundTasks) && os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(seconds)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    /// Register once at launch. The handler runs `body` (ingest → match → notify)
    /// then reschedules. Wire this from the app's launch if/when background modes
    /// are enabled by the human (see ARCHITECTURE.md → human-owned setup).
    public static func registerHandler(_ body: @escaping () async -> Void) {
        #if canImport(BackgroundTasks) && os(iOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            scheduleRefresh()               // reschedule the next wake-up
            let work = Task {
                await body()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
        #endif
    }
}
