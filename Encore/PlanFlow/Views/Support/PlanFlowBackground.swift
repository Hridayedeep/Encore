//
//  PlanFlowBackground.swift
//  EveningPlanner
//
//  A soft, adaptive backdrop for every screen — Liquid Glass needs
//  something with color/depth behind it to actually refract; a flat
//  system background makes glass surfaces nearly invisible. Built from
//  semantic colors only, so it flips correctly with light/dark mode
//  without any explicit color-scheme handling.
//

import SwiftUI

struct PlanFlowBackground: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.32),
                    Color.purple.opacity(0.22),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.mint.opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func planFlowScreenBackground() -> some View {
        background(PlanFlowBackground())
    }
}
