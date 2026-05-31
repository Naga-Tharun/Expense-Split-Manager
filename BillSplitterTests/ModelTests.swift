//
//  ModelTests.swift
//  BillSplitterTests
//
//  Tests for SwiftData model initialization, property accessors,
//  relationships, and type-safe enum accessors.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class ModelTests: XCTestCase {

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

    // ================================================================
    // MARK: - User
    // ================================================================

    func testUserInitDefaults() {
        let user = User(name: "Alice")
        context.insert(user)
        XCTAssertEqual(user.name, "Alice")
        XCTAssertEqual(user.profileColor, "#000000")
        XCTAssertNotNil(user.id)
    }

    func testUserInitCustomValues() {
        let uuid = UUID()
        let date = Date.distantPast
        let user = User(id: uuid, name: "Bob", profileColor: "#FF0000", createdAt: date)
        context.insert(user)
        XCTAssertEqual(user.id, uuid)
        XCTAssertEqual(user.name, "Bob")
        XCTAssertEqual(user.profileColor, "#FF0000")
        XCTAssertEqual(user.createdAt, date)
    }

    func testUserUniqueIDs() {
        let u1 = User(name: "Alice")
        let u2 = User(name: "Bob")
        context.insert(u1)
        context.insert(u2)
        XCTAssertNotEqual(u1.id, u2.id)
    }

    func testUserRelationshipsInitiallyNilOrEmpty() {
        let user = User(name: "Test")
        context.insert(user)
        try? context.save()
        // Relationships are optional arrays — nil or empty is valid
        let expenses = user.expenses ?? []
        XCTAssertTrue(expenses.isEmpty)
    }

    // ================================================================
    // MARK: - Expense
    // ================================================================

    func testExpenseInitDefaults() {
        let e = Expense(expenseDescription: "Lunch", amount: 50.0)
        context.insert(e)
        XCTAssertEqual(e.expenseDescription, "Lunch")
        XCTAssertEqual(e.amount, 50.0)
        XCTAssertEqual(e.category, .general)
        XCTAssertEqual(e.splitType, .equal)
        XCTAssertNil(e.notes)
        XCTAssertNil(e.paidBy)
        XCTAssertNil(e.group)
    }

    func testExpenseInitCustomValues() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let e = Expense(
            expenseDescription: "Flight",
            amount: 2500,
            category: .travel,
            date: date,
            notes: "Round trip",
            splitType: .custom
        )
        context.insert(e)
        XCTAssertEqual(e.expenseDescription, "Flight")
        XCTAssertEqual(e.amount, 2500)
        XCTAssertEqual(e.category, .travel)
        XCTAssertEqual(e.date, date)
        XCTAssertEqual(e.notes, "Round trip")
        XCTAssertEqual(e.splitType, .custom)
    }

    func testExpenseCategoryAccessorRoundTrip() {
        let e = Expense(expenseDescription: "Test", amount: 10)
        context.insert(e)

        for cat in ExpenseCategory.allCases {
            e.category = cat
            XCTAssertEqual(e.category, cat)
            XCTAssertEqual(e.categoryRaw, cat.rawValue)
        }
    }

    func testExpenseSplitTypeAccessorRoundTrip() {
        let e = Expense(expenseDescription: "Test", amount: 10)
        context.insert(e)

        for split in SplitType.allCases {
            e.splitType = split
            XCTAssertEqual(e.splitType, split)
            XCTAssertEqual(e.splitTypeRaw, split.rawValue)
        }
    }

    func testExpenseCategoryFallbackToGeneral() {
        let e = Expense(expenseDescription: "Test", amount: 10)
        context.insert(e)
        e.categoryRaw = "unknown_category"
        XCTAssertEqual(e.category, .general, "Unknown raw value should fall back to .general")
    }

    func testExpenseSplitTypeFallbackToEqual() {
        let e = Expense(expenseDescription: "Test", amount: 10)
        context.insert(e)
        e.splitTypeRaw = "unknown_split"
        XCTAssertEqual(e.splitType, .equal, "Unknown raw value should fall back to .equal")
    }

    func testExpensePaidByRelationship() {
        let user = User(name: "Alice", profileColor: "#007AFF")
        let expense = Expense(expenseDescription: "Coffee", amount: 5)
        context.insert(user)
        context.insert(expense)
        expense.paidBy = user
        try? context.save()

        XCTAssertEqual(expense.paidBy?.id, user.id)
        XCTAssertEqual(expense.paidBy?.name, "Alice")
    }

    func testExpenseGroupRelationship() {
        let group = Group(name: "Trip")
        let expense = Expense(expenseDescription: "Hotel", amount: 200)
        context.insert(group)
        context.insert(expense)
        expense.group = group
        try? context.save()

        XCTAssertEqual(expense.group?.id, group.id)
    }

    // ================================================================
    // MARK: - ExpenseParticipant
    // ================================================================

    func testExpenseParticipantInitDefaults() {
        let p = ExpenseParticipant()
        context.insert(p)
        XCTAssertEqual(p.amountOwed, 0.0)
        XCTAssertFalse(p.isPaid)
        XCTAssertNil(p.friend)
    }

    func testExpenseParticipantCustomValues() {
        let user = User(name: "Bob", profileColor: "#FF9500")
        context.insert(user)
        let p = ExpenseParticipant(friend: user, amountOwed: 125.50, isPaid: true)
        context.insert(p)
        XCTAssertEqual(p.amountOwed, 125.50)
        XCTAssertTrue(p.isPaid)
        XCTAssertEqual(p.friend?.name, "Bob")
    }

    func testExpenseParticipantsLinkedToExpense() {
        let user = User(name: "Alice", profileColor: "#007AFF")
        let expense = Expense(expenseDescription: "Dinner", amount: 100)
        context.insert(user)
        context.insert(expense)

        let p1 = ExpenseParticipant(friend: user, amountOwed: 50)
        context.insert(p1)
        expense.participants = [p1]
        try? context.save()

        XCTAssertEqual(expense.participants?.count, 1)
        XCTAssertEqual(expense.participants?.first?.amountOwed, 50)
    }

    // ================================================================
    // MARK: - Settlement
    // ================================================================

    func testSettlementInitDefaults() {
        let s = Settlement()
        context.insert(s)
        XCTAssertEqual(s.amount, 0.0)
        XCTAssertFalse(s.isConfirmed)
        XCTAssertEqual(s.paymentMethod, .cash)
        XCTAssertNil(s.fromFriend)
        XCTAssertNil(s.toFriend)
        XCTAssertNil(s.notes)
    }

    func testSettlementCustomValues() {
        let alice = User(name: "Alice", profileColor: "#007AFF")
        let bob = User(name: "Bob", profileColor: "#FF9500")
        context.insert(alice)
        context.insert(bob)

        let s = Settlement(
            fromFriend: alice,
            toFriend: bob,
            amount: 500,
            paymentMethod: .upi,
            notes: "For dinner",
            isConfirmed: true
        )
        context.insert(s)

        XCTAssertEqual(s.fromFriend?.name, "Alice")
        XCTAssertEqual(s.toFriend?.name, "Bob")
        XCTAssertEqual(s.amount, 500)
        XCTAssertEqual(s.paymentMethod, .upi)
        XCTAssertEqual(s.notes, "For dinner")
        XCTAssertTrue(s.isConfirmed)
    }

    func testSettlementPaymentMethodAccessorRoundTrip() {
        let s = Settlement()
        context.insert(s)

        for method in PaymentMethod.allCases {
            s.paymentMethod = method
            XCTAssertEqual(s.paymentMethod, method)
            XCTAssertEqual(s.paymentMethodRaw, method.rawValue)
        }
    }

    func testSettlementPaymentMethodFallbackToCash() {
        let s = Settlement()
        context.insert(s)
        s.paymentMethodRaw = "bitcoin"
        XCTAssertEqual(s.paymentMethod, .cash, "Unknown raw value should fall back to .cash")
    }

    func testSettlementNilPaymentMethodRawFallsToCash() {
        let s = Settlement()
        context.insert(s)
        s.paymentMethodRaw = nil
        XCTAssertEqual(s.paymentMethod, .cash)
    }

    // ================================================================
    // MARK: - Group
    // ================================================================

    func testGroupInitDefaults() {
        let g = Group(name: "Trip")
        context.insert(g)
        XCTAssertEqual(g.name, "Trip")
        XCTAssertNil(g.groupDescription)
        XCTAssertEqual(g.iconName, "person.3.fill")
        XCTAssertEqual(g.colorHex, "#FF9500")
    }

    func testGroupInitCustomValues() {
        let g = Group(
            name: "Roommates",
            groupDescription: "Monthly bills",
            iconName: "house.fill",
            colorHex: "#00BCD4"
        )
        context.insert(g)
        XCTAssertEqual(g.name, "Roommates")
        XCTAssertEqual(g.groupDescription, "Monthly bills")
        XCTAssertEqual(g.iconName, "house.fill")
        XCTAssertEqual(g.colorHex, "#00BCD4")
    }

    func testGroupMembersRelationship() {
        let g = Group(name: "Trip")
        let alice = User(name: "Alice", profileColor: "#007AFF")
        let bob = User(name: "Bob", profileColor: "#FF9500")
        context.insert(g)
        context.insert(alice)
        context.insert(bob)
        g.members = [alice, bob]
        try? context.save()

        XCTAssertEqual(g.members?.count, 2)
    }

    func testGroupExpenseRelationship() {
        let g = Group(name: "Trip")
        let e = Expense(expenseDescription: "Hotel", amount: 300)
        context.insert(g)
        context.insert(e)
        e.group = g
        try? context.save()

        XCTAssertEqual(g.expenses?.count, 1)
        XCTAssertEqual(g.expenses?.first?.expenseDescription, "Hotel")
    }

    // ================================================================
    // MARK: - SchemaVersioning
    // ================================================================

    func testSchemaV1HasAllModels() {
        let models = SchemaV1.models
        XCTAssertEqual(models.count, 5)
    }

    func testSchemaVersionIdentifier() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func testMigrationPlanHasNoStagesYet() {
        XCTAssertTrue(BillSplitterMigrationPlan.stages.isEmpty)
    }

    func testMigrationPlanIncludesSchemaV1() {
        XCTAssertEqual(BillSplitterMigrationPlan.schemas.count, 1)
    }
}
