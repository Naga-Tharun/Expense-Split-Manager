//
//  DataServiceTests.swift
//  BillSplitterTests
//
//  Integration tests for DataService — persistence operations
//  with in-memory SwiftData containers.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class DataServiceTests: XCTestCase {

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

    private func makeExpense(_ desc: String, amount: Double, paidBy: User, participants: [User]) -> Expense {
        let e = Expense(expenseDescription: desc, amount: amount)
        e.paidBy = paidBy
        context.insert(e)

        let parts = participants.map { user in
            let p = ExpenseParticipant(friend: user, amountOwed: amount / Double(participants.count))
            context.insert(p)
            return p
        }
        e.participants = parts
        return e
    }

    private func makeSettlement(from: User, to: User, amount: Double) -> Settlement {
        let s = Settlement(fromFriend: from, toFriend: to, amount: amount)
        context.insert(s)
        return s
    }

    private func makeGroup(_ name: String, members: [User]) -> Group {
        let g = Group(name: name, iconName: "house.fill")
        g.members = members
        context.insert(g)
        return g
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    // ================================================================
    // MARK: - addFriend
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
        XCTAssertEqual(fetchAll(User.self).count, 2)
    }

    // ================================================================
    // MARK: - recordSettlement
    // ================================================================

    func testRecordSettlement() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        try DataService.recordSettlement(from: me, to: alice, amount: 50, notes: "Coffee", context: context)

        let settlements = fetchAll(Settlement.self)
        XCTAssertEqual(settlements.count, 1)
        XCTAssertEqual(settlements.first?.amount, 50)
        XCTAssertEqual(settlements.first?.notes, "Coffee")
        XCTAssertEqual(settlements.first?.fromFriend?.id, me.id)
        XCTAssertEqual(settlements.first?.toFriend?.id, alice.id)
    }

    func testRecordSettlementNilNotes() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        try DataService.recordSettlement(from: me, to: alice, amount: 25, notes: nil, context: context)

        let s = fetchAll(Settlement.self).first
        XCTAssertNil(s?.notes)
    }

    // ================================================================
    // MARK: - deleteExpenses
    // ================================================================

    func testDeleteExpensesRemovesThem() throws {
        let me = makeUser("Me")
        let e1 = makeExpense("Lunch", amount: 50, paidBy: me, participants: [me])
        _ = makeExpense("Dinner", amount: 80, paidBy: me, participants: [me])
        try context.save()

        try DataService.deleteExpenses([e1], context: context)
        let remaining = fetchAll(Expense.self)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.expenseDescription, "Dinner")
    }

    func testDeleteAllExpenses() throws {
        let me = makeUser("Me")
        let expenses = [
            makeExpense("A", amount: 10, paidBy: me, participants: [me]),
            makeExpense("B", amount: 20, paidBy: me, participants: [me])
        ]
        try context.save()

        try DataService.deleteExpenses(expenses, context: context)
        XCTAssertEqual(fetchAll(Expense.self).count, 0)
    }

    // ================================================================
    // MARK: - deleteSettlements
    // ================================================================

    func testDeleteSettlements() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let s1 = makeSettlement(from: me, to: alice, amount: 30)
        _ = makeSettlement(from: alice, to: me, amount: 20)
        try context.save()

        try DataService.deleteSettlements([s1], context: context)
        XCTAssertEqual(fetchAll(Settlement.self).count, 1)
    }

    // ================================================================
    // MARK: - deleteFriend (cascade cleanup)
    // ================================================================

    func testDeleteFriendRemovesOrphanedParticipants() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        _ = makeExpense("Shared", amount: 100, paidBy: me, participants: [me, alice])
        try context.save() // flush inserts so deleteFriend's save starts clean

        let allParticipants = fetchAll(ExpenseParticipant.self)
        let allSettlements = fetchAll(Settlement.self)

        // Before: 2 participants
        XCTAssertEqual(allParticipants.count, 2)

        try DataService.deleteFriend(
            alice,
            allParticipants: allParticipants,
            allSettlements: allSettlements,
            context: context
        )

        // Alice should be gone from users
        let remainingUsers = fetchAll(User.self)
        XCTAssertFalse(remainingUsers.contains(where: { $0.name == "Alice" }))
        XCTAssertTrue(remainingUsers.contains(where: { $0.name == "Me" }))

        // No participant should still reference Alice
        let remainingParticipants = fetchAll(ExpenseParticipant.self)
        let aliceParticipants = remainingParticipants.filter { $0.friend?.name == "Alice" }
        XCTAssertEqual(aliceParticipants.count, 0, "No participants should reference the deleted friend")
    }

    func testDeleteFriendRemovesOrphanedSettlements() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        _ = makeSettlement(from: me, to: alice, amount: 50)
        _ = makeSettlement(from: alice, to: me, amount: 30)
        try context.save()

        let allParticipants = fetchAll(ExpenseParticipant.self)
        let allSettlements = fetchAll(Settlement.self)

        try DataService.deleteFriend(
            alice,
            allParticipants: allParticipants,
            allSettlements: allSettlements,
            context: context
        )

        XCTAssertEqual(fetchAll(Settlement.self).count, 0)
    }

    // ================================================================
    // MARK: - deleteGroup
    // ================================================================

    func testDeleteGroup() throws {
        let me = makeUser("Me")
        let group = makeGroup("Flatmates", members: [me])
        try context.save()

        try DataService.deleteGroup(group, context: context)
        XCTAssertEqual(fetchAll(Group.self).count, 0)
        // User should NOT be deleted (nullify rule)
        XCTAssertEqual(fetchAll(User.self).count, 1)
    }

    // ================================================================
    // MARK: - clearAllData
    // ================================================================

    func testClearAllDataKeepsCurrentUser() throws {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        _ = makeExpense("Lunch", amount: 60, paidBy: me, participants: [me, alice])
        _ = makeSettlement(from: alice, to: me, amount: 30)
        _ = makeGroup("Team", members: [me, bob])
        try context.save()

        let expenses     = fetchAll(Expense.self)
        let participants = fetchAll(ExpenseParticipant.self)
        let groups       = fetchAll(Group.self)
        let settlements  = fetchAll(Settlement.self)
        let allUsers     = fetchAll(User.self)

        try DataService.clearAllData(
            expenses: expenses,
            participants: participants,
            groups: groups,
            settlements: settlements,
            allUsers: allUsers,
            currentUserID: me.id,
            context: context
        )

        // Only me should remain
        let remainingUsers = fetchAll(User.self)
        XCTAssertEqual(remainingUsers.count, 1)
        XCTAssertEqual(remainingUsers.first?.id, me.id)

        XCTAssertEqual(fetchAll(Expense.self).count, 0)
        XCTAssertEqual(fetchAll(Settlement.self).count, 0)
        XCTAssertEqual(fetchAll(Group.self).count, 0)
    }

    func testClearAllDataWithNilCurrentUserDeletesEveryone() throws {
        _ = makeUser("Alice")
        _ = makeUser("Bob")
        try context.save()

        let allUsers = fetchAll(User.self)

        try DataService.clearAllData(
            expenses: [],
            participants: [],
            groups: [],
            settlements: [],
            allUsers: allUsers,
            currentUserID: nil,
            context: context
        )

        XCTAssertEqual(fetchAll(User.self).count, 0)
    }
}
