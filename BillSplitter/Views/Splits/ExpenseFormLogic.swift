//
//  ExpenseFormLogic.swift
//  BillSplitter
//
//  Pure-value helpers shared between AddExpenseView and EditExpenseView.
//  No SwiftUI dependency — just validation and participant math.
//

import Foundation

/// Namespace for expense form calculations used by both Add and Edit views.
enum ExpenseFormLogic {

    // MARK: - Participant List

    /// Builds the effective participant list based on group vs. manual selection.
    /// When a group is selected, `excludedGroupMemberIDs` allows individual
    /// members to be unchecked from that expense without leaving the group.
    static func participantList(
        selectedGroup: Group?,
        friends: [User],
        selectedParticipantIDs: Set<UUID>,
        currentUser: User?,
        excludedGroupMemberIDs: Set<UUID> = []
    ) -> [User] {
        if let g = selectedGroup {
            return (g.members ?? []).filter { !excludedGroupMemberIDs.contains($0.id) }
        }
        var list = friends.filter { selectedParticipantIDs.contains($0.id) }
        if let me = currentUser, !excludedGroupMemberIDs.contains(me.id) {
            list.insert(me, at: 0)
        }
        return list
    }

    // MARK: - Split Calculations

    static func equalShare(amount: Double, participantCount: Int) -> Double {
        guard participantCount > 0 else { return 0 }
        return amount / Double(participantCount)
    }

    static func customTotal(_ customAmounts: [UUID: String]) -> Double {
        customAmounts.values.compactMap { Double($0) }.reduce(0, +)
    }

    static func percentageTotal(_ percentages: [UUID: String]) -> Double {
        percentages.values.compactMap { Double($0) }.reduce(0, +)
    }

    // MARK: - Validation

    static func isValid(
        description: String,
        amount: Double,
        participantCount: Int,
        splitType: SplitType,
        customTotal: Double,
        percentageTotal: Double
    ) -> Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && amount > 0
            && participantCount >= 2
            && (splitType != .custom     || abs(customTotal - amount) < 0.01)
            && (splitType != .percentage || abs(percentageTotal - 100) < 0.01)
    }

    // MARK: - Field-Level Error Messages

    /// Returns an error string if the amount text is non-empty but invalid.
    static func amountError(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil } // not yet touched
        guard let value = Double(trimmed) else { return "Enter a valid number" }
        if value <= 0 { return "Amount must be greater than zero" }
        return nil
    }

    /// Returns an error string if the description is touched but empty.
    static func descriptionError(_ text: String, fieldTouched: Bool) -> String? {
        guard fieldTouched else { return nil }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Description is required"
        }
        return nil
    }

    /// Returns an error if fewer than 2 participants when the user has started filling the form.
    static func participantError(count: Int, formStarted: Bool) -> String? {
        guard formStarted, count < 2 else { return nil }
        return "Select at least one friend to split with"
    }

    /// Returns an error when custom amounts don't match the expense total.
    static func customSplitError(customTotal: Double, expenseAmount: Double) -> String? {
        guard expenseAmount > 0 else { return nil }
        let diff = abs(customTotal - expenseAmount)
        if diff >= 0.01 {
            let remaining = expenseAmount - customTotal
            if remaining > 0 {
                return "\(CurrencyHelper.symbol)\(String(format: "%.2f", remaining)) left to assign"
            } else {
                return "\(CurrencyHelper.symbol)\(String(format: "%.2f", -remaining)) over the total"
            }
        }
        return nil
    }

    /// Returns an error when percentages don't sum to 100%.
    static func percentageSplitError(percentageTotal: Double) -> String? {
        let diff = abs(percentageTotal - 100)
        if diff >= 0.01 {
            let remaining = 100 - percentageTotal
            if remaining > 0 {
                return "\(String(format: "%.1f", remaining))% left to assign"
            } else {
                return "\(String(format: "%.1f", -remaining))% over 100%"
            }
        }
        return nil
    }

    // MARK: - Build Participants

    /// Creates ExpenseParticipant objects with correct amountOwed based on split type.
    /// For equal splits, the last participant absorbs the rounding remainder
    /// so the split always sums to the exact expense amount.
    static func buildParticipants(
        from participantList: [User],
        splitType: SplitType,
        amount: Double,
        customAmounts: [UUID: String],
        percentages: [UUID: String]
    ) -> [ExpenseParticipant] {
        let count = participantList.count
        let baseShare = equalShare(amount: amount, participantCount: count)

        return participantList.enumerated().map { index, user in
            let ep = ExpenseParticipant(friend: user)
            switch splitType {
            case .equal:
                if index == count - 1 && count > 0 {
                    // Last participant absorbs rounding remainder
                    let othersTotal = (Double(count - 1) * (baseShare * 100).rounded() / 100)
                    ep.amountOwed = ((amount - othersTotal) * 100).rounded() / 100
                } else {
                    ep.amountOwed = (baseShare * 100).rounded() / 100
                }
            case .custom:
                ep.amountOwed = Double(customAmounts[user.id] ?? "0") ?? 0
            case .percentage:
                ep.amountOwed = amount * ((Double(percentages[user.id] ?? "0") ?? 0) / 100.0)
            }
            return ep
        }
    }
}
