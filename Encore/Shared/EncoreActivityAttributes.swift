//
//  EncoreActivityAttributes.swift
//  Encore (Flow A) — Live Activity contract (see claude.md §10.5)
//
//  DUAL-TARGET: add to BOTH the app (starts/updates the activity) and the
//  EncoreWidget target (renders it). Static attributes never change; ContentState
//  is what the app updates as the night progresses.
//

import Foundation
import ActivityKit

public struct EncoreActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var phase: Phase
        public var statusMessage: String
        public var countdownTarget: Date        // showtime, then show-end
        public var readyByText: String?         // set during the post-show phase
        public init(phase: Phase, statusMessage: String,
                    countdownTarget: Date, readyByText: String? = nil) {
            self.phase = phase; self.statusMessage = statusMessage
            self.countdownTarget = countdownTarget; self.readyByText = readyByText
        }

        public enum Phase: String, Codable, Hashable {
            case upcoming, getEssentials, liveNow, postShow

            public var label: String {
                switch self {
                case .upcoming:      return "Upcoming"
                case .getEssentials: return "Get essentials"
                case .liveNow:       return "Live now"
                case .postShow:      return "After the show"
                }
            }
            public var symbol: String {
                switch self {
                case .upcoming:      return "calendar"
                case .getEssentials: return "bag.fill"
                case .liveNow:       return "music.mic"
                case .postShow:      return "takeoutbag.and.cup.and.straw.fill"
                }
            }
        }
    }

    // Static for the life of the activity.
    public var eventID: String
    public var eventTitle: String
    public var venueName: String
    public init(eventID: String, eventTitle: String, venueName: String) {
        self.eventID = eventID; self.eventTitle = eventTitle; self.venueName = venueName
    }
}
