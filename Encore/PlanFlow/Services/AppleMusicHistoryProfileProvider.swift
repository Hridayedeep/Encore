//
//  AppleMusicHistoryProfileProvider.swift
//  EveningPlanner
//
//  Real Apple Music integration: reads the signed-in user's Heavy Rotation
//  and Recently Played History (https://developer.apple.com/documentation/
//  applemusicapi/history) once MusicAuthorization has been granted, and
//  turns the genres in that listening history into preferenceTags via
//  MusicTasteTagMapper.
//
//  Requires the "MusicKit" capability enabled for this app's bundle ID in
//  the Apple Developer portal (Signing & Capabilities in Xcode) — MusicKit
//  handles the developer/user token exchange for MusicDataRequest once that
//  capability is provisioned. That's an account-level setup step outside
//  this codebase; it can't be verified from a simulator build. Until it's
//  provisioned (or on a device without an active Apple Music subscription),
//  loadProfile() safely returns an empty profile — never throws, never
//  blocks the flow.
//

import Foundation
import MusicKit

struct AppleMusicHistoryProfileProvider: UserProfileProvider {
    let sourceName = "Apple Music (heavy rotation & recently played)"

    func loadProfile() async -> UserInterestProfile {
        guard MusicAuthorization.currentStatus == .authorized else { return UserInterestProfile() }

        var weightedGenreCounts: [String: Double] = [:]
        await accumulate(&weightedGenreCounts, endpoint: "v1/me/history/heavy-rotation", weight: 3)
        await accumulate(&weightedGenreCounts, endpoint: "v1/me/recent/played/tracks", weight: 1)

        guard !weightedGenreCounts.isEmpty else { return UserInterestProfile() }

        var profile = UserInterestProfile()
        profile.sourceNames = [sourceName]
        for (genre, weight) in weightedGenreCounts {
            for (tag, tagWeight) in MusicTasteTagMapper.tags(forGenre: genre, weight: weight) {
                profile.tagWeights[tag, default: 0] += tagWeight
            }
        }
        return profile
    }

    private func accumulate(_ counts: inout [String: Double], endpoint: String, weight: Double) async {
        guard let url = URL(string: "https://api.music.apple.com/\(endpoint)") else { return }
        do {
            let request = MusicDataRequest(urlRequest: URLRequest(url: url))
            let response = try await request.response()
            let decoded = try JSONDecoder().decode(HistoryResponse.self, from: response.data)
            for genre in decoded.data.flatMap({ $0.attributes?.genreNames ?? [] }) {
                counts[genre, default: 0] += weight
            }
        } catch {
            // Best-effort signal only: unauthorized/unprovisioned/network failures
            // just mean this source contributes nothing this run.
        }
    }

    private struct HistoryResponse: Decodable {
        let data: [HistoryItem]
    }

    private struct HistoryItem: Decodable {
        let attributes: Attributes?
        struct Attributes: Decodable {
            let genreNames: [String]?
        }
    }
}
