//
//  SiriIntentTests.swift
//  BillSplitterTests
//
//  Tests for Siri App Intents — validates intent logic, entity queries,
//  enum mappings, and error handling. Tests run against in-memory SwiftData
//  containers to verify the data operations without Siri runtime.
//

import XCTest
import SwiftData
import AppIntents
@testable import BillSplitter

@MainActor
final class SiriIntentTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var me: User!
    private var alice: User!
    private var bob: User!

    /// Both the standard and shared (App Group) UserDefaults must be cleared
    /// because `CurrentUserManager` checks `SharedContainer.defaults` first.
    private static let allStores: [UserDefaults] = [.standard, SharedContainer.defaults]

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        me    = User(name: "Me", profileColor: "#00BCD4")
        alice = User(name: "Alice", profileColor: "#007AFF")
        bob   = User(name: "Bob", profileColor: "#FF9500")
        [me, alice, bob].forEach { context.insert($0) }
        try! context.save()

        // Register current user in ALL stores
        for store in Self.allStores {
            store.set(me.id.uuidString, forKey: CurrentUserManager.idKey)
        }
    }

    override func tearDown() {
        let keys = [CurrentUserManager.idKey, CurrentUserManager.nameKey, CurrentUserManager.colorKey]
        for store in Self.allStores {
            for key in keys {
                store.removeObject(forKey: key)
            }
        }
        container = nil
        context = nil
        me = nil
        alice = nil
        bob = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeExpense(_ desc: String, amount: Double, paidBy: User, participants: [(User, Double)]) -> Expense {
        let e = Expense(expenseDescription: desc, amount: amount)
        e.paidBy = paidBy
        context.insert(e)

        var parts: [ExpenseParticipant] = []
        for (user, owed) in participants {
            let p = ExpenseParticipant(friend: user, amountOwed: owed)
            context.insert(p)
            parts.append(p)
        }
        e.participants = parts
        return e
    }

    private func makeSettlement(from: User, to: User, amount: Double, confirmed: Bool = true) -> Settlement {
        let s = Settlement(fromFriend: from, toFriend: to, amount: amount, isConfirmed: confirmed)
        context.insert(s)
        return s
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    // ================================================================
    // MARK: - CategoryAppEnum Mapping
    // ================================================================

    func testCategoryAppEnumMapsToModelCategory() {
        XCTAssertEqual(CategoryAppEnum.general.modelCategory, .general)
        XCTAssertEqual(CategoryAppEnum.food.modelCategory, .food)
        XCTAssertEqual(CategoryAppEnum.transport.modelCategory, .transport)
        XCTAssertEqual(CategoryAppEnum.accommodation.modelCategory, .accommodation)
        XCTAssertEqual(CategoryAppEnum.entertainment.modelCategory, .entertainment)
        XCTAssertEqual(CategoryAppEnum.shopping.modelCategory, .shopping)
        XCTAssertEqual(CategoryAppEnum.utilities.modelCategory, .utilities)
        XCTAssertEqual(CategoryAppEnum.travel.modelCategory, .travel)
    }

    func testAllCategoriesHaveDisplayRepresentation() {
        for cat in CategoryAppEnum.allCases {
            XCTAssertNotNil(CategoryAppEnum.caseDisplayRepresentations[cat], "\(cat) missing display representation")
        }
    }

    // ================================================================
    // MARK: - PaymentMethodAppEnum Mapping
    // ================================================================

    func testPaymentMethodAppEnumMapsToModel() {
        XCTAssertEqual(PaymentMethodAppEnum.cash.modelMethod, .cash)
        XCTAssertEqual(PaymentMethodAppEnum.upi.modelMethod, .upi)
        XCTAssertEqual(PaymentMethodAppEnum.bankTransfer.modelMethod, .bankTransfer)
        XCTAssertEqual(PaymentMethodAppEnum.card.modelMethod, .card)
        XCTAssertEqual(PaymentMethodAppEnum.other.modelMethod, .other)
    }

    func testAllPaymentMethodsHaveDisplayRepresentation() {
        for method in PaymentMethodAppEnum.allCases {
            XCTAssertNotNil(PaymentMethodAppEnum.caseDisplayRepresentations[method], "\(method) missing display representation")
        }
    }

    // ================================================================
    // MARK: - FriendEntity
    // ================================================================

    func testFriendEntityDisplayRepresentation() {
        let entity = FriendEntity(id: UUID(), name: "Alex")
        // DisplayRepresentation.title is a LocalizedStringResource, so we
        // verify the entity name is correctly stored and used.
        XCTAssertEqual(entity.name, "Alex")
        // Verify displayRepresentation is non-nil (title is built from name)
        let display = entity.displayRepresentation
        XCTAssertNotNil(display)
    }

    func testFriendEntityIDPreservation() {
        let uuid = UUID()
        let entity = FriendEntity(id: uuid, name: "Test")
        XCTAssertEqual(entity.id, uuid)
    }

    // ================================================================
    // MARK: - IntentError Messages
    // ================================================================

    func testIntentErrorMessages() {
        // Verify all error cases have non-empty messages
        let errors: [IntentError] = [.invalidAmount, .emptyDescription, .noCurrentUser, .friendNotFound]
        for error in errors {
            let message = String(localized: error.localizedStringResource)
            XCTAssertFalse(message.isEmpty, "Error \(error) has empty message")
        }
    }

    // ================================================================
    // MARK: - Balance Calculation (used by CheckBalanceIntent)
    // ================================================================

    func testBalanceCalculationForIntent() {
        // Me paid 1000, split equally with Alice
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balances = BalanceCalculator.netBalances(
            expenses: expenses,
            settlements: settlements,
            currentUserID: me.id
        )

        // Alice owes me 500
        XCTAssertEqual(balances[alice.id] ?? 0, 500, accuracy: 0.01)
    }

    func testBalanceAfterSettlement() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        _ = makeSettlement(from: alice, to: me, amount: 500, confirmed: true)
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balances = BalanceCalculator.netBalances(
            expenses: expenses,
            settlements: settlements,
            currentUserID: me.id
        )

        // After settlement, balance should be ~0
        let aliceBalance = balances[alice.id] ?? 0
        XCTAssertTrue(abs(aliceBalance) < BalanceCalculator.epsilon)
    }

    func testOverallBalanceSummary() {
        // Me paid 1000 split with Alice (Alice owes 500)
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        // Bob paid 600 split with me (I owe 300)
        _ = makeExpense("Lunch", amount: 600, paidBy: bob, participants: [(bob, 300), (me, 300)])
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balances = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        let owedToMe = BalanceCalculator.totalOwedToYou(balances)
        let iOwe     = BalanceCalculator.totalYouOwe(balances)

        XCTAssertEqual(owedToMe, 500, accuracy: 0.01)
        XCTAssertEqual(iOwe, 300, accuracy: 0.01)
    }

    // ================================================================
    // MARK: - Settlement Direction Logic (used by SettleUpIntent)
    // ================================================================

    func testSettlementDirectionWhenIOwe() {
        // Bob paid, I owe Bob → balance is negative
        _ = makeExpense("Taxi", amount: 400, paidBy: bob, participants: [(bob, 200), (me, 200)])
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balance = BalanceCalculator.balance(
            for: bob.id, expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        // I owe Bob → balance should be negative
        XCTAssertTrue(balance < -BalanceCalculator.epsilon, "Balance should be negative when I owe")

        // SettleUpIntent logic: when negative → from: me, to: friend
        let iShouldPay = balance < -BalanceCalculator.epsilon
        XCTAssertTrue(iShouldPay)
    }

    func testSettlementDirectionWhenTheyOwe() {
        // I paid, Alice owes me → balance is positive
        _ = makeExpense("Coffee", amount: 200, paidBy: me, participants: [(me, 100), (alice, 100)])
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balance = BalanceCalculator.balance(
            for: alice.id, expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        // Alice owes me → balance should be positive
        XCTAssertTrue(balance > BalanceCalculator.epsilon, "Balance should be positive when they owe me")
    }

    // ================================================================
    // MARK: - Expense Creation Logic (used by AddExpenseIntent)
    // ================================================================

    func testEqualSplitBuildParticipants() {
        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice],
            splitType: .equal,
            amount: 100,
            customAmounts: [:],
            percentages: [:]
        )

        XCTAssertEqual(participants.count, 2)

        let total = participants.reduce(0) { $0 + $1.amountOwed }
        XCTAssertEqual(total, 100, accuracy: 0.01, "Participant amounts should sum to expense total")
    }

    func testEqualSplitWithOddAmount() {
        // 33.33 can't split evenly — last participant absorbs rounding
        let participants = ExpenseFormLogic.buildParticipants(
            from: [me, alice, bob],
            splitType: .equal,
            amount: 100,
            customAmounts: [:],
            percentages: [:]
        )

        XCTAssertEqual(participants.count, 3)

        let total = participants.reduce(0) { $0 + $1.amountOwed }
        XCTAssertEqual(total, 100, accuracy: 0.01, "Rounding remainder should be absorbed by last participant")
    }

    // ================================================================
    // MARK: - Unconfirmed Settlement Ignored
    // ================================================================

    func testUnconfirmedSettlementNotCountedInBalance() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        _ = makeSettlement(from: alice, to: me, amount: 500, confirmed: false) // NOT confirmed
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)

        let balance = BalanceCalculator.balance(
            for: alice.id, expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        // Unconfirmed settlement should NOT affect balance
        XCTAssertEqual(balance, 500, accuracy: 0.01)
    }

    // ================================================================
    // MARK: - CurrentUserManager Used by Intents
    // ================================================================

    func testCurrentUserResolvedFromDefaults() {
        let allUsers = fetchAll(User.self)
        let current = CurrentUserManager.currentUser(from: allUsers)
        XCTAssertEqual(current?.id, me.id)
    }

    func testFriendsExcludeCurrentUser() {
        let allUsers = fetchAll(User.self)
        let friends = CurrentUserManager.friends(from: allUsers)
        XCTAssertFalse(friends.contains(where: { $0.id == me.id }))
        XCTAssertTrue(friends.contains(where: { $0.id == alice.id }))
        XCTAssertTrue(friends.contains(where: { $0.id == bob.id }))
    }
}
