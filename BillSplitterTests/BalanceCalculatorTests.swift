//
//  BalanceCalculatorTests.swift
//  BillSplitterTests
//
//  Unit tests for BalanceCalculator — the core balance computation engine.
//  To use: add a test target in Xcode (File → New → Target → Unit Testing Bundle),
//  then add the main app's source files to the test target or use @testable import.
//

import XCTest
import SwiftData
@testable import BillSplitter

final class BalanceCalculatorTests: XCTestCase {

    // MARK: - Helpers

    private var container: ModelContainer!
    private var context: ModelContext!

    private var me: User!
    private var alice: User!
    private var bob: User!

    override func setUp() {
        super.setUp()
        let schema = Schema([User.self, Group.self, Expense.self, ExpenseParticipant.self, Settlement.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        me    = User(name: "Me",    profileColor: "#00BCD4")
        alice = User(name: "Alice", profileColor: "#007AFF")
        bob   = User(name: "Bob",   profileColor: "#FF9500")
        [me, alice, bob].forEach { context.insert($0) }
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    /// Helper: create an expense with equal split among the given users, paid by payer.
    private func makeExpense(
        description: String = "Test",
        amount: Double,
        paidBy payer: User,
        splitAmong participants: [(User, Double)]
    ) -> Expense {
        let expense = Expense(expenseDescription: description, amount: amount)
        expense.paidBy = payer
        context.insert(expense)

        var parts: [ExpenseParticipant] = []
        for (user, owed) in participants {
            let p = ExpenseParticipant(friend: user, amountOwed: owed)
            context.insert(p)
            parts.append(p)
        }
        expense.participants = parts
        return expense
    }

    private func makeSettlement(from: User, to: User, amount: Double, confirmed: Bool = true) -> Settlement {
        let s = Settlement(fromFriend: from, toFriend: to, amount: amount, isConfirmed: confirmed)
        context.insert(s)
        return s
    }

    // MARK: - Tests: No Data

    func testEmptyDataReturnsEmptyBalances() {
        let balances = BalanceCalculator.netBalances(expenses: [], settlements: [], currentUserID: me.id)
        XCTAssertTrue(balances.isEmpty)
    }

    // MARK: - Tests: Single Expense

    func testIPaidEqualSplit() {
        // I pay $100, split equally with Alice ($50 each)
        _ = makeExpense(amount: 100, paidBy: me, splitAmong: [(me, 50), (alice, 50)])
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        // Alice owes me $50
        XCTAssertEqual(balances[alice.id], 50, accuracy: 0.01)
        // My own entry should not appear
        XCTAssertNil(balances[me.id])
    }

    func testFriendPaidEqualSplit() {
        // Alice pays $100, split equally ($50 each)
        _ = makeExpense(amount: 100, paidBy: alice, splitAmong: [(me, 50), (alice, 50)])
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        // I owe Alice $50 (negative)
        XCTAssertEqual(balances[alice.id], -50, accuracy: 0.01)
    }

    func testIPaidThreeWaySplit() {
        // I pay $300, split 3 ways ($100 each)
        _ = makeExpense(amount: 300, paidBy: me, splitAmong: [(me, 100), (alice, 100), (bob, 100)])
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        XCTAssertEqual(balances[alice.id], 100, accuracy: 0.01)
        XCTAssertEqual(balances[bob.id],   100, accuracy: 0.01)
    }

    // MARK: - Tests: Custom Split

    func testCustomSplitAmounts() {
        // I pay $100, Alice owes $70, I owe $30
        _ = makeExpense(amount: 100, paidBy: me, splitAmong: [(me, 30), (alice, 70)])
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        XCTAssertEqual(balances[alice.id], 70, accuracy: 0.01)
    }

    // MARK: - Tests: Multiple Expenses

    func testMultipleExpensesNetOut() {
        // I pay $60 split equally → Alice owes me $30
        _ = makeExpense(description: "Lunch", amount: 60, paidBy: me, splitAmong: [(me, 30), (alice, 30)])
        // Alice pays $40 split equally → I owe Alice $20
        _ = makeExpense(description: "Coffee", amount: 40, paidBy: alice, splitAmong: [(me, 20), (alice, 20)])
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        // Net: Alice owes me $30 - $20 = $10
        XCTAssertEqual(balances[alice.id], 10, accuracy: 0.01)
    }

    // MARK: - Tests: Settlements

    func testSettlementReducesDebt() {
        // Alice owes me $100
        _ = makeExpense(amount: 100, paidBy: me, splitAmong: [(alice, 100)])
        // Alice pays me $60
        _ = makeSettlement(from: alice, to: me, amount: 60)

        let expenses    = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: settlements, currentUserID: me.id)

        // Alice still owes me $40
        XCTAssertEqual(balances[alice.id], 40, accuracy: 0.01)
    }

    func testSettlementIPay() {
        // I owe Alice $80
        _ = makeExpense(amount: 80, paidBy: alice, splitAmong: [(me, 80)])
        // I pay Alice $50
        _ = makeSettlement(from: me, to: alice, amount: 50)

        let expenses    = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: settlements, currentUserID: me.id)

        // I still owe Alice $30
        XCTAssertEqual(balances[alice.id], -30, accuracy: 0.01)
    }

    func testUnconfirmedSettlementIgnored() {
        _ = makeExpense(amount: 100, paidBy: me, splitAmong: [(alice, 100)])
        _ = makeSettlement(from: alice, to: me, amount: 60, confirmed: false)

        let expenses    = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: settlements, currentUserID: me.id)

        // Unconfirmed settlement should not reduce debt
        XCTAssertEqual(balances[alice.id], 100, accuracy: 0.01)
    }

    func testFullSettlement() {
        _ = makeExpense(amount: 50, paidBy: me, splitAmong: [(alice, 50)])
        _ = makeSettlement(from: alice, to: me, amount: 50)

        let expenses    = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []

        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: settlements, currentUserID: me.id)

        // Fully settled — should be 0
        XCTAssertEqual(balances[alice.id] ?? 0, 0, accuracy: 0.01)
    }

    // MARK: - Tests: Edge Cases

    func testExpenseWithNoParticipantsIgnored() {
        let expense = Expense(expenseDescription: "Ghost", amount: 100)
        expense.paidBy = me
        expense.participants = []
        context.insert(expense)

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        XCTAssertTrue(balances.isEmpty)
    }

    func testExpenseWithNoPayer() {
        let expense = Expense(expenseDescription: "Orphan", amount: 100)
        expense.paidBy = nil
        let p = ExpenseParticipant(friend: alice, amountOwed: 100)
        context.insert(p)
        expense.participants = [p]
        context.insert(expense)

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        // No payer → should be skipped
        XCTAssertTrue(balances.isEmpty)
    }

    func testThirdPartySettlementIgnored() {
        // Settlement between Alice and Bob — should not affect my balances
        _ = makeSettlement(from: alice, to: bob, amount: 100)

        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []
        let balances = BalanceCalculator.netBalances(expenses: [], settlements: settlements, currentUserID: me.id)

        XCTAssertTrue(balances.isEmpty)
    }

    func testFriendPaidButImNotAParticipant() {
        // Alice pays $100, only Bob is a participant (I'm not involved)
        _ = makeExpense(amount: 100, paidBy: alice, splitAmong: [(bob, 100)])

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let balances = BalanceCalculator.netBalances(expenses: expenses, settlements: [], currentUserID: me.id)

        // I'm not a participant, so my balance should be unaffected
        XCTAssertNil(balances[alice.id])
    }

    // MARK: - Tests: Aggregation Helpers

    func testTotalOwedToYou() {
        let balances: [UUID: Double] = [
            UUID(): 50,    // someone owes me $50
            UUID(): -30,   // I owe someone $30
            UUID(): 20,    // someone owes me $20
            UUID(): 0.001, // negligible — should be ignored
        ]
        XCTAssertEqual(BalanceCalculator.totalOwedToYou(balances), 70, accuracy: 0.01)
    }

    func testTotalYouOwe() {
        let balances: [UUID: Double] = [
            UUID(): 50,
            UUID(): -30,
            UUID(): -20,
            UUID(): -0.001, // negligible
        ]
        XCTAssertEqual(BalanceCalculator.totalYouOwe(balances), 50, accuracy: 0.01)
    }

    func testZeroBalancesIgnored() {
        let balances: [UUID: Double] = [UUID(): 0, UUID(): 0.004, UUID(): -0.003]
        XCTAssertEqual(BalanceCalculator.totalOwedToYou(balances), 0, accuracy: 0.01)
        XCTAssertEqual(BalanceCalculator.totalYouOwe(balances), 0, accuracy: 0.01)
    }
}
