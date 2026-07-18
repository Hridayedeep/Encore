//
//  PlanRequest.swift
//  EveningPlanner
//
//  Typed shape the itinerary engine consumes, built from the generic
//  questionnaire answers by PlanRequestMapper. preferenceTags is the
//  union of every tag-contributing answer (vibe, cuisine, budget, and
//  any future single/multi-select question whose maps_to_field is
//  "preferenceTags") — adding a new tag-style question is a JSON-only
//  change, no Swift change here or in the mapper.
//

import Foundation

struct PlanRequest {
    var preferenceTags: Set<String> = []
    var goingOut: String = "go_out"
    var startTime: Date = Date()
    var groupSize: Int = 2
}
