//
//  SeedData.swift
//  Encore (Flow A) — rich hardcoded seed data (see claude.md §6)
//
//  Dates are computed relative to `now` at seed time so nothing looks stale on
//  stage. Poster/artwork assets are referenced by name; UI degrades gracefully
//  when an asset is missing (gradient + SF Symbol placeholder).
//

import Foundation

// MARK: - Personas

public struct Persona: Identifiable {
    public var id: String
    public var name: String
    public var blurb: String
    public var accentAsset: String   // SF Symbol used as the persona avatar
    public var taste: TasteProfile
}

public enum SeedData {

    // Home base for all distance math — Noida Sector 168.
    public static let home = Place(
        name: "Home",
        coordinate: Coordinate(lat: 28.5013, lng: 77.4200),
        area: "Noida Sec 168"
    )

    // MARK: Artists (shared across personas + events)

    public static let artists: [Artist] = [
        Artist(id: "diljit",  name: "Diljit Dosanjh", genres: ["punjabi-pop", "desi-hiphop"]),
        Artist(id: "aujla",   name: "Karan Aujla",    genres: ["punjabi-pop", "desi-hiphop"]),
        Artist(id: "apdhillon", name: "AP Dhillon",   genres: ["punjabi-pop", "pop"]),
        Artist(id: "shubh",   name: "Shubh",          genres: ["punjabi-pop", "desi-hiphop"]),
        Artist(id: "arijit",  name: "Arijit Singh",   genres: ["bollywood", "acoustic"]),
        Artist(id: "prateek", name: "Prateek Kuhad",  genres: ["indie-folk", "acoustic"]),
        Artist(id: "anuv",    name: "Anuv Jain",      genres: ["indie-folk", "acoustic"]),
        Artist(id: "taba",    name: "Taba Chake",     genres: ["indie-folk", "acoustic"]),
        Artist(id: "garrix",  name: "Martin Garrix",  genres: ["edm", "house"]),
        Artist(id: "weeknd",  name: "The Weeknd",     genres: ["pop", "rnb"]),
        Artist(id: "dualipa", name: "Dua Lipa",       genres: ["pop", "house"]),
        Artist(id: "fredagain", name: "Fred again..", genres: ["edm", "house"]),
    ]

    public static func artist(_ id: String) -> Artist {
        artists.first { $0.id == id } ?? Artist(id: id, name: id.capitalized, genres: [])
    }

    private static func artists(_ ids: [String]) -> [Artist] { ids.map { artist($0) } }

    private static func scored(_ ids: [String]) -> [ScoredArtist] {
        ids.enumerated().map { idx, id in
            // Rank decays down the list; recency near 1 for top entries.
            ScoredArtist(artist: artist(id),
                         frequency: Double(ids.count - idx) / Double(ids.count),
                         recencyWeight: max(0.5, 1.0 - Double(idx) * 0.12))
        }
    }

    // MARK: Personas (§6)

    public static let personas: [Persona] = [
        Persona(
            id: "aarav", name: "Aarav",
            blurb: "Punjabi-pop / desi hip-hop",
            accentAsset: "flame.fill",
            taste: TasteProfile(
                topArtists: scored(["diljit", "aujla", "apdhillon", "shubh"]),
                onRepeat: artists(["diljit", "aujla", "apdhillon"]),
                discovered: artists(["shubh"]),
                genreWeights: ["punjabi-pop": 0.9, "desi-hiphop": 0.7, "pop": 0.3]
            )
        ),
        Persona(
            id: "meera", name: "Meera",
            blurb: "Bollywood / indie folk",
            accentAsset: "guitars.fill",
            taste: TasteProfile(
                topArtists: scored(["arijit", "prateek", "anuv", "taba"]),
                onRepeat: artists(["arijit", "prateek", "anuv"]),
                discovered: artists(["taba"]),
                genreWeights: ["bollywood": 0.8, "indie-folk": 0.85, "acoustic": 0.5]
            )
        ),
        Persona(
            id: "kabir", name: "Kabir",
            blurb: "EDM / global pop",
            accentAsset: "waveform",
            taste: TasteProfile(
                topArtists: scored(["garrix", "weeknd", "dualipa", "fredagain"]),
                onRepeat: artists(["garrix", "weeknd", "dualipa"]),
                discovered: artists(["fredagain"]),
                genreWeights: ["edm": 0.9, "pop": 0.6, "house": 0.5]
            )
        ),
    ]

    // MARK: Related-artist graph (for the .similarArtist beat)

    /// artistID -> similar artistIDs (catalog `.relatedArtists` stand-in).
    public static let relatedGraph: [String: [String]] = [
        "diljit": ["aujla", "apdhillon", "shubh"],
        "aujla": ["diljit", "shubh", "apdhillon"],
        "apdhillon": ["shubh", "diljit"],
        "shubh": ["aujla", "apdhillon"],
        "arijit": ["prateek", "anuv"],
        "prateek": ["anuv", "taba", "arijit"],
        "anuv": ["taba", "prateek"],
        "taba": ["anuv", "prateek"],
        "garrix": ["fredagain", "dualipa"],
        "weeknd": ["dualipa"],
        "dualipa": ["weeknd", "garrix"],
        "fredagain": ["garrix"],
    ]

    // MARK: Venues

    private static func place(_ name: String, _ area: String, _ lat: Double, _ lng: Double) -> Place {
        Place(name: name, coordinate: Coordinate(lat: lat, lng: lng), area: area)
    }

    // MARK: Events (~14, relative dates) — §6

    public static func events(now: Date, calendar: Calendar = .current) -> [Event] {
        func at(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func link(_ id: String) -> URL { URL(string: "https://district.in/events/\(id)")! }

        let jln     = place("JLN Stadium", "Delhi", 28.5828, 77.2340)
        let noidaIndoor = place("Noida Indoor Stadium", "Noida", 28.5480, 77.3910)
        let dlfDowntown = place("DLF Downtown", "Gurugram", 28.4595, 77.0720)
        let pianoMan = place("The Piano Man", "Gurugram", 28.4820, 77.0890)
        let sunburnNoida = place("Sunburn Arena", "Noida", 28.5355, 77.3910)
        let greaterNoida = place("Sunburn Arena", "Greater Noida", 28.4744, 77.5040)
        let pvrLogix = place("PVR Logix", "Noida", 28.5760, 77.3560)
        let cinepolis = place("Cinepolis DLF Mall", "Noida", 28.5675, 77.3260)
        let habitat = place("Habitat", "Noida", 28.5700, 77.3300)
        let gaurCity = place("Gaur City Mall", "Noida", 28.6070, 77.4230)
        let antisocial = place("antiSOCIAL", "Delhi", 28.5535, 77.1910)

        return [
            Event(id: "e1", type: .concert, title: "Dil-Luminati Tour",
                  artistIDs: ["diljit"], venue: jln, startTime: at(5, 19),
                  durationMinutes: 150, priceFrom: 2999, isOutdoor: true,
                  posterAsset: "poster_diljit", districtDeepLink: link("e1")),
            Event(id: "e2", type: .concert, title: "It Was All A Dream",
                  artistIDs: ["aujla"], venue: noidaIndoor, startTime: at(2, 20),
                  durationMinutes: 150, priceFrom: 2499, isOutdoor: false,
                  posterAsset: "poster_aujla", districtDeepLink: link("e2")),
            Event(id: "e3", type: .concert, title: "Summer High Tour",
                  artistIDs: ["apdhillon"], venue: dlfDowntown, startTime: at(9, 20),
                  durationMinutes: 150, priceFrom: 3499, isOutdoor: true,
                  posterAsset: "poster_apdhillon", districtDeepLink: link("e3")),
            Event(id: "e4", type: .concert, title: "Live in Concert",
                  artistIDs: ["arijit"], venue: jln, startTime: at(7, 19),
                  durationMinutes: 150, priceFrom: 1999, isOutdoor: true,
                  posterAsset: "poster_arijit", districtDeepLink: link("e4")),
            Event(id: "e5", type: .concert, title: "Silhouettes Tour",
                  artistIDs: ["prateek"], venue: pianoMan, startTime: at(4, 21),
                  durationMinutes: 120, priceFrom: 1499, isOutdoor: false,
                  posterAsset: "poster_prateek", districtDeepLink: link("e5")),
            Event(id: "e6", type: .concert, title: "Baarishein Live",
                  artistIDs: ["anuv"], venue: sunburnNoida, startTime: at(3, 19),
                  durationMinutes: 120, priceFrom: 1799, isOutdoor: true,
                  posterAsset: "poster_anuv", districtDeepLink: link("e6")),
            Event(id: "e7", type: .festival, title: "Sunburn Arena",
                  artistIDs: ["garrix"], venue: greaterNoida, startTime: at(6, 18),
                  durationMinutes: 240, priceFrom: 4999, isOutdoor: true,
                  posterAsset: "poster_garrix", districtDeepLink: link("e7")),
            Event(id: "e8", type: .concert, title: "After Hours",
                  artistIDs: ["weeknd"], venue: jln, startTime: at(12, 20),
                  durationMinutes: 150, priceFrom: 5999, isOutdoor: true,
                  posterAsset: "poster_weeknd", districtDeepLink: link("e8")),
            Event(id: "e9", type: .movie, title: "Chamak",
                  artistIDs: ["diljit", "shubh"], filmGenres: ["music-biopic", "drama"],
                  venue: pvrLogix, startTime: at(1, 18, 30),
                  durationMinutes: 150, priceFrom: 350, isOutdoor: false,
                  posterAsset: "poster_chamak", districtDeepLink: link("e9")),
            Event(id: "e10", type: .movie, title: "Dil Aashiqana",
                  artistIDs: ["arijit"], filmGenres: ["romance", "musical"],
                  venue: cinepolis, startTime: at(2, 21),
                  durationMinutes: 145, priceFrom: 300, isOutdoor: false,
                  posterAsset: "poster_dilaashiqana", districtDeepLink: link("e10")),
            Event(id: "e11", type: .comedy, title: "Stand-up Special",
                  artistIDs: [], venue: habitat, startTime: at(3, 20),
                  durationMinutes: 90, priceFrom: 799, isOutdoor: false,
                  posterAsset: "poster_standup", districtDeepLink: link("e11")),
            Event(id: "e12", type: .concert, title: "Reprise Tour",
                  artistIDs: ["shubh"], venue: gaurCity, startTime: at(8, 19),
                  durationMinutes: 120, priceFrom: 2799, isOutdoor: false,
                  posterAsset: "poster_shubh", districtDeepLink: link("e12")),
            Event(id: "e13", type: .movie, title: "Neon Nights",
                  artistIDs: ["weeknd", "dualipa"], filmGenres: ["thriller", "musical"],
                  venue: pvrLogix, startTime: at(4, 22),
                  durationMinutes: 130, priceFrom: 350, isOutdoor: false,
                  posterAsset: "poster_neonnights", districtDeepLink: link("e13")),
            Event(id: "e14", type: .concert, title: "Indie Nights",
                  artistIDs: ["taba", "anuv"], venue: antisocial, startTime: at(5, 20),
                  durationMinutes: 150, priceFrom: 1299, isOutdoor: false,
                  posterAsset: "poster_indienights", districtDeepLink: link("e14")),
        ]
    }

    // MARK: Restaurants (§6)

    public static let restaurants: [Restaurant] = [
        Restaurant(id: "r1", name: "Farzi Cafe", cuisine: "Modern Indian",
                   place: place("Farzi Cafe", "Connaught Place", 28.5900, 77.2400),
                   etaMinutes: 30, priceForTwo: 2000, imageAsset: "rest_farzi"),
        Restaurant(id: "r2", name: "Bikanervala", cuisine: "North Indian",
                   place: place("Bikanervala", "Noida Sec 18", 28.5700, 77.3250),
                   etaMinutes: 20, priceForTwo: 800, imageAsset: "rest_bikaner"),
        Restaurant(id: "r3", name: "The Immigrant Cafe", cuisine: "Continental",
                   place: place("The Immigrant Cafe", "Gurugram", 28.4700, 77.0800),
                   etaMinutes: 35, priceForTwo: 2400, imageAsset: "rest_immigrant"),
        Restaurant(id: "r4", name: "Dhaba Estd 1986", cuisine: "Punjabi",
                   place: place("Dhaba", "Delhi", 28.5850, 77.2380),
                   etaMinutes: 25, priceForTwo: 1600, imageAsset: "rest_dhaba"),
        Restaurant(id: "r5", name: "Social", cuisine: "Global / Bar",
                   place: place("Social", "Noida Sec 18", 28.5695, 77.3260),
                   etaMinutes: 22, priceForTwo: 1500, imageAsset: "rest_social"),
        Restaurant(id: "r6", name: "Prego", cuisine: "Italian",
                   place: place("Prego", "Gurugram", 28.4620, 77.0740),
                   etaMinutes: 32, priceForTwo: 2800, imageAsset: "rest_prego"),
    ]

    /// Nearest restaurant to a given event venue.
    public static func nearestRestaurant(to event: Event) -> Restaurant {
        restaurants.min { a, b in
            a.place.coordinate.distanceKm(to: event.venue.coordinate)
                < b.place.coordinate.distanceKm(to: event.venue.coordinate)
        } ?? restaurants[0]
    }

    // MARK: Blinkit quick-commerce catalog (§6)

    public static let blinkitCatalog: [CartItem] = [
        CartItem(id: "b1", name: "Water (1L x2)",       price: 40,  vendor: .blinkit, imageAsset: "item_water"),
        CartItem(id: "b2", name: "Red Bull (4-pack)",   price: 500, vendor: .blinkit, imageAsset: "item_redbull"),
        CartItem(id: "b3", name: "Lay's Chips",         price: 60,  vendor: .blinkit, imageAsset: "item_chips"),
        CartItem(id: "b4", name: "Maggi (2-pack)",      price: 48,  vendor: .blinkit, imageAsset: "item_maggi"),
        CartItem(id: "b5", name: "Paracetamol strip",   price: 30,  vendor: .blinkit, imageAsset: "item_paracetamol"),
        CartItem(id: "b6", name: "Cold Coffee (2)",     price: 180, vendor: .blinkit, imageAsset: "item_coldcoffee"),
        CartItem(id: "b7", name: "Electrolyte sachets", price: 120, vendor: .blinkit, imageAsset: "item_electrolyte"),
        CartItem(id: "b8", name: "Nachos + Salsa",      price: 220, vendor: .blinkit, imageAsset: "item_nachos"),
        CartItem(id: "b9", name: "Fresh Lime Soda mix", price: 90,  vendor: .blinkit, imageAsset: "item_limesoda"),
        CartItem(id: "b10", name: "Dark Chocolate",     price: 150, vendor: .blinkit, imageAsset: "item_chocolate"),
    ]

    /// Bistro / post-event hot-food suggestions.
    public static let bistroCatalog: [CartItem] = [
        CartItem(id: "bi1", name: "Butter Chicken Bowl", price: 320, vendor: .bistro, imageAsset: "item_butterchicken"),
        CartItem(id: "bi2", name: "Paneer Tikka Wrap",   price: 240, vendor: .bistro, imageAsset: "item_paneerwrap"),
        CartItem(id: "bi3", name: "Loaded Fries",        price: 180, vendor: .bistro, imageAsset: "item_fries"),
        CartItem(id: "bi4", name: "Mac & Cheese",        price: 260, vendor: .bistro, imageAsset: "item_maccheese"),
    ]
}
