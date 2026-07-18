//
//  AppleMusicPermissionView.swift
//  EveningPlanner
//
//  Onboarding step between Welcome and the questionnaire. Explains why we
//  want Apple Music access and requests it explicitly via MusicAuthorization
//  — prefill is never fetched silently in the background. "Not now" skips
//  straight to the questionnaire with nothing prefilled.
//

import SwiftUI
import MusicKit

struct AppleMusicPermissionView: View {
    @EnvironmentObject private var flow: PlanFlowViewModel
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.accentColor, .purple], startPoint: .top, endPoint: .bottom)
                )
                .padding(28)
                .glassEffect(.regular, in: .circle)

            VStack(spacing: 8) {
                Text("Personalize with Apple Music")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("We'll look at your heavy rotation and recently played tracks to pre-fill your vibe, so your first recommendations are already tailored to you. You can always change them yourself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            personaPicker
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: allow) {
                    Text(isRequesting ? "Requesting…" : "Allow Apple Music access")
                }
                .buttonStyle(.primaryCTA)
                .disabled(isRequesting)

                Button(action: skip) {
                    Text("Not now")
                }
                .buttonStyle(.secondaryCTA)
                .disabled(isRequesting)
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .planFlowScreenBackground()
    }

    private var personaPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Apple Music access isn't set up in this build yet, so we'll simulate your taste from a sample profile:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Sample listening profile", selection: $flow.selectedMusicPersona) {
                ForEach(SampleMusicPersona.allCases) { persona in
                    Text(persona.displayName).tag(persona)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func allow() {
        isRequesting = true
        Task {
            _ = await MusicAuthorization.request()
            isRequesting = false
            flow.path.append(PlanFlowRoute.questionnaire)
        }
    }

    private func skip() {
        flow.path.append(PlanFlowRoute.questionnaire)
    }
}
