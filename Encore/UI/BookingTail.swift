//
//  BookingTail.swift
//  Encore (Flow A) — shared booking tail (see claude.md §21)
//
//  Mock Payment (Success / Failed) → Success popup (Add to calendar / continue).
//  No real transactions. Success fires the booking-success haptic + animation.
//

import SwiftUI
import EventKit

// MARK: - Payment (mock)

struct EncorePaymentView: View {
    @Bindable var store: EncoreStore
    @Binding var path: [EncoreRoute]
    @State private var processing = false
    @State private var failed = false

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(EncoreTheme.accent)
                Text("Confirm & pay")
                    .font(.title.bold()).foregroundStyle(.white)

                if let plan = store.currentPlan {
                    Text(plan.event.title)
                        .font(.headline).foregroundStyle(.white.opacity(0.9))
                }

                Text("Mock payment — no real transaction.")
                    .font(.caption).foregroundStyle(EncoreTheme.textMuted)

                if failed {
                    Label("Payment failed. Try again.", systemImage: "xmark.octagon.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    simulate(success: true)
                } label: {
                    Label("Success", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(EncoreTheme.accent))
                        .foregroundStyle(.white)
                }
                .disabled(processing)

                Button {
                    simulate(success: false)
                } label: {
                    Text("Simulate failure")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.10)))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .disabled(processing)
            }
            .padding()

            if processing {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.6)
            }
        }
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func simulate(success: Bool) {
        processing = true
        failed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            processing = false
            if success {
                store.confirmBooking()
                EncoreHaptics.shared.success()
                path.append(.success)
            } else {
                failed = true
                EncoreHaptics.shared.error()
            }
        }
    }
}

// MARK: - Success

struct EncoreSuccessView: View {
    @Bindable var store: EncoreStore
    @Binding var path: [EncoreRoute]
    @State private var drawn = false
    @State private var calendarAdded = false

    var body: some View {
        ZStack {
            EncoreTheme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Circle().fill(EncoreTheme.accent).frame(width: 120, height: 120)
                        .shadow(color: EncoreTheme.magenta.opacity(0.6), radius: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(drawn ? 1 : 0.2)
                        .opacity(drawn ? 1 : 0)
                }
                .rotationEffect(.degrees(drawn ? 0 : -25))

                Text("You're going!")
                    .font(.largeTitle.bold()).foregroundStyle(.white)
                if let plan = store.currentPlan {
                    Text(plan.event.title)
                        .font(.headline).foregroundStyle(EncoreTheme.magenta)
                }

                VStack(spacing: 8) {
                    statusRow(calendarAdded ? "Added to Calendar" : "Add to Calendar",
                              icon: calendarAdded ? "calendar.badge.checkmark" : "calendar")
                    statusRow("Ticket in Wallet (stub)", icon: "wallet.pass.fill")
                    statusRow("Countdown started", icon: "timer")
                }
                .padding(.top, 8)

                Spacer()

                if !calendarAdded {
                    Button { addToCalendar() } label: {
                        Label("Add to calendar", systemImage: "calendar.badge.plus")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(EncoreTheme.accent))
                            .foregroundStyle(.white)
                    }
                }

                Button {
                    previewNudges()
                } label: {
                    Label("Preview pre/post nudges (demo)", systemImage: "bell.badge")
                        .font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.25)))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Live Activity phase control (demo — advance the Dynamic Island).
                HStack(spacing: 8) {
                    phaseButton("Essentials", .getEssentials)
                    phaseButton("Live", .liveNow)
                    phaseButton("Post-show", .postShow)
                    Button {
                        EncoreHaptics.shared.selection()
                        store.endLiveActivity()
                    } label: {
                        Text("End").font(.caption2.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.2)))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Button {
                    path.removeAll()
                } label: {
                    Text("Back to For You")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.10)))
                        .foregroundStyle(.white)
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { drawn = true }
            // Schedule the pre-event (Blinkit) + post-event (Zomato) local nudges.
            store.scheduleBookingNudges()
        }
    }

    private func phaseButton(_ label: String, _ phase: EncoreActivityAttributes.ContentState.Phase) -> some View {
        Button {
            EncoreHaptics.shared.selection()
            store.advanceLiveActivity(to: phase)
        } label: {
            Text(label).font(.caption2.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12)))
                .foregroundStyle(.white)
        }
    }

    private func previewNudges() {
        guard let plan = store.currentPlan else { return }
        EncoreHaptics.shared.selection()
        EncoreNotifications.shared.fireDemo(
            stage: .preEvent, eventID: plan.event.id,
            title: "Pre-show check 🥤",
            body: "Grab cold drinks & essentials from Blinkit before you leave for \(plan.event.venue.name).",
            seconds: 5)
        EncoreNotifications.shared.fireDemo(
            stage: .postEvent, eventID: plan.event.id,
            title: "Tired from all that dancing? 🍜",
            body: "Order hot food home on Zomato — timed to land as you walk in.",
            seconds: 9)
    }

    private func statusRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(EncoreTheme.magenta)
            Text(text).font(.subheadline).foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func addToCalendar() {
        guard let plan = store.currentPlan else { return }
        let eventStore = EKEventStore()
        eventStore.requestWriteOnlyAccessToEvents { granted, _ in
            guard granted else {
                DispatchQueue.main.async { EncoreHaptics.shared.error() }
                return
            }
            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.title = "🎟 \(plan.event.title)"
            ekEvent.startDate = plan.event.startTime
            ekEvent.endDate = plan.event.endTime
            ekEvent.location = "\(plan.event.venue.name), \(plan.event.venue.area)"
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            try? eventStore.save(ekEvent, span: .thisEvent)
            DispatchQueue.main.async {
                calendarAdded = true
                EncoreHaptics.shared.selection()
            }
        }
    }
}
