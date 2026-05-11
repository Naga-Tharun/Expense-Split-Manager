//
//  ExpenseFormLogicTests.swift
//  BillSplitterTests
//
//  Unit tests for ExpenseFormLogic — pure validation and calculation helpers.
//  No SwiftUI dependency; tests run entirely in-memory.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class ExpenseFormLogicTests: XCTestCase {

    // MARK: - SwiftData setup (for participant/user tests)

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    private func makeUser(_ name: String) -> User {
        let u = User(name: name, profileColor: "#007AFF")
        context.insert(u)
        return u
    }

    // ================================================================
    // MARK: - equalShare
    // ================================================================

    func testEqualShareTwoParticipants() {
        XCTAssertEqual(ExpenseFormLogic.equalShare(amount: 100, participantCount: 2), 50, accuracy: 0.001)
    }

    func testEqualShareThreeParticipants() {
        XCTAssertEqual(ExpenseFormLogic.equalShare(amount: 100, participantCount: 3), 33.333, accuracy: 0.01)
    }

    func testEqualShareOneParticipant() {
        XCTAssertEqual(ExpenseFormLogic.equalShare(amount: 50, participantCount: 1), 50, accuracy: 0.001)
    }

    func testEqualShareZeroParticipantsReturnsZero() {
        XCTAssertEqual(ExpenseFormLogic.equalShare(amount: 100, participantCount: 0), 0)
    }

    func testEqualShareZeroAmount() {
        XCTAssertEqual(ExpenseFormLogic.equalShare(amount: 0, participantCount: 3), 0)
    }

    // ================================================================
    // MARK: - customTotal
    // ================================================================

    func testCustomTotalValidAmounts() {
        let id1 = UUID(), id2 = UUID()
        let amounts: [UUID: String] = [id1: "30.50", id2: "69.50"]
        XCTAssertEqual(ExpenseFormLogic.customTotal(amounts), 100, accuracy: 0.01)
    }

    func testCustomTotalIgnoresInvalidStrings() {
        let id1 = UUID(), id2 = UUID()
        let amounts: [UUID: String] = [id1: "abc", id2: "50"]
        XCTAssertEqual(ExpenseFormLogic.customTotal(amounts), 50, accuracy: 0.01)
    }

    func testCustomTotalEmptyDict() {
        XCTAssertEqual(ExpenseFormLogic.customTotal([:]), 0)
    }

    func testCustomTotalEmptyStrings() {
        let amounts: [UUID: String] = [UUID(): "", UUID(): ""]
        XCTAssertEqual(ExpenseFormLogic.customTotal(amounts), 0)
    }

    // ================================================================
    // MARK: - percentageTotal
    // ================================================================

    func testPercentageTotalSumsCorrectly() {
        let pcts: [UUID: String] = [UUID(): "33.33", UUID(): "33.33", UUID(): "33.34"]
        XCTAssertEqual(ExpenseFormLogic.percentageTotal(pcts), 100, accuracy: 0.01)
    }

    func testPercentageTotalIgnoresNonNumeric() {
        let pcts: [UUID: String] = [UUID(): "50", UUID(): "nope"]
        XCTAssertEqual(ExpenseFormLogic.percentageTotal(pcts), 50, accuracy: 0.01)
    }

    func testPercentageTotalEmpty() {
        XCTAssertEqual(ExpenseFormLogic.percentageTotal([:]), 0)
    }

    // ================================================================
    // MARK: - amountError
    // ================================================================

    func testAmountErrorEmptyStringReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.amountError(""))
    }

    func testAmountErrorWhitespaceOnlyReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.amountError("   "))
    }

    func testAmountErrorValidNumberReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.amountError("42.50"))
    }

    func testAmountErrorNonNumericReturnsError() {
        XCTAssertEqual(ExpenseFormLogic.amountError("abc"), "Enter a valid number")
    }

    func testAmountErrorZeroReturnsError() {
        XCTAssertEqual(ExpenseFormLogic.amountError("0"), "Amount must be greater than zero")
    }

    func testAmountErrorNegativeReturnsError() {
        XCTAssertEqual(ExpenseFormLogic.amountError("-5"), "Amount must be greater than zero")
    }

    func testAmountErrorLargeValidNumber() {
        XCTAssertNil(ExpenseFormLogic.amountError("999999.99"))
    }

    // ================================================================
    // MARK: - descriptionError
    // ================================================================

    func testDescriptionErrorUntouchedReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.descriptionError("", fieldTouched: false))
    }

    func testDescriptionErrorTouchedAndEmptyReturnsError() {
        XCTAssertEqual(
            ExpenseFormLogic.descriptionError("", fieldTouched: true),
            "Description is required"
        )
    }

    func testDescriptionErrorTouchedWhitespaceOnlyReturnsError() {
        XCTAssertEqual(
            ExpenseFormLogic.descriptionError("   ", fieldTouched: true),
            "Description is required"
        )
    }

    func testDescriptionErrorTouchedWithTextReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.descriptionError("Lunch", fieldTouched: true))
    }

    // ================================================================
    // MARK: - participantError
    // ================================================================

    func testParticipantErrorFormNotStartedReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.participantError(count: 0, formStarted: false))
    }

    func testParticipantErrorFormStartedZeroReturnsError() {
        XCTAssertEqual(
            ExpenseFormLogic.participantError(count: 0, formStarted: true),
            "Select at least one friend to split with"
        )
    }

    func testParticipantErrorFormStartedOneReturnsError() {
        XCTAssertEqual(
            ExpenseFormLogic.participantError(count: 1, formStarted: true),
            "Select at least one friend to split with"
        )
    }

    func testParticipantErrorFormStartedTwoReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.participantError(count: 2, formStarted: true))
    }

    func testParticipantErrorFormStartedManyReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.participantError(count: 10, formStarted: true))
    }

    // ================================================================
    // MARK: - customSplitError
    // ================================================================

    func testCustomSplitErrorMatchesExactly() {
        XCTAssertNil(ExpenseFormLogic.customSplitError(customTotal: 100, expenseAmount: 100))
    }

    func testCustomSplitErrorWithinTolerance() {
        XCTAssertNil(ExpenseFormLogic.customSplitError(customTotal: 99.995, expenseAmount: 100))
    }

    func testCustomSplitErrorUnderTotal() {
        let error = ExpenseFormLogic.customSplitError(customTotal: 80, expenseAmount: 100)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("left to assign"), "Expected 'left to assign', got: \(error!)")
    }

    func testCustomSplitErrorOverTotal() {
        let error = ExpenseFormLogic.customSplitError(customTotal: 110, expenseAmount: 100)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("over the total"), "Expected 'over the total', got: \(error!)")
    }

    func testCustomSplitErrorZeroExpenseReturnsNil() {
        XCTAssertNil(ExpenseFormLogic.customSplitError(customTotal: 50, expenseAmount: 0))
    }

    // ================================================================
    // MARK: - percentageSplitError
    // ================================================================

    func testPercentageSplitErrorExact100() {
        XCTAssertNil(ExpenseFormLogic.percentageSplitError(percentageTotal: 100))
    }

    func testPercentageSplitErrorWithinTolerance() {
        XCTAssertNil(ExpenseFormLogic.percentageSplitError(percentageTotal: 99.995))
    }

    func testPercentageSplitErrorUnder100() {
        let error = ExpenseFormLogic.percentageSplitError(percentageTotal: 85)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("left to assign"), "Expected 'left to assign', got: \(error!)")
    }

    func testPercentageSplitErrorOver100() {
        let error = ExpenseFormLogic.percentageSplitError(percentageTotal: 110)
        XCTAssertNotNil(error)
        XCTAssertTrue(error!.contains("over 100%"), "Expected 'over 100%', got: \(error!)")
    }

    // ================================================================
    // MARK: - isValid
    // ================================================================

    func testIsValidAllConditionsMet() {
        XCTAssertTrue(ExpenseFormLogic.isValid(
            description: "Lunch",
            amount: 50,
            participantCount: 2,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidEmptyDescription() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "",
            amount: 50,
            participantCount: 2,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidWhitespaceDescription() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "   ",
            amount: 50,
            participantCount: 2,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidZeroAmount() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "Coffee",
            amount: 0,
            participantCount: 2,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidNegativeAmount() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "Coffee",
            amount: -10,
            participantCount: 2,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidOneParticipant() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "Coffee",
            amount: 50,
            participantCount: 1,
            splitType: .equal,
            customTotal: 0,
            percentageTotal: 0
        ))
    }

    func testIsValidCustomSplitMismatch() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "Dinner",
            amount: 100,
            participantCount: 2,
            splitType: .custom,
            customTotal: 80,
            percentageTotal: 0
        ))
    }

    func testIsValidCustomSplitMatches() {
        XCTAssertTrue(ExpenseFormLogic.isValid(
            description: "Dinner",
            amount: 100,
            participantCount: 2,
            splitType: .custom,
            customTotal: 100,
            percentageTotal: 0
        ))
    }

    func testIsValidPercentageSplitMismatch() {
        XCTAssertFalse(ExpenseFormLogic.isValid(
            description: "Rent",
            amount: 1000,
            participantCount: 3,
            splitType: .percentage,
            customTotal: 0,
            percentageTotal: 90
        ))
    }

    func testIsValidPercentageSplitMatches() {
        XCTAssertTrue(ExpenseFormLogic.isValid(
            description: "Rent",
            amount: 1000,
            participantCount: 3,
            splitType: .percentage,
            customTotal: 0,
            percentageTotal: 100
        ))
    }

    func testIsValidEqualSplitIgnoresCustomAndPercentageTotals() {
        // Custom/percentage totals are irrelevant when splitType == .equal
        XCTAssertTrue(ExpenseFormLogic.isValid(
            description: "Lunch",
            amount: 50,
            participantCount: 2,
            splitType: .equal,
            customTotal: 999,
            percentageTotal: 999
        ))
    }

    // ================================================================
    // MARK: - participantList
    // ================================================================

    func testParticipantListWithGroup() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        let group = Group(name: "Flatmates", iconName: "house.fill")
        group.members = [me, alice, bob]
        context.insert(group)

        let result = ExpenseFormLogic.participantList(
            selectedGroup: group,
            friends: [],
            selectedParticipantIDs: [],
            currentUser: me
        )
        XCTAssertEqual(result.count, 3)
    }

    func testParticipantListWithoutGroupManualSelection() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")

        let result = ExpenseFormLogic.participantList(
            selectedGroup: nil,
            friends: [alice, bob],
            selectedParticipantIDs: [alice.id],
            currentUser: me
        )
        // Me + Alice (Bob not selected)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Me")
        XCTAssertEqual(result[1].name, "Alice")
    }

    func testParticipantListNoCurrentUser() {
        let alice = makeUser("Alice")
        let result = ExpenseFormLogic.participantList(
            selectedGroup: nil,
            friends: [alice],
            selectedParticipantIDs: [alice.id],
            currentUser: nil
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Alice")
    }

    // ================================================================
    // MARK: - buildParticipants
    // ================================================================

    func testBuildParticipantsEqualSplit() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")

        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice],
            splitType: .equal,
            amount: 100,
            customAmounts: [:],
            percentages: [:]
        )
        participants.forEach { context.insert($0) }

        XCTAssertEqual(participants.count, 2)
        let total = participants.reduce(0) { $0 + $1.amountOwed }
        XCTAssertEqual(total, 100, accuracy: 0.01)
    }

    func testBuildParticipantsEqualSplitThreeWayRounding() {
        let users = (0..<3).map { makeUser("User\($0)") }

        let participants = ExpenseFormLogic.buildParticipants(
            from: users,
            splitType: .equal,
            amount: 100,
            customAmounts: [:],
            percentages: [:]
        )
        participants.forEach { context.insert($0) }

        XCTAssertEqual(participants.count, 3)
        // All shares should sum to exactly 100 (rounding absorbed by last participant)
        let total = participants.reduce(0) { $0 + $1.amountOwed }
        XCTAssertEqual(total, 100, accuracy: 0.001)
    }

    func testBuildParticipantsCustomSplit() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")

        let customAmounts: [UUID: String] = [me.id: "30", alice.id: "70"]
        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice],
            splitType: .custom,
            amount: 100,
            customAmounts: customAmounts,
            percentages: [:]
        )
        participants.forEach { context.insert($0) }

        XCTAssertEqual(participants.count, 2)
        XCTAssertEqual(participants[0].amountOwed, 30, accuracy: 0.01)
        XCTAssertEqual(participants[1].amountOwed, 70, accuracy: 0.01)
    }

    func testBuildParticipantsPercentageSplit() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")

        let pcts: [UUID: String] = [me.id: "40", alice.id: "60"]
        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice],
            splitType: .percentage,
            amount: 200,
            customAmounts: [:],
            percentages: pcts
        )
        participants.forEach { context.insert($0) }

        XCTAssertEqual(participants.count, 2)
        XCTAssertEqual(participants[0].amountOwed, 80, accuracy: 0.01)  // 40% of 200
        XCTAssertEqual(participants[1].amountOwed, 120, accuracy: 0.01) // 60% of 200
    }

    func testBuildParticipantsCustomMissingAmountDefaultsToZero() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")

        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice],
            splitType: .custom,
            amount: 100,
            customAmounts: [me.id: "100"],  // Alice has no entry
            percentages: [:]
        )
        participants.forEach { context.insert($0) }

        XCTAssertEqual(participants[1].amountOwed, 0, accuracy: 0.01)
    }

    func testBuildParticipantsEqualSplitSevenWayRounding() {
        // 100 / 7 = 14.2857… — tests the rounding remainder logic
        let users = (0..<7).map { makeUser("U\($0)") }

        let participants = ExpenseFormLogic.buildParticipants(
            from: users,
            splitType: .equal,
            amount: 100,
            customAmounts: [:],
            percentages: [:]
        )
        participants.forEach { context.insert($0) }

        let total = participants.reduce(0) { $0 + $1.amountOwed }
        XCTAssertEqual(total, 100, accuracy: 0.001, "Seven-way split must sum to exactly 100")
    }
}
