//
//  EncoreHomeWidget.swift
//  EncoreWidget — Home/Lock screen widget (see claude.md §10.4)
//
//  Reads the App Group snapshot the app writes; shows the #1 matched show with an
//  interactive Book button (App Intent). Ticket motif, shared with the Live Activity.
//

import WidgetKit
import SwiftUI
import AppIntents

struct EncoreEntry: TimelineEntry {
    let date: Date
    let snapshot: EncoreSnapshot?
}

struct EncoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> EncoreEntry {
        EncoreEntry(date: Date(), snapshot: EncoreSnapshot(
            nextEventTitle: "Dil-Luminati Tour", nextEventVenue: "JLN Stadium",
            heroHeadline: "You've had Diljit on repeat"))
    }

    func getSnapshot(in context: Context, completion: @escaping (EncoreEntry) -> Void) {
        completion(EncoreEntry(date: Date(), snapshot: EncoreSharedStore.readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EncoreEntry>) -> Void) {
        let entry = EncoreEntry(date: Date(), snapshot: EncoreSharedStore.readSnapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct EncoreHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "EncoreHomeWidget", provider: EncoreProvider()) { entry in
            EncoreWidgetView(entry: entry)
                .containerBackground(for: .widget) { WStyle.surface }
        }
        .configurationDisplayName("Encore — For You")
        .description("The show that best matches your music taste.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct EncoreWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: EncoreEntry

    private let glyph = "music.mic"

    var body: some View {
        if let snap = entry.snapshot, let title = snap.nextEventTitle {
            if family == .systemMedium { medium(snap, title) } else { small(snap, title) }
        } else {
            emptyState
        }
    }

    // MARK: Small

    @ViewBuilder
    private func small(_ snap: EncoreSnapshot, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                PosterBadge(title: title, symbol: glyph, size: 30)
                Text("FOR YOU")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(WStyle.faint)
            }
            Spacer(minLength: 8)
            Text(snap.heroHeadline ?? title)
                .font(.subheadline.bold()).foregroundStyle(WStyle.ink)
                .lineLimit(3).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            bookButton(snap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium

    @ViewBuilder
    private func medium(_ snap: EncoreSnapshot, _ title: String) -> some View {
        HStack(spacing: 14) {
            PosterBadge(title: title, symbol: glyph, size: 74)
            VStack(alignment: .leading, spacing: 6) {
                Text("FOR YOU")
                    .font(.system(size: 10, weight: .heavy)).tracking(1.5)
                    .foregroundStyle(WStyle.faint)
                Text(snap.heroHeadline ?? title)
                    .font(.headline).foregroundStyle(WStyle.ink)
                    .lineLimit(2).minimumScaleFactor(0.9)
                if let venue = snap.nextEventVenue {
                    Label("\(title) · \(venue)", systemImage: "mappin.and.ellipse")
                        .font(.caption2).foregroundStyle(WStyle.dim).lineLimit(1)
                }
                Spacer(minLength: 4)
                bookButton(snap)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    @ViewBuilder
    private func bookButton(_ snap: EncoreSnapshot) -> some View {
        if let id = snap.nextEventID {
            Button(intent: BookShowIntent(eventID: id)) {
                HStack(spacing: 5) {
                    Text(snap.planStatus == "booked" ? "View night" : "See the night")
                        .font(.caption2.bold())
                    Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterBadge(title: "Encore", symbol: "waveform", size: 34)
            Spacer(minLength: 0)
            Text("Open Encore to find shows for your taste.")
                .font(.caption).foregroundStyle(WStyle.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
