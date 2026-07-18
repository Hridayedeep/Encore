//
//  ItineraryGenerator.swift
//  EveningPlanner
//
//  Pairs an activity venue with a food venue, ranked by vibe-tag overlap
//  with the request. Ranking (not filtering) means it never produces an
//  empty result just because nothing matches every selected vibe.
//

import Foundation

struct ItineraryGenerator {
    func generateVariants(for request: PlanRequest, venues: [Venue], count: Int = 5) -> [ItineraryVariant] {
        let activities = venues.filter { $0.category == .activity }
        let foodVenues = venues.filter { $0.category == .food }
        guard !activities.isEmpty, !foodVenues.isEmpty else { return [] }

        func vibeScore(_ venue: Venue) -> Int {
            Set(venue.vibeTags).intersection(request.preferenceTags).count
        }

        let rankedActivities = activities.sorted { vibeScore($0) > vibeScore($1) }
        let rankedFood = foodVenues.sorted { vibeScore($0) > vibeScore($1) }

        // Diagonal (round-robin) pairing instead of "top activity x every food" —
        // with a large venue pool that would otherwise show the same activity
        // for every one of the first N variants.
        var combos: [(activity: Venue, food: Venue)] = []
        let rounds = rankedActivities.count
        outer: for round in 0..<rounds {
            for activityIndex in 0..<rankedActivities.count {
                let foodIndex = (activityIndex + round) % rankedFood.count
                combos.append((rankedActivities[activityIndex], rankedFood[foodIndex]))
                if combos.count >= count { break outer }
            }
        }

        let activityDurationMinutes = 60
        let foodStartTime = Calendar.current.date(
            byAdding: .minute,
            value: activityDurationMinutes,
            to: request.startTime
        ) ?? request.startTime

        return combos.prefix(count).enumerated().map { index, combo in
            let activityStop = ItineraryStop(
                venueName: combo.activity.name,
                location: combo.activity.location,
                startTime: request.startTime,
                durationMinutes: activityDurationMinutes,
                priceLabel: combo.activity.priceLabel(forGroupSize: request.groupSize)
            )
            let foodStop = ItineraryStop(
                venueName: combo.food.name,
                location: combo.food.location,
                startTime: foodStartTime,
                durationMinutes: 60,
                priceLabel: combo.food.priceLabel(forGroupSize: request.groupSize)
            )
            return ItineraryVariant(
                id: index + 1,
                stops: [activityStop, foodStop],
                totalCost: combo.activity.cost(forGroupSize: request.groupSize) + combo.food.cost(forGroupSize: request.groupSize)
            )
        }
    }
}
