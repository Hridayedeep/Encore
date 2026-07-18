//
//  TimingEngine.swift
//  Encore (Flow A) — post-event smart-timing engine (see claude.md §8)
//
//  Anchors delivery to actual arrival-home and adapts when reality changes. Pure
//  & injectable (now / currentLoc / vendorETA passed in) so it's demoable live.
//

import Foundation

public struct TimingEngine {
    public init() {}

    /// Straight-line travel estimate (MapKit ETA stand-in): ~25 km/h city avg.
    public func travelTime(from: Coordinate, to: Coordinate) -> TimeInterval {
        let km = from.distanceKm(to: to)
        let hours = km / 25.0
        return max(5 * 60, hours * 3600)   // floor 5 min
    }

    public func planPostEvent(event: Event,
                              home: Place,
                              currentLoc: Coordinate,
                              vendorETA: TimeInterval,
                              timing: DeliveryTiming,
                              suggestedItems: [CartItem],
                              vendor: Vendor,
                              now: Date) -> PostEventOrder? {
        guard timing != .skip else { return nil }

        let estEnd = event.endTime
        let travel = travelTime(from: currentLoc, to: home.coordinate)
        let arriveHome = max(now, estEnd).addingTimeInterval(travel)

        let placeAt: Date
        switch timing {
        case .now:
            placeAt = now
        case .onArrival:
            placeAt = arriveHome.addingTimeInterval(-vendorETA)   // ready as you walk in
        case .whenMinutesAway(let m):
            placeAt = arriveHome.addingTimeInterval(-Double(m) * 60)
        case .skip:
            return nil
        }

        let clampedPlaceAt = max(now, placeAt)
        return PostEventOrder(vendor: vendor,
                              items: suggestedItems,
                              timing: timing,
                              computedPlaceAt: clampedPlaceAt,
                              computedReadyBy: clampedPlaceAt.addingTimeInterval(vendorETA))
    }

    /// Vendor pick: fast hot meal → Bistro; full meal → Zomato; snacks / all-closed → Blinkit.
    public func pickVendor(now: Date, restaurantsOpen: Bool) -> Vendor {
        guard restaurantsOpen else { return .blinkit }   // late-night guard
        return .bistro
    }

    /// Are sit-down restaurants plausibly open at `date`? (Blinkit is 24/7.)
    public func restaurantsOpen(at date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 8 && hour < 23
    }
}
