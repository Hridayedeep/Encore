//
//  EncoreLiveActivity.swift
//  EncoreWidget — Lock Screen + Dynamic Island (see claude.md §10.5)
//
//  Ticket-stub motif, monochrome. Smart countdown: a ticking HH:MM:SS only when
//  the show is close or live, otherwise a clean date / day-count (no "306 hours").
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Smart countdown

private struct Countdown {
    let target: Date
    let phase: EncoreActivityAttributes.ContentState.Phase

    var label: String { phase == .liveNow ? "ends in" : "starts in" }

    /// Dramatic ticking clock only when live or inside the final ~6 hours;
    /// otherwise a calm date so we never render "306:38:31".
    var usesTimer: Bool {
        phase == .liveNow || target.timeIntervalSinceNow < 6 * 3600
    }

    var days: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0)
    }
}

// MARK: - Shared building blocks

private struct PhaseChip: View {
    let phase: EncoreActivityAttributes.ContentState.Phase
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: phase.symbol).font(.system(size: 9, weight: .bold))
            Text(phase.label.uppercased())
                .font(.system(size: 9, weight: .bold)).tracking(0.6)
        }
        .foregroundStyle(phase == .liveNow ? .black : WStyle.ink)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(
            Capsule().fill(phase == .liveNow ? AnyShapeStyle(.white)
                                             : AnyShapeStyle(Color.white.opacity(0.12))))
        .overlay(Capsule().stroke(WStyle.hairline, lineWidth: phase == .liveNow ? 0 : 1))
    }
}

/// The ticket-stub countdown column (top value + bottom caption).
private struct CountdownStub: View {
    let cd: Countdown
    var big: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if cd.usesTimer {
                Text(cd.target, style: .timer)
                    .font((big ? Font.title3 : .headline).monospacedDigit().bold())
                    .foregroundStyle(WStyle.ink)
                    .frame(maxWidth: big ? 92 : 72, alignment: .trailing)
                Text(cd.label).font(.system(size: 9, weight: .medium)).foregroundStyle(WStyle.faint)
            } else {
                Text(cd.target, format: .dateTime.month(.abbreviated).day())
                    .font((big ? Font.title3 : .headline).bold())
                    .foregroundStyle(WStyle.ink)
                Text(cd.target, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(WStyle.dim)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

// MARK: - Widget

struct EncoreLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EncoreActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .widgetURL(URL(string: "encore://event?id=\(context.attributes.eventID)"))
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let cd = Countdown(target: context.state.countdownTarget, phase: context.state.phase)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PosterBadge(title: context.attributes.eventTitle,
                                symbol: context.state.phase.symbol, size: 38)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownStub(cd: cd, big: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.eventTitle)
                            .font(.callout.bold()).foregroundStyle(WStyle.ink).lineLimit(1)
                        Text(context.attributes.venueName)
                            .font(.caption2).foregroundStyle(WStyle.dim).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack {
                            PhaseChip(phase: context.state.phase)
                            Spacer(minLength: 6)
                            Text(context.state.statusMessage)
                                .font(.caption2).foregroundStyle(WStyle.dim)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        phaseButton(context)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(WStyle.ink)
            } compactTrailing: {
                if cd.usesTimer {
                    Text(cd.target, style: .timer)
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(WStyle.ink).frame(maxWidth: 46)
                } else {
                    Text("\(cd.days)d")
                        .font(.caption2.bold()).foregroundStyle(WStyle.ink)
                }
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(WStyle.ink)
            }
            .widgetURL(URL(string: "encore://event?id=\(context.attributes.eventID)"))
            .keylineTint(.white)
        }
    }

    @ViewBuilder
    private func phaseButton(_ context: ActivityViewContext<EncoreActivityAttributes>) -> some View {
        let id = context.attributes.eventID
        switch context.state.phase {
        case .getEssentials, .upcoming:
            StubButton(intent: OrderEssentialsIntent(eventID: id),
                       title: "Order essentials", symbol: "bag.fill")
        case .liveNow:
            EmptyView()
        case .postShow:
            StubButton(intent: OrderFoodIntent(eventID: id),
                       title: "Order food", symbol: "takeoutbag.and.cup.and.straw.fill")
        }
    }
}

// MARK: - Filled pill button (white on black), reused across regions

private struct StubButton<I: AppIntent>: View {
    let intent: I
    let title: String
    let symbol: String

    var body: some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock Screen / banner view (the ticket)

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<EncoreActivityAttributes>

    private var cd: Countdown {
        Countdown(target: context.state.countdownTarget, phase: context.state.phase)
    }

    var body: some View {
        HStack(spacing: 12) {
            PosterBadge(title: context.attributes.eventTitle,
                        symbol: context.state.phase.symbol, size: 48)

            VStack(alignment: .leading, spacing: 5) {
                PhaseChip(phase: context.state.phase)
                Text(context.attributes.eventTitle)
                    .font(.headline).foregroundStyle(WStyle.ink).lineLimit(1)
                if let readyBy = context.state.readyByText, context.state.phase == .postShow {
                    Label("Hot food home ~\(readyBy)", systemImage: "takeoutbag.and.cup.and.straw.fill")
                        .font(.caption.bold()).foregroundStyle(WStyle.ink).lineLimit(1)
                } else {
                    Text(context.attributes.venueName)
                        .font(.caption).foregroundStyle(WStyle.dim).lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // Perforated stub edge + countdown
            HStack(spacing: 10) {
                DashedDivider()
                CountdownStub(cd: cd, big: true)
            }
        }
        .padding(14)
        .background(WStyle.surface)
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.06), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 40).allowsHitTesting(false)
        }
    }
}

/// Vertical perforated line — the "tear here" of a ticket stub.
private struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .foregroundStyle(WStyle.hairline)
            .frame(width: 1)
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY + 2))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 2))
            return p
        }
    }
}
