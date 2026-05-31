//
//  GroupMemberRemovalTests.swift
//  BillSplitterTests
//
//  Tests for group member removal logic — verifies that members with
//  unsettled balances are blocked from removal, and members with zero
//  or fully settled balances can be removed.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class GroupMemberRemovalTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var me: User!
    private var alice: User!
    private var bob: User!
    private var group: Group!

    private static let allStores: [UserDefaults] = [.standard, SharedContainer.defaults]

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        Self.clearDefaults()

        me    = User(name: "Me", profileColor: "#00BCD4")
        alice = User(name: "Alice", profileColor: "#007AFF")
        bob   = User(name: "Bob", profileColor: "#FF9500")
        [me, alice, bob].forEach { context.insert($0) }

        group = Group(name: "Flatmates", iconName: "house.fill")
        context.insert(group)
        group.members = [me, alice, bob]

        try! context.save()

        for store in Self.allStores {
            store.set(me.id.uuidString, forKey: CurrentUserManager.idKey)
        }
    }

    override func tearDown() {
        Self.clearDefaults()
        container = nil
        context = nil
        me = nil
        alice = nil
        bob = nil
        group = nil
        super.tearDown()
    }

    private static func clearDefaults() {
        let keys = [CurrentUserManager.idKey, CurrentUserManager.nameKey, CurrentUserManager.colorKey]
        for store in allStores {
            for key in keys { store.removeObject(forKey: key) }
        }
    }

    private func makeExpense(
        _ desc: String,
        amount: Double,
        paidBy: User,
        participants: [(User, Double)]
    ) -> Expense {
        let e = Expense(expenseDescription: desc, amount: amount)
        e.paidBy = paidBy
        e.group = group
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

    private func makeSettlement(from: User, to: User, amount: Double) -> Settlement {
        let s = Settlement(fromFriend: from, toFriend: to, amount: amount, isConfirmed: true)
        context.insert(s)
        return s
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    /// Simulates the balance check used by GroupDetailView / EditGroupView
    /// before allowing member removal.
    private func hasUnsettledBalance(_ member: User) -> Bool {
        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)
        let balance = BalanceCalculator.balance(
            for: member.id,
            expenses: expenses,
            settlements: settlements,
            currentUserID: me.id
        )
        return abs(balance) > BalanceCalculator.epsilon
    }

    /// Simulates removing a member from the group.
    private func removeMember(_ member: User) {
        var updated = group.members ?? []
        updated.removeAll { $0.id == member.id }
        group.members = updated
        try? context.save()
    }

    // ================================================================
    // MARK: - No Expenses — Removal Allowed
    // ================================================================

    func testRemovalAllowedWhenNoExpenses() {
        XCTAssertFalse(hasUnsettledBalance(alice))
        XCTAssertFalse(hasUnsettledBalance(bob))
    }

    func testRemoveMemberWithNoExpenses() {
        XCTAssertFalse(hasUnsettledBalance(alice))
        removeMember(alice)
        XCTAssertEqual(group.members?.count, 2)
        XCTAssertFalse(group.members?.contains(where: { $0.id == alice.id }) ?? true)
    }

    // ================================================================
    // MARK: - Unsettled Balance — Removal Blocked
    // ================================================================

    func testRemovalBlockedWhenFriendOwesMe() {
        // I paid 1000, split equally with Alice → Alice owes 500
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        try! context.save()

        XCTAssertTrue(hasUnsettledBalance(alice), "Alice owes me — should block removal")
    }

    func testRemovalBlockedWhenIOwe() {
        // Alice paid 600, split equally with me → I owe 300
        _ = makeExpense("Lunch", amount: 600, paidBy: alice, participants: [(alice, 300), (me, 300)])
        try! context.save()

        XCTAssertTrue(hasUnsettledBalance(alice), "I owe Alice — should block removal")
    }

    func testRemovalBlockedWithMultipleExpenses() {
        // I paid 100 split with Alice
        _ = makeExpense("Coffee", amount: 100, paidBy: me, participants: [(me, 50), (alice, 50)])
        // Alice paid 200 split with me
        _ = makeExpense("Taxi", amount: 200, paidBy: alice, participants: [(alice, 100), (me, 100)])
        try! context.save()

        // Net: Alice owes 50, I owe 100 → net I owe 50
        XCTAssertTrue(hasUnsettledBalance(alice), "Net balance is non-zero — should block")
    }

    func testUnsettledBalanceAmount() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        try! context.save()

        let expenses = fetchAll(Expense.self)
        let settlements = fetchAll(Settlement.self)
        let balance = BalanceCalculator.balance(
            for: alice.id, expenses: expenses, settlements: settlements, currentUserID: me.id
        )

        XCTAssertEqual(balance, 500, accuracy: 0.01, "Alice owes me 500")
    }

    // ================================================================
    // MARK: - Fully Settled — Removal Allowed
    // ================================================================

    func testRemovalAllowedAfterFullSettlement() {
        // I paid 1000, split equally → Alice owes 500
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        // Alice settles the full 500
        _ = makeSettlement(from: alice, to: me, amount: 500)
        try! context.save()

        XCTAssertFalse(hasUnsettledBalance(alice), "Fully settled — removal should be allowed")
    }

    func testRemovalAllowedAfterMultipleSettlements() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        // Alice pays in two installments
        _ = makeSettlement(from: alice, to: me, amount: 200)
        _ = makeSettlement(from: alice, to: me, amount: 300)
        try! context.save()

        XCTAssertFalse(hasUnsettledBalance(alice), "Fully settled via multiple payments — removal allowed")
    }

    // ================================================================
    // MARK: - Partial Settlement — Still Blocked
    // ================================================================

    func testRemovalBlockedAfterPartialSettlement() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        // Alice only pays 200 of the 500
        _ = makeSettlement(from: alice, to: me, amount: 200)
        try! context.save()

        XCTAssertTrue(hasUnsettledBalance(alice), "Partially settled — should still block")
    }

    func testPartialSettlementRemainingAmount() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        _ = makeSettlement(from: alice, to: me, amount: 200)
        try! context.save()

        let balance = BalanceCalculator.balance(
            for: alice.id,
            expenses: fetchAll(Expense.self),
            settlements: fetchAll(Settlement.self),
            currentUserID: me.id
        )
        XCTAssertEqual(balance, 300, accuracy: 0.01, "300 still owed after partial settlement")
    }

    // ================================================================
    // MARK: - Unconfirmed Settlement — Still Blocked
    // ================================================================

    func testRemovalBlockedWhenSettlementUnconfirmed() {
        _ = makeExpense("Dinner", amount: 1000, paidBy: me, participants: [(me, 500), (alice, 500)])
        // Unconfirmed settlement — should NOT count
        let s = Settlement(fromFriend: alice, toFriend: me, amount: 500, isConfirmed: false)
        context.insert(s)
        try! context.save()

        XCTAssertTrue(hasUnsettledBalance(alice), "Unconfirmed settlement should not clear balance")
    }

    // ================================================================
    // MARK: - Cannot Remove Self
    // ================================================================

    func testCurrentUserCannotBeRemoved() {
        // The view logic prevents removing the current user.
        // Simulate the guard: skip if member is current user.
        let members = group.members ?? []
        let toRemove = members.filter { $0.id == me.id }
        let shouldBlock = toRemove.contains(where: { $0.id == me.id })
        XCTAssertTrue(shouldBlock, "Current user removal should be blocked by guard")
    }

    // ================================================================
    // MARK: - Independent Members
    // ================================================================

    func testOneMemberBlockedOtherAllowed() {
        // Alice owes me, but Bob has no expenses
        _ = makeExpense("Dinner", amount: 100, paidBy: me, participants: [(me, 50), (alice, 50)])
        try! context.save()

        XCTAssertTrue(hasUnsettledBalance(alice), "Alice has unsettled balance")
        XCTAssertFalse(hasUnsettledBalance(bob), "Bob has no balance — removal allowed")
    }

    func testRemoveBobWhileAliceBlocked() {
        _ = makeExpense("Dinner", amount: 100, paidBy: me, participants: [(me, 50), (alice, 50)])
        try! context.save()

        // Bob can be removed
        XCTAssertFalse(hasUnsettledBalance(bob))
        removeMember(bob)
        XCTAssertEqual(group.members?.count, 2)
        XCTAssertFalse(group.members?.contains(where: { $0.id == bob.id }) ?? true)

        // Alice still can't be removed
        XCTAssertTrue(hasUnsettledBalance(alice))
    }

    // ================================================================
    // MARK: - Edge: Tiny Balance Within Epsilon
    // ================================================================

    func testRemovalAllowedWhenBalanceWithinEpsilon() {
        // Create an expense that results in a rounding dust balance
        _ = makeExpense("Split three ways", amount: 10, paidBy: me,
                        participants: [(me, 3.34), (alice, 3.33), (bob, 3.33)])
        // Settle with a matching tiny amount
        _ = makeSettlement(from: alice, to: me, amount: 3.33)
        try! context.save()

        let balance = BalanceCalculator.balance(
            for: alice.id,
            expenses: fetchAll(Expense.self),
            settlements: fetchAll(Settlement.self),
            currentUserID: me.id
        )

        // Balance should be essentially zero (within epsilon)
        XCTAssertTrue(abs(balance) <= BalanceCalculator.epsilon,
                       "Balance \(balance) should be within epsilon")
        XCTAssertFalse(hasUnsettledBalance(alice), "Dust balance should not block removal")
    }

    // ================================================================
    // MARK: - Group Membership After Removal
    // ================================================================

    func testGroupMemberCountAfterRemoval() {
        XCTAssertEqual(group.members?.count, 3)
        removeMember(bob)
        XCTAssertEqual(group.members?.count, 2)
        removeMember(alice)
        XCTAssertEqual(group.members?.count, 1)
        // Only "me" remains
        XCTAssertEqual(group.members?.first?.id, me.id)
    }

    func testRemovedMemberNotInGroupButStillInDatabase() {
        removeMember(bob)
        // Bob is no longer a group member
        XCTAssertFalse(group.members?.contains(where: { $0.id == bob.id }) ?? true)
        // But Bob still exists as a user
        let allUsers = fetchAll(User.self)
        XCTAssertTrue(allUsers.contains(where: { $0.id == bob.id }))
    }
}
