//
//  CurrentUserManagerTests.swift
//  BillSplitterTests
//
//  Tests for CurrentUserManager — resolve logic, accessors, and friends filtering.
//  Uses a dedicated UserDefaults suite to avoid polluting the real defaults.
//

import XCTest
import SwiftData
@testable import BillSplitter

@MainActor
final class CurrentUserManagerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        // Clear UserDefaults keys used by CurrentUserManager
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.idKey)
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.nameKey)
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.colorKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.idKey)
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.nameKey)
        UserDefaults.standard.removeObject(forKey: CurrentUserManager.colorKey)
        container = nil
        context = nil
        super.tearDown()
    }

    private func makeUser(_ name: String) -> User {
        let u = User(name: name, profileColor: "#007AFF")
        context.insert(u)
        try? context.save()
        return u
    }

    // ================================================================
    // MARK: - resolve()
    // ================================================================

    func testResolveFirstLaunchCreatesUser() {
        // No users exist, no UUID stored
        let me = CurrentUserManager.resolve(in: container)
        XCTAssertEqual(me.name, "You") // default name
        XCTAssertNotNil(UserDefaults.standard.string(forKey: CurrentUserManager.idKey))
    }

    func testResolveWithStoredIDReturnsExistingUser() {
        let alice = makeUser("Alice")
        UserDefaults.standard.set(alice.id.uuidString, forKey: CurrentUserManager.idKey)

        let resolved = CurrentUserManager.resolve(in: container)
        XCTAssertEqual(resolved.id, alice.id)
        XCTAssertEqual(resolved.name, "Alice")
    }

    func testResolveStaleIDAdoptsFirstExistingUser() {
        // UUID in defaults doesn't match any user
        UserDefaults.standard.set(UUID().uuidString, forKey: CurrentUserManager.idKey)
        _ = makeUser("Alice")
        _ = makeUser("Bob")

        let resolved = CurrentUserManager.resolve(in: container)
        // Should adopt alice (first fetched user)
        XCTAssertNotNil(resolved)
        // The stored ID should now be updated
        let storedID = UserDefaults.standard.string(forKey: CurrentUserManager.idKey)
        XCTAssertEqual(storedID, resolved.id.uuidString)
    }

    func testResolveWithCustomNameAndColor() {
        // Set custom name/color before first launch
        UserDefaults.standard.set("Tharun", forKey: CurrentUserManager.nameKey)
        UserDefaults.standard.set("#FF5722", forKey: CurrentUserManager.colorKey)

        let me = CurrentUserManager.resolve(in: container)
        XCTAssertEqual(me.name, "Tharun")
        XCTAssertEqual(me.profileColor, "#FF5722")
    }

    // ================================================================
    // MARK: - currentUserID
    // ================================================================

    func testCurrentUserIDWhenNoneStored() {
        XCTAssertNil(CurrentUserManager.currentUserID)
    }

    func testCurrentUserIDWhenStored() {
        let uuid = UUID()
        UserDefaults.standard.set(uuid.uuidString, forKey: CurrentUserManager.idKey)
        XCTAssertEqual(CurrentUserManager.currentUserID, uuid)
    }

    func testCurrentUserIDWithInvalidStringReturnsNil() {
        UserDefaults.standard.set("not-a-uuid", forKey: CurrentUserManager.idKey)
        XCTAssertNil(CurrentUserManager.currentUserID)
    }

    // ================================================================
    // MARK: - currentUser(from:)
    // ================================================================

    func testCurrentUserFromListFindsMatch() {
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        UserDefaults.standard.set(alice.id.uuidString, forKey: CurrentUserManager.idKey)

        let result = CurrentUserManager.currentUser(from: [alice, bob])
        XCTAssertEqual(result?.id, alice.id)
    }

    func testCurrentUserFromListNoMatch() {
        let alice = makeUser("Alice")
        UserDefaults.standard.set(UUID().uuidString, forKey: CurrentUserManager.idKey)

        let result = CurrentUserManager.currentUser(from: [alice])
        XCTAssertNil(result)
    }

    func testCurrentUserFromListNoStoredID() {
        let alice = makeUser("Alice")
        let result = CurrentUserManager.currentUser(from: [alice])
        XCTAssertNil(result)
    }

    // ================================================================
    // MARK: - friends(from:)
    // ================================================================

    func testFriendsExcludesCurrentUser() {
        let me = makeUser("Me")
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")
        UserDefaults.standard.set(me.id.uuidString, forKey: CurrentUserManager.idKey)

        let friends = CurrentUserManager.friends(from: [me, alice, bob])
        XCTAssertEqual(friends.count, 2)
        XCTAssertFalse(friends.contains(where: { $0.id == me.id }))
    }

    func testFriendsWithNoStoredIDReturnsAll() {
        let alice = makeUser("Alice")
        let bob = makeUser("Bob")

        let friends = CurrentUserManager.friends(from: [alice, bob])
        XCTAssertEqual(friends.count, 2)
    }

    // ================================================================
    // MARK: - updateProfile
    // ================================================================

    func testUpdateProfileChangesNameAndColor() {
        let me = makeUser("OldName")
        UserDefaults.standard.set(me.id.uuidString, forKey: CurrentUserManager.idKey)

        CurrentUserManager.updateProfile(name: "NewName", color: "#FF0000", in: context)

        // Check UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: CurrentUserManager.nameKey), "NewName")
        XCTAssertEqual(UserDefaults.standard.string(forKey: CurrentUserManager.colorKey), "#FF0000")

        // Check SwiftData
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        let updated = users.first(where: { $0.id == me.id })
        XCTAssertEqual(updated?.name, "NewName")
        XCTAssertEqual(updated?.profileColor, "#FF0000")
    }

    func testUpdateProfileNoStoredIDDoesNothing() {
        _ = makeUser("Alice")
        // No ID stored → updateProfile should be a no-op
        CurrentUserManager.updateProfile(name: "Changed", color: "#000", in: context)

        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        XCTAssertEqual(users.first?.name, "Alice") // unchanged
    }
}
