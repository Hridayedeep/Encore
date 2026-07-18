//
//  AnswerValue.swift
//  EveningPlanner
//
//  A generic answer to a questionnaire question, keyed by question id in
//  PlanFlowViewModel.answers. Encodes as a plain JSON string / array / date
//  (not the default enum-with-associated-value shape) so the whole answers
//  dictionary is already the payload shape a future backend would expect.
//

import Foundation

enum AnswerValue: Equatable {
    case text(String)
    case multipleChoice([String])
    case date(Date)
}

extension AnswerValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringArray = try? container.decode([String].self) {
            self = .multipleChoice(stringArray)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let string = try? container.decode(String.self) {
            self = .text(string)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported answer value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .multipleChoice(let values): try container.encode(values)
        case .date(let value): try container.encode(value)
        }
    }
}
