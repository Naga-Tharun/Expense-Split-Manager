//
//  SpotlightIndexer.swift
//  BillSplitter
//
//  Indexes expenses and friends into Core Spotlight so they appear
//  in the system search. Tapping a result deep-links back into the app.
//

import CoreSpotlight
import Foundation
import os
import UniformTypeIdentifiers

// typealias so the compiler doesn't confuse SwiftData.Group with Swift.Group
typealias ExpenseGroup = SchemaV1.Group

private let logger = Logger(subsystem: "com.billsplitter", category: "spotlight")

enum SpotlightIndexer {

    // MARK: - Domain Identifiers

    /// Used to group all items by type for bulk deletion.
    private static let expenseDomain = "com.billsplitter.expense"
    private static let friendDomain  = "com.billsplitter.friend"
    private static let groupDomain   = "com.billsplitter.group"

    private static let bundleID = "project.ios.BillSplitter"

    // MARK: - Activity Types (for NSUserActivity engagement ranking)

    /// Activity types registered in Info.plist under NSUserActivityTypes.
    static let viewExpenseActivityType = "com.billsplitter.viewExpense"
    static let viewFriendActivityType  = "com.billsplitter.viewFriend"
    static let viewGroupActivityType   = "com.billsplitter.viewGroup"

    // MARK: - Unique Identifier Helpers

    /// Builds a Spotlight unique ID from a domain + UUID.
    static func expenseID(_ uuid: UUID) -> String { "\(expenseDomain).\(uuid.uuidString)" }
    static func friendID(_ uuid: UUID) -> String  { "\(friendDomain).\(uuid.uuidString)" }
    static func groupID(_ uuid: UUID) -> String   { "\(groupDomain).\(uuid.uuidString)" }

    // MARK: - Index Expenses

    /// Index a single expense as a searchable item.
    static func index(_ expense: Expense) {
        let attributes = buildExpenseAttributes(expense)

        let item = CSSearchableItem(
            uniqueIdentifier: expenseID(expense.id),
            domainIdentifier: expenseDomain,
            attributeSet: attributes
        )
        item.isUpdate = true
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 90, to: .now)

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                logger.error("Failed to index expense '\(expense.expenseDescription)': \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple expenses at once (used for bulk re-indexing).
    static func indexAll(_ expenses: [Expense]) {
        guard !expenses.isEmpty else { return }

        let items = expenses.map { expense -> CSSearchableItem in
            let attributes = buildExpenseAttributes(expense)

            let item = CSSearchableItem(
                uniqueIdentifier: expenseID(expense.id),
                domainIdentifier: expenseDomain,
                attributeSet: attributes
            )
            item.expirationDate = Calendar.current.date(byAdding: .day, value: 90, to: .now)
            item.isUpdate = true
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                logger.error("Failed to bulk index \(expenses.count) expenses: \(error.localizedDescription)")
            } else {
                logger.info("Indexed \(expenses.count) expenses in Spotlight")
            }
        }
    }

    /// Remove a single expense from the index.
    static func deindex(expenseID uuid: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [expenseID(uuid)]) { error in
            if let error {
                logger.error("Failed to deindex expense \(uuid): \(error.localizedDescription)")
            }
        }
    }

    /// Remove multiple expenses from the index.
    static func deindex(expenseIDs uuids: [UUID]) {
        guard !uuids.isEmpty else { return }
        let ids = uuids.map { expenseID($0) }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids) { error in
            if let error {
                logger.error("Failed to deindex \(uuids.count) expenses: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Index Friends

    /// Index a single friend as a searchable item.
    static func index(_ friend: User) {
        let attributes = buildFriendAttributes(friend)

        let item = CSSearchableItem(
            uniqueIdentifier: friendID(friend.id),
            domainIdentifier: friendDomain,
            attributeSet: attributes
        )
        item.isUpdate = true

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                logger.error("Failed to index friend '\(friend.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple friends at once (used for bulk re-indexing).
    static func indexAll(_ friends: [User]) {
        guard !friends.isEmpty else { return }

        let items = friends.map { friend -> CSSearchableItem in
            let attributes = buildFriendAttributes(friend)

            let item = CSSearchableItem(
                uniqueIdentifier: friendID(friend.id),
                domainIdentifier: friendDomain,
                attributeSet: attributes
            )
            item.isUpdate = true
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                logger.error("Failed to bulk index \(friends.count) friends: \(error.localizedDescription)")
            } else {
                logger.info("Indexed \(friends.count) friends in Spotlight")
            }
        }
    }

    /// Remove a single friend from the index.
    static func deindex(friendID uuid: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [friendID(uuid)]) { error in
            if let error {
                logger.error("Failed to deindex friend \(uuid): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Index Groups

    /// Index a single group as a searchable item.
    static func index(_ group: ExpenseGroup) {
        let attributes = buildGroupAttributes(group)

        let item = CSSearchableItem(
            uniqueIdentifier: groupID(group.id),
            domainIdentifier: groupDomain,
            attributeSet: attributes
        )
        item.isUpdate = true
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 90, to: .now)

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                logger.error("Failed to index group '\(group.name)': \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple groups at once (used for bulk re-indexing).
    static func indexAll(_ groups: [ExpenseGroup]) {
        guard !groups.isEmpty else { return }

        let items = groups.map { group -> CSSearchableItem in
            let attributes = buildGroupAttributes(group)

            let item = CSSearchableItem(
                uniqueIdentifier: groupID(group.id),
                domainIdentifier: groupDomain,
                attributeSet: attributes
            )
            item.isUpdate = true
            item.expirationDate = Calendar.current.date(byAdding: .day, value: 90, to: .now)
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                logger.error("Failed to bulk index \(groups.count) groups: \(error.localizedDescription)")
            } else {
                logger.info("Indexed \(groups.count) groups in Spotlight")
            }
        }
    }

    /// Remove a single group from the index.
    static func deindex(groupID uuid: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [groupID(uuid)]) { error in
            if let error {
                logger.error("Failed to deindex group \(uuid): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Bulk Operations

    /// Upsert all items into Spotlight on launch.
    static func reindexAll(expenses: [Expense], friends: [User], groups: [ExpenseGroup]) {
        indexAll(expenses)
        indexAll(friends)
        indexAll(groups)
    }

    /// Full wipe and re-index — call only after a data restore or migration.
    static func forceReindexAll(expenses: [Expense], friends: [User], groups: [ExpenseGroup]) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [expenseDomain, friendDomain, groupDomain]) { error in
            if let error {
                logger.error("Failed to clear Spotlight index: \(error.localizedDescription)")
                return
            }
            indexAll(expenses)
            indexAll(friends)
            indexAll(groups)
        }
    }

    /// Remove everything from the Spotlight index (used on Clear All Data).
    static func deleteAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [expenseDomain, friendDomain, groupDomain]) { error in
            if let error {
                logger.error("Failed to clear Spotlight index: \(error.localizedDescription)")
            } else {
                logger.info("Cleared all Spotlight items")
            }
        }
    }

    // MARK: - NSUserActivity Donation (Engagement Ranking)

    /// Donate a user activity for viewing an expense.
    /// Call this when the user taps into an expense detail.
    /// iOS uses engagement frequency to rank Spotlight results higher.
    static func donateExpenseActivity(_ expense: Expense) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewExpenseActivityType)
        activity.title = expense.expenseDescription
        activity.userInfo = [CSSearchableItemActivityIdentifier: expenseID(expense.id)]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = expenseID(expense.id)

        // Link activity to the CSSearchableItem so Spotlight deduplicates
        let attrs = buildExpenseAttributes(expense)
        attrs.relatedUniqueIdentifier = expenseID(expense.id)
        activity.contentAttributeSet = attrs
        return activity
    }

    /// Donate a user activity for viewing a group.
    static func donateGroupActivity(_ group: ExpenseGroup) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewGroupActivityType)
        activity.title = group.name
        activity.userInfo = [CSSearchableItemActivityIdentifier: groupID(group.id)]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = groupID(group.id)

        let attrs = buildGroupAttributes(group)
        attrs.relatedUniqueIdentifier = groupID(group.id)
        activity.contentAttributeSet = attrs
        return activity
    }

    /// Donate a user activity for viewing a friend.
    /// Call this when the user taps into a friend detail.
    static func donateFriendActivity(_ friend: User) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewFriendActivityType)
        activity.title = friend.name
        activity.userInfo = [CSSearchableItemActivityIdentifier: friendID(friend.id)]
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = friendID(friend.id)

        let attrs = buildFriendAttributes(friend)
        attrs.relatedUniqueIdentifier = friendID(friend.id)
        activity.contentAttributeSet = attrs
        return activity
    }

    // MARK: - Attribute Builders

    private static func buildExpenseAttributes(_ expense: Expense) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = expense.expenseDescription
        attributes.displayName = expense.expenseDescription
        attributes.contentDescription = buildExpenseDescription(expense)
        attributes.keywords = buildExpenseKeywords(expense)
        attributes.rankingHint = rankingScore(for: expense)
        attributes.creator = bundleID
        return attributes
    }

    private static func buildFriendAttributes(_ friend: User) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .contact)
        attributes.title = friend.name
        attributes.displayName = friend.name
        attributes.contentDescription = "Friend in BillSplitter"
        attributes.keywords = [friend.name, "friend", "BillSplitter", "balance", "split"]
        attributes.supportsNavigation = true
        attributes.creator = bundleID
        return attributes
    }

    private static func buildGroupAttributes(_ group: ExpenseGroup) -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = group.name
        attributes.displayName = group.name

        let memberCount = group.members?.count ?? 0
        let expenseCount = group.expenses?.count ?? 0
        attributes.contentDescription = "\(memberCount) members \u{00B7} \(expenseCount) expenses"

        var keywords: [String] = [group.name, "group", "BillSplitter"]
        if let members = group.members {
            keywords.append(contentsOf: members.map(\.name))
        }
        attributes.keywords = keywords
        attributes.supportsNavigation = true
        attributes.creator = bundleID
        return attributes
    }

    // MARK: - Description & Keywords

    private static func buildExpenseDescription(_ expense: Expense) -> String {
        let amount = CurrencyHelper.formatted(expense.amount)
        let category = expense.category.label
        let payer = expense.paidBy?.name ?? "Unknown"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: expense.date)

        return "\(amount) · \(category) · Paid by \(payer) · \(dateStr)"
    }

    private static func buildExpenseKeywords(_ expense: Expense) -> [String] {
        var keywords: [String] = [
            expense.expenseDescription,
            expense.category.label,
            expense.category.rawValue,
            "expense",
            "bill",
            "split",
            CurrencyHelper.formatted(expense.amount),
            String(format: "%.2f", expense.amount)
        ]
        if let payer = expense.paidBy?.name {
            keywords.append(payer)
        }
        if let participants = expense.participants {
            for p in participants {
                if let name = p.friend?.name {
                    keywords.append(name)
                }
            }
        }
        if let notes = expense.notes, !notes.isEmpty {
            keywords.append(notes)
        }
        return keywords
    }

    // MARK: - Ranking

    /// Computes a ranking score (0–100) for an expense.
    /// Recent and higher-value expenses rank higher in Spotlight.
    private static func rankingScore(for expense: Expense) -> NSNumber {
        // Recency: full score if today, decays over 30 days
        let age = Date.now.timeIntervalSince(expense.date)
        let daysSinceCreated = max(0, age / 86_400)
        let recencyScore = max(0, 1.0 - daysSinceCreated / 30.0)

        // Amount: higher amounts get a small boost (capped)
        let amountScore = min(expense.amount / 1000.0, 1.0)

        // Weighted: 70% recency + 30% amount
        let score = (recencyScore * 70) + (amountScore * 30)
        return NSNumber(value: score)
    }
}
