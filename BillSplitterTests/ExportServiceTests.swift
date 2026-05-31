//
//  ExportServiceTests.swift
//  BillSplitterTests
//
//  Tests for CSV export, PDF generation, and settlement summaries.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class ExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var me: User!
    private var alice: User!

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        me    = User(name: "Me", profileColor: "#00BCD4")
        alice = User(name: "Alice", profileColor: "#007AFF")
        [me, alice].forEach { context.insert($0) }
        try! context.save()
    }

    override func tearDown() {
        container = nil
        context = nil
        me = nil; alice = nil
        super.tearDown()
    }

    private func makeExpense(_ desc: String, amount: Double, category: ExpenseCategory = .general) -> Expense {
        let e = Expense(expenseDescription: desc, amount: amount, category: category)
        e.paidBy = me
        context.insert(e)
        return e
    }

    // MARK: - CSV

    func testCSVHeaderAndRowCount() {
        let e1 = makeExpense("Lunch", amount: 500, category: .food)
        let e2 = makeExpense("Taxi", amount: 200, category: .transport)
        try! context.save()

        let csv = ExportService.csvString(from: [e1, e2], scope: .all)
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 3, "Should have header + 2 rows")
        XCTAssertTrue(lines[0].hasPrefix("Date,Description,Amount"))
    }

    func testCSVContainsExpenseData() {
        let e = makeExpense("Coffee", amount: 150)
        try! context.save()

        let csv = ExportService.csvString(from: [e], scope: .all)
        XCTAssertTrue(csv.contains("Coffee"))
        XCTAssertTrue(csv.contains("150.00"))
    }

    func testCSVEscapesCommas() {
        let e = makeExpense("Lunch, dinner", amount: 300)
        try! context.save()

        let csv = ExportService.csvString(from: [e], scope: .all)
        // Commas in values should be quoted
        XCTAssertTrue(csv.contains("\"Lunch, dinner\""))
    }

    func testCSVFileCreation() {
        let e = makeExpense("Test", amount: 100)
        try! context.save()

        let url = ExportService.csvFile(from: [e], scope: .all)
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".csv"))

        // Clean up
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    func testCSVFriendScopeIncludesShareColumn() {
        let e = makeExpense("Dinner", amount: 1000)
        let p1 = ExpenseParticipant(friend: me, amountOwed: 600)
        let p2 = ExpenseParticipant(friend: alice, amountOwed: 400)
        [p1, p2].forEach { context.insert($0) }
        e.participants = [p1, p2]
        try! context.save()

        let csv = ExportService.csvString(from: [e], scope: .friend(alice))
        XCTAssertTrue(csv.contains("Alice's Share"), "Friend CSV should have share column header")
        XCTAssertTrue(csv.contains("400.00"), "Friend CSV should contain Alice's share amount")
    }

    func testCSVEmptyExpenses() {
        let csv = ExportService.csvString(from: [], scope: .all)
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1, "Should only have header")
    }

    // MARK: - PDF

    func testPDFDataGeneration() {
        let e = makeExpense("Hotel", amount: 5000, category: .accommodation)
        try! context.save()

        let data = ExportService.pdfData(from: [e], scope: .all, currencySymbol: "₹")
        XCTAssertNotNil(data)
        XCTAssertTrue((data?.count ?? 0) > 100, "PDF should have meaningful content")
    }

    func testPDFFileCreation() {
        let e = makeExpense("Flight", amount: 15000, category: .travel)
        try! context.save()

        let url = ExportService.pdfFile(from: [e], scope: .all, currencySymbol: "$")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".pdf"))

        if let url { try? FileManager.default.removeItem(at: url) }
    }

    func testPDFScopedFilenames() {
        let group = Group(name: "Trip")
        context.insert(group)
        try! context.save()

        let csvURL = ExportService.csvFile(from: [], scope: .group(group))
        XCTAssertTrue(csvURL?.lastPathComponent.contains("Trip") ?? false)

        let pdfURL = ExportService.pdfFile(from: [], scope: .friend(alice), currencySymbol: "$")
        XCTAssertTrue(pdfURL?.lastPathComponent.contains("Alice") ?? false)

        if let csvURL { try? FileManager.default.removeItem(at: csvURL) }
        if let pdfURL { try? FileManager.default.removeItem(at: pdfURL) }
    }

    // MARK: - Settlement Summary Text

    func testSettlementSummaryTextContainsFriendName() {
        let e = makeExpense("Dinner", amount: 1000)
        let p1 = ExpenseParticipant(friend: me, amountOwed: 500)
        let p2 = ExpenseParticipant(friend: alice, amountOwed: 500)
        [p1, p2].forEach { context.insert($0) }
        e.participants = [p1, p2]
        try! context.save()

        let text = ExportService.settlementSummaryText(
            friend: alice, balance: 500,
            sharedExpenses: [e], settlements: [],
            currentUserName: "Me", currencySymbol: "₹"
        )

        XCTAssertTrue(text.contains("Alice"))
        XCTAssertTrue(text.contains("Me"))
        XCTAssertTrue(text.contains("Dinner"))
        XCTAssertTrue(text.contains("₹500.00"))
    }

    func testSettlementSummarySettledUp() {
        let text = ExportService.settlementSummaryText(
            friend: alice, balance: 0,
            sharedExpenses: [], settlements: [],
            currentUserName: "Me", currencySymbol: "$"
        )

        XCTAssertTrue(text.contains("All settled up"))
    }

    func testSettlementSummaryIncludesSettlements() {
        let s = Settlement(fromFriend: alice, toFriend: me, amount: 300, paymentMethod: .upi, isConfirmed: true)
        context.insert(s)
        try! context.save()

        let text = ExportService.settlementSummaryText(
            friend: alice, balance: 0,
            sharedExpenses: [], settlements: [s],
            currentUserName: "Me", currencySymbol: "$"
        )

        XCTAssertTrue(text.contains("UPI"))
        XCTAssertTrue(text.contains("300.00"))
    }

    // MARK: - Settlement Summary PDF

    func testSettlementSummaryPDFGeneration() {
        let e = makeExpense("Lunch", amount: 600)
        try! context.save()

        let data = ExportService.settlementSummaryPDF(
            friend: alice, balance: 300,
            sharedExpenses: [e], settlements: [],
            currentUserName: "Me", currencySymbol: "$"
        )

        XCTAssertNotNil(data)
        XCTAssertTrue((data?.count ?? 0) > 100)
    }

    func testSettlementSummaryPDFFileCreation() {
        let url = ExportService.settlementSummaryPDFFile(
            friend: alice, balance: 0,
            sharedExpenses: [], settlements: [],
            currentUserName: "Me", currencySymbol: "$"
        )

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.lastPathComponent.contains("Alice"))
        XCTAssertTrue(url!.lastPathComponent.hasSuffix(".pdf"))

        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
