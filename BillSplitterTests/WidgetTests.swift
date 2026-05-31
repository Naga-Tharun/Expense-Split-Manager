//
//  WidgetTests.swift
//  BillSplitterTests
//
//  Tests for widget timeline entry construction and balance formatting.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class WidgetTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var me: User!
    private var alice: User!
    private var bob: User!

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

        for store in Self.allStores {
            store.set(me.id.uuidString, forKey: CurrentUserManager.idKey)
        }
    }

    override func tearDown() {
        for store in Self.allStores {
            store.removeObject(forKey: CurrentUserManager.idKey)
        }
        container = nil
        context = nil
        me = nil; alice = nil; bob = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeExpense(_ desc: String, amount: Double, paidBy: User, participants: [(User, Double)]) {
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
    }

    // MARK: - Balance Data for Widget

    func testWidgetBalanceDataMatchesCalculator() {
        // Me paid 1000, split with Alice
        makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        try! context.save()

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: me.id
        )
        let owedToMe = BalanceCalculator.totalOwedToYou(balances)
        let iOwe = BalanceCalculator.totalYouOwe(balances)

        XCTAssertEqual(owedToMe, 500, accuracy: 0.01)
        XCTAssertEqual(iOwe, 0, accuracy: 0.01)
        XCTAssertEqual(owedToMe - iOwe, 500, accuracy: 0.01, "Net balance should be 500")
    }

    func testWidgetBalanceWithMultipleFriends() {
        // Me paid 900 split 3 ways
        makeExpense("Trip", amount: 900, paidBy: me, participants: [(me, 300), (alice, 300), (bob, 300)])
        // Bob paid 600 split with me
        makeExpense("Lunch", amount: 600, paidBy: bob, participants: [(bob, 300), (me, 300)])
        try! context.save()

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        // Alice owes 300, Bob owes 300 but I owe Bob 300 → Bob net 0
        XCTAssertEqual(balances[alice.id] ?? 0, 300, accuracy: 0.01)
        XCTAssertEqual(balances[bob.id] ?? 0, 0, accuracy: 0.01)
    }

    func testWidgetTopBalancesSortedByAbsoluteValue() {
        // Create varied balances
        makeExpense("Big", amount: 2000, paidBy: me, participants: [(me, 1000), (alice, 1000)])
        makeExpense("Small", amount: 200, paidBy: bob, participants: [(bob, 100), (me, 100)])
        try! context.save()

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        let sorted = balances
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(4)

        // Alice (1000) should come before Bob (-100)
        let sortedKeys = sorted.map { $0.key }
        XCTAssertEqual(sortedKeys.first, alice.id)
    }

    func testWidgetEmptyState() {
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        XCTAssertTrue(balances.isEmpty)
        XCTAssertEqual(BalanceCalculator.totalOwedToYou(balances), 0)
        XCTAssertEqual(BalanceCalculator.totalYouOwe(balances), 0)
    }

    func testCurrencySymbolFromSharedDefaults() {
        SharedContainer.defaults.set("INR", forKey: "currency")
        let symbol = CurrencyHelper.symbol(for: "INR")
        XCTAssertEqual(symbol, "₹")
        SharedContainer.defaults.removeObject(forKey: "currency")
    }
}
