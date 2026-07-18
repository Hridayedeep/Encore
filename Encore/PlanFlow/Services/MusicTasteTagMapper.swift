//
//  MusicTasteTagMapper.swift
//  EveningPlanner
//
//  Maps an Apple Music genre name to the app's existing preferenceTags
//  vocabulary (vibe tags like "lively"/"chill", cuisine tags like "cafe",
//  budget tags like "premium") so a listening profile plugs straight into
//  the same ranking ItineraryGenerator already does for questionnaire
//  answers — no separate scoring path.
//

import Foundation

enum MusicTasteTagMapper {
    private static let genreTags: [String: [String]] = [
        "edm": ["lively"],
        "dance": ["lively"],
        "house": ["lively"],
        "hip-hop/rap": ["lively", "street_food"],
        "hip-hop": ["lively", "street_food"],
        "pop": ["lively", "food_focused"],
        "k-pop": ["lively"],
        "r&b/soul": ["romantic"],
        "r&b": ["romantic"],
        "jazz": ["romantic", "intellectual", "cafe"],
        "classical": ["intellectual", "romantic"],
        "opera": ["intellectual", "premium"],
        "lo-fi": ["chill", "cafe"],
        "chill": ["chill", "cafe"],
        "acoustic": ["chill", "romantic"],
        "indie": ["chill", "intellectual"],
        "indie pop": ["chill", "intellectual"],
        "singer/songwriter": ["chill", "romantic"],
        "electronic": ["lively", "intellectual"],
        "world": ["intellectual", "street_food"],
        "soundtrack": ["intellectual", "chill"],
        "alternative": ["intellectual", "chill"],
        "rock": ["lively"],
        "metal": ["lively"],
        "country": ["chill", "budget_friendly"]
    ]

    static func tags(forGenre genre: String, weight: Double) -> [String: Double] {
        guard let tags = genreTags[genre.lowercased()] else { return [:] }
        var weights: [String: Double] = [:]
        for tag in tags { weights[tag] = weight }
        return weights
    }
}
