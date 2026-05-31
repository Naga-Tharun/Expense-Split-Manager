//
//  SpotlightIndexerTests.swift
//  BillSplitterTests
//
//  Tests for Spotlight indexing — identifier generation, attribute building,
//  ranking scores, and keyword construction.
//

import XCTest
import SwiftData
import CoreSpotlight
@testable import BillSplitter

@MainActor
final class SpotlightIndexerTests: XCTestCase {

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

    private func makeExpense(
        _ desc: String,
        amount: Double,
        paidBy: User,
        participants: [(User, Double)],
        category: ExpenseCategory = .general,
        date: Date = .now,
        notes: String? = nil
    ) -> Expense {
        let e = Expense(
            expenseDescription: desc,
            amount: amount,
            category: category,
            date: date,
            notes: notes
        )
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

    // ================================================================
    // MARK: - Identifier Generation
    // ================================================================

    func testExpenseIDFormat() {
        let uuid = UUID()
        let id = SpotlightIndexer.expenseID(uuid)
        XCTAssertEqual(id, "com.billsplitter.expense.\(uuid.uuidString)")
    }

    func testFriendIDFormat() {
        let uuid = UUID()
        let id = SpotlightIndexer.friendID(uuid)
        XCTAssertEqual(id, "com.billsplitter.friend.\(uuid.uuidString)")
    }

    func testExpenseIDsAreUnique() {
        let id1 = SpotlightIndexer.expenseID(UUID())
        let id2 = SpotlightIndexer.expenseID(UUID())
        XCTAssertNotEqual(id1, id2)
    }

    func testFriendIDsAreUnique() {
        let id1 = SpotlightIndexer.friendID(UUID())
        let id2 = SpotlightIndexer.friendID(UUID())
        XCTAssertNotEqual(id1, id2)
    }

    func testExpenseAndFriendIDsHaveDifferentPrefixes() {
        let uuid = UUID()
        let expID = SpotlightIndexer.expenseID(uuid)
        let frdID = SpotlightIndexer.friendID(uuid)
        XCTAssertNotEqual(expID, frdID)
        XCTAssertTrue(expID.hasPrefix("com.billsplitter.expense."))
        XCTAssertTrue(frdID.hasPrefix("com.billsplitter.friend."))
    }

    // ================================================================
    // MARK: - Activity Types
    // ================================================================

    func testActivityTypeConstants() {
        XCTAssertEqual(SpotlightIndexer.viewExpenseActivityType, "com.billsplitter.viewExpense")
        XCTAssertEqual(SpotlightIndexer.viewFriendActivityType, "com.billsplitter.viewFriend")
    }

    // ================================================================
    // MARK: - NSUserActivity Donation
    // ================================================================

    func testDonateExpenseActivityProperties() {
        let me = makeUser("Me")
        let expense = makeExpense("Lunch", amount: 500, paidBy: me, participants: [(me, 500)])

        let activity = SpotlightIndexer.donateExpenseActivity(expense)

        XCTAssertEqual(activity.activityType, SpotlightIndexer.viewExpenseActivityType)
        XCTAssertEqual(activity.title, "Lunch")
        XCTAssertTrue(activity.isEligibleForSearch)
        XCTAssertTrue(activity.isEligibleForPrediction)
        XCTAssertEqual(activity.persistentIdentifier, SpotlightIndexer.expenseID(expense.id))

        // Verify userInfo contains searchable identifier
        let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        XCTAssertEqual(identifier, SpotlightIndexer.expenseID(expense.id))

        // Verify contentAttributeSet has relatedUniqueIdentifier
        XCTAssertEqual(activity.contentAttributeSet?.relatedUniqueIdentifier, SpotlightIndexer.expenseID(expense.id))
    }

    func testDonateFriendActivityProperties() {
        let friend = makeUser("Alex")

        let activity = SpotlightIndexer.donateFriendActivity(friend)

        XCTAssertEqual(activity.activityType, SpotlightIndexer.viewFriendActivityType)
        XCTAssertEqual(activity.title, "Alex")
        XCTAssertTrue(activity.isEligibleForSearch)
        XCTAssertTrue(activity.isEligibleForPrediction)
        XCTAssertEqual(activity.persistentIdentifier, SpotlightIndexer.friendID(friend.id))
        XCTAssertEqual(activity.contentAttributeSet?.relatedUniqueIdentifier, SpotlightIndexer.friendID(friend.id))
    }

    // ================================================================
    // MARK: - Deep Link Identifier Parsing
    // ================================================================

    func testFriendUUIDExtractedFromIdentifier() {
        let uuid = UUID()
        let identifier = SpotlightIndexer.friendID(uuid)
        let prefix = "com.billsplitter.friend."

        let uuidString = String(identifier.dropFirst(prefix.count))
        let parsed = UUID(uuidString: uuidString)

        XCTAssertEqual(parsed, uuid)
    }

    func testExpenseUUIDExtractedFromIdentifier() {
        let uuid = UUID()
        let identifier = SpotlightIndexer.expenseID(uuid)
        let prefix = "com.billsplitter.expense."

        let uuidString = String(identifier.dropFirst(prefix.count))
        let parsed = UUID(uuidString: uuidString)

        XCTAssertEqual(parsed, uuid)
    }

    // ================================================================
    // MARK: - Indexing Calls Don't Crash
    // ================================================================

    func testIndexExpenseDoesNotCrash() {
        let me = makeUser("Me")
        let expense = makeExpense("Dinner", amount: 1200, paidBy: me, participants: [(me, 1200)], category: .food)
        SpotlightIndexer.index(expense)
        // No crash = pass
    }

    func testIndexFriendDoesNotCrash() {
        let friend = makeUser("Priya")
        SpotlightIndexer.index(friend)
    }

    func testIndexAllExpensesDoesNotCrash() {
        let me = makeUser("Me")
        let expenses = [
            makeExpense("A", amount: 10, paidBy: me, participants: [(me, 10)]),
            makeExpense("B", amount: 20, paidBy: me, participants: [(me, 20)])
        ]
        SpotlightIndexer.indexAll(expenses)
    }

    func testIndexAllFriendsDoesNotCrash() {
        let friends = [makeUser("Alice"), makeUser("Bob")]
        SpotlightIndexer.indexAll(friends)
    }

    func testIndexAllEmptyArrayDoesNotCrash() {
        SpotlightIndexer.indexAll([Expense]())
        SpotlightIndexer.indexAll([User]())
    }

    func testReindexAllDoesNotCrash() {
        let me = makeUser("Me")
        let friend = makeUser("Alice")
        let expense = makeExpense("Lunch", amount: 100, paidBy: me, participants: [(me, 50), (friend, 50)])
        SpotlightIndexer.reindexAll(expenses: [expense], friends: [friend])
    }

    func testDeindexDoesNotCrash() {
        SpotlightIndexer.deindex(expenseID: UUID())
        SpotlightIndexer.deindex(expenseIDs: [UUID(), UUID()])
        SpotlightIndexer.deindex(friendID: UUID())
    }

    func testDeleteAllDoesNotCrash() {
        SpotlightIndexer.deleteAll()
    }

    // ================================================================
    // MARK: - Expense with Notes & Participants
    // ================================================================

    func testIndexExpenseWithNotesAndParticipants() {
        let me = makeUser("Me")
        let friend = makeUser("Alex")
        let expense = makeExpense(
            "Team Dinner",
            amount: 2400,
            paidBy: me,
            participants: [(me, 1200), (friend, 1200)],
            category: .food,
            notes: "Birthday celebration"
        )
        // Should not crash even with notes and multiple participants
        SpotlightIndexer.index(expense)
    }

    func testIndexExpenseWithNilPaidBy() {
        let e = Expense(expenseDescription: "Orphan", amount: 100)
        context.insert(e)
        // paidBy is nil — should not crash
        SpotlightIndexer.index(e)
    }

    // ================================================================
    // MARK: - Expense Activity Attribute Content
    // ================================================================

    func testExpenseActivityAttributeSetHasTitle() {
        let me = makeUser("Me")
        let expense = makeExpense("Coffee Run", amount: 45, paidBy: me, participants: [(me, 45)], category: .food)

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let attrs = activity.contentAttributeSet

        XCTAssertEqual(attrs?.title, "Coffee Run")
        XCTAssertEqual(attrs?.displayName, "Coffee Run")
    }

    func testExpenseActivityAttributeSetHasDescription() {
        let me = makeUser("Alice")
        let expense = makeExpense("Dinner", amount: 200, paidBy: me, participants: [(me, 200)], category: .food)

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let desc = activity.contentAttributeSet?.contentDescription ?? ""

        // Description includes amount, category, payer name, and date
        XCTAssertTrue(desc.contains("Food"), "Description should contain category label")
        XCTAssertTrue(desc.contains("Alice"), "Description should contain payer name")
    }

    func testExpenseActivityAttributeSetHasKeywords() {
        let me = makeUser("Me")
        let friend = makeUser("Priya")
        let expense = makeExpense(
            "Team Lunch",
            amount: 500,
            paidBy: me,
            participants: [(me, 250), (friend, 250)],
            category: .food,
            notes: "Friday treat"
        )

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let keywords = activity.contentAttributeSet?.keywords ?? []

        XCTAssertTrue(keywords.contains("Team Lunch"), "Should include description")
        XCTAssertTrue(keywords.contains("Food"), "Should include category label")
        XCTAssertTrue(keywords.contains("food"), "Should include category raw value")
        XCTAssertTrue(keywords.contains("Me"), "Should include payer name")
        XCTAssertTrue(keywords.contains("Priya"), "Should include participant name")
        XCTAssertTrue(keywords.contains("Friday treat"), "Should include notes")
        XCTAssertTrue(keywords.contains("expense"), "Should include generic keyword")
        XCTAssertTrue(keywords.contains("bill"), "Should include generic keyword")
    }

    func testExpenseActivityKeywordsWithNoPayer() {
        let e = Expense(expenseDescription: "Orphan Expense", amount: 50)
        context.insert(e)

        let activity = SpotlightIndexer.donateExpenseActivity(e)
        let keywords = activity.contentAttributeSet?.keywords ?? []

        XCTAssertTrue(keywords.contains("Orphan Expense"))
        // Should NOT crash when paidBy is nil
        XCTAssertFalse(keywords.isEmpty)
    }

    func testExpenseActivityKeywordsWithNoNotes() {
        let me = makeUser("Me")
        let expense = makeExpense("Simple", amount: 10, paidBy: me, participants: [(me, 10)])

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let keywords = activity.contentAttributeSet?.keywords ?? []

        // Notes is nil — should not include any notes keyword
        XCTAssertFalse(keywords.isEmpty)
        XCTAssertTrue(keywords.contains("Simple"))
    }

    func testExpenseActivityHasRankingHint() {
        let me = makeUser("Me")
        let expense = makeExpense("Recent", amount: 100, paidBy: me, participants: [(me, 100)])

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let ranking = activity.contentAttributeSet?.rankingHint

        XCTAssertNotNil(ranking, "Expense should have a ranking hint")
        XCTAssertGreaterThan(ranking?.doubleValue ?? 0, 0, "Recent expense should have positive ranking")
    }

    func testExpenseRankingHigherForRecentExpenses() {
        let me = makeUser("Me")
        let recent = makeExpense("Recent", amount: 100, paidBy: me, participants: [(me, 100)], date: Date())
        let old = makeExpense("Old", amount: 100, paidBy: me, participants: [(me, 100)],
                              date: Date().addingTimeInterval(-60 * 86_400)) // 60 days ago

        let recentActivity = SpotlightIndexer.donateExpenseActivity(recent)
        let oldActivity = SpotlightIndexer.donateExpenseActivity(old)

        let recentRank = recentActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0
        let oldRank = oldActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0

        XCTAssertGreaterThan(recentRank, oldRank, "Recent expenses should rank higher")
    }

    func testExpenseRankingHigherForLargerAmounts() {
        let me = makeUser("Me")
        let date = Date() // Same date for both
        let small = makeExpense("Small", amount: 10, paidBy: me, participants: [(me, 10)], date: date)
        let large = makeExpense("Large", amount: 900, paidBy: me, participants: [(me, 900)], date: date)

        let smallActivity = SpotlightIndexer.donateExpenseActivity(small)
        let largeActivity = SpotlightIndexer.donateExpenseActivity(large)

        let smallRank = smallActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0
        let largeRank = largeActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0

        XCTAssertGreaterThan(largeRank, smallRank, "Larger amounts should rank higher")
    }

    func testExpenseRankingCapsAmountContribution() {
        let me = makeUser("Me")
        let date = Date()
        let big = makeExpense("Big", amount: 1000, paidBy: me, participants: [(me, 1000)], date: date)
        let huge = makeExpense("Huge", amount: 10000, paidBy: me, participants: [(me, 10000)], date: date)

        let bigActivity = SpotlightIndexer.donateExpenseActivity(big)
        let hugeActivity = SpotlightIndexer.donateExpenseActivity(huge)

        let bigRank = bigActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0
        let hugeRank = hugeActivity.contentAttributeSet?.rankingHint?.doubleValue ?? 0

        // Both should cap at 30 for amount component, so they should be equal
        XCTAssertEqual(bigRank, hugeRank, accuracy: 0.1, "Amount contribution should cap at 1000")
    }

    // ================================================================
    // MARK: - Friend Activity Attribute Content
    // ================================================================

    func testFriendActivityAttributeSetHasTitle() {
        let friend = makeUser("Ravi")
        let activity = SpotlightIndexer.donateFriendActivity(friend)
        let attrs = activity.contentAttributeSet

        XCTAssertEqual(attrs?.title, "Ravi")
        XCTAssertEqual(attrs?.displayName, "Ravi")
    }

    func testFriendActivityAttributeSetHasDescription() {
        let friend = makeUser("Ravi")
        let activity = SpotlightIndexer.donateFriendActivity(friend)
        let desc = activity.contentAttributeSet?.contentDescription ?? ""

        XCTAssertTrue(desc.contains("BillSplitter"), "Description should mention BillSplitter")
    }

    func testFriendActivityAttributeSetHasKeywords() {
        let friend = makeUser("Priya")
        let activity = SpotlightIndexer.donateFriendActivity(friend)
        let keywords = activity.contentAttributeSet?.keywords ?? []

        XCTAssertTrue(keywords.contains("Priya"), "Should include friend name")
        XCTAssertTrue(keywords.contains("friend"), "Should include 'friend' keyword")
        XCTAssertTrue(keywords.contains("BillSplitter"), "Should include app name")
    }

    // ================================================================
    // MARK: - ForceReindexAll
    // ================================================================

    func testForceReindexAllDoesNotCrash() {
        let me = makeUser("Me")
        let friend = makeUser("Bob")
        let expense = makeExpense("Test", amount: 50, paidBy: me, participants: [(me, 25), (friend, 25)])
        SpotlightIndexer.forceReindexAll(expenses: [expense], friends: [friend])
    }

    func testForceReindexAllWithEmptyArrays() {
        SpotlightIndexer.forceReindexAll(expenses: [], friends: [])
    }

    // ================================================================
    // MARK: - Deindex Multiple
    // ================================================================

    func testDeindexEmptyExpenseIDsDoesNotCrash() {
        SpotlightIndexer.deindex(expenseIDs: [])
    }

    // ================================================================
    // MARK: - Expense Description Formatting
    // ================================================================

    func testExpenseDescriptionContainsCategoryAndPayer() {
        let me = makeUser("Alice")
        let expense = makeExpense("Uber", amount: 300, paidBy: me, participants: [(me, 300)], category: .transport)

        let activity = SpotlightIndexer.donateExpenseActivity(expense)
        let desc = activity.contentAttributeSet?.contentDescription ?? ""

        XCTAssertTrue(desc.contains("Transport"), "Should contain category label")
        XCTAssertTrue(desc.contains("Alice"), "Should contain payer name")
        XCTAssertTrue(desc.contains("Paid by"), "Should contain 'Paid by'")
    }

    func testExpenseDescriptionWithNilPaidByShowsUnknown() {
        let e = Expense(expenseDescription: "Mystery", amount: 100)
        context.insert(e)

        let activity = SpotlightIndexer.donateExpenseActivity(e)
        let desc = activity.contentAttributeSet?.contentDescription ?? ""

        XCTAssertTrue(desc.contains("Unknown"), "Nil paidBy should show 'Unknown'")
    }

    // ================================================================
    // MARK: - All Categories Produce Valid Keywords
    // ================================================================

    func testAllCategoriesProduceKeywords() {
        let me = makeUser("Me")
        for cat in ExpenseCategory.allCases {
            let expense = makeExpense("Test \(cat.label)", amount: 50, paidBy: me,
                                      participants: [(me, 50)], category: cat)
            let activity = SpotlightIndexer.donateExpenseActivity(expense)
            let keywords = activity.contentAttributeSet?.keywords ?? []
            XCTAssertFalse(keywords.isEmpty, "Category \(cat) should produce keywords")
            XCTAssertTrue(keywords.contains(cat.label), "Keywords should contain category label '\(cat.label)'")
        }
    }
}
