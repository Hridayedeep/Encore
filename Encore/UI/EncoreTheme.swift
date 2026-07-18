//
//  EncoreTheme.swift
//  Encore (Flow A) — design tokens + haptics (see claude.md §11, §12)
//
//  Liquid Glass, dark-first, one accent gradient (deep violet → magenta —
//  "concert-night"). Namespaced under `EncoreTheme` so it never collides with
//  the host EveningPlanner `Theme`.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreHaptics

// Simple black & white for the first version. Monochrome tokens; `accent` and
// `magenta` are kept as names (used across the UI) but resolve to grayscale so
// the whole app is B&W without touching each view. Swap in color later.
enum EncoreTheme {
    static let bg = Color.black
    static let bgSecondary = Color(white: 0.10)
    static let violet = Color.white          // "accent mark" — now white
    static let magenta = Color.white         // "highlight" — now white
    static let textMuted = Color.white.opacity(0.55)

    static var background: LinearGradient {
        LinearGradient(colors: [.black, Color(white: 0.04)],
                       startPoint: .top, endPoint: .bottom)
    }

    /// Primary fill: dark button on black, readable white text (no per-view edits).
    static var accent: LinearGradient {
        LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A stable grayscale gradient per id so posterless cards still feel distinct.
    static func posterGradient(for seed: String) -> LinearGradient {
        let shades: [(Double, Double)] = [
            (0.28, 0.12), (0.40, 0.18), (0.20, 0.08), (0.34, 0.14), (0.46, 0.22),
        ]
        let idx = abs(seed.hashValue) % shades.count
        let pair = shades[idx]
        return LinearGradient(colors: [Color(white: pair.0), Color(white: pair.1)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Liquid-glass card modifier

struct EncoreGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(EncoreTheme.bgSecondary.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func encoreGlass(cornerRadius: CGFloat = 20) -> some View {
        modifier(EncoreGlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Haptics (§12)

@MainActor
final class EncoreHaptics {
    static let shared = EncoreHaptics()
    var enabled = true
    private var engine: CHHapticEngine?

    private init() { prepare() }

    private func prepare() {
        #if canImport(UIKit)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
        #endif
    }

    func light() {
        guard enabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    func selection() {
        guard enabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    func error() {
        guard enabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
    func success() {
        guard enabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        bookingSuccessPattern()
    }

    /// "Match found" — two soft transients ~120 ms apart (heartbeat).
    func matchFound() {
        guard enabled else { return }
        playPattern([(0.0, 0.6, 0.4), (0.12, 0.9, 0.5)])
    }

    /// Booking success — three rising transients.
    private func bookingSuccessPattern() {
        playPattern([(0.0, 0.5, 0.4), (0.1, 0.7, 0.6), (0.22, 1.0, 0.9)])
    }

    /// Gentle double-tap for the post-event prompt.
    func doubleTap() {
        guard enabled else { return }
        playPattern([(0.0, 0.5, 0.4), (0.14, 0.5, 0.4)])
    }

    // events: [(relativeTime, intensity, sharpness)]
    private func playPattern(_ events: [(TimeInterval, Float, Float)]) {
        #if canImport(UIKit)
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        let hapticEvents = events.map { t, i, s in
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: i),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: s)
            ], relativeTime: t)
        }
        if let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
        #endif
    }
}

// MARK: - Reusable poster view (nil-safe: falls back to gradient + symbol)

struct EncorePoster: View {
    let event: Event
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            if UIImage(named: event.posterAsset) != nil {
                Image(event.posterAsset)
                    .resizable()
                    .scaledToFill()
            } else {
                EncoreTheme.posterGradient(for: event.id)
                symbolOverlay
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var symbolOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(event.title)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .shadow(radius: 8)
    }

    private var symbol: String {
        switch event.type {
        case .concert:  return "music.mic"
        case .movie:    return "film.fill"
        case .comedy:   return "theatermasks.fill"
        case .festival: return "sparkles"
        }
    }
}
