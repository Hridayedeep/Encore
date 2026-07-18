//
//  BookingDetailsView.swift
//  EveningPlanner
//
//  Reached from the Welcome screen's sticky "upcoming event" banner, not
//  from the booking flow itself (which now ends at BookingSuccessPopupView).
//  Payment is mocked/instant — there's no real payment status to poll, so
//  "Paid" is shown unconditionally once a booking exists. "Add to calendar"
//  is the one real integration here (EventKit via CalendarService).
//

import SwiftUI

private enum CalendarAddState: Equatable {
    case idle
    case adding
    case added
    case failed(String)
}

struct BookingDetailsView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel
    @State private var calendarState: CalendarAddState = .idle

    var body: some View {
        ScrollView {
            if let booking = flow.latestBooking {
                VStack(alignment: .leading, spacing: 24) {
                    stopsSection(booking)
                    paymentSection(booking)
                    calendarSection
                }
                .padding()
            } else {
                Text("No upcoming booking.")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Booking details")
        .navigationBarTitleDisplayMode(.inline)
        .planFlowScreenBackground()
        .onAppear {
            if flow.latestBooking?.calendarAdded == true {
                calendarState = .added
            }
        }
    }

    private func stopsSection(_ booking: Booking) -> some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                ForEach(Array(booking.variant.stops.enumerated()), id: \.offset) { _, stop in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(stop.venueName)
                                .font(.headline)
                            Label(stop.location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Label(stop.timeLabel, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func paymentSection(_ booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payment")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount paid")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(PriceFormatter.rupees(booking.variant.totalCost))
                        .font(.title3.bold())
                }
                Spacer()
                Label("Paid", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)))
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar")
                .font(.headline)

            Button(action: addToCalendar) {
                Label(calendarButtonTitle, systemImage: calendarIcon)
            }
            .buttonStyle(.primaryCTA)
            .disabled(calendarState == .adding || calendarState == .added)

            if case .failed(let message) = calendarState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var calendarButtonTitle: String {
        switch calendarState {
        case .idle: return "Add to calendar"
        case .adding: return "Adding…"
        case .added: return "Added to calendar"
        case .failed: return "Try again"
        }
    }

    private var calendarIcon: String {
        calendarState == .added ? "checkmark" : "calendar.badge.plus"
    }

    private func addToCalendar() {
        guard let variant = flow.latestBooking?.variant else { return }
        calendarState = .adding
        Task {
            do {
                try await CalendarService().addEvents(for: variant)
                calendarState = .added
                flow.latestBooking?.calendarAdded = true
            } catch {
                calendarState = .failed(error.localizedDescription)
            }
        }
    }
}
