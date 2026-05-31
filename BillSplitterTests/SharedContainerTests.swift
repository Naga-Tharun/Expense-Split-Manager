//
//  SharedContainerTests.swift
//  BillSplitterTests
//
//  Tests for SharedContainer — App Group defaults, store URL,
//  and ModelContainer creation. Also tests SaveErrorState.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class SharedContainerTests: XCTestCase {

    // ================================================================
    // MARK: - App Group Constants
    // ================================================================

    func testAppGroupIDIsNotEmpty() {
        XCTAssertFalse(SharedContainer.appGroupID.isEmpty)
    }

    func testAppGroupIDFormat() {
        // App Group IDs should start with "group."
        XCTAssertTrue(SharedContainer.appGroupID.hasPrefix("group."))
    }

    // ================================================================
    // MARK: - Shared Defaults
    // ================================================================

    func testSharedDefaultsWriteAndRead() {
        let key = "test_shared_\(UUID().uuidString)"
        SharedContainer.defaults.set("hello", forKey: key)
        XCTAssertEqual(SharedContainer.defaults.string(forKey: key), "hello")
        SharedContainer.defaults.removeObject(forKey: key)
    }

    func testSharedDefaultsIsNotNil() {
        XCTAssertNotNil(SharedContainer.defaults)
    }

    // ================================================================
    // MARK: - Store URL
    // ================================================================

    func testStoreURLEndsWithStoreName() {
        let url = SharedContainer.storeURL
        XCTAssertTrue(url.lastPathComponent == "BillSplitter.store")
    }

    func testStoreURLIsFileURL() {
        let url = SharedContainer.storeURL
        XCTAssertTrue(url.isFileURL)
    }

    // ================================================================
    // MARK: - ModelContainer Creation
    // ================================================================

    func testMakeInMemoryContainerSucceeds() {
        XCTAssertNoThrow(try SharedContainer.makeModelContainer(inMemory: true))
    }

    func testInMemoryContainerCanInsertAndFetch() throws {
        let container = try SharedContainer.makeModelContainer(inMemory: true)
        let context = container.mainContext

        let user = User(name: "Test User", profileColor: "#FF0000")
        context.insert(user)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<User>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test User")
    }

    func testInMemoryContainerSupportsAllModels() throws {
        let container = try SharedContainer.makeModelContainer(inMemory: true)
        let context = container.mainContext

        let user = User(name: "Me", profileColor: "#000")
        let expense = Expense(expenseDescription: "Test", amount: 100)
        let group = Group(name: "Trip")
        let settlement = Settlement(amount: 50)
        let participant = ExpenseParticipant(amountOwed: 25)

        context.insert(user)
        context.insert(expense)
        context.insert(group)
        context.insert(settlement)
        context.insert(participant)

        XCTAssertNoThrow(try context.save())
    }
}

// ================================================================
// MARK: - SaveErrorState Tests
// ================================================================

final class SaveErrorStateTests: XCTestCase {

    func testInitialState() {
        let state = SaveErrorState()
        XCTAssertFalse(state.showAlert)
        XCTAssertTrue(state.message.isEmpty)
    }

    func testPerformSuccessKeepsAlertHidden() {
        let state = SaveErrorState()
        state.perform { /* no-op success */ }
        XCTAssertFalse(state.showAlert)
        XCTAssertTrue(state.message.isEmpty)
    }

    func testPerformFailureShowsAlert() {
        let state = SaveErrorState()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }

        state.perform { throw TestError() }

        XCTAssertTrue(state.showAlert)
        XCTAssertEqual(state.message, "Something went wrong")
    }

    func testPerformFailureThenSuccessResetsOnNextSuccess() {
        let state = SaveErrorState()

        struct TestError: LocalizedError {
            var errorDescription: String? { "Error 1" }
        }

        state.perform { throw TestError() }
        XCTAssertTrue(state.showAlert)

        // Manually dismiss alert (like user tapping OK)
        state.showAlert = false
        state.message = ""

        // Next success should not re-show
        state.perform { /* success */ }
        XCTAssertFalse(state.showAlert)
    }

    func testPerformExecutesWorkClosure() {
        let state = SaveErrorState()
        var executed = false
        state.perform { executed = true }
        XCTAssertTrue(executed)
    }

    func testPerformMultipleFailuresUpdatesMessage() {
        let state = SaveErrorState()

        struct Error1: LocalizedError {
            var errorDescription: String? { "First error" }
        }
        struct Error2: LocalizedError {
            var errorDescription: String? { "Second error" }
        }

        state.perform { throw Error1() }
        XCTAssertEqual(state.message, "First error")

        state.perform { throw Error2() }
        XCTAssertEqual(state.message, "Second error")
    }
}
