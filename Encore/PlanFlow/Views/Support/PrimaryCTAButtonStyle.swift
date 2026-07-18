//
//  PrimaryCTAButtonStyle.swift
//  EveningPlanner
//
//  The two CTA looks used across the flow, both pinned to the same
//  height so a Previous/Next or Book now/Shuffle pair always lines up:
//   - primaryCTA: solid white, black text (Plan my evening, Next/Finish,
//     Book now, Add to calendar, …).
//   - secondaryCTA: a hand-built frosted-glass capsule (ultraThinMaterial
//     + a thin hairline border) instead of the system .glass button
//     style/.glassEffect(), which renders a bright specular rim we don't
//     want on secondary actions (Previous, Shuffle/retry, Not now).
//

import SwiftUI

enum CTAMetrics {
    static let height: CGFloat = 50
}

struct PrimaryCTAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: CTAMetrics.height)
            .background(Color.white, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

struct SecondaryCTAButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: CTAMetrics.height)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

extension ButtonStyle where Self == PrimaryCTAButtonStyle {
    static var primaryCTA: PrimaryCTAButtonStyle { PrimaryCTAButtonStyle() }
}

extension ButtonStyle where Self == SecondaryCTAButtonStyle {
    static var secondaryCTA: SecondaryCTAButtonStyle { SecondaryCTAButtonStyle() }
}
