//
//  QuestionnaireDefinition.swift
//  EveningPlanner
//
//  Generic schema for a JSON- (and later backend-) driven questionnaire.
//  Adding a new question or option is a data change here, not a Swift change.
//

import Foundation

enum QuestionType: String, Codable {
    case singleSelect = "single_select"
    case multiSelect = "multi_select"
    case date
}

struct QuestionOption: Codable, Identifiable, Hashable {
    let value: String
    let label: String
    var emoji: String?
    var available: Bool?
    var unavailableReason: String?
    /// Generic per-option scalar payload. Used today by group_size options to
    /// carry a headcount (e.g. "big_group" -> 8), but stays option-type-agnostic
    /// so a future question can reuse it for its own numeric meaning.
    var numericValue: Double?

    var id: String { value }
    var isAvailable: Bool { available ?? true }

    enum CodingKeys: String, CodingKey {
        case value, label, emoji, available
        case unavailableReason = "unavailable_reason"
        case numericValue = "numeric_value"
    }
}

struct Question: Codable, Identifiable {
    let id: String
    let question: String
    var subtext: String?
    let type: QuestionType
    let mapsToField: String
    var required: Bool = false
    var options: [QuestionOption]?

    enum CodingKeys: String, CodingKey {
        case id, question, subtext, type, options, required
        case mapsToField = "maps_to_field"
    }
}

struct QuestionnaireDefinition: Codable {
    let questionnaireId: String
    let title: String
    let questions: [Question]
}
