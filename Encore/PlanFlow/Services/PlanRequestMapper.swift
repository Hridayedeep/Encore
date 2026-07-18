//
//  PlanRequestMapper.swift
//  EveningPlanner
//
//  Translates the generic, JSON-driven answers dictionary into the typed
//  PlanRequest the itinerary engine consumes. This is the one place that
//  knows about specific maps_to_field values. "preferenceTags" handles any
//  single/multi-select question generically (vibe, cuisine, budget, and any
//  future tag-style question need no change here), leaving "goingOut",
//  "startTime" and "groupSize" as the only structural fields.
//

import Foundation

enum PlanRequestMapper {
    static func makePlanRequest(from answers: [String: AnswerValue], questions: [Question]) -> PlanRequest {
        var request = PlanRequest()

        for question in questions {
            guard let value = answers[question.id] else { continue }

            switch question.mapsToField {
            case "preferenceTags":
                switch value {
                case .multipleChoice(let values):
                    request.preferenceTags.formUnion(values)
                case .text(let value):
                    request.preferenceTags.insert(value)
                case .date:
                    break
                }
            case "goingOut":
                if case .text(let value) = value {
                    request.goingOut = value
                }
            case "startTime":
                if case .date(let value) = value {
                    request.startTime = value
                }
            case "groupSize":
                if case .text(let value) = value,
                   let option = question.options?.first(where: { $0.value == value }),
                   let numericValue = option.numericValue {
                    request.groupSize = max(Int(numericValue), 1)
                }
            default:
                break
            }
        }

        return request
    }
}
