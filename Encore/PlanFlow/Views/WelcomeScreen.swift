//
//  WelcomeScreen.swift
//  EveningPlanner
//
//  Screen 1. Owns the NavigationStack and the single PlanFlowViewModel
//  shared by every downstream screen via @EnvironmentObject. The home
//  content below "Plan my evening" (location/bookmarks/profile/search/
//  categories) is deliberately non-interactive — it exists to make the
//  screen read like a real home screen, not a functional district-app
//  clone. Only "Plan my evening" and the upcoming-booking banner navigate.
//

import SwiftUI

struct WelcomeScreen: View {
    @StateObject private var flow = PlanFlowViewModel()

    var body: some View {
        ZStack {
            NavigationStack(path: $flow.path) {
                WelcomeContent()
                    .navigationDestination(for: PlanFlowRoute.self) { route in
                        destination(for: route)
                    }
            }

            if flow.showBookingSuccessPopup {
                BookingSuccessPopupView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .environmentObject(flow)
        .animation(.easeInOut(duration: 0.25), value: flow.showBookingSuccessPopup)
    }

    @ViewBuilder
    private func destination(for route: PlanFlowRoute) -> some View {
        switch route {
        case .questionnaire:
            QuestionnaireView()
        case .loading:
            LoadingView()
        case .itinerary:
            ItineraryCardView()
        case .bookingDetails:
            BookingDetailsView()
        case .encoreConnect:
            // EncoreRootView has no NavigationStack of its own — every
            // Encore screen (Connect/Feed/Detail/Occasion/Payment/Success)
            // pushes onto this single shared stack via `flow.path`, so
            // there's only ever one NavigationStack in the app.
            EncoreRootView()
        }
    }
}

private struct WelcomeContent: View {
    @EnvironmentObject private var flow: PlanFlowViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HomeTopBar()
                HomeSearchBar()
                HomeCategoriesGrid()
                planEveningButton
                connectAppleMusicButton
            }
            .padding()
        }
        .planFlowScreenBackground()
        .safeAreaInset(edge: .bottom) {
            if let booking = flow.latestBooking {
                UpcomingBookingBanner(booking: booking)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { flow.path.append(PlanFlowRoute.bookingDetails) }
            }
        }
    }

    private var planEveningButton: some View {
        Button(action: {
            flow.path.append(PlanFlowRoute.questionnaire)
        }) {
            PlanEveningCard()
        }
        .buttonStyle(.plain)
    }

    private var connectAppleMusicButton: some View {
        Button(action: {
            flow.path.append(PlanFlowRoute.encoreConnect)
        }) {
            Text("Connect Apple Music to get better event recommendations")
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.secondaryCTA)
    }
}

private struct PlanEveningCard: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Image("go_carting")
                .resizable()
                .aspectRatio(contentMode: .fill)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.75), location: 0.45),
                    .init(color: .black.opacity(0.97), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 130)

            HStack {
                Text("Plan your evening")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 24)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Decorative, non-interactive home sections

private struct HomeTopBar: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Choose location")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("Set your evening's starting point")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "bookmark")
                .font(.title3)
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
        }
        .allowsHitTesting(false)
    }
}

private struct HomeSearchBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("Search things to do tonight")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: Capsule())
        .allowsHitTesting(false)
    }
}

private struct HomeCategory: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
}

/// Placeholder tiles — swap `systemImage` for a real `Image("category_…")`
/// asset per category once those are added; layout doesn't need to change.
private let homeCategories: [HomeCategory] = [
    HomeCategory(title: "Dining", systemImage: "fork.knife", tint: .pink),
    HomeCategory(title: "Movies", systemImage: "film.fill", tint: .blue),
    HomeCategory(title: "Events", systemImage: "music.mic", tint: .orange),
    HomeCategory(title: "Stores", systemImage: "bag.fill", tint: .green),
    HomeCategory(title: "Activities", systemImage: "figure.socialdance", tint: .cyan),
    HomeCategory(title: "Play", systemImage: "gamecontroller.fill", tint: .purple)
]

private struct HomeCategoriesGrid: View {
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(homeCategories) { category in
                    CategoryTile(category: category)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CategoryTile: View {
    let category: HomeCategory

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(category.tint.opacity(0.28))
                Image(systemName: category.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(category.tint)
            }
            .frame(height: 60)

            Text(category.title)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct UpcomingBookingBanner: View {
    let booking: Booking

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Upcoming: \(booking.primaryLocation)")
                    .font(.subheadline.weight(.semibold))
                Text("\(booking.startTime, style: .date) • \(booking.startTime, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassEffect(.regular.tint(.accentColor.opacity(0.3)), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    WelcomeScreen()
}
