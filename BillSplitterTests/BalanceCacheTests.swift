//
//  BalanceCacheTests.swift
//  BillSplitterTests
//
//  Tests for BalanceCache — @Observable state, refresh logic, and sorting.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class BalanceCacheTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var cache: BalanceCache!

    private var me: User!
    private var alice: User!
    private var bob: User!

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
        cache = BalanceCache()

        me    = User(name: "Me",    profileColor: "#00BCD4")
        alice = User(name: "Alice", profileColor: "#007AFF")
        bob   = User(name: "Bob",   profileColor: "#FF9500")
        [me, alice, bob].forEach { context.insert($0) }
    }

    override func tearDown() {
        cache = nil
        container = nil
        context = nil
        super.tearDown()
    }

    private func makeExpense(amount: Double, paidBy payer: User, participants: [(User, Double)]) {
        let e = Expense(expenseDescription: "Test", amount: amount)
        e.paidBy = payer
        context.insert(e)
        var parts: [ExpenseParticipant] = []
        for (user, owed) in participants {
            let p = ExpenseParticipant(friend: user, amountOwed: owed)
            context.insert(p)
            parts.append(p)
        }
        e.participants = parts
    }

    private func fetchExpenses() -> [Expense] {
        (try? context.fetch(FetchDescriptor<Expense>())) ?? []
    }

    private func fetchSettlements() -> [Settlement] {
        (try? context.fetch(FetchDescriptor<Settlement>())) ?? []
    }

    // ================================================================
    // MARK: - Initial State
    // ================================================================

    func testInitialStateNotLoaded() {
        XCTAssertFalse(cache.isLoaded)
        XCTAssertNil(cache.lastRefreshed)
        XCTAssertEqual(cache.netBalance, 0)
        XCTAssertEqual(cache.totalOwedToYou, 0)
        XCTAssertEqual(cache.totalYouOwe, 0)
        XCTAssertTrue(cache.balances.isEmpty)
    }

    // ================================================================
    // MARK: - refresh()
    // ================================================================

    func testRefreshSetsIsLoaded() {
        cache.refresh(expenses: [], settlements: [], currentUserID: me.id)
        XCTAssertTrue(cache.isLoaded)
        XCTAssertNotNil(cache.lastRefreshed)
    }

    func testRefreshCalculatesBalances() {
        // Me pays $100, split equally with Alice
        makeExpense(amount: 100, paidBy: me, participants: [(me, 50), (alice, 50)])

        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)

        XCTAssertEqual(cache.balance(for: alice.id), 50, accuracy: 0.01)
        XCTAssertEqual(cache.totalOwedToYou, 50, accuracy: 0.01)
        XCTAssertEqual(cache.totalYouOwe, 0, accuracy: 0.01)
        XCTAssertEqual(cache.netBalance, 50, accuracy: 0.01)
    }

    func testRefreshUpdatesOnSecondCall() {
        makeExpense(amount: 100, paidBy: me, participants: [(me, 50), (alice, 50)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)
        let firstRefresh = cache.lastRefreshed

        // Add another expense
        makeExpense(amount: 60, paidBy: alice, participants: [(me, 30), (alice, 30)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)

        // Alice owes me 50, I owe Alice 30 → net 20
        XCTAssertEqual(cache.balance(for: alice.id), 20, accuracy: 0.01)
        XCTAssertTrue(cache.lastRefreshed! >= firstRefresh!)
    }

    // ================================================================
    // MARK: - balance(for:)
    // ================================================================

    func testBalanceForUnknownFriendReturnsZero() {
        cache.refresh(expenses: [], settlements: [], currentUserID: me.id)
        XCTAssertEqual(cache.balance(for: UUID()), 0)
    }

    // ================================================================
    // MARK: - netBalance
    // ================================================================

    func testNetBalanceOwedOverall() {
        // Alice owes me $100
        makeExpense(amount: 100, paidBy: me, participants: [(alice, 100)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)
        XCTAssertEqual(cache.netBalance, 100, accuracy: 0.01)
    }

    func testNetBalanceIOweOverall() {
        // I owe Alice $80
        makeExpense(amount: 80, paidBy: alice, participants: [(me, 80)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)
        XCTAssertEqual(cache.netBalance, -80, accuracy: 0.01)
    }

    // ================================================================
    // MARK: - sortedFriends
    // ================================================================

    func testSortedFriendsExcludesCurrentUser() {
        makeExpense(amount: 100, paidBy: me, participants: [(alice, 50), (bob, 50)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)

        let sorted = cache.sortedFriends(from: [me, alice, bob], currentUserID: me.id)
        XCTAssertFalse(sorted.contains(where: { $0.id == me.id }))
        XCTAssertEqual(sorted.count, 2)
    }

    func testSortedFriendsOrderByAbsoluteBalance() {
        // Alice owes me $100, Bob owes me $50
        makeExpense(amount: 100, paidBy: me, participants: [(alice, 100)])
        makeExpense(amount: 50, paidBy: me, participants: [(bob, 50)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)

        let sorted = cache.sortedFriends(from: [me, alice, bob], currentUserID: me.id)
        XCTAssertEqual(sorted.first?.name, "Alice") // higher balance first
        XCTAssertEqual(sorted.last?.name, "Bob")
    }

    func testSortedFriendsNegativeBalanceSortedByAbsValue() {
        // I owe Alice $200, Bob owes me $50
        makeExpense(amount: 200, paidBy: alice, participants: [(me, 200)])
        makeExpense(amount: 50, paidBy: me, participants: [(bob, 50)])
        cache.refresh(expenses: fetchExpenses(), settlements: fetchSettlements(), currentUserID: me.id)

        let sorted = cache.sortedFriends(from: [me, alice, bob], currentUserID: me.id)
        // Alice has |−200| = 200, Bob has |50| = 50 → Alice first
        XCTAssertEqual(sorted.first?.name, "Alice")
    }
}
