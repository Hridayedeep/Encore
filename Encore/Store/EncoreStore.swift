//
//  EncoreStore.swift
//  Encore (Flow A) — @Observable UI source of truth (see ARCHITECTURE.md)
//
//  Owns the sources + on-device services and exposes the shortlist/plan to the UI.
//  The taste pipeline is: MusicSource → TasteIngestionService → TasteStore →
//  EntityResolver → RecommendationEngine. Demo clock/location are injectable.
//

import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
public final class EncoreStore {

    // MARK: Injectable "now" / location (demo overrides)
    public var demoNow: Date? = nil
    public var demoLocation: Coordinate? = nil
    public var now: Date { demoNow ?? Date() }
    public var currentLocation: Coordinate { demoLocation ?? SeedData.home.coordinate }

    // MARK: Sources (swap Hardcoded ↔ MusicKit at the seam)
    public private(set) var musicSource: MusicSource
    public private(set) var eventsSource: EventsSource
    public private(set) var foodSource: FoodSource

    // MARK: On-device services
    public private(set) var tasteStore: TasteStore
    public let resolver: EntityResolver
    public var engine = RecommendationEngine()
    public let nudgeEngine = NudgeEngine()
    public let timingEngine = TimingEngine()

    // MARK: Config
    public var searchRadiusKm: Double = 50
    public var lookaheadDays: Int = 14
    public var partySize: Int = 1
    public let home = SeedData.home

    // MARK: State
    public private(set) var taste: TasteProfile?
    public var activePersona: Persona?
    public private(set) var shortlist: [ScoredEvent] = []
    public private(set) var nudges: [String: EventNudge] = [:]
    public var dismissedEventIDs: Set<String> = []
    public var currentPlan: OccasionPlan?
    public var isLoading = false
    /// True when taste came from the live MusicKit source (else demo persona).
    public var usingLiveTaste = false

    // MARK: Notifications
    public var pendingNotificationRoute: NotifRoute?
    private var didFireMatchNotification = false

    // MARK: Init

    public init(persona: Persona? = nil, now: Date = Date()) {
        let p = persona ?? SeedData.personas[0]
        self.musicSource = HardcodedMusicSource(persona: p)
        self.eventsSource = HardcodedEventsSource(now: now)
        self.foodSource = HardcodedFoodSource()
        self.tasteStore = TasteStore(namespace: persona?.id ?? "demo")
        self.resolver = EntityResolver()
        self.activePersona = persona
    }

    // MARK: Connect (persona now; MusicKit later)

    public func connect(persona: Persona) async {
        activePersona = persona
        musicSource = HardcodedMusicSource(persona: persona)
        eventsSource = HardcodedEventsSource(now: now)
        tasteStore = TasteStore(namespace: persona.id)
        usingLiveTaste = false
        await refresh()
    }

    /// Attempt the live Apple Music source; fall back to persona if unauthorized.
    public func connectAppleMusic() async -> Bool {
        let ok = await MusicKitMusicSource.authorize()
        guard ok else { return false }
        musicSource = MusicKitMusicSource()
        tasteStore = TasteStore(namespace: "applemusic")
        usingLiveTaste = true
        await refresh()
        return true
    }

    // MARK: Refresh — the full taste → match pipeline

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Persona signals double as the fallback if the live source can't be reached.
        let fallback = try? await HardcodedMusicSource(
            persona: activePersona ?? SeedData.personas[0]).fetchSignals()

        let ingestion = TasteIngestionService(source: musicSource, store: tasteStore)
        var profile = await ingestion.runCycle(now: now, fallback: fallback)

        // Entity resolution: remap taste artists onto the bookable District roster
        // so id-based matching works for BOTH the hardcoded and live paths.
        if let inventory = try? await eventsSource.inventoryArtists() {
            profile = resolveTaste(profile, against: inventory)
        }
        self.taste = profile

        guard let events = try? await eventsSource.events(
            near: currentLocation, radiusKm: searchRadiusKm, within: lookaheadDays) else {
            shortlist = []; nudges = [:]; return
        }

        // Related-artist set for the "similar sound" beat.
        var related = Set<String>()
        for id in profile.allArtistIDs {
            if let more = try? await musicSource.relatedArtists(to: id) {
                related.formUnion(more.map(\.id))
            }
        }
        related.subtract(profile.allArtistIDs)

        var eng = engine
        eng.feedbackMultipliers = tasteStore.feedback
        let context = MatchContext(home: home, now: now, relatedIDs: related)

        let ranked = eng.rank(events, for: profile, context: context)
            .filter { !dismissedEventIDs.contains($0.event.id) }

        shortlist = Array(ranked.prefix(8))
        nudges = Dictionary(uniqueKeysWithValues: shortlist.map {
            ($0.event.id, nudgeEngine.nudge(for: $0, taste: profile, now: now))
        })
        writeSnapshot()
    }

    /// Publish the small shared snapshot the widget + Live Activity read.
    private func writeSnapshot() {
        var snap = EncoreSnapshot()
        if let hero = heroEvent {
            snap.nextEventID = hero.event.id
            snap.nextEventTitle = hero.event.title
            snap.nextEventVenue = hero.event.venue.name
            snap.nextEventDate = hero.event.startTime
            snap.heroHeadline = nudge(for: hero.event)?.headline
        }
        if let plan = currentPlan {
            snap.planStatus = plan.status.rawValue
            // Once booked, the widget should point at the booked show.
            snap.nextEventID = plan.event.id
            snap.nextEventTitle = plan.event.title
            snap.nextEventVenue = plan.event.venue.name
            snap.nextEventDate = plan.event.startTime
            if let ready = plan.postEvent?.computedReadyBy {
                let f = DateFormatter(); f.timeStyle = .short
                snap.readyByText = f.string(from: ready)
            }
        }
        EncoreSharedStore.writeSnapshot(snap)
        // Tell WidgetKit to refresh now instead of waiting for its ~15-min policy,
        // so the Home Screen widget reflects the new match / booking immediately.
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Rewrite taste-artist ids to their District inventory ids where resolvable.
    private func resolveTaste(_ profile: TasteProfile, against inventory: [Artist]) -> TasteProfile {
        func remap(_ artist: Artist) -> Artist { resolver.resolve(artist, against: inventory) ?? artist }
        var p = profile
        p.onRepeat = profile.onRepeat.map { remap($0) }
        p.discovered = profile.discovered.map { remap($0) }
        p.topArtists = profile.topArtists.map {
            ScoredArtist(artist: remap($0.artist), frequency: $0.frequency, recencyWeight: $0.recencyWeight)
        }
        return p
    }

    public var heroEvent: ScoredEvent? { shortlist.first }
    public var restOfShortlist: [ScoredEvent] { Array(shortlist.dropFirst()) }
    public func nudge(for event: Event) -> EventNudge? { nudges[event.id] }

    /// Look up an event by id across the current shortlist + full seed catalog.
    public func event(id: String) -> Event? {
        shortlist.first { $0.event.id == id }?.event
            ?? SeedData.events(now: now).first { $0.id == id }
    }

    // MARK: Notification triggers

    public func requestNotificationPermission() async {
        _ = await EncoreNotifications.shared.requestAuthorization()
    }

    /// Fire the match-found nudge for the hero once per session (demo of the
    /// "busy user gets pinged" story). No-op if not authorized.
    public func notifyMatchFoundIfNeeded() async {
        guard !didFireMatchNotification, let hero = heroEvent,
              await EncoreNotifications.shared.isAuthorized() else { return }
        didFireMatchNotification = true
        let nudge = nudge(for: hero.event)
        EncoreNotifications.shared.fireMatchFound(
            eventID: hero.event.id,
            title: "A show for you 🎟",
            body: nudge?.headline ?? hero.event.title)
    }

    /// On booking: schedule the pre-event (Blinkit) + post-event (Zomato) nudges.
    public func scheduleBookingNudges() {
        guard let plan = currentPlan else { return }
        EncoreNotifications.shared.schedulePreEvent(
            eventID: plan.event.id, venueName: plan.event.venue.name, start: plan.event.startTime)
        EncoreNotifications.shared.schedulePostEvent(
            eventID: plan.event.id, end: plan.event.endTime)
    }

    // MARK: Feedback loop (dismiss down-weights, book up-weights)

    public func dismiss(_ event: Event) {
        dismissedEventIDs.insert(event.id)
        applyFeedback(to: event, factor: 0.85)
        shortlist.removeAll { $0.event.id == event.id }
    }

    private func applyFeedback(to event: Event, factor: Double) {
        let genres = event.artistIDs.flatMap { SeedData.artist($0).genres }
        tasteStore.nudgeFeedback(artistIDs: event.artistIDs, genres: genres, factor: factor)
    }

    // MARK: Occasion building

    public func buildOccasion(for event: Event) async -> OccasionPlan {
        let dinner = await defaultDinner(for: event)
        let preDrinks = defaultPreDrinks(for: event)
        let post = await defaultPostEvent(for: event, timing: .onArrival)
        let plan = OccasionPlan(event: event, partySize: partySize,
                                dinner: dinner, preDrinks: preDrinks,
                                postEvent: post, status: .draft)
        currentPlan = plan
        return plan
    }

    public func defaultDinner(for event: Event) async -> DinnerOption {
        let nearby = (try? await foodSource.restaurants(near: event.venue.coordinate)) ?? []
        let restaurant = nearby.first ?? SeedData.nearestRestaurant(to: event)
        let time = event.startTime.addingTimeInterval(-90 * 60)
        return DinnerOption(restaurant: restaurant, time: time, vendor: .zomato)
    }

    public func defaultPreDrinks(for event: Event) -> BlinkitCart {
        let items = SeedData.blinkitCatalog.filter { ["b1", "b2"].contains($0.id) }
        let deliverBefore = event.startTime.addingTimeInterval(-120 * 60)
        return BlinkitCart(items: items, deliverBefore: deliverBefore)
    }

    public func defaultPostEvent(for event: Event, timing: DeliveryTiming) async -> PostEventOrder? {
        let open = timingEngine.restaurantsOpen(at: event.endTime)
        let vendor = timingEngine.pickVendor(now: now, restaurantsOpen: open)
        let catalog = vendor == .blinkit ? SeedData.blinkitCatalog : SeedData.bistroCatalog
        let items = Array(catalog.prefix(2))
        let eta = (try? await foodSource.estimatedETA(vendor: vendor, to: home.coordinate)) ?? (15 * 60)
        return timingEngine.planPostEvent(
            event: event, home: home, currentLoc: currentLocation,
            vendorETA: eta, timing: timing, suggestedItems: items, vendor: vendor, now: now)
    }

    public func recomputePostEvent(timing: DeliveryTiming) async {
        guard var plan = currentPlan else { return }
        plan.postEvent = await defaultPostEvent(for: plan.event, timing: timing)
        currentPlan = plan
        writeSnapshot()
        // Reflect the new "ready by" on a running Live Activity.
        if plan.status == .booked, let post = plan.postEvent {
            EncoreLiveActivityController.shared.update(
                phase: .getEssentials,
                message: "Hot food home ~as you walk in.",
                countdownTarget: plan.event.startTime,
                readyByText: EncoreLiveActivityController.timeString(post.computedReadyBy))
        }
    }

    // MARK: Booking

    public func confirmBooking() {
        guard var plan = currentPlan else { return }
        plan.status = .booked
        currentPlan = plan
        applyFeedback(to: plan.event, factor: 1.1)
        writeSnapshot()
        EncoreLiveActivityController.shared.start(plan: plan)
    }

    // MARK: Live Activity phase control (used by later demo panel)

    public func advanceLiveActivity(to phase: EncoreActivityAttributes.ContentState.Phase) {
        guard let plan = currentPlan else { return }
        let message: String
        let countdown: Date
        var readyBy: String? = nil
        switch phase {
        case .upcoming, .getEssentials:
            message = "Heading out soon? Grab your pre-show essentials."
            countdown = plan.event.startTime
        case .liveNow:
            message = "Enjoy the show 🎶"
            countdown = plan.event.endTime
        case .postShow:
            message = "Tired from dancing? Order hot food home."
            countdown = plan.event.endTime
            if let ready = plan.postEvent?.computedReadyBy {
                readyBy = EncoreLiveActivityController.timeString(ready)
            }
        }
        EncoreLiveActivityController.shared.update(
            phase: phase, message: message, countdownTarget: countdown, readyByText: readyBy)
    }

    public func endLiveActivity() { EncoreLiveActivityController.shared.end() }

    // MARK: Consume App-Intent / widget route (call on foreground)

    public func consumeSharedPendingRoute() {
        if let route = EncoreSharedStore.consumePendingRoute() {
            pendingNotificationRoute = route
        }
    }
}
