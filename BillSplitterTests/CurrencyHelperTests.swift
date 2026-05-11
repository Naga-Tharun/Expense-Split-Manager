//
//  CurrencyHelperTests.swift
//  BillSplitterTests
//
//  Tests for CurrencyHelper — symbol mapping and formatting.
//

import XCTest
@testable import BillSplitter

@MainActor
final class CurrencyHelperTests: XCTestCase {

    // ================================================================
    // MARK: - symbol(for:)
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

    func testSymbolForUnknownCodeDefaultsToDollar() {
        XCTAssertEqual(CurrencyHelper.symbol(for: "JPY"), "$")
    }

    func testSymbolForEmptyStringDefaultsToDollar() {
        XCTAssertEqual(CurrencyHelper.symbol(for: ""), "$")
    }

    // ================================================================
    // MARK: - supported currencies list
    // ================================================================

    func testSupportedContainsFourCurrencies() {
        XCTAssertEqual(CurrencyHelper.supported.count, 4)
    }

    func testSupportedCodesAreUnique() {
        let codes = CurrencyHelper.supported.map(\.code)
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    // ================================================================
    // MARK: - formatted()
    // ================================================================

    func testFormattedPositiveValue() {
        let result = CurrencyHelper.formatted(42.5)
        // Should contain the symbol and "42.50"
        XCTAssertTrue(result.contains("42.50") || result.contains("42,50"),
                       "Expected formatted value, got: \(result)")
    }

    func testFormattedZero() {
        let result = CurrencyHelper.formatted(0)
        XCTAssertTrue(result.contains("0.00") || result.contains("0,00"),
                       "Expected zero formatted, got: \(result)")
    }

    func testFormattedLargeNumber() {
        let result = CurrencyHelper.formatted(1234567.89)
        // Should contain grouping separator
        XCTAssertTrue(result.contains("1,234,567.89") || result.contains("1.234.567,89") || result.contains("12,34,567.89"),
                       "Expected grouped large number, got: \(result)")
    }

    // ================================================================
    // MARK: - formattedAbs()
    // ================================================================

    func testFormattedAbsNegativeBecomesPositive() {
        let result = CurrencyHelper.formattedAbs(-99.99)
        XCTAssertTrue(result.contains("99.99") || result.contains("99,99"),
                       "Expected absolute formatted, got: \(result)")
        XCTAssertFalse(result.contains("-"), "Should not contain minus sign")
    }

    func testFormattedAbsPositiveUnchanged() {
        let pos = CurrencyHelper.formatted(50)
        let absResult = CurrencyHelper.formattedAbs(50)
        XCTAssertEqual(pos, absResult)
    }
}
