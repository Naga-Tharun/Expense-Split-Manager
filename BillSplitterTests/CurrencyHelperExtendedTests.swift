//
//  CurrencyHelperExtendedTests.swift
//  BillSplitterTests
//
//  Extended tests for CurrencyHelper — symbol lookup, formatting,
//  absolute value formatting, and supported currencies.
//

import XCTest
@testable import BillSplitter

final class CurrencyHelperExtendedTests: XCTestCase {

    // ================================================================
    // MARK: - Supported Currencies
    // ================================================================

    func testSupportedCurrenciesNotEmpty() {
        XCTAssertFalse(CurrencyHelper.supported.isEmpty)
    }

    func testSupportedCurrenciesContainINR() {
        XCTAssertTrue(CurrencyHelper.supported.contains(where: { $0.code == "INR" && $0.symbol == "₹" }))
    }

    func testSupportedCurrenciesContainUSD() {
        XCTAssertTrue(CurrencyHelper.supported.contains(where: { $0.code == "USD" && $0.symbol == "$" }))
    }

    func testSupportedCurrenciesContainEUR() {
        XCTAssertTrue(CurrencyHelper.supported.contains(where: { $0.code == "EUR" && $0.symbol == "€" }))
    }

    func testSupportedCurrenciesContainGBP() {
        XCTAssertTrue(CurrencyHelper.supported.contains(where: { $0.code == "GBP" && $0.symbol == "£" }))
    }

    func testSupportedCurrencyCount() {
        XCTAssertEqual(CurrencyHelper.supported.count, 4)
    }

    // ================================================================
    // MARK: - Symbol Lookup
    // ================================================================

    func testSymbolForINR() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "INR"), "₹")
    }

    func testSymbolForUSD() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "USD"), "$")
    }

    func testSymbolForEUR() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "EUR"), "€")
    }

    func testSymbolForGBP() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "GBP"), "£")
    }

    func testSymbolForUnknownCodeFallsToDollar() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "JPY"), "$")
        XCTAssertEqual(CurrencyHelper.symbol(for: "XYZ"), "$")
    }

    func testSymbolForEmptyStringFallsToDollar() {
        XCTAssertEqual(CurrencyHelper.symbol(for: ""), "$")
    }

    // ================================================================
    // MARK: - Symbol Property
    // ================================================================

    func testSymbolPropertyReturnsNonEmpty() {
        // Whatever the current locale/setting, symbol should not be empty
        XCTAssertFalse(CurrencyHelper.symbol.isEmpty)
    }

    // ================================================================
    // MARK: - Formatted
    // ================================================================

    func testFormattedIncludesSymbol() {
        let result = CurrencyHelper.formatted(100.0)
        let sym = CurrencyHelper.symbol
        XCTAssertTrue(result.hasPrefix(sym), "Formatted string should start with currency symbol")
    }

    func testFormattedHasTwoDecimalPlaces() {
        let result = CurrencyHelper.formatted(42.5)
        // Should end with .50
        XCTAssertTrue(result.hasSuffix("50"), "Should format to 2 decimal places: \(result)")
    }

    func testFormattedZero() {
        let result = CurrencyHelper.formatted(0)
        XCTAssertTrue(result.contains("0.00"), "Zero should format as 0.00: \(result)")
    }

    // ================================================================
    // MARK: - FormattedAbs
    // ================================================================

    func testFormattedAbsPositive() {
        let pos = CurrencyHelper.formattedAbs(250.0)
        let normal = CurrencyHelper.formatted(250.0)
        XCTAssertEqual(pos, normal, "Positive value should be same as formatted")
    }

    func testFormattedAbsNegative() {
        let neg = CurrencyHelper.formattedAbs(-250.0)
        let pos = CurrencyHelper.formatted(250.0)
        XCTAssertEqual(neg, pos, "Negative value should format as absolute")
    }

    func testFormattedAbsZero() {
        let result = CurrencyHelper.formattedAbs(0)
        XCTAssertTrue(result.contains("0.00"))
    }
}
