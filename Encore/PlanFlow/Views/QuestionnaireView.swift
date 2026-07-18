//
//  QuestionnaireView.swift
//  EveningPlanner
//
//  Screen 2. Loads QuestionnaireDefinition from flow.questionnaireProvider
//  and pages through its questions one at a time, with a smoothly
//  animated progress bar pinned to the bottom of the screen.
//

import SwiftUI

struct QuestionnaireView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel
    @State private var currentIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            if let questionnaire = flow.questionnaire {
                ScrollView {
                    if let profile = flow.interestProfile, !profile.isEmpty {
                        prefillBanner(profile: profile)
                    }

                    QuestionRendererView(
                        question: questionnaire.questions[currentIndex],
                        answer: bindingForCurrentAnswer(questionnaire.questions[currentIndex])
                    )
                    .id(questionnaire.questions[currentIndex].id)
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Spacer(minLength: 0)

                navigationButtons(questionnaire: questionnaire)
                progressBar(currentIndex: currentIndex, total: questionnaire.questions.count)
            } else if let error = flow.generationError {
                Spacer()
                Text(error).foregroundStyle(.red).padding()
                Spacer()
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .planFlowScreenBackground()
        .task {
            await flow.loadQuestionnaireIfNeeded()
        }
    }

    private func prefillBanner(profile: UserInterestProfile) -> some View {
        Label("Pre-filled from \(profile.sourceNames.joined(separator: ", ")) — tap any answer to change it", systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private func bindingForCurrentAnswer(_ question: Question) -> Binding<AnswerValue?> {
        Binding(
            get: { flow.answers[question.id] },
            set: { flow.answers[question.id] = $0 }
        )
    }

    private func isCurrentAnswerValid(_ question: Question) -> Bool {
        guard question.required else { return true }
        switch flow.answers[question.id] {
        case .text(let value): return !value.isEmpty
        case .multipleChoice(let values): return !values.isEmpty
        case .date: return true
        case .none: return false
        }
    }

    private func navigationButtons(questionnaire: QuestionnaireDefinition) -> some View {
        let question = questionnaire.questions[currentIndex]
        let isLastQuestion = currentIndex == questionnaire.questions.count - 1
        let isFirstQuestion = currentIndex == 0

        return HStack(spacing: 12) {
            if !isFirstQuestion {
                Button(action: goBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                }
                .buttonStyle(.secondaryCTA)
            }

            Button(action: { advance(questionnaire: questionnaire) }) {
                HStack {
                    Text(isLastQuestion ? "Finish" : "Next")
                    Image(systemName: isLastQuestion ? "checkmark" : "chevron.right")
                }
            }
            .buttonStyle(.primaryCTA)
            .disabled(!isCurrentAnswerValid(question))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(nil, value: isLastQuestion)
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex -= 1
        }
    }

    private func advance(questionnaire: QuestionnaireDefinition) {
        if currentIndex < questionnaire.questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        } else {
            flow.path.append(PlanFlowRoute.loading)
        }
    }

    private func progressBar(currentIndex: Int, total: Int) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(colors: [.purple, .accentColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * CGFloat(currentIndex + 1) / CGFloat(total))
                    .animation(.easeInOut(duration: 0.35), value: currentIndex)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, 12)
    }
}
