//
//  DataService.swift
//  BillSplitter
//
//  Centralizes persistence operations that involve multi-step
//  delete/insert logic. Views call these instead of manually
//  orchestrating modelContext.delete/insert sequences.
//

import SwiftData
import Foundation
import WidgetKit

enum DataService {

    /// Tells WidgetKit to refresh all BillSplitter widgets.
    /// Call after any data mutation that affects balances.
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Friend Deletion

    /// Delete a friend and clean up orphaned participants & settlements.
    static func deleteFriend(
        _ friend: User,
        allParticipants: [ExpenseParticipant],
        allSettlements: [Settlement],
        context: ModelContext
    ) throws {
        // Remove expense participants linked to this friend
        let orphanedParticipants = allParticipants.filter { $0.friend?.id == friend.id }
        orphanedParticipants.forEach { context.delete($0) }

        // Remove settlements involving this friend
        let orphanedSettlements = allSettlements.filter {
            $0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id
        }
        orphanedSettlements.forEach { context.delete($0) }

        context.delete(friend)
        try context.save()
        reloadWidgets()
        SpotlightIndexer.deindex(friendID: friend.id)
    }

    // MARK: - Expense Deletion

    /// Delete one or more expenses from a filtered list.
    static func deleteExpenses(
        _ expenses: [Expense],
        context: ModelContext
    ) throws {
        let ids = expenses.map(\.id)
        expenses.forEach { context.delete($0) }
        try context.save()
        reloadWidgets()
        SpotlightIndexer.deindex(expenseIDs: ids)
    }

    // MARK: - Settlement Deletion

    /// Delete one or more settlements.
    static func deleteSettlements(
        _ settlements: [Settlement],
        context: ModelContext
    ) throws {
        settlements.forEach { context.delete($0) }
        try context.save()
        reloadWidgets()
    }

    // MARK: - Group Deletion

    /// Delete a group (expenses cascade via relationship).
    static func deleteGroup(
        _ group: Group,
        context: ModelContext
    ) throws {
        context.delete(group)
        try context.save()
        reloadWidgets()
    }

    // MARK: - Clear All Data

    /// Remove all user-created data, keeping only the current user record.
    static func clearAllData(
        expenses: [Expense],
        participants: [ExpenseParticipant],
        groups: [Group],
        settlements: [Settlement],
        allUsers: [User],
        currentUserID: UUID?,
        context: ModelContext
    ) throws {
        participants.forEach { context.delete($0) }
        expenses.forEach     { context.delete($0) }
        groups.forEach       { context.delete($0) }
        settlements.forEach  { context.delete($0) }
        allUsers.filter { $0.id != currentUserID }.forEach { context.delete($0) }
        try context.save()
        reloadWidgets()
        SpotlightIndexer.deleteAll()
    }

    // MARK: - Add Friend

    /// Create and persist a new friend.
    static func addFriend(
        name: String,
        profileColor: String,
        context: ModelContext
    ) throws {
        let user = User(name: name, profileColor: profileColor)
        context.insert(user)
        try context.save()
        SpotlightIndexer.index(user)
    }

    // MARK: - Record Settlement

    /// Create and persist a settlement record.
    static func recordSettlement(
        from: User,
        to: User,
        amount: Double,
        notes: String?,
        context: ModelContext
    ) throws {
        let s = Settlement(fromFriend: from, toFriend: to, amount: amount, notes: notes)
        context.insert(s)
        try context.save()
        reloadWidgets()
    }
}
