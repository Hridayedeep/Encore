//
//  EventDetailView.swift
//  Encore (Flow A) — event detail (see claude.md §11 S3)
//
//  Hero poster, artist/date, MapKit mini-map + distance, "why this matched you",
//  and the two CTAs: Plan my night → Occasion Builder, or just book the ticket.
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    @Bindable var store: EncoreStore
    let event: Event
    @Binding var path: [EncoreRoute]

    private var scored: ScoredEvent? {
        store.shortlist.first { $0.event.id == event.id }
    }

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EncorePoster(event: event, height: 300, cornerRadius: 24)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text(artistLine)
                            .font(.headline)
                            .foregroundStyle(EncoreTheme.magenta)
                        Text(dateLine)
                            .font(.subheadline)
                            .foregroundStyle(EncoreTheme.textMuted)
                    }

                    mapCard
                    if let scored { whyCard(scored) }
                    priceAndActions
                }
                .padding()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var artistLine: String {
        let names = event.artistIDs.map { SeedData.artist($0).name }
        if names.isEmpty { return event.type.rawValue.capitalized }
        if event.type == .movie { return "Soundtrack: " + names.joined(separator: ", ") }
        return names.joined(separator: ", ")
    }

    private var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d · h:mm a"
        return "\(f.string(from: event.startTime)) · \(event.venue.name), \(event.venue.area)"
    }

    // MARK: Map

    private var mapCard: some View {
        let venueCoord = CLLocationCoordinate2D(latitude: event.venue.coordinate.lat,
                                                longitude: event.venue.coordinate.lng)
        let km = event.distanceKm(from: store.home)
        let travelMin = Int((store.timingEngine.travelTime(from: store.home.coordinate,
                                                           to: event.venue.coordinate) / 60).rounded())
        return VStack(alignment: .leading, spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: venueCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))) {
                Marker(event.venue.name, coordinate: venueCoord)
                    .tint(EncoreTheme.magenta)
            }
            .frame(height: 160)
            .disabled(true)

            HStack {
                Label("\(Int(km.rounded())) km away", systemImage: "location.fill")
                Spacer()
                Label("~\(travelMin) min drive", systemImage: "car.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(12)
        }
        .encoreGlass(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Why matched

    private func whyCard(_ scored: ScoredEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why this matched you")
                .font(.headline).foregroundStyle(.white)
            ForEach(Array(scored.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(EncoreTheme.magenta)
                    Text(reason.phrase)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .encoreGlass(cornerRadius: 18)
    }

    // MARK: Price + actions

    private var priceAndActions: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tickets from")
                    .font(.subheadline).foregroundStyle(EncoreTheme.textMuted)
                Spacer()
                Text("₹\(event.priceFrom)")
                    .font(.title2.bold()).foregroundStyle(.white)
            }

            Button {
                EncoreHaptics.shared.selection()
                Task {
                    _ = await store.buildOccasion(for: event)
                    path.append(.occasion(event))
                }
            } label: {
                Label("Plan my night", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(EncoreTheme.accent))
                    .foregroundStyle(.white)
            }

            Button {
                EncoreHaptics.shared.selection()
                #if canImport(UIKit)
                UIApplication.shared.open(store.eventsSource.deepLink(for: event))
                #endif
            } label: {
                Text("Just book the ticket")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.10)))
                    .foregroundStyle(.white)
            }
        }
    }
}
