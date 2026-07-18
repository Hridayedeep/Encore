//
//  ItineraryCardView.swift
//  EveningPlanner
//
//  Screen 3. Shows one of the 5 generated variants at a time — "option
//  X/5" labels which one. Thumbs up/down just log via EventLogger today;
//  Shuffle jumps to a different random candidate from the same 5.
//

import SwiftUI

struct ItineraryCardView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel
    @State private var feedbackGiven: Bool?
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 20) {
            if !flow.variants.isEmpty {
                header
            }

            if let variant = flow.selectedVariant {
                narrationBlurb(variant)

                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        VStack(spacing: 16) {
                            ForEach(Array(variant.stops.enumerated()), id: \.offset) { index, stop in
                                StopCard(index: index + 1, stop: stop)
                            }
                        }
                    }
                }

                feedbackRow

                actionButtons
            } else {
                Spacer()
                Text(flow.generationError ?? "No itinerary could be generated for these preferences.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .planFlowScreenBackground()
        .onChange(of: flow.selectedVariantIndex) { _, _ in
            feedbackGiven = nil
        }
        .task(id: flow.selectedVariantIndex) {
            await flow.loadNarrationIfNeeded()
        }
        .sheet(isPresented: $showShareSheet) {
            if let variant = flow.selectedVariant {
                ShareItinerarySheet(variant: variant)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(flow.selectedVariant == nil)
            }
        }
    }

    @ViewBuilder
    private func narrationBlurb(_ variant: ItineraryVariant) -> some View {
        if let narration = variant.narration {
            Text(narration)
                .font(.subheadline.italic())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Thinking about why you'll love this tonight, one detail at a time.")
                .font(.subheadline.italic())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: .placeholder)
                .shimmering()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Option \(flow.selectedVariantIndex + 1) / \(flow.variants.count)")
                    .font(.headline)
                Spacer()
            }

            if let variant = flow.selectedVariant {
                TotalCostBanner(totalCost: variant.totalCost, groupSize: flow.planRequest.groupSize)
            }
        }
    }

    private var feedbackRow: some View {
        HStack(spacing: 16) {
            Spacer()
            feedbackButton(
                isSelected: feedbackGiven == true,
                systemImage: feedbackGiven == true ? "hand.thumbsup.fill" : "hand.thumbsup",
                action: { giveFeedback(liked: true) }
            )
            feedbackButton(
                isSelected: feedbackGiven == false,
                systemImage: feedbackGiven == false ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                action: { giveFeedback(liked: false) }
            )
            Spacer()
        }
        .font(.title3)
    }

    private func feedbackButton(isSelected: Bool, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .background(.ultraThinMaterial, in: Circle())
        .overlay(
            Circle().strokeBorder(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [.purple, .purple.opacity(0)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(Color.white.opacity(0.16)),
                lineWidth: isSelected ? 2 : 1
            )
        )
    }

    private var actionButtons: some View {
        Button(action: { flow.bookNow() }) {
            Text("Book now")
        }
        .buttonStyle(.primaryCTA)
    }

    private func giveFeedback(liked: Bool) {
        feedbackGiven = liked
        flow.logFeedback(liked: liked)
    }
}

private struct TotalCostBanner: View {
    let totalCost: Int
    let groupSize: Int

    var body: some View {
        HStack {
            Text(groupSize > 1 ? "TOTAL FOR \(groupSize) TONIGHT" : "TOTAL FOR TONIGHT")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(PriceFormatter.rupees(totalCost))
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding()
        .glassEffect(.regular.tint(.accentColor.opacity(0.35)), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct StopCard: View {
    let index: Int
    let stop: ItineraryStop

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.accentColor, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Text("\(index)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(stop.venueName)
                    .font(.headline)
                Label(stop.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(stop.timeLabel, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(stop.priceLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }
}
