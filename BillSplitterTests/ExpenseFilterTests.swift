//
//  ExpenseFilterTests.swift
//  BillSplitterTests
//
//  Tests for the [Expense].filtered() extension — search, category filter, sorting.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class ExpenseFilterTests: XCTestCase {

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

    private func makeExpense(
        _ desc: String,
        amount: Double,
        category: ExpenseCategory = .general,
        date: Date = Date(),
        paidByName: String? = nil,
        groupName: String? = nil
    ) -> Expense {
        let e = Expense(expenseDescription: desc, amount: amount)
        e.category = category
        e.date = date
        context.insert(e)

        if let name = paidByName {
            let user = User(name: name, profileColor: "#007AFF")
            context.insert(user)
            e.paidBy = user
        }

        if let gName = groupName {
            let g = Group(name: gName, iconName: "house.fill")
            context.insert(g)
            e.group = g
        }

        return e
    }

    // ================================================================
    // MARK: - Search
    // ================================================================

    func testSearchByDescription() {
        let e1 = makeExpense("Lunch at cafe", amount: 30)
        let e2 = makeExpense("Dinner party", amount: 80)

        let result = [e1, e2].filtered(searchText: "lunch")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Lunch at cafe")
    }

    func testSearchCaseInsensitive() {
        let e1 = makeExpense("GROCERY Shopping", amount: 50)

        let result = [e1].filtered(searchText: "grocery")
        XCTAssertEqual(result.count, 1)
    }

    func testSearchByPaidByName() {
        let e1 = makeExpense("Coffee", amount: 5, paidByName: "Alice")
        let e2 = makeExpense("Tea", amount: 4, paidByName: "Bob")

        let result = [e1, e2].filtered(searchText: "alice")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Coffee")
    }

    func testSearchByGroupName() {
        let e1 = makeExpense("Rent", amount: 1000, groupName: "Flatmates")
        let e2 = makeExpense("Dinner", amount: 50, groupName: "Work Team")

        let result = [e1, e2].filtered(searchText: "flatmates")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Rent")
    }

    func testSearchEmptyStringReturnsAll() {
        let e1 = makeExpense("A", amount: 10)
        let e2 = makeExpense("B", amount: 20)

        let result = [e1, e2].filtered(searchText: "")
        XCTAssertEqual(result.count, 2)
    }

    func testSearchNoMatchReturnsEmpty() {
        let e1 = makeExpense("Lunch", amount: 30)

        let result = [e1].filtered(searchText: "zzzzz")
        XCTAssertTrue(result.isEmpty)
    }

    // ================================================================
    // MARK: - Category Filter
    // ================================================================

    func testCategoryFilterFood() {
        let e1 = makeExpense("Pizza", amount: 20, category: .food)
        let e2 = makeExpense("Taxi", amount: 30, category: .transport)

        let result = [e1, e2].filtered(category: .food)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Pizza")
    }

    func testCategoryFilterNilReturnsAll() {
        let e1 = makeExpense("A", amount: 10, category: .food)
        let e2 = makeExpense("B", amount: 20, category: .transport)

        let result = [e1, e2].filtered(category: nil)
        XCTAssertEqual(result.count, 2)
    }

    func testCategoryFilterNoMatchReturnsEmpty() {
        let e1 = makeExpense("Taxi", amount: 30, category: .transport)

        let result = [e1].filtered(category: .entertainment)
        XCTAssertTrue(result.isEmpty)
    }

    // ================================================================
    // MARK: - Sort
    // ================================================================

    func testSortByDateDescending() {
        let old = makeExpense("Old", amount: 10, date: Date().addingTimeInterval(-86400))
        let new = makeExpense("New", amount: 20, date: Date())

        let result = [old, new].filtered(sortOrder: .dateDesc)
        XCTAssertEqual(result.first?.expenseDescription, "New")
    }

    func testSortByDateAscending() {
        let old = makeExpense("Old", amount: 10, date: Date().addingTimeInterval(-86400))
        let new = makeExpense("New", amount: 20, date: Date())

        let result = [old, new].filtered(sortOrder: .dateAsc)
        XCTAssertEqual(result.first?.expenseDescription, "Old")
    }

    func testSortByAmountHighest() {
        let cheap = makeExpense("Cheap", amount: 10)
        let pricey = makeExpense("Pricey", amount: 100)

        let result = [cheap, pricey].filtered(sortOrder: .amountHigh)
        XCTAssertEqual(result.first?.expenseDescription, "Pricey")
    }

    func testSortByAmountLowest() {
        let cheap = makeExpense("Cheap", amount: 10)
        let pricey = makeExpense("Pricey", amount: 100)

        let result = [cheap, pricey].filtered(sortOrder: .amountLow)
        XCTAssertEqual(result.first?.expenseDescription, "Cheap")
    }

    // ================================================================
    // MARK: - Combined Filters
    // ================================================================

    func testSearchPlusCategoryFilter() {
        let e1 = makeExpense("Pizza lunch", amount: 20, category: .food)
        let e2 = makeExpense("Pizza taxi ride", amount: 30, category: .transport)
        let e3 = makeExpense("Sushi dinner", amount: 50, category: .food)

        let result = [e1, e2, e3].filtered(searchText: "pizza", category: .food)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Pizza lunch")
    }

    func testSearchPlusSortByAmount() {
        let e1 = makeExpense("Coffee small", amount: 3)
        let e2 = makeExpense("Coffee large", amount: 5)
        let e3 = makeExpense("Lunch", amount: 30)

        let result = [e1, e2, e3].filtered(searchText: "coffee", sortOrder: .amountHigh)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.expenseDescription, "Coffee large")
    }

    func testAllFiltersCombined() {
        let e1 = makeExpense("Team pizza", amount: 40, category: .food,
                             date: Date().addingTimeInterval(-86400))
        let e2 = makeExpense("Team sushi", amount: 60, category: .food,
                             date: Date())
        let e3 = makeExpense("Team taxi", amount: 25, category: .transport,
                             date: Date())

        let result = [e1, e2, e3].filtered(
            searchText: "team",
            category: .food,
            sortOrder: .amountLow
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.expenseDescription, "Team pizza")
        XCTAssertEqual(result.last?.expenseDescription, "Team sushi")
    }

    // ================================================================
    // MARK: - Empty Array
    // ================================================================

    func testFilterEmptyArrayReturnsEmpty() {
        let result: [Expense] = [].filtered(searchText: "anything", category: .food, sortOrder: .dateDesc)
        XCTAssertTrue(result.isEmpty)
    }

    // ================================================================
    // MARK: - Edge Cases
    // ================================================================

    func testSearchPartialMatch() {
        let e1 = makeExpense("Restaurant bill", amount: 120)
        let result = [e1].filtered(searchText: "rest")
        XCTAssertEqual(result.count, 1)
    }

    func testSearchMultipleWordsInDescription() {
        let e1 = makeExpense("Coffee at Blue Bottle", amount: 7)
        let e2 = makeExpense("Tea at home", amount: 2)

        let result = [e1, e2].filtered(searchText: "bottle")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.expenseDescription, "Coffee at Blue Bottle")
    }

    func testCategoryFilterAllCategoriesReturnCorrectly() {
        var expenses: [Expense] = []
        for cat in ExpenseCategory.allCases {
            expenses.append(makeExpense("Test \(cat.label)", amount: 10, category: cat))
        }

        for cat in ExpenseCategory.allCases {
            let result = expenses.filtered(category: cat)
            XCTAssertEqual(result.count, 1, "Should find exactly 1 expense for \(cat.label)")
            XCTAssertEqual(result.first?.category, cat)
        }
    }

    func testSortStabilityWithEqualDates() {
        let date = Date()
        let e1 = makeExpense("Alpha", amount: 50, date: date)
        let e2 = makeExpense("Beta", amount: 50, date: date)

        let result = [e1, e2].filtered(sortOrder: .dateDesc)
        XCTAssertEqual(result.count, 2) // Both should be present, order doesn't matter
    }

    func testSortStabilityWithEqualAmounts() {
        let e1 = makeExpense("Alpha", amount: 100)
        let e2 = makeExpense("Beta", amount: 100)

        let result = [e1, e2].filtered(sortOrder: .amountHigh)
        XCTAssertEqual(result.count, 2)
    }

    func testFilterLargeArray() {
        var expenses: [Expense] = []
        for i in 0..<200 {
            expenses.append(makeExpense("Expense \(i)", amount: Double(i)))
        }

        let result = expenses.filtered(searchText: "Expense 19", sortOrder: .amountHigh)
        // "Expense 19", "Expense 190", "Expense 191", ..., "Expense 199" = 11 matches
        XCTAssertEqual(result.count, 11)
        // Highest amount first (199)
        XCTAssertEqual(result.first?.amount, 199)
    }

    func testSearchWithWhitespace() {
        let e1 = makeExpense("Lunch with team", amount: 50)
        let result = [e1].filtered(searchText: "  lunch  ")
        // Whitespace in search should still match if lowercase contains works
        // Note: the filter uses lowercased().contains() which doesn't trim whitespace
        // so "  lunch  " won't match "lunch with team" — this tests actual behavior
        XCTAssertEqual(result.count, 0, "Search with leading/trailing spaces should not match")
    }

    func testSearchByGroupNamePartial() {
        let e1 = makeExpense("Dinner", amount: 100, groupName: "Weekend Warriors")
        let result = [e1].filtered(searchText: "weekend")
        XCTAssertEqual(result.count, 1)
    }

    // ================================================================
    // MARK: - ExpenseSortOption
    // ================================================================

    func testExpenseSortOptionCaseCount() {
        XCTAssertEqual(ExpenseSortOption.allCases.count, 4)
    }

    func testExpenseSortOptionRawValues() {
        XCTAssertEqual(ExpenseSortOption.dateDesc.rawValue, "Newest")
        XCTAssertEqual(ExpenseSortOption.dateAsc.rawValue, "Oldest")
        XCTAssertEqual(ExpenseSortOption.amountHigh.rawValue, "Highest")
        XCTAssertEqual(ExpenseSortOption.amountLow.rawValue, "Lowest")
    }

    func testExpenseSortOptionIdentifiable() {
        for opt in ExpenseSortOption.allCases {
            XCTAssertEqual(opt.id, opt.rawValue)
        }
    }
}
