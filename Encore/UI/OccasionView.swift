//
//  OccasionView.swift
//  Encore (Flow A) — Occasion Builder (see claude.md §11 S4, §8)
//
//  Editable stack: Ticket · Dinner · Pre-drinks · After-the-show (timing engine).
//  Each card toggles on by default with a smart default. Live total + Confirm.
//

import SwiftUI

struct OccasionView: View {
    @Bindable var store: EncoreStore
    let event: Event
    @Binding var path: [EncoreRoute]

    @State private var includeDinner = true
    @State private var includePreDrinks = true
    @State private var timing: DeliveryTiming = .onArrival

    private var plan: OccasionPlan? { store.currentPlan }

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Build the night")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Because it's Eternal, the night doesn't end at the ticket.")
                        .font(.subheadline).foregroundStyle(EncoreTheme.textMuted)

                    ticketCard
                    dinnerCard
                    preDrinksCard
                    afterShowCard
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Ticket

    private var ticketCard: some View {
        cardShell(emoji: "🎟", title: "Ticket · District", on: .constant(true), locked: true) {
            HStack {
                EncorePoster(event: event, height: 64, cornerRadius: 12).frame(width: 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).font(.subheadline.bold()).foregroundStyle(.white)
                    Text("\(event.venue.name) · from ₹\(event.priceFrom)")
                        .font(.caption).foregroundStyle(EncoreTheme.textMuted)
                }
                Spacer()
                Stepper(value: $store.partySize, in: 1...10) {
                    Text("×\(store.partySize)").font(.subheadline.bold()).foregroundStyle(.white)
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    // MARK: Dinner

    private var dinnerCard: some View {
        cardShell(emoji: "🍽", title: "Dinner near the venue", on: $includeDinner) {
            if let dinner = plan?.dinner {
                HStack {
                    Image(systemName: "fork.knife")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(EncoreTheme.posterGradient(for: dinner.restaurant.id)))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dinner.restaurant.name).font(.subheadline.bold()).foregroundStyle(.white)
                        Text("\(dinner.restaurant.cuisine) · ₹\(dinner.restaurant.priceForTwo) for two · \(timeString(dinner.time))")
                            .font(.caption).foregroundStyle(EncoreTheme.textMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Pre-drinks

    private var preDrinksCard: some View {
        cardShell(emoji: "🥤", title: "Pre-drinks & snacks · Blinkit", on: $includePreDrinks) {
            if let cart = plan?.preDrinks {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(cart.items) { item in
                        HStack {
                            Text("• \(item.name)").font(.caption).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("₹\(item.price)").font(.caption).foregroundStyle(EncoreTheme.textMuted)
                        }
                    }
                    Text("Arrives before you leave · ~\(timeString(cart.deliverBefore))")
                        .font(.caption2).foregroundStyle(EncoreTheme.magenta)
                }
            }
        }
    }

    // MARK: After the show (timing engine)

    private var afterShowCard: some View {
        cardShell(emoji: "🌙", title: "After the show", on: .constant(true), locked: true) {
            VStack(alignment: .leading, spacing: 12) {
                if let post = plan?.postEvent {
                    Text(afterShowCopy(post))
                        .font(.subheadline).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Image(systemName: vendorIcon(post.vendor))
                        Text("\(post.vendor.rawValue.capitalized) · ready by ~\(timeString(post.computedReadyBy))")
                            .font(.caption.bold())
                        Spacer()
                    }
                    .foregroundStyle(EncoreTheme.magenta)
                } else if timing == .skip {
                    Text("No post-event order. You can add one later from Manage.")
                        .font(.caption).foregroundStyle(EncoreTheme.textMuted)
                }

                Picker("Timing", selection: $timing) {
                    Text("Now").tag(DeliveryTiming.now)
                    Text("On arrival").tag(DeliveryTiming.onArrival)
                    Text("20 min out").tag(DeliveryTiming.whenMinutesAway(20))
                    Text("Skip").tag(DeliveryTiming.skip)
                }
                .pickerStyle(.segmented)
                .onChange(of: timing) { _, newValue in
                    EncoreHaptics.shared.selection()
                    Task { await store.recomputePostEvent(timing: newValue) }
                }
            }
        }
    }

    private func afterShowCopy(_ post: PostEventOrder) -> String {
        switch post.timing {
        case .onArrival:
            return "We'll have hot food home ~as you walk in (\(timeString(post.computedReadyBy)))."
        case .now:
            return "Ordering now — hot food home by ~\(timeString(post.computedReadyBy))."
        case .whenMinutesAway(let m):
            return "We'll fire the order when you're \(m) min out — ready ~\(timeString(post.computedReadyBy))."
        case .skip:
            return ""
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Live total").font(.subheadline).foregroundStyle(EncoreTheme.textMuted)
                Spacer()
                Text("₹\(liveTotal)").font(.title3.bold()).foregroundStyle(.white)
            }
            Button {
                EncoreHaptics.shared.selection()
                path.append(.payment)
            } label: {
                Label("Confirm the night", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(EncoreTheme.accent))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var liveTotal: Int {
        var total = event.priceFrom * store.partySize
        if includeDinner, let d = plan?.dinner { total += d.restaurant.priceForTwo }
        if includePreDrinks, let c = plan?.preDrinks { total += c.total }
        if let post = plan?.postEvent { total += post.total }
        return total
    }

    // MARK: Reusable card shell

    @ViewBuilder
    private func cardShell<Content: View>(emoji: String, title: String,
                                          on: Binding<Bool>, locked: Bool = false,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji).font(.title3)
                Text(title).font(.headline).foregroundStyle(.white)
                Spacer()
                if !locked {
                    Toggle("", isOn: on).labelsHidden().tint(EncoreTheme.magenta)
                }
            }
            if locked || on.wrappedValue {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .encoreGlass(cornerRadius: 18)
        .opacity(locked || on.wrappedValue ? 1 : 0.5)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: date)
    }

    private func vendorIcon(_ vendor: Vendor) -> String {
        switch vendor {
        case .bistro:         return "takeoutbag.and.cup.and.straw.fill"
        case .zomato:         return "fork.knife"
        case .blinkit:        return "bag.fill"
        case .districtDining: return "wineglass.fill"
        }
    }
}
