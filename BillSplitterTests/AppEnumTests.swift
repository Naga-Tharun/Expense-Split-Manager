//
//  AppEnumTests.swift
//  BillSplitterTests
//
//  Tests for SplitType, ExpenseCategory, and PaymentMethod enums —
//  labels, icons, raw values, CaseIterable, and Identifiable.
//

import XCTest
@testable import BillSplitter

final class AppEnumTests: XCTestCase {

    // ================================================================
    // MARK: - SplitType
    // ================================================================

    func testSplitTypeRawValues() {
        XCTAssertEqual(SplitType.equal.rawValue, "equal")
        XCTAssertEqual(SplitType.custom.rawValue, "custom")
        XCTAssertEqual(SplitType.percentage.rawValue, "percentage")
    }

    func testSplitTypeCaseCount() {
        XCTAssertEqual(SplitType.allCases.count, 3)
    }

    func testSplitTypeIdentifiable() {
        for splitType in SplitType.allCases {
            XCTAssertEqual(splitType.id, splitType.rawValue)
        }
    }

    func testSplitTypeLabelsNotEmpty() {
        for splitType in SplitType.allCases {
            XCTAssertFalse(splitType.label.isEmpty, "\(splitType) has empty label")
        }
    }

    func testSplitTypeEqualLabel() {
        XCTAssertEqual(SplitType.equal.label, "Equal")
    }

    func testSplitTypePercentageLabel() {
        XCTAssertEqual(SplitType.percentage.label, "By %")
    }

    func testSplitTypeCustomLabelContainsCurrency() {
        let label = SplitType.custom.label
        // The label includes the currency symbol
        XCTAssertTrue(label.hasPrefix("Custom "), "Custom label should start with 'Custom '")
    }

    func testSplitTypeInitFromRawValue() {
        XCTAssertEqual(SplitType(rawValue: "equal"), .equal)
        XCTAssertEqual(SplitType(rawValue: "custom"), .custom)
        XCTAssertEqual(SplitType(rawValue: "percentage"), .percentage)
        XCTAssertNil(SplitType(rawValue: "invalid"))
    }

    // ================================================================
    // MARK: - ExpenseCategory
    // ================================================================

    func testExpenseCategoryCaseCount() {
        XCTAssertEqual(ExpenseCategory.allCases.count, 8)
    }

    func testExpenseCategoryRawValues() {
        XCTAssertEqual(ExpenseCategory.general.rawValue, "general")
        XCTAssertEqual(ExpenseCategory.food.rawValue, "food")
        XCTAssertEqual(ExpenseCategory.transport.rawValue, "transport")
        XCTAssertEqual(ExpenseCategory.accommodation.rawValue, "accommodation")
        XCTAssertEqual(ExpenseCategory.entertainment.rawValue, "entertainment")
        XCTAssertEqual(ExpenseCategory.shopping.rawValue, "shopping")
        XCTAssertEqual(ExpenseCategory.utilities.rawValue, "utilities")
        XCTAssertEqual(ExpenseCategory.travel.rawValue, "travel")
    }

    func testExpenseCategoryIdentifiable() {
        for cat in ExpenseCategory.allCases {
            XCTAssertEqual(cat.id, cat.rawValue)
        }
    }

    func testExpenseCategoryLabelsNotEmpty() {
        for cat in ExpenseCategory.allCases {
            XCTAssertFalse(cat.label.isEmpty, "\(cat) has empty label")
        }
    }

    func testExpenseCategoryLabels() {
        XCTAssertEqual(ExpenseCategory.general.label, "General")
        XCTAssertEqual(ExpenseCategory.food.label, "Food")
        XCTAssertEqual(ExpenseCategory.transport.label, "Transport")
        XCTAssertEqual(ExpenseCategory.accommodation.label, "Stay")
        XCTAssertEqual(ExpenseCategory.entertainment.label, "Fun")
        XCTAssertEqual(ExpenseCategory.shopping.label, "Shopping")
        XCTAssertEqual(ExpenseCategory.utilities.label, "Utilities")
        XCTAssertEqual(ExpenseCategory.travel.label, "Travel")
    }

    func testExpenseCategoryIconsNotEmpty() {
        for cat in ExpenseCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty, "\(cat) has empty icon")
        }
    }

    func testExpenseCategoryIcons() {
        XCTAssertEqual(ExpenseCategory.general.icon, "square.grid.2x2.fill")
        XCTAssertEqual(ExpenseCategory.food.icon, "fork.knife")
        XCTAssertEqual(ExpenseCategory.transport.icon, "car.fill")
        XCTAssertEqual(ExpenseCategory.accommodation.icon, "house.fill")
        XCTAssertEqual(ExpenseCategory.entertainment.icon, "theatermasks.fill")
        XCTAssertEqual(ExpenseCategory.shopping.icon, "cart.fill")
        XCTAssertEqual(ExpenseCategory.utilities.icon, "bolt.fill")
        XCTAssertEqual(ExpenseCategory.travel.icon, "airplane")
    }

    func testExpenseCategoryInitFromRawValue() {
        for cat in ExpenseCategory.allCases {
            XCTAssertEqual(ExpenseCategory(rawValue: cat.rawValue), cat)
        }
        XCTAssertNil(ExpenseCategory(rawValue: "nonexistent"))
    }

    // ================================================================
    // MARK: - PaymentMethod
    // ================================================================

    func testPaymentMethodCaseCount() {
        XCTAssertEqual(PaymentMethod.allCases.count, 5)
    }

    func testPaymentMethodRawValues() {
        XCTAssertEqual(PaymentMethod.cash.rawValue, "cash")
        XCTAssertEqual(PaymentMethod.upi.rawValue, "upi")
        XCTAssertEqual(PaymentMethod.bankTransfer.rawValue, "bank transfer")
        XCTAssertEqual(PaymentMethod.card.rawValue, "card")
        XCTAssertEqual(PaymentMethod.other.rawValue, "other")
    }

    func testPaymentMethodIdentifiable() {
        for method in PaymentMethod.allCases {
            XCTAssertEqual(method.id, method.rawValue)
        }
    }

    func testPaymentMethodLabelsNotEmpty() {
        for method in PaymentMethod.allCases {
            XCTAssertFalse(method.label.isEmpty, "\(method) has empty label")
        }
    }

    func testPaymentMethodLabels() {
        XCTAssertEqual(PaymentMethod.cash.label, "Cash")
        XCTAssertEqual(PaymentMethod.upi.label, "UPI")
        XCTAssertEqual(PaymentMethod.bankTransfer.label, "Bank Transfer")
        XCTAssertEqual(PaymentMethod.card.label, "Card")
        XCTAssertEqual(PaymentMethod.other.label, "Other")
    }

    func testPaymentMethodIconsNotEmpty() {
        for method in PaymentMethod.allCases {
            XCTAssertFalse(method.icon.isEmpty, "\(method) has empty icon")
        }
    }

    func testPaymentMethodIcons() {
        XCTAssertEqual(PaymentMethod.cash.icon, "banknote.fill")
        XCTAssertEqual(PaymentMethod.upi.icon, "iphone.radiowaves.left.and.right")
        XCTAssertEqual(PaymentMethod.bankTransfer.icon, "building.columns.fill")
        XCTAssertEqual(PaymentMethod.card.icon, "creditcard.fill")
        XCTAssertEqual(PaymentMethod.other.icon, "ellipsis.circle.fill")
    }

    func testPaymentMethodInitFromRawValue() {
        for method in PaymentMethod.allCases {
            XCTAssertEqual(PaymentMethod(rawValue: method.rawValue), method)
        }
        XCTAssertNil(PaymentMethod(rawValue: "crypto"))
    }
}
