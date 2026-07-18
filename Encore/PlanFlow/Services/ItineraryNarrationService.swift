//
//  ItineraryNarrationService.swift
//  EveningPlanner
//
//  Wraps Apple's on-device FoundationModels (confirmed working in this
//  Simulator via LanguageModelSession().respond(to:)). ItineraryGenerator
//  still owns venue selection — this only writes copy on top of an
//  already-chosen ItineraryVariant: a short "why this fits you" blurb for
//  the itinerary card, and a tone-styled invite message for sharing.
//  Every call has a plain-text fallback so a model that's unavailable or
//  errors never blocks the UI — same pattern as the other "real API, mock
//  fallback" seams in this app (AppleMusicHistoryProfileProvider, etc.).
//

import Foundation
import FoundationModels

struct ItineraryNarrationService {
    func blurb(for variant: ItineraryVariant, tags: Set<String>) async -> String {
        let stopsDescription = variant.stops
            .map { "\($0.venueName) at \($0.location) (\($0.timeLabel))" }
            .joined(separator: ", then ")
        let tagList = tags.isEmpty ? "a good night out" : tags.sorted().joined(separator: ", ")

        let prompt = """
        Write exactly one short, warm sentence (max 25 words) explaining why this evening plan suits \
        someone who likes \(tagList). The plan: \(stopsDescription). No greeting, no quotation marks — \
        just the sentence.
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return clean(response.content)
        } catch {
            return "A pick tuned to your \(tags.first ?? "kind of") evening."
        }
    }

    func shareMessage(for variant: ItineraryVariant, tone: ShareTone) async -> String {
        let stopsDescription = variant.stops
            .map { "\($0.venueName) at \($0.location) (\($0.timeLabel))" }
            .joined(separator: ", then ")

        let prompt = """
        Write a short invitation (2-3 sentences) for a friend to join this evening plan: \(stopsDescription). \
        Tone: \(tone.promptStyle). Do not include a greeting like "Hey" or a sign-off — just the invitation itself.
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return clean(response.content)
        } catch {
            return tone.fallbackMessage
        }
    }

    private func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
