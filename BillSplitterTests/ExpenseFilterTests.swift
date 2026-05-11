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
}
