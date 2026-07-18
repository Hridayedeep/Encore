//
//  QuestionRendererView.swift
//  EveningPlanner
//
//  Switches on Question.type to pick a concrete input view. This switch
//  is the only place that needs a case added when a new question type
//  is introduced — everything else in the flow is already generic.
//

import SwiftUI

struct QuestionRendererView: View {
    let question: Question
    @Binding var answer: AnswerValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.question)
                .font(.title2.bold())

            if let subtext = question.subtext {
                Text(subtext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            switch question.type {
            case .multiSelect:
                MultiSelectOptionsView(options: question.options ?? [], answer: $answer)
            case .singleSelect:
                SingleSelectOptionsView(options: question.options ?? [], answer: $answer)
            case .date:
                DateAnswerView(answer: $answer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
