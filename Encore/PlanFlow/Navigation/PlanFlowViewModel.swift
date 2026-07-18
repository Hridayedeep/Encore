//
//  PlanFlowViewModel.swift
//  EveningPlanner
//
//  Single source of truth for the Plan My Evening flow: owns navigation,
//  the loaded questionnaire definition, the generic answers dictionary,
//  and the generated itinerary candidates. Every screen reads/writes
//  this via @EnvironmentObject instead of passing state through inits.
//

import Combine
import SwiftUI

final class PlanFlowViewModel: ObservableObject {
    @Published var path = NavigationPath()
    @Published var questionnaire: QuestionnaireDefinition?
    @Published var answers: [String: AnswerValue] = [:]
    @Published var planRequest = PlanRequest()
    @Published var variants: [ItineraryVariant] = []
    @Published var selectedVariantIndex = 0
    @Published var generationError: String?
    @Published var interestProfile: UserInterestProfile?
    /// Which bundled sample listening history to fall back to for the
    /// Apple Music prefill, picked by the user on AppleMusicPermissionView.
    /// See AppleMusicHistoryProfileProvider's header for why a sample is
    /// still needed alongside the real MusicKit call.
    @Published var selectedMusicPersona: SampleMusicPersona = .chillListener
    /// The single "upcoming event" the Welcome screen's sticky banner
    /// points at. Booking another evening overwrites it.
    @Published var latestBooking: Booking?
    /// Drives the auto-dismissing "Booking successful" overlay, owned at
    /// the WelcomeScreen level so it survives the path reset that follows it.
    @Published var showBookingSuccessPopup = false

    let questionnaireProvider: QuestionnaireProvider
    let venueRepository: VenueRepository
    let itineraryGenerator: ItineraryGenerator
    let eventLogger: EventLogger
    let userProfileServiceProvider: (SampleMusicPersona) -> UserProfileService
    let narrationService: ItineraryNarrationService

    init(
        questionnaireProvider: QuestionnaireProvider = BundledQuestionnaireProvider(resourceName: "plan_my_evening_questionnaire"),
        venueRepository: VenueRepository = BundledVenueRepository(),
        itineraryGenerator: ItineraryGenerator = ItineraryGenerator(),
        eventLogger: EventLogger = ConsoleEventLogger(),
        userProfileServiceProvider: @escaping (SampleMusicPersona) -> UserProfileService = { persona in
            UserProfileService(providers: [
                AppleMusicHistoryProfileProvider(),
                SampleMusicProfileProvider(persona: persona)
            ])
        },
        narrationService: ItineraryNarrationService = ItineraryNarrationService()
    ) {
        self.questionnaireProvider = questionnaireProvider
        self.venueRepository = venueRepository
        self.itineraryGenerator = itineraryGenerator
        self.eventLogger = eventLogger
        self.userProfileServiceProvider = userProfileServiceProvider
        self.narrationService = narrationService
    }

    var selectedVariant: ItineraryVariant? {
        guard variants.indices.contains(selectedVariantIndex) else { return nil }
        return variants[selectedVariantIndex]
    }

    /// Apple Music prefill is unbound from the flow for now (no permission
    /// screen calls into it) — flip this to re-enable once that's wired
    /// back in, rather than deleting the prefill implementation.
    private let prefillEnabled = false

    func loadQuestionnaireIfNeeded() async {
        guard questionnaire == nil else { return }
        do {
            let loaded = try await questionnaireProvider.loadQuestionnaire()
            questionnaire = loaded
            if prefillEnabled {
                await prefillFromInterestProfile(questions: loaded.questions)
            }
        } catch {
            generationError = "Couldn't load the questionnaire."
        }
    }

    /// Best-effort prefill: only fills questions the user hasn't already
    /// answered, and only tag-style ("preferenceTags") questions — it never
    /// touches goingOut/startTime/groupSize, which aren't taste signals.
    private func prefillFromInterestProfile(questions: [Question]) async {
        let profile = await userProfileServiceProvider(selectedMusicPersona).loadProfile()
        interestProfile = profile
        guard !profile.isEmpty else { return }

        for question in questions {
            guard question.mapsToField == "preferenceTags",
                  let options = question.options,
                  answers[question.id] == nil else { continue }

            let candidateValues = Set(options.map(\.value))
            let limit = question.type == .multiSelect ? 3 : 1
            let matchedTags = profile.topTags(matching: candidateValues, limit: limit)
            guard !matchedTags.isEmpty else { continue }

            switch question.type {
            case .multiSelect:
                answers[question.id] = .multipleChoice(matchedTags)
            case .singleSelect:
                if let best = matchedTags.first {
                    answers[question.id] = .text(best)
                }
            case .date:
                break
            }
        }
    }

    func generateItinerary() async {
        guard let questions = questionnaire?.questions else { return }
        planRequest = PlanRequestMapper.makePlanRequest(from: answers, questions: questions)
        do {
            let venues = try venueRepository.loadVenues()
            try await Task.sleep(nanoseconds: 700_000_000)
            variants = itineraryGenerator.generateVariants(for: planRequest, venues: venues)
            selectedVariantIndex = 0
            generationError = variants.isEmpty ? "Couldn't find a match for these preferences." : nil
        } catch {
            generationError = "Couldn't load venues."
        }
    }

    /// Best-effort, on-demand: only generates a blurb for the variant
    /// currently on screen, and only once. Called from ItineraryCardView's
    /// .task(id: selectedVariantIndex) — never blocks itinerary display.
    func loadNarrationIfNeeded() async {
        guard variants.indices.contains(selectedVariantIndex) else { return }
        let variant = variants[selectedVariantIndex]
        guard variant.narration == nil else { return }

        let text = await narrationService.blurb(for: variant, tags: planRequest.preferenceTags)

        guard let currentIndex = variants.firstIndex(where: { $0.id == variant.id }) else { return }
        variants[currentIndex].narration = text
    }

    func shuffle() {
        guard variants.count > 1 else { return }
        var newIndex = selectedVariantIndex
        while newIndex == selectedVariantIndex {
            newIndex = Int.random(in: 0..<variants.count)
        }
        selectedVariantIndex = newIndex
    }

    func logFeedback(liked: Bool) {
        guard let variant = selectedVariant else { return }
        eventLogger.log(.itineraryFeedback(variantId: variant.id, liked: liked))
    }

    /// Called from "Book now" — no payment screen anymore, this just
    /// records the booking and shows the success popup. The popup itself
    /// resets the flow back to the Welcome screen once it's done.
    func bookNow() {
        guard let variant = selectedVariant else { return }
        latestBooking = Booking(variant: variant, bookedAt: Date())
        showBookingSuccessPopup = true
    }

    func finishBookingSuccessPopup() {
        showBookingSuccessPopup = false
        reset()
    }

    func reset() {
        answers = [:]
        planRequest = PlanRequest()
        variants = []
        selectedVariantIndex = 0
        generationError = nil
        path = NavigationPath()
    }
}
