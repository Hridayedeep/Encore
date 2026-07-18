//
//  LoadingView.swift
//  EveningPlanner
//
//  "(API). Loading..." from the wireframe — even though generation is
//  local/mock today, PlanFlowViewModel.generateItinerary() has a real
//  minimum delay so this doesn't flash instantly.
//

import SwiftUI

struct LoadingView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Finding the best spots for tonight…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .planFlowScreenBackground()
        .task {
            await flow.generateItinerary()
            flow.path.append(PlanFlowRoute.itinerary)
        }
    }
}
