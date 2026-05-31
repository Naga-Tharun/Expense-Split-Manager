//
//  CheckBalanceIntent.swift
//  BillSplitter
//
//  App Intent for checking balances via Siri.
//  "How much do I owe?" or "Check my balance with Alex"
//

import AppIntents
import SwiftData
import Foundation
import os

private let checkBalanceLogger = Logger(subsystem: "com.billsplitter", category: "siri.checkBalance")

struct CheckBalanceIntent: AppIntent {

    static var title: LocalizedStringResource = "Check Balance"

    static var description: IntentDescription {
        "Check how much you owe or are owed — overall or with a specific friend."
    }

    // MARK: - Parameters

    @Parameter(title: "Friend", description: "Leave empty for overall balance", default: nil,
               requestValueDialog: "Which friend? Leave blank for overall balance.")
    var friend: FriendEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Check balance with \(\.$friend)")
    }

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let capturedFriend = friend

        let dialogText: String = try await MainActor.run {
            let container = try SharedContainer.makeModelContainer()
            let context = ModelContext(container)

            let allUsers    = try context.fetch(FetchDescriptor<User>())
            let expenses    = try context.fetch(FetchDescriptor<Expense>())
            let settlements = try context.fetch(FetchDescriptor<Settlement>())

            guard let currentUserID = CurrentUserManager.currentUserID else {
                throw IntentError.noCurrentUser
            }

            let balances = BalanceCalculator.netBalances(
                expenses: expenses,
                settlements: settlements,
                currentUserID: currentUserID
            )

            // Single-friend balance
            if let capturedFriend {
                guard let friendUser = allUsers.first(where: { $0.id == capturedFriend.id }) else {
                    throw IntentError.friendNotFound
                }

                let bal = balances[capturedFriend.id] ?? 0
                let response = Self.friendBalanceText(name: friendUser.name, balance: bal)
                checkBalanceLogger.info("Siri: Balance with \(friendUser.name) = \(bal, format: .fixed(precision: 2))")
                return response
            }

            // Overall summary
            let owedToYou = BalanceCalculator.totalOwedToYou(balances)
            let youOwe    = BalanceCalculator.totalYouOwe(balances)
            let response  = Self.overallBalanceText(
                owedToYou: owedToYou, youOwe: youOwe,
                balances: balances, allUsers: allUsers
            )
            checkBalanceLogger.info("Siri: Overall — owed to you: \(owedToYou, format: .fixed(precision: 2)), you owe: \(youOwe, format: .fixed(precision: 2))")
            return response
        }

        return .result(dialog: "\(dialogText)")
    }

    // MARK: - Formatting Helpers

    private static func friendBalanceText(name: String, balance: Double) -> String {
        if abs(balance) < BalanceCalculator.epsilon {
            return "You're all settled up with \(name)!"
        } else if balance > 0 {
            return "\(name) owes you \(CurrencyHelper.formattedAbs(balance))."
        } else {
            return "You owe \(name) \(CurrencyHelper.formattedAbs(balance))."
        }
    }

    private static func overallBalanceText(
        owedToYou: Double,
        youOwe: Double,
        balances: [UUID: Double],
        allUsers: [User]
    ) -> String {
        if owedToYou < BalanceCalculator.epsilon && youOwe < BalanceCalculator.epsilon {
            return "You're all settled up — no outstanding balances!"
        }

        var parts: [String] = []

        if owedToYou > BalanceCalculator.epsilon {
            parts.append("You are owed \(CurrencyHelper.formatted(owedToYou)) in total")
        }
        if youOwe > BalanceCalculator.epsilon {
            parts.append("You owe \(CurrencyHelper.formatted(youOwe)) in total")
        }

        // Mention the top friend by amount
        if let topEntry = balances.max(by: { abs($0.value) < abs($1.value) }),
           abs(topEntry.value) > BalanceCalculator.epsilon,
           let topFriend = allUsers.first(where: { $0.id == topEntry.key }) {
            let detail = friendBalanceText(name: topFriend.name, balance: topEntry.value)
            parts.append("Biggest: \(detail)")
        }

        return parts.joined(separator: ". ")
    }
}
