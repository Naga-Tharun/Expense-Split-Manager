//
//  CurrencyHelper.swift
//  BillSplitter
//
//  Reads the user's currency preference from @AppStorage / UserDefaults
//  and provides the correct symbol for display throughout the app.
//

import Foundation

enum CurrencyHelper {
    /// Supported currencies and their symbols.
    static let supported: [(code: String, symbol: String)] = [
        ("INR", "₹"), ("USD", "$"), ("EUR", "€"), ("GBP", "£")
    ]

    /// Returns the symbol for the stored currency code.
    /// On first launch, auto-detects from the device locale.
    /// Reads from shared App Group defaults so the widget can access it too.
    static var symbol: String {
        let code = SharedContainer.defaults.string(forKey: "currency")
            ?? UserDefaults.standard.string(forKey: "currency")
            ?? defaultCurrencyCode
        return Self.symbol(for: code)
    }

    /// Detects the best default currency from the user's locale,
    /// falling back to USD if the locale currency isn't supported.
    private static var defaultCurrencyCode: String {
        if let localeCode = Locale.current.currency?.identifier,
           supported.contains(where: { $0.code == localeCode }) {
            return localeCode
        }
        return "USD"
    }

    static func symbol(for code: String) -> String {
        supported.first { $0.code == code }?.symbol ?? "$"
    }

    /// Locale-aware number formatter (thousands grouping + 2 decimal places).
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// Formats a Double as a currency string: "₹1,234.56"
    static func formatted(_ value: Double) -> String {
        let sym = symbol
        let num = numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "\(sym)\(num)"
    }

    /// Formats with absolute value: always positive display
    static func formattedAbs(_ value: Double) -> String {
        formatted(abs(value))
    }
}
