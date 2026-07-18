//
//  SampleMusicProfileProvider.swift
//  EveningPlanner
//
//  Stand-in signal while AppleMusicHistoryProfileProvider's MusicKit
//  capability isn't provisioned (see that file's header) or is running in
//  Simulator, so the prefill feature is demoable today. Reads a bundled
//  sample listening history (one of SampleMusicPersona's resource files)
//  the same way BundledVenueRepository reads mock_venues.json. Drop this
//  from UserProfileService's provider list once the real Apple Music
//  source is verified end-to-end on a device.
//

import Foundation

struct SampleMusicProfileProvider: UserProfileProvider {
    let sourceName: String
    let resourceName: String

    init(persona: SampleMusicPersona) {
        self.resourceName = persona.rawValue
        self.sourceName = "Apple Music (\(persona.displayName) — sample)"
    }

    func loadProfile() async -> UserInterestProfile {
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([GenrePlayCount].self, from: data)
        else { return UserInterestProfile() }

        var profile = UserInterestProfile()
        profile.sourceNames = [sourceName]
        for entry in entries {
            for (tag, weight) in MusicTasteTagMapper.tags(forGenre: entry.genre, weight: Double(entry.playCount)) {
                profile.tagWeights[tag, default: 0] += weight
            }
        }
        return profile
    }

    private struct GenrePlayCount: Decodable {
        let genre: String
        let playCount: Int
    }
}
