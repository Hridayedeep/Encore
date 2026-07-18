//
//  WidgetStyle.swift
//  EncoreWidget — shared monochrome "ticket" design tokens for the widget target.
//
//  Used by BOTH EncoreHomeWidget and EncoreLiveActivity so the two surfaces read
//  as one system. Extension-local (no dependency on the app's EncoreTheme).
//

import SwiftUI

enum WStyle {
    static let ink = Color.white
    static let dim = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.40)
    static let hairline = Color.white.opacity(0.14)

    /// A stable grayscale gradient per seed so posterless events still feel distinct.
    static func poster(_ seed: String) -> LinearGradient {
        let shades: [(Double, Double)] = [
            (0.34, 0.15), (0.46, 0.22), (0.24, 0.10), (0.38, 0.17), (0.50, 0.26),
        ]
        let pair = shades[abs(seed.hashValue) % max(1, shades.count)]
        return LinearGradient(colors: [Color(white: pair.0), Color(white: pair.1)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The card surface: a soft top-lit near-black.
    static let surface = LinearGradient(
        colors: [Color(white: 0.11), Color(white: 0.03)],
        startPoint: .top, endPoint: .bottom)
}

/// A small "poster" tile: seeded gradient + hairline + a category glyph.
struct PosterBadge: View {
    let title: String
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(WStyle.poster(title))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(WStyle.hairline, lineWidth: 1))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92)))
            .frame(width: size, height: size)
    }
}
