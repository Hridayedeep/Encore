//
//  QuestionnaireProvider.swift
//  EveningPlanner
//
//  Swapping BundledQuestionnaireProvider for RemoteQuestionnaireProvider
//  is the entire migration to a backend-served questionnaire — no view
//  or model code changes.
//

import Foundation

protocol QuestionnaireProvider {
    func loadQuestionnaire() async throws -> QuestionnaireDefinition
}

struct BundledQuestionnaireProvider: QuestionnaireProvider {
    let resourceName: String

    func loadQuestionnaire() async throws -> QuestionnaireDefinition {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuestionnaireDefinition.self, from: data)
    }
}

struct RemoteQuestionnaireProvider: QuestionnaireProvider {
    let url: URL

    func loadQuestionnaire() async throws -> QuestionnaireDefinition {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(QuestionnaireDefinition.self, from: data)
    }
}
