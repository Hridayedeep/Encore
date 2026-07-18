//
//  MusicKitMusicSource.swift
//  Encore (Flow A) — the REAL Apple Music taste source (see ARCHITECTURE.md, §4.1)
//
//  Reads taste from Apple Music via MusicKit — heavy-rotation, music-summaries
//  (Replay), recent/played, recommendations — fired through MusicDataRequest,
//  which auto-attaches the Music-User-Token once authorized. Compiles WITHOUT the
//  paid Developer account / MusicKit entitlement; it simply fails auth at runtime,
//  and the caller falls back to a HardcodedMusicSource persona. Plug the token in
//  later by adding the capability + subscription — no code change needed here.
//

import Foundation
#if canImport(MusicKit)
import MusicKit
#endif

public struct MusicKitUnavailable: Error { public let reason: String }

public struct MusicKitMusicSource: MusicSource {
    public var isLive: Bool { true }
    public init() {}

    // MARK: Authorization

    /// Request authorization; returns true only if authorized with a subscription.
    @discardableResult
    public static func authorize() async -> Bool {
        #if canImport(MusicKit)
        let status = await MusicAuthorization.request()
        return status == .authorized
        #else
        return false
        #endif
    }

    public static var isAuthorized: Bool {
        #if canImport(MusicKit)
        return MusicAuthorization.currentStatus == .authorized
        #else
        return false
        #endif
    }

    // MARK: Signals

    public func fetchSignals() async throws -> RawTasteSignals {
        #if canImport(MusicKit)
        guard Self.isAuthorized else { throw MusicKitUnavailable(reason: "not authorized") }

        async let heavy = artists(fromRaw: "https://api.music.apple.com/v1/me/history/heavy-rotation?limit=20")
        async let top   = artists(fromRaw: "https://api.music.apple.com/v1/me/music-summaries?filter[year]=latest&views=top-artists")
        async let recent = artists(fromRaw: "https://api.music.apple.com/v1/me/recent/played/tracks?limit=30&types=songs")
        async let recs  = artists(fromRaw: "https://api.music.apple.com/v1/me/recommendations")

        return RawTasteSignals(
            heavyRotation: (try? await heavy) ?? [],
            topArtistsRanked: (try? await top) ?? [],
            recentlyPlayed: (try? await recent) ?? [],
            recommendations: (try? await recs) ?? []
        )
        #else
        throw MusicKitUnavailable(reason: "MusicKit not available")
        #endif
    }

    public func relatedArtists(to artistID: String) async throws -> [Artist] {
        #if canImport(MusicKit)
        guard Self.isAuthorized else { throw MusicKitUnavailable(reason: "not authorized") }
        let url = "https://api.music.apple.com/v1/catalog/us/artists/\(artistID)?include=related-artists"
        return (try? await artists(fromRaw: url)) ?? []
        #else
        throw MusicKitUnavailable(reason: "MusicKit not available")
        #endif
    }

    // MARK: Raw request + decode

    #if canImport(MusicKit)
    /// Fire a raw Apple Music endpoint and map the resource payload → [Artist].
    private func artists(fromRaw urlString: String) async throws -> [Artist] {
        guard let url = URL(string: urlString) else { return [] }
        let request = MusicDataRequest(urlRequest: URLRequest(url: url))
        let response = try await request.response()
        let decoded = try JSONDecoder().decode(AppleMusicResourceResponse.self, from: response.data)
        return decoded.artists()
    }
    #endif
}

// MARK: - Minimal decodable for the Apple Music resource payload

/// We only need artistName + genreNames + id — robust to albums/songs/artists.
struct AppleMusicResourceResponse: Decodable {
    struct Resource: Decodable {
        let id: String
        let type: String
        let attributes: Attributes?
        struct Attributes: Decodable {
            let name: String?
            let artistName: String?
            let genreNames: [String]?
        }
    }
    let data: [Resource]

    /// Collapse resources into unique artists (by normalized name / artist id).
    func artists() -> [Artist] {
        var seen = Set<String>()
        var result: [Artist] = []
        for r in data {
            let type = r.type
            let name = r.attributes?.artistName ?? r.attributes?.name
            let id = (type == "artists") ? r.id : (name ?? r.id)
            guard let displayName = name ?? (type == "artists" ? r.attributes?.name : nil),
                  !displayName.isEmpty else { continue }
            let key = displayName.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(Artist(id: id, name: displayName, genres: r.attributes?.genreNames ?? []))
        }
        return result
    }
}
