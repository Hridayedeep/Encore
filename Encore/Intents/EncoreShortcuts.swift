//
//  EncoreShortcuts.swift
//  Encore (Flow A) — Siri / Spotlight zero-config phrases (see claude.md §10.2)
//
//  DUAL-TARGET friendly. Exposes the taste-search intent to Siri with spoken
//  phrases. `.applicationName` resolves to the app's display name at runtime.
//

import Foundation
import AppIntents

@available(iOS 17.0, *)
public struct EncoreShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindShowsForMyTasteIntent(),
            phrases: [
                "Find shows for my taste in \(.applicationName)",
                "Show me concerts in \(.applicationName)",
                "What should I see with \(.applicationName)"
            ],
            shortTitle: "Find Shows",
            systemImageName: "music.mic"
        )
    }
}
