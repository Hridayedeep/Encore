//
//  ShareTone.swift
//  EveningPlanner
//
//  Tone options for the shareable invite card (ShareItinerarySheet). Each
//  case carries its own prompt fragment so ItineraryNarrationService's
//  share-message prompt stays generic — adding a fifth tone is a
//  data-only change here, not a prompt-writing change in the service.
//

import Foundation

enum ShareTone: String, CaseIterable, Identifiable {
    case romantic
    case fun
    case hype
    case elegant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .romantic: return "Romantic"
        case .fun: return "Fun"
        case .hype: return "Hype"
        case .elegant: return "Elegant"
        }
    }

    var emoji: String {
        switch self {
        case .romantic: return "🌹"
        case .fun: return "🎉"
        case .hype: return "🔥"
        case .elegant: return "✨"
        }
    }

    /// Fed straight into the LLM prompt as the style instruction.
    var promptStyle: String {
        switch self {
        case .romantic: return "warm, romantic, and poetic — like a heartfelt invitation to someone you love"
        case .fun: return "playful, upbeat, and casual — like texting your best friend about a fun plan"
        case .hype: return "high-energy and hype — like getting a friend pumped for a big night out"
        case .elegant: return "elegant, refined, and understated — like a tasteful formal invitation"
        }
    }

    var fallbackMessage: String {
        switch self {
        case .romantic: return "I've planned something special for us tonight — just say yes."
        case .fun: return "Got the perfect plan for tonight, you in?"
        case .hype: return "Tonight's going to be UNREAL. Let's gooo!"
        case .elegant: return "I would be delighted if you would join me for an evening, carefully arranged."
        }
    }
}
