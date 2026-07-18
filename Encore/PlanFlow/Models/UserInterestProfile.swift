//
//  UserInterestProfile.swift
//  EveningPlanner
//
//  Generic bag of tag weights inferred about the user from one or more
//  sources (Apple Music today; anything else later). Tags are the same
//  vocabulary as questionnaire option values (see plan_my_evening_
//  questionnaire.json / mock_venues.json vibeTags) so a profile can be
//  matched directly against question options with no translation layer.
//

import Foundation

struct UserInterestProfile {
    var tagWeights: [String: Double] = [:]
    var sourceNames: [String] = []

    var isEmpty: Bool { tagWeights.isEmpty }

    mutating func merge(_ other: UserInterestProfile) {
        for (tag, weight) in other.tagWeights {
            tagWeights[tag, default: 0] += weight
        }
        sourceNames.append(contentsOf: other.sourceNames)
    }

    func topTags(matching candidates: Set<String>, limit: Int) -> [String] {
        tagWeights
            .filter { candidates.contains($0.key) && $0.value > 0 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }
}
