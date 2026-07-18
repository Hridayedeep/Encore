//
//  UserProfileProvider.swift
//  EveningPlanner
//
//  Same protocol-swap pattern as QuestionnaireProvider/VenueRepository:
//  a new interest source (Instagram, Spotify, calendar history, ...) is a
//  new type conforming to this protocol, added to UserProfileService's
//  provider list — nothing upstream (PlanFlowViewModel, the prefill logic)
//  needs to change. Best-effort by design: a denied/failed/empty source
//  returns an empty profile rather than throwing, so it never blocks the
//  flow.
//

import Foundation

protocol UserProfileProvider {
    var sourceName: String { get }
    func loadProfile() async -> UserInterestProfile
}
