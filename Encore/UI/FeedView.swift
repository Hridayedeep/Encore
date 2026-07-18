//
//  FeedView.swift
//  Encore (Flow A) — "For You" feed (see claude.md §11 S2)
//
//  Hero nudge (shortlist #1) + shortlist cards. Match-found haptic on hero
//  appear. Swipe-away dismiss feeds the light feedback loop. Pull to refresh.
//

import SwiftUI

struct FeedView: View {
    @Bindable var store: EncoreStore
    @Binding var path: [EncoreRoute]
    @State private var didPulse = false

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar

                    if store.isLoading && store.shortlist.isEmpty {
                        loadingState
                    } else if store.shortlist.isEmpty {
                        emptyState
                    } else {
                        if let hero = store.heroEvent {
                            heroCard(hero)
                        }
                        if !store.restOfShortlist.isEmpty {
                            Text("More shows for you")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .padding(.top, 8)
                            ForEach(store.restOfShortlist) { scored in
                                shortlistCard(scored)
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable { await store.refresh() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.shortlist.isEmpty { await store.refresh() }
        }
        .onAppear {
            if !didPulse && !store.shortlist.isEmpty {
                didPulse = true
                EncoreHaptics.shared.matchFound()
                Task { await store.notifyMatchFoundIfNeeded() }
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOR YOU")
                    .font(.caption.bold())
                    .tracking(2)
                    .foregroundStyle(EncoreTheme.magenta)
                Text(store.activePersona.map { "Hey \($0.name)" } ?? "Encore")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            if let persona = store.activePersona {
                Image(systemName: persona.accentAsset)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(EncoreTheme.posterGradient(for: persona.id)))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: Hero card (shortlist #1)

    @ViewBuilder
    private func heroCard(_ scored: ScoredEvent) -> some View {
        let nudge = store.nudge(for: scored.event)
        Button {
            EncoreHaptics.shared.selection()
            path.append(.detail(scored.event))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                EncorePoster(event: scored.event, height: 240, cornerRadius: 24)
                    .overlay(alignment: .topLeading) {
                        Text(scored.event.type.rawValue.capitalized)
                            .font(.caption2.bold())
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(.ultraThinMaterial))
                            .foregroundStyle(.white)
                            .padding(12)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    if let nudge {
                        Text(nudge.headline)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(scored.event.title).font(.title3.bold()).foregroundStyle(.white)
                    }

                    reasonChips(scored, pulseFirst: true)

                    HStack {
                        Spacer()
                        Label(nudge?.cta ?? "See the night", systemImage: "arrow.right")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Capsule().fill(EncoreTheme.accent))
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
            }
            .encoreGlass(cornerRadius: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: Shortlist card

    private func shortlistCard(_ scored: ScoredEvent) -> some View {
        Button {
            EncoreHaptics.shared.selection()
            path.append(.detail(scored.event))
        } label: {
            HStack(spacing: 14) {
                EncorePoster(event: scored.event, height: 96, cornerRadius: 16)
                    .frame(width: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(scored.event.title)
                        .font(.headline).foregroundStyle(.white)
                        .lineLimit(2)
                    Text(subtitle(scored))
                        .font(.caption).foregroundStyle(EncoreTheme.textMuted)
                    reasonChips(scored, pulseFirst: false)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .encoreGlass(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .swipeToDismiss {
            withAnimation { store.dismiss(scored.event) }
            EncoreHaptics.shared.selection()
        }
    }

    private func subtitle(_ scored: ScoredEvent) -> String {
        let artist = scored.event.artistIDs.first.map { SeedData.artist($0).name }
        let day = NudgeEngine.relativeDay(scored.event.startTime, now: store.now)
        let km = Int(scored.distanceKm.rounded())
        return [artist, "\(km) km", day].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Reason chips

    private func reasonChips(_ scored: ScoredEvent, pulseFirst: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(scored.reasons.prefix(3).enumerated()), id: \.offset) { idx, reason in
                    Text(reason.chip)
                        .font(.caption2.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(chipColor(reason).opacity(0.25)))
                        .overlay(Capsule().stroke(chipColor(reason).opacity(0.5), lineWidth: 1))
                        .foregroundStyle(.white)
                        .modifier(PulseIf(active: pulseFirst && idx == 0))
                }
                // distance chip
                Text("\(Int(scored.distanceKm.rounded())) km")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.10)))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func chipColor(_ reason: MatchReason) -> Color {
        switch reason {
        case .onRepeat, .soundtrack: return EncoreTheme.magenta
        case .topArtist:             return EncoreTheme.violet
        default:                     return Color.white
        }
    }

    // MARK: States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text("Reading your taste…")
                .font(.subheadline).foregroundStyle(EncoreTheme.textMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 44)).foregroundStyle(.white.opacity(0.4))
            Text("No shows match your taste this week")
                .font(.headline).foregroundStyle(.white)
            Text("Try broadening your radius or a different persona.")
                .font(.caption).foregroundStyle(EncoreTheme.textMuted)
                .multilineTextAlignment(.center)
            Button("Broaden radius") {
                store.searchRadiusKm = 100
                Task { await store.refresh() }
            }
            .font(.subheadline.bold())
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Capsule().fill(EncoreTheme.accent))
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
        .encoreGlass()
    }
}

// MARK: - Small helpers

private struct PulseIf: ViewModifier {
    let active: Bool
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? 1.06 : 1.0)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    on = true
                }
            }
    }
}

/// Lightweight horizontal swipe-to-dismiss for a card.
private struct SwipeToDismiss: ViewModifier {
    let action: () -> Void
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(1 - Double(abs(offset) / 300))
            .gesture(
                DragGesture()
                    .onChanged { v in if v.translation.width < 0 { offset = v.translation.width } }
                    .onEnded { v in
                        if v.translation.width < -110 {
                            withAnimation { offset = -400 }
                            action()
                        } else {
                            withAnimation { offset = 0 }
                        }
                    }
            )
    }
}

private extension View {
    func swipeToDismiss(_ action: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(action: action))
    }
}
