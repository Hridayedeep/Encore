//
//  SampleMusicPersona.swift
//  EveningPlanner
//
//  Stand-in listening profiles used while AppleMusicHistoryProfileProvider's
//  MusicKit capability isn't provisioned (see that file's header). Each case
//  maps to a bundled sample_music_taste_*.json read by
//  SampleMusicProfileProvider. Picked by the user on AppleMusicPermissionView
//  so the "personalize with your taste" story is demoable end to end without
//  a real Apple Music connection.
//

import Foundation

enum SampleMusicPersona: String, CaseIterable, Identifiable {
    case chillListener = "sample_music_taste_chill"
    case partyListener = "sample_music_taste_party"
    case jazzHead = "sample_music_taste_jazz"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chillListener: return "Chill listener"
        case .partyListener: return "Party listener"
        case .jazzHead: return "Jazz & classical head"
        }
    }
}
