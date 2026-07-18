//
//  UserProfileService.swift
//  EveningPlanner
//
//  Merges every configured UserProfileProvider into one UserInterestProfile.
//  Adding "any other source" the user mentioned (Spotify, Instagram, past
//  bookings, ...) is adding one more provider to this list — nothing else
//  in the app changes.
//

import Foundation

struct UserProfileService {
    let providers: [UserProfileProvider]

    init(providers: [UserProfileProvider] = [
        AppleMusicHistoryProfileProvider(),
        SampleMusicProfileProvider(persona: .chillListener)
    ]) {
        self.providers = providers
    }

    func loadProfile() async -> UserInterestProfile {
        var merged = UserInterestProfile()
        for provider in providers {
            let profile = await provider.loadProfile()
            if !profile.isEmpty {
                merged.merge(profile)
            }
        }
        return merged
    }
}
