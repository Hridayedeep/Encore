//
//  EncoreApp.swift
//  Encore — standalone app entry (Flow A, independent build).
//
//  No Firebase / auth / Flow B. Launches straight into the taste-driven flow.
//

import SwiftUI

@main
struct EncoreApp: App {
    init() {
        // Local notification delegate + categories, before launch finishes.
        EncoreNotifications.shared.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            WelcomeScreen()
                .preferredColorScheme(.dark)
        }
    }
}
