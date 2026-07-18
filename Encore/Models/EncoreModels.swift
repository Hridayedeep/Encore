//
//  EncoreModels.swift
//  Encore (Flow A) — data models (see claude.md §5)
//
//  The contract. Real-shaped so live APIs are a drop-in later. All types are
//  prefixed conceptually under "Encore" via this module; names match the spec.
//

import Foundation

// MARK: - Geo

public struct Coordinate: Codable, Hashable {
    public var lat: Double
    public var lng: Double
    public init(lat: Double, lng: Double) { self.lat = lat; self.lng = lng }

    /// Great-circle distance in km (haversine).
    public func distanceKm(to other: Coordinate) -> Double {
        let r = 6371.0
        let dLat = (other.lat - lat) * .pi / 180
        let dLng = (other.lng - lng) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat * .pi / 180) * cos(other.lat * .pi / 180)
            * sin(dLng / 2) * sin(dLng / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}



public struct Place: Codable, Hashable {
    public var name: String
    public var coordinate: Coordinate
    public var area: String
    public init(name: String, coordinate: Coordinate, area: String) {
        self.name = name; self.coordinate = coordinate; self.area = area
    }
}

// MARK: - Taste

public struct Artist: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var genres: [String]
    public var artworkAsset: String?   // local asset name in prototype
    public init(id: String, name: String, genres: [String], artworkAsset: String? = nil) {
        self.id = id; self.name = name; self.genres = genres; self.artworkAsset = artworkAsset
    }
}

public struct ScoredArtist: Codable, Hashable {
    public var artist: Artist
    public var frequency: Double
    public var recencyWeight: Double
    public init(artist: Artist, frequency: Double, recencyWeight: Double) {
        self.artist = artist; self.frequency = frequency; self.recencyWeight = recencyWeight
    }
}

public struct TasteProfile: Codable {
    public var topArtists: [ScoredArtist]      // ranked by frequency*recency
    public var onRepeat: [Artist]              // heavy rotation — strongest signal
    public var discovered: [Artist]            // first seen < 14 days ago
    public var genreWeights: [String: Double]  // normalized 0...1
    public init(topArtists: [ScoredArtist], onRepeat: [Artist], discovered: [Artist], genreWeights: [String: Double]) {
        self.topArtists = topArtists; self.onRepeat = onRepeat
        self.discovered = discovered; self.genreWeights = genreWeights
    }

    /// Convenience: every artist id known to the taste profile.
    public var allArtistIDs: Set<String> {
        var s = Set(onRepeat.map(\.id))
        s.formUnion(topArtists.map(\.artist.id))
        s.formUnion(discovered.map(\.id))
        return s
    }
}

// MARK: - Events

public enum EventType: String, Codable { case concert, movie, comedy, festival }

public struct Event: Identifiable, Codable, Hashable {
    public var id: String
    public var type: EventType
    public var title: String
    public var artistIDs: [String]        // concerts: performers; movies: soundtrack artists
    public var filmGenres: [String]?      // movies only
    public var venue: Place
    public var startTime: Date
    public var durationMinutes: Int
    public var priceFrom: Int             // ₹
    public var isOutdoor: Bool
    public var posterAsset: String        // local image asset (nil-safe in UI)
    public var districtDeepLink: URL

    public init(id: String, type: EventType, title: String, artistIDs: [String],
                filmGenres: [String]? = nil, venue: Place, startTime: Date,
                durationMinutes: Int, priceFrom: Int, isOutdoor: Bool,
                posterAsset: String, districtDeepLink: URL) {
        self.id = id; self.type = type; self.title = title; self.artistIDs = artistIDs
        self.filmGenres = filmGenres; self.venue = venue; self.startTime = startTime
        self.durationMinutes = durationMinutes; self.priceFrom = priceFrom
        self.isOutdoor = isOutdoor; self.posterAsset = posterAsset
        self.districtDeepLink = districtDeepLink
    }

    public var endTime: Date { startTime.addingTimeInterval(Double(durationMinutes) * 60) }
    public func distanceKm(from home: Place) -> Double { home.coordinate.distanceKm(to: venue.coordinate) }
}

// MARK: - Occasion / orchestration

public enum PlanStatus: String, Codable { case draft, booked, live, completed }

public enum Vendor: String, Codable { case zomato, blinkit, bistro, districtDining }

public enum DeliveryTiming: Codable, Equatable, Hashable {
    case now, onArrival, whenMinutesAway(Int), skip
}

public struct Restaurant: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var cuisine: String
    public var place: Place
    public var etaMinutes: Int
    public var priceForTwo: Int
    public var imageAsset: String
    public init(id: String, name: String, cuisine: String, place: Place,
                etaMinutes: Int, priceForTwo: Int, imageAsset: String) {
        self.id = id; self.name = name; self.cuisine = cuisine; self.place = place
        self.etaMinutes = etaMinutes; self.priceForTwo = priceForTwo; self.imageAsset = imageAsset
    }
}

public struct CartItem: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var price: Int
    public var vendor: Vendor
    public var imageAsset: String
    public init(id: String, name: String, price: Int, vendor: Vendor, imageAsset: String) {
        self.id = id; self.name = name; self.price = price; self.vendor = vendor; self.imageAsset = imageAsset
    }
}

public struct DinnerOption: Codable, Hashable {
    public var restaurant: Restaurant
    public var time: Date
    public var vendor: Vendor
    public init(restaurant: Restaurant, time: Date, vendor: Vendor) {
        self.restaurant = restaurant; self.time = time; self.vendor = vendor
    }
}

public struct BlinkitCart: Codable, Hashable {
    public var items: [CartItem]
    public var deliverBefore: Date
    public init(items: [CartItem], deliverBefore: Date) {
        self.items = items; self.deliverBefore = deliverBefore
    }
    public var total: Int { items.reduce(0) { $0 + $1.price } }
}

public struct PostEventOrder: Codable, Hashable {
    public var vendor: Vendor
    public var items: [CartItem]
    public var timing: DeliveryTiming
    public var computedPlaceAt: Date
    public var computedReadyBy: Date
    public init(vendor: Vendor, items: [CartItem], timing: DeliveryTiming,
                computedPlaceAt: Date, computedReadyBy: Date) {
        self.vendor = vendor; self.items = items; self.timing = timing
        self.computedPlaceAt = computedPlaceAt; self.computedReadyBy = computedReadyBy
    }
    public var total: Int { items.reduce(0) { $0 + $1.price } }
}

public struct OccasionPlan: Identifiable, Codable {
    public var id: UUID
    public var event: Event
    public var partySize: Int
    public var dinner: DinnerOption?
    public var preDrinks: BlinkitCart?
    public var postEvent: PostEventOrder?
    public var status: PlanStatus
    public init(id: UUID = UUID(), event: Event, partySize: Int,
                dinner: DinnerOption? = nil, preDrinks: BlinkitCart? = nil,
                postEvent: PostEventOrder? = nil, status: PlanStatus = .draft) {
        self.id = id; self.event = event; self.partySize = partySize
        self.dinner = dinner; self.preDrinks = preDrinks
        self.postEvent = postEvent; self.status = status
    }
}

// MARK: - Recommendation engine value types (see §7)

public enum MatchReason: String, Codable, CaseIterable {
    case onRepeat, topArtist, similarArtist, newlyDiscovered, soundtrack, youreFree, weatherWatch

    /// Human phrase for UI chips + the nudge prompt.
    public var phrase: String {
        switch self {
        case .onRepeat:        return "You've had them on repeat"
        case .topArtist:       return "One of your top artists"
        case .similarArtist:   return "Sounds like what you love"
        case .newlyDiscovered: return "Someone you just discovered"
        case .soundtrack:      return "Soundtrack you play on repeat"
        case .youreFree:       return "You're free that night"
        case .weatherWatch:    return "Rain watch"
        }
    }

    /// Short chip label.
    public var chip: String {
        switch self {
        case .onRepeat:        return "On repeat"
        case .topArtist:       return "Top artist"
        case .similarArtist:   return "Similar sound"
        case .newlyDiscovered: return "Newly discovered"
        case .soundtrack:      return "Soundtrack match"
        case .youreFree:       return "You're free"
        case .weatherWatch:    return "Weather watch"
        }
    }

    /// Strength ordering for sorting reasons (higher = stronger).
    public var strength: Int {
        switch self {
        case .onRepeat:        return 100
        case .soundtrack:      return 80
        case .topArtist:       return 70
        case .similarArtist:   return 40
        case .newlyDiscovered: return 25
        case .youreFree:       return 15
        case .weatherWatch:    return 5
        }
    }
}

public struct ScoredEvent: Identifiable {
    public var event: Event
    public var score: Double
    public var reasons: [MatchReason]
    public var distanceKm: Double
    public var id: String { event.id }
    public init(event: Event, score: Double, reasons: [MatchReason], distanceKm: Double) {
        self.event = event; self.score = score; self.reasons = reasons; self.distanceKm = distanceKm
    }
}

/// Context the engine reads for a given ranking pass. Injectable for demo mode.
public struct MatchContext {
    public var home: Place
    public var now: Date
    public var relatedIDs: Set<String>          // artist ids reachable via related-artists
    public var freeNights: Set<DateComponents>  // calendar-free evenings (day granularity)
    public var rainyEventIDs: Set<String>       // events flagged rain-risk
    public init(home: Place, now: Date, relatedIDs: Set<String> = [],
                freeNights: Set<DateComponents> = [], rainyEventIDs: Set<String> = []) {
        self.home = home; self.now = now; self.relatedIDs = relatedIDs
        self.freeNights = freeNights; self.rainyEventIDs = rainyEventIDs
    }
}
