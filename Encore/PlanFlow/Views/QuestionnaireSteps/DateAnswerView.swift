//
//  DateAnswerView.swift
//  EveningPlanner
//
//  Renders question type "date" as a real calendar picker. Kept to a
//  plain Date answer (no availability logic) so wiring EventKit-derived
//  free/busy slots in later is additive, not a rewrite.
//

import SwiftUI

struct DateAnswerView: View {
    @Binding var answer: AnswerValue?

    private var selectedDate: Date {
        if case .date(let value) = answer { return value }
        return Date()
    }

    var body: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { selectedDate },
                set: { answer = .date($0) }
            ),
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .onAppear {
            if answer == nil { answer = .date(Date()) }
        }
    }
}
