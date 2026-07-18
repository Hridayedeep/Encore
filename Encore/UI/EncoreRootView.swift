//
//  EncoreRootView.swift
//  Encore (Flow A) — entry gate + navigation (see claude.md §11)
//
//  Hosts the Encore taste-driven flow. Lives as its own tab inside the existing
//  EveningPlanner shell. Connect (persona) → For You feed → Detail → Occasion →
//  mock Payment → Success.
//

import SwiftUI

enum EncoreRoute: Hashable {
    case detail(Event)
    case occasion(Event)
    case payment
    case success
}

struct EncoreRootView: View {
    @State private var store = EncoreStore()
    @State private var path: [EncoreRoute] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.activePersona == nil {
                    ConnectView(store: store)
                } else {
                    FeedView(store: store, path: $path)
                }
            }
            .navigationDestination(for: EncoreRoute.self) { route in
                switch route {
                case .detail(let event):
                    EventDetailView(store: store, event: event, path: $path)
                case .occasion(let event):
                    OccasionView(store: store, event: event, path: $path)
                case .payment:
                    EncorePaymentView(store: store, path: $path)
                case .success:
                    EncoreSuccessView(store: store, path: $path)
                }
            }
        }
        .tint(EncoreTheme.magenta)
        .preferredColorScheme(.dark)
        .onAppear {
            EncoreNotifications.shared.onTap = { [weak store] route in
                store?.pendingNotificationRoute = route
            }
            store.consumeSharedPendingRoute()
        }
        .onChange(of: scenePhase) { _, phase in
            // App Intents / widget wrote a route while we were backgrounded.
            if phase == .active { store.consumeSharedPendingRoute() }
        }
        .onOpenURL { url in
            // encore://event?id=... from the Live Activity widgetURL.
            guard url.scheme == "encore",
                  let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                      .queryItems?.first(where: { $0.name == "id" })?.value else { return }
            store.pendingNotificationRoute = NotifRoute(eventID: id, stage: .match)
        }
        .onChange(of: store.pendingNotificationRoute) { _, route in
            guard let route, let event = store.event(id: route.eventID) else { return }
            store.pendingNotificationRoute = nil
            switch route.stage {
            case .match:
                path = [.detail(event)]
            case .preEvent, .postEvent:
                // Route into the occasion so the Blinkit/Zomato cards are visible.
                Task {
                    _ = await store.buildOccasion(for: event)
                    path = [.detail(event), .occasion(event)]
                }
            }
        }
    }
}

// MARK: - Connect / persona picker (S1)

struct ConnectView: View {
    @Bindable var store: EncoreStore
    @State private var connecting: String? = nil
    @State private var appleMusicFailed = false

    private func connectAppleMusic() async {
        connecting = "applemusic"
        EncoreHaptics.shared.selection()
        let ok = await store.connectAppleMusic()
        connecting = nil
        if ok {
            EncoreHaptics.shared.matchFound()
        } else {
            appleMusicFailed = true
            EncoreHaptics.shared.error()
        }
    }

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()
            glow

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    // Real path — attempts live MusicKit; falls back to persona if
                    // there's no paid dev account / subscription yet.
                    Button {
                        Task { await connectAppleMusic() }
                    } label: {
                        connectRow(icon: "applelogo", title: "Connect Apple Music",
                                   subtitle: appleMusicFailed ? "Not available yet — pick a demo persona below"
                                                             : "Find shows you'll actually love",
                                   tint: EncoreTheme.accent)
                    }
                    .overlay(alignment: .topTrailing) {
                        Text(appleMusicFailed ? "token later" : "live")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(6)
                            .background(Capsule().fill(.white.opacity(0.12)))
                            .offset(x: -10, y: 10)
                    }

                    Text("Not an Apple Music subscriber? Try a demo persona")
                        .font(.subheadline)
                        .foregroundStyle(EncoreTheme.textMuted)
                        .padding(.top, 4)

                    ForEach(SeedData.personas) { persona in
                        Button {
                            Task { await connect(persona) }
                        } label: {
                            personaRow(persona)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func connect(_ persona: Persona) async {
        connecting = persona.id
        EncoreHaptics.shared.selection()
        await store.connect(persona: persona)
        await store.requestNotificationPermission()
        EncoreHaptics.shared.matchFound()
        connecting = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(EncoreTheme.accent)
            Text("Encore")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.white)
            Text("Your music taste, turned into the perfect night out.")
                .font(.body)
                .foregroundStyle(EncoreTheme.textMuted)
        }
        .padding(.bottom, 8)
    }

    private func connectRow(icon: String, title: String, subtitle: String, tint: LinearGradient) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(tint))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(EncoreTheme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
        }
        .padding()
        .encoreGlass()
    }

    private func personaRow(_ persona: Persona) -> some View {
        HStack(spacing: 14) {
            Image(systemName: persona.accentAsset)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(EncoreTheme.posterGradient(for: persona.id)))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(persona.name).font(.headline).foregroundStyle(.white)
                Text(persona.blurb).font(.caption).foregroundStyle(EncoreTheme.textMuted)
            }
            Spacer()
            if connecting == persona.id {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding()
        .encoreGlass()
    }

    private var glow: some View {
        Circle()
            .fill(EncoreTheme.violet.opacity(0.25))
            .frame(width: 300, height: 300)
            .blur(radius: 80)
            .offset(x: -80, y: -180)
    }
}
