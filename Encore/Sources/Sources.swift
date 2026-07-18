//
//  Sources.swift
//  Encore (Flow A) — source protocols + hardcoded impls (see ARCHITECTURE.md, §4)
//
//  The seam to real APIs. `MusicSource` exposes the RAW weighted signals from the
//  Data Ingestion Matrix — the on-device TasteStore is what timestamps + derives
//  the TasteProfile. UI never touches hardcoded data directly.
//

import Foundation

// MARK: - Raw taste signals (one poll's worth, straight from the source)

/// Ordered = strongest first. Weights are applied downstream by TasteStore.
public struct RawTasteSignals {
    public var heavyRotation: [Artist]      // v1/me/history/heavy-rotation — High
    public var topArtistsRanked: [Artist]   // v1/me/music-summaries (Replay) — Very High
    public var recentlyPlayed: [Artist]     // v1/me/recent/played — Medium (recency/discovery)
    public var recommendations: [Artist]    // v1/me/recommendations — Low (explore only)
    public init(heavyRotation: [Artist] = [], topArtistsRanked: [Artist] = [],
                recentlyPlayed: [Artist] = [], recommendations: [Artist] = []) {
        self.heavyRotation = heavyRotation
        self.topArtistsRanked = topArtistsRanked
        self.recentlyPlayed = recentlyPlayed
        self.recommendations = recommendations
    }
}

// MARK: - Protocols

public protocol MusicSource {
    /// True for the live MusicKit source, false for a hardcoded persona.
    var isLive: Bool { get }
    /// One poll of the raw signals (the ingestion layer feeds these to TasteStore).
    func fetchSignals() async throws -> RawTasteSignals
    func relatedArtists(to artistID: String) async throws -> [Artist]
}

public protocol EventsSource {
    func events(near coord: Coordinate, radiusKm: Double, within days: Int) async throws -> [Event]
    func deepLink(for event: Event) -> URL
    /// The full artist roster in the inventory — used by the EntityResolver.
    func inventoryArtists() async throws -> [Artist]
}

public protocol FoodSource {                             // Zomato + Blinkit + Bistro unified
    func restaurants(near coord: Coordinate) async throws -> [Restaurant]
    func quickCommerceCatalog() async throws -> [CartItem]
    func bistroCatalog() async throws -> [CartItem]
    func estimatedETA(vendor: Vendor, to coord: Coordinate) async throws -> TimeInterval
}

// MARK: - Hardcoded music source (a persona)

public struct HardcodedMusicSource: MusicSource {
    public let persona: Persona
    public var isLive: Bool { false }
    public init(persona: Persona) { self.persona = persona }

    public func fetchSignals() async throws -> RawTasteSignals {
        let t = persona.taste
        let discoveredIDs = Set(t.discovered.map(\.id))
        // Discovered artists are deliberately kept OUT of the baseline signals
        // (heavy-rotation / top-artists) — an artist you just found wouldn't be in
        // your Replay top or heavy rotation yet. They appear only in recent/recs,
        // so the velocity logic in TasteStore can flag them as "newly discovered",
        // exactly as it would with live data.
        let baselineTop = t.topArtists.map(\.artist).filter { !discoveredIDs.contains($0.id) }
        let baselineHeavy = t.onRepeat.filter { !discoveredIDs.contains($0.id) }
        let recent = t.discovered + t.discovered + t.onRepeat + baselineTop  // discovered weighted up
        return RawTasteSignals(
            heavyRotation: baselineHeavy,
            topArtistsRanked: baselineTop,
            recentlyPlayed: recent,
            recommendations: t.discovered
        )
    }

    public func relatedArtists(to artistID: String) async throws -> [Artist] {
        (SeedData.relatedGraph[artistID] ?? []).map { SeedData.artist($0) }
    }
}

// MARK: - Hardcoded events source

public struct HardcodedEventsSource: EventsSource {
    private let now: Date
    public init(now: Date) { self.now = now }

    public func events(near coord: Coordinate, radiusKm: Double, within days: Int) async throws -> [Event] {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        return SeedData.events(now: now).filter { event in
            let within = event.startTime >= now && event.startTime <= cutoff
            let near = coord.distanceKm(to: event.venue.coordinate) <= radiusKm
            return within && near
        }
    }

    public func deepLink(for event: Event) -> URL { event.districtDeepLink }

    public func inventoryArtists() async throws -> [Artist] {
        let ids = Set(SeedData.events(now: now).flatMap(\.artistIDs))
        return ids.map { SeedData.artist($0) }
    }
}

// MARK: - Hardcoded food source

public struct HardcodedFoodSource: FoodSource {
    public init() {}

    public func restaurants(near coord: Coordinate) async throws -> [Restaurant] {
        SeedData.restaurants.sorted {
            coord.distanceKm(to: $0.place.coordinate) < coord.distanceKm(to: $1.place.coordinate)
        }
    }

    public func quickCommerceCatalog() async throws -> [CartItem] { SeedData.blinkitCatalog }
    public func bistroCatalog() async throws -> [CartItem] { SeedData.bistroCatalog }

    public func estimatedETA(vendor: Vendor, to coord: Coordinate) async throws -> TimeInterval {
        let minutes: Double
        switch vendor {
        case .bistro:          minutes = 12
        case .blinkit:         minutes = 15
        case .zomato:          minutes = 35
        case .districtDining:  minutes = 40
        }
        return minutes * 60
    }
}
