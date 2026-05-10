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
    static func participantList(
        selectedGroup: Group?,
        friends: [User],
        selectedParticipantIDs: Set<UUID>,
        currentUser: User?
    ) -> [User] {
        if let g = selectedGroup { return g.members ?? [] }
        var list = friends.filter { selectedParticipantIDs.contains($0.id) }
        if let me = currentUser { list.insert(me, at: 0) }
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
