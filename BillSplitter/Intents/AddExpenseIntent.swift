//
//  AddExpenseIntent.swift
//  BillSplitter
//
//  App Intent for adding an expense via Siri.
//  "Add a $20 lunch expense with Alex"
//

import AppIntents
import SwiftData
import Foundation
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "siri.addExpense")

struct AddExpenseIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Expense"

    static var description: IntentDescription {
        "Add a new expense and split it equally with a friend."
    }

    // MARK: - Parameters

    @Parameter(title: "Description", description: "What the expense is for",
               requestValueDialog: "What is this expense for?")
    var expenseDescription: String

    @Parameter(title: "Amount", description: "Total expense amount",
               requestValueDialog: "How much was it?")
    var amount: Double

    @Parameter(title: "Friend", description: "Who to split with",
               requestValueDialog: "Who do you want to split with?")
    var friend: FriendEntity

    @Parameter(title: "Category", default: .general,
               requestValueDialog: "What category?")
    var category: CategoryAppEnum

    // MARK: - Confirmation

    static var isDiscoverable: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) \(\.$expenseDescription) with \(\.$friend)") {
            \.$category
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw IntentError.invalidAmount
        }

        guard !expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IntentError.emptyDescription
        }

        let capturedAmount = amount
        let capturedDesc = expenseDescription
        let capturedCategory = category
        let capturedFriendID = friend.id

        let dialogText: String = try await MainActor.run {
            let container = try SharedContainer.makeModelContainer()
            let context = ModelContext(container)

            // Resolve current user
            let allUsers = try context.fetch(FetchDescriptor<User>())
            guard let currentUser = CurrentUserManager.currentUser(from: allUsers) else {
                throw IntentError.noCurrentUser
            }

            // Resolve friend
            guard let friendUser = allUsers.first(where: { $0.id == capturedFriendID }) else {
                throw IntentError.friendNotFound
            }

            // Create expense
            let desc = capturedDesc.trimmingCharacters(in: .whitespacesAndNewlines)
            let expense = Expense(
                expenseDescription: desc,
                amount: capturedAmount,
                category: capturedCategory.modelCategory,
                date: .now,
                splitType: .equal
            )
            expense.paidBy = currentUser

            // Build equal-split participants (current user + friend)
            let participantList = [currentUser, friendUser]
            let participants = ExpenseFormLogic.buildParticipants(
                from: participantList,
                splitType: .equal,
                amount: capturedAmount,
                customAmounts: [:],
                percentages: [:]
            )
            participants.forEach { context.insert($0) }
            expense.participants = participants

            context.insert(expense)
            try context.save()

            // Post-save housekeeping
            DataService.reloadWidgets()
            SpotlightIndexer.index(expense)

            let formatted = CurrencyHelper.formatted(capturedAmount)
            let share = CurrencyHelper.formatted(capturedAmount / 2)
            logger.info("Siri: Added expense '\(desc)' for \(formatted) split with \(friendUser.name)")

            return "Done! Added \(formatted) for \(desc) — you and \(friendUser.name) each owe \(share)."
        }

        return .result(dialog: "\(dialogText)")
    }
}

// MARK: - Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount
    case emptyDescription
    case noCurrentUser
    case friendNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount:    return "The amount must be greater than zero."
        case .emptyDescription: return "Please provide a description for the expense."
        case .noCurrentUser:    return "Could not find your user profile. Please open BillSplitter first."
        case .friendNotFound:   return "That friend wasn't found in BillSplitter."
        }
    }
}
