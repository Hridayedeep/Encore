//
//  BookingSuccessPopupView.swift
//  EveningPlanner
//
//  Replaces the old payment screen: booking is instant/mocked, so this is
//  just a timed confirmation overlay. Owned at the WelcomeScreen level (see
//  PlanFlowViewModel.showBookingSuccessPopup) so it stays on screen for its
//  full duration even though it also triggers the path reset back to Welcome.
//

import SwiftUI

struct BookingSuccessPopupView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel
    @State private var animateCheck = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                        .frame(width: 84, height: 84)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(animateCheck ? 1 : 0.4)
                        .opacity(animateCheck ? 1 : 0)
                }
                Text("Booking successful")
                    .font(.title3.bold())
            }
            .padding(36)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                animateCheck = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                flow.finishBookingSuccessPopup()
            }
        }
    }
}
