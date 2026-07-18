//
//  ShareItinerarySheet.swift
//  EveningPlanner
//
//  Lets the user pick a tone, has ItineraryNarrationService write an
//  invite in that tone, renders ShareableItineraryCard to an image
//  off-screen via ImageRenderer, and hands that image to the system
//  share sheet via ShareLink — a real shareable card, not just text.
//

import SwiftUI
import UIKit

struct ShareItinerarySheet: View {
    let variant: ItineraryVariant

    @Environment(\.dismiss) private var dismiss
    @State private var tone: ShareTone = .romantic
    @State private var message: String?
    @State private var renderedImage: UIImage?

    private let narrationService = ItineraryNarrationService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Tone", selection: $tone) {
                        ForEach(ShareTone.allCases) { candidate in
                            Text("\(candidate.emoji) \(candidate.displayName)").tag(candidate)
                        }
                    }
                    .pickerStyle(.segmented)

                    cardPreview

                    if let renderedImage {
                        ShareLink(
                            item: Image(uiImage: renderedImage),
                            preview: SharePreview("My evening plan", image: Image(uiImage: renderedImage))
                        ) {
                            Text("Share")
                        }
                        .buttonStyle(.primaryCTA)
                    }
                }
                .padding()
            }
            .planFlowScreenBackground()
            .navigationTitle("Share with a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: tone) {
                await regenerate()
            }
        }
    }

    @ViewBuilder
    private var cardPreview: some View {
        if let message {
            ShareableItineraryCard(variant: variant, message: message, tone: tone)
        } else {
            ShareableItineraryCard(
                variant: variant,
                message: "Writing your invite for tonight, one line at a time.",
                tone: tone
            )
            .redacted(reason: .placeholder)
            .shimmering()
        }
    }

    private func regenerate() async {
        // Clear immediately (before the await) so the previous tone's
        // content never lingers on screen while the new one loads.
        message = nil
        renderedImage = nil
        let text = await narrationService.shareMessage(for: variant, tone: tone)
        message = text
        renderedImage = renderCardImage(message: text)
    }

    @MainActor
    private func renderCardImage(message: String) -> UIImage? {
        let content = ShareableItineraryCard(variant: variant, message: message, tone: tone)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

private struct ShareableItineraryCard: View {
    let variant: ItineraryVariant
    let message: String
    let tone: ShareTone

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("PLAN MY EVENING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text(tone.emoji)
                    .font(.title2)
            }

            Text(message)
                .font(.title3.weight(.semibold))
                .italic()
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(variant.stops.enumerated()), id: \.offset) { index, stop in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(LinearGradient(colors: [.purple, .accentColor], startPoint: .top, endPoint: .bottom))
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stop.venueName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(stop.location) • \(stop.timeLabel)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.55), Color.accentColor.opacity(0.35), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
