//
//  CurrencyHelper.swift
//  BillSplitter
//
//  Reads the user's currency preference from @AppStorage / UserDefaults
//  and provides the correct symbol for display throughout the app.
//

import Foundation

enum CurrencyHelper {
    /// Returns the symbol for the stored currency code.
    /// Falls back to ₹ (INR) when the key is missing.
    static var symbol: String {
        let code = UserDefaults.standard.string(forKey: "currency") ?? "INR"
        return Self.symbol(for: code)
    }

    static func symbol(for code: String) -> String {
        switch code {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default:    return "₹"   // INR
        }
    }

    /// Formats a Double as a currency string: "₹1,234.56"
    static func formatted(_ value: Double) -> String {
        let sym = symbol
        return "\(sym)\(String(format: "%.2f", value))"
    }

    /// Formats with absolute value: always positive display
    static func formattedAbs(_ value: Double) -> String {
        formatted(abs(value))
    }
}
