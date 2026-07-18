//
//  VenueRepository.swift
//  EveningPlanner
//

import Foundation

protocol VenueRepository {
    func loadVenues() throws -> [Venue]
}

struct BundledVenueRepository: VenueRepository {
    let resourceName: String

    init(resourceName: String = "mock_venues") {
        self.resourceName = resourceName
    }

    func loadVenues() throws -> [Venue] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Venue].self, from: data)
    }
}
