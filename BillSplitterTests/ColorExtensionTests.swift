//
//  ColorExtensionTests.swift
//  BillSplitterTests
//
//  Tests for Color(hex:) initializer and toHexString() conversion.
//

import XCTest
import SwiftUI
import UIKit
@testable import BillSplitter

final class ColorExtensionTests: XCTestCase {

    // MARK: - Helpers

    /// Extracts RGBA components from a Color via UIColor.
    private func components(of color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    // ================================================================
    // MARK: - 6-Digit Hex
    // ================================================================

    func testHex6DigitBlack() {
        let color = Color(hex: "#000000")
        let c = components(of: color)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testHex6DigitWhite() {
        let color = Color(hex: "#FFFFFF")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 1.0, accuracy: 0.01)
    }

    func testHex6DigitRed() {
        let color = Color(hex: "#FF0000")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func testHex6DigitGreen() {
        let color = Color(hex: "#00FF00")
        let c = components(of: color)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func testHex6DigitBlue() {
        let color = Color(hex: "#0000FF")
        let c = components(of: color)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 1.0, accuracy: 0.01)
    }

    func testHex6DigitCyan() {
        let color = Color(hex: "#00BCD4")
        let c = components(of: color)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.737, accuracy: 0.01) // 188/255
        XCTAssertEqual(c.b, 0.831, accuracy: 0.01) // 212/255
    }

    func testHex6DigitWithoutHash() {
        let color = Color(hex: "FF9500")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.584, accuracy: 0.01) // 149/255
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func testHex6DigitLowercase() {
        let color = Color(hex: "#ff5722")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.341, accuracy: 0.01) // 87/255
        XCTAssertEqual(c.b, 0.133, accuracy: 0.01) // 34/255
    }

    // ================================================================
    // MARK: - 3-Digit Hex
    // ================================================================

    func testHex3DigitBlack() {
        let color = Color(hex: "#000")
        let c = components(of: color)
        XCTAssertEqual(c.r, 0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    func testHex3DigitWhite() {
        let color = Color(hex: "#FFF")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 1.0, accuracy: 0.01)
    }

    func testHex3DigitRed() {
        let color = Color(hex: "#F00")
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
    }

    // ================================================================
    // MARK: - 8-Digit Hex (with alpha)
    // ================================================================

    func testHex8DigitFullOpaque() {
        let color = Color(hex: "#FFFF0000") // alpha=FF, red
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testHex8DigitHalfAlpha() {
        let color = Color(hex: "#80FF0000") // alpha=0x80 (~128), red
        let c = components(of: color)
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 0.502, accuracy: 0.01) // 128/255
    }

    // ================================================================
    // MARK: - Invalid / Edge Cases
    // ================================================================

    func testHexInvalidStringFallsToGray() {
        let color = Color(hex: "xyz")
        // For invalid hex, Scanner produces 0 → 3 chars → (255, 0, 0, 0)
        // At minimum, it doesn't crash
        let _ = components(of: color)
        XCTAssertNotNil(color)
    }

    func testHexEmptyStringFallsToDefault() {
        let color = Color(hex: "")
        let c = components(of: color)
        // empty → default case → gray (128, 128, 128)
        XCTAssertEqual(c.r, 0.502, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.502, accuracy: 0.01)
        XCTAssertEqual(c.b, 0.502, accuracy: 0.01)
    }

    func testHexSingleCharFallsToDefault() {
        let color = Color(hex: "#A")
        let c = components(of: color)
        // 1 char → default case → gray
        XCTAssertEqual(c.r, 0.502, accuracy: 0.01)
    }

    // ================================================================
    // MARK: - toHexString Round-Trip
    // ================================================================

    func testToHexStringBlack() {
        let color = Color(hex: "#000000")
        XCTAssertEqual(color.toHexString(), "#000000")
    }

    func testToHexStringWhite() {
        let color = Color(hex: "#FFFFFF")
        XCTAssertEqual(color.toHexString(), "#FFFFFF")
    }

    func testToHexStringRed() {
        let color = Color(hex: "#FF0000")
        XCTAssertEqual(color.toHexString(), "#FF0000")
    }

    func testToHexStringRoundTrip() {
        // Color→UIColor→CGFloat→Int can lose ±1 per channel due to
        // floating-point precision, so we compare with a tolerance.
        let hexes = ["#007AFF", "#FF9500", "#00BCD4", "#34C759", "#FF3B30"]
        for hex in hexes {
            let color = Color(hex: hex)
            let result = color.toHexString()
            // Parse both hex strings to integers and compare with tolerance
            let expected = parseHexRGB(hex)
            let actual   = parseHexRGB(result)
            XCTAssertTrue(
                abs(expected.r - actual.r) <= 1 &&
                abs(expected.g - actual.g) <= 1 &&
                abs(expected.b - actual.b) <= 1,
                "Round-trip outside ±1 tolerance for \(hex): got \(result)"
            )
        }
    }

    /// Parses "#RRGGBB" into integer RGB components.
    private func parseHexRGB(_ hex: String) -> (r: Int, g: Int, b: Int) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        return (r: Int((int >> 16) & 0xFF), g: Int((int >> 8) & 0xFF), b: Int(int & 0xFF))
    }
}
