//
//  DataServiceExtendedTests.swift
//  BillSplitterTests
//
//  Extended tests for DataService — friend deletion with orphan cleanup,
//  expense deletion, settlement deletion, group deletion, clear all data,
//  and add friend.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class DataServiceExtendedTests: XCTestCase {

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

    // MARK: - Helpers

    private func makeUser(_ name: String) -> User {
        let u = User(name: name, profileColor: "#007AFF")
        context.insert(u)
        return u
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    // ================================================================
    // MARK: - Add Friend
    // ================================================================

    func testAddFriendCreatesUser() throws {
        try DataService.addFriend(name: "Alice", profileColor: "#FF0000", context: context)
        let users = fetchAll(User.self)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Alice")
        XCTAssertEqual(users.first?.profileColor, "#FF0000")
    }

    func testAddMultipleFriends() throws {
        try DataService.addFriend(name: "Alice", profileColor: "#FF0000", context: context)
        try DataService.addFriend(name: "Bob", profileColor: "#00FF00", context: context)
        let users = fetchAll(User.self)
        XCTAssertEqual(users.count, 2)
    }

    // ================================================================
    // MARK: - Delete Friend
    // ================================================================

    func testDeleteFriendRemovesUser() throws {
        let friend = makeUser("Alice")
        try context.save()

        let allParticipants = fetchAll(ExpenseParticipant.self)
        let allSettlements = fetchAll(Settlement.self)

        try DataService.deleteFriend(friend, allParticipants: allParticipants,
                                     allSettlements: allSettlements, context: context)

        XCTAssertTrue(fetchAll(User.self).isEmpty)
    }

    func testDeleteFriendCleansUpParticipants() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")

        let expense = Expense(expenseDescription: "Dinner", amount: 100)
        context.insert(expense)
        expense.paidBy = me

        let p1 = ExpenseParticipant(friend: me, amountOwed: 50)
        let p2 = ExpenseParticipant(friend: alice, amountOwed: 50)
        context.insert(p1)
        context.insert(p2)
        expense.participants = [p1, p2]
        try context.save()

        let allParticipants = fetchAll(ExpenseParticipant.self)
        let allSettlements = fetchAll(Settlement.self)

        try DataService.deleteFriend(alice, allParticipants: allParticipants,
                                     allSettlements: allSettlements, context: context)

        // Alice's participant should be removed
        let remainingParticipants = fetchAll(ExpenseParticipant.self)
        XCTAssertEqual(remainingParticipants.count, 1)
        XCTAssertEqual(remainingParticipants.first?.friend?.name, "Me")
    }

    func testDeleteFriendCleansUpSettlements() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")

        let s1 = Settlement(fromFriend: me, toFriend: alice, amount: 100)
        let s2 = Settlement(fromFriend: alice, toFriend: bob, amount: 50)
        let s3 = Settlement(fromFriend: me, toFriend: bob, amount: 75) // unrelated
        context.insert(s1)
        context.insert(s2)
        context.insert(s3)
        try context.save()

        let allParticipants = fetchAll(ExpenseParticipant.self)
        let allSettlements = fetchAll(Settlement.self)

        try DataService.deleteFriend(alice, allParticipants: allParticipants,
                                     allSettlements: allSettlements, context: context)

        // s1 and s2 involve Alice, should be deleted; s3 should remain
        let remaining = fetchAll(Settlement.self)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.amount, 75)
    }

    // ================================================================
    // MARK: - Delete Expenses
    // ================================================================

    func testDeleteExpensesRemovesFromContext() throws {
        let me = makeUser("Me")
        let e1 = Expense(expenseDescription: "A", amount: 10)
        let e2 = Expense(expenseDescription: "B", amount: 20)
        context.insert(e1)
        context.insert(e2)
        e1.paidBy = me
        e2.paidBy = me
        try context.save()

        try DataService.deleteExpenses([e1], context: context)

        let remaining = fetchAll(Expense.self)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.expenseDescription, "B")
    }

    func testDeleteMultipleExpenses() throws {
        let e1 = Expense(expenseDescription: "A", amount: 10)
        let e2 = Expense(expenseDescription: "B", amount: 20)
        let e3 = Expense(expenseDescription: "C", amount: 30)
        context.insert(e1)
        context.insert(e2)
        context.insert(e3)
        try context.save()

        try DataService.deleteExpenses([e1, e2], context: context)

        let remaining = fetchAll(Expense.self)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.expenseDescription, "C")
    }

    // ================================================================
    // MARK: - Delete Settlements
    // ================================================================

    func testDeleteSettlementsRemovesFromContext() throws {
        let s1 = Settlement(amount: 100)
        let s2 = Settlement(amount: 200)
        context.insert(s1)
        context.insert(s2)
        try context.save()

        try DataService.deleteSettlements([s1], context: context)

        let remaining = fetchAll(Settlement.self)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.amount, 200)
    }

    // ================================================================
    // MARK: - Delete Group
    // ================================================================

    func testDeleteGroupRemovesFromContext() throws {
        let g = Group(name: "Trip")
        context.insert(g)
        try context.save()

        try DataService.deleteGroup(g, context: context)

        XCTAssertTrue(fetchAll(Group.self).isEmpty)
    }

    // ================================================================
    // MARK: - Record Settlement
    // ================================================================

    func testRecordSettlementCreatesRecord() throws {
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        try context.save()

        try DataService.recordSettlement(from: alice, to: bob, amount: 500, notes: "For lunch", context: context)

        let settlements = fetchAll(Settlement.self)
        XCTAssertEqual(settlements.count, 1)
        XCTAssertEqual(settlements.first?.fromFriend?.name, "Alice")
        XCTAssertEqual(settlements.first?.toFriend?.name, "Bob")
        XCTAssertEqual(settlements.first?.amount, 500)
        XCTAssertEqual(settlements.first?.notes, "For lunch")
    }

    func testRecordSettlementWithNilNotes() throws {
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        try context.save()

        try DataService.recordSettlement(from: alice, to: bob, amount: 100, notes: nil, context: context)

        let settlements = fetchAll(Settlement.self)
        XCTAssertEqual(settlements.count, 1)
        XCTAssertNil(settlements.first?.notes)
    }

    // ================================================================
    // MARK: - Clear All Data
    // ================================================================

    func testClearAllDataRemovesEverythingExceptCurrentUser() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")

        let expense = Expense(expenseDescription: "Dinner", amount: 100)
        context.insert(expense)
        expense.paidBy = me

        let p = ExpenseParticipant(friend: alice, amountOwed: 50)
        context.insert(p)
        expense.participants = [p]

        let group = Group(name: "Trip")
        context.insert(group)

        let settlement = Settlement(fromFriend: alice, toFriend: bob, amount: 200)
        context.insert(settlement)

        try context.save()

        try DataService.clearAllData(
            expenses: fetchAll(Expense.self),
            participants: fetchAll(ExpenseParticipant.self),
            groups: fetchAll(Group.self),
            settlements: fetchAll(Settlement.self),
            allUsers: fetchAll(User.self),
            currentUserID: me.id,
            context: context
        )

        XCTAssertTrue(fetchAll(Expense.self).isEmpty)
        XCTAssertTrue(fetchAll(ExpenseParticipant.self).isEmpty)
        XCTAssertTrue(fetchAll(Group.self).isEmpty)
        XCTAssertTrue(fetchAll(Settlement.self).isEmpty)

        let remainingUsers = fetchAll(User.self)
        XCTAssertEqual(remainingUsers.count, 1)
        XCTAssertEqual(remainingUsers.first?.id, me.id, "Only current user should remain")
    }

    func testClearAllDataWithNilCurrentUserRemovesAllUsers() throws {
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        try context.save()

        try DataService.clearAllData(
            expenses: [],
            participants: [],
            groups: [],
            settlements: [],
            allUsers: [alice, bob],
            currentUserID: nil,
            context: context
        )

        XCTAssertTrue(fetchAll(User.self).isEmpty, "All users removed when currentUserID is nil")
    }
}
