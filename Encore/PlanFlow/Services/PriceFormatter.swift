//
//  PriceFormatter.swift
//  EveningPlanner
//

import Foundation

enum PriceFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func rupees(_ amount: Int) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
    }
}
