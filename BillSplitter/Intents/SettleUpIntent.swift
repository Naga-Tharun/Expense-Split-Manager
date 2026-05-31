//
//  SettleUpIntent.swift
//  BillSplitter
//
//  App Intent for recording a settlement via Siri.
//  "Settle up with Alex for $50"
//

import AppIntents
import SwiftData
import Foundation
import os

private let settleUpLogger = Logger(subsystem: "com.billsplitter", category: "siri.settleUp")

struct SettleUpIntent: AppIntent {

    static var title: LocalizedStringResource = "Settle Up"

    static var description: IntentDescription {
        "Record a payment to settle a balance with a friend."
    }

    // MARK: - Parameters

    @Parameter(title: "Friend", description: "Who you're settling up with",
               requestValueDialog: "Who are you settling up with?")
    var friend: FriendEntity

    @Parameter(title: "Amount", description: "Amount to settle",
               requestValueDialog: "How much are you settling?")
    var amount: Double

    @Parameter(title: "Payment Method", default: .cash,
               requestValueDialog: "How are you paying?")
    var paymentMethod: PaymentMethodAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Settle \(\.$amount) with \(\.$friend)") {
            \.$paymentMethod
        }
    }

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            throw IntentError.invalidAmount
        }

        let capturedAmount = amount
        let capturedFriendID = friend.id
        let capturedMethod = paymentMethod

        let dialogText: String = try await MainActor.run {
            let container = try SharedContainer.makeModelContainer()
            let context = ModelContext(container)

            let allUsers    = try context.fetch(FetchDescriptor<User>())
            let expenses    = try context.fetch(FetchDescriptor<Expense>())
            let settlements = try context.fetch(FetchDescriptor<Settlement>())

            guard let currentUser = CurrentUserManager.currentUser(from: allUsers) else {
                throw IntentError.noCurrentUser
            }

            guard let friendUser = allUsers.first(where: { $0.id == capturedFriendID }) else {
                throw IntentError.friendNotFound
            }

            // Determine direction based on current balance
            guard let currentUserID = CurrentUserManager.currentUserID else {
                throw IntentError.noCurrentUser
            }

            let balance = BalanceCalculator.balance(
                for: friendUser.id,
                expenses: expenses,
                settlements: settlements,
                currentUserID: currentUserID
            )

            // Determine payer/payee:
            //   balance < 0 → I owe them → I'm paying (from: me, to: friend)
            //   balance > 0 → They owe me → They're paying (from: friend, to: me)
            //   balance ≈ 0 → Still allow settlement (from: me, to: friend)
            let fromUser: User
            let toUser: User

            if balance < -BalanceCalculator.epsilon {
                fromUser = currentUser
                toUser   = friendUser
            } else {
                fromUser = friendUser
                toUser   = currentUser
            }

            // Record settlement — mark confirmed so it applies to balances
            let settlement = Settlement(
                fromFriend: fromUser,
                toFriend: toUser,
                amount: capturedAmount,
                paymentMethod: capturedMethod.modelMethod,
                notes: "Settled via Siri",
                isConfirmed: true
            )
            context.insert(settlement)
            try context.save()

            DataService.reloadWidgets()

            let formatted = CurrencyHelper.formatted(capturedAmount)
            settleUpLogger.info("Siri: Settled \(formatted) — \(fromUser.name) → \(toUser.name)")

            let direction = fromUser.id == currentUser.id
                ? "You paid \(friendUser.name) \(formatted)"
                : "\(friendUser.name) paid you \(formatted)"

            return "Settled! \(direction). Balance updated."
        }

        return .result(dialog: "\(dialogText)")
    }
}

// MARK: - Payment Method App Enum

enum PaymentMethodAppEnum: String, AppEnum {
    case cash         = "cash"
    case upi          = "upi"
    case bankTransfer = "bank transfer"
    case card         = "card"
    case other        = "other"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Payment Method"
    }

    static var caseDisplayRepresentations: [PaymentMethodAppEnum: DisplayRepresentation] {
        [
            .cash:         "Cash",
            .upi:          "UPI",
            .bankTransfer: "Bank Transfer",
            .card:         "Card",
            .other:        "Other"
        ]
    }

    var modelMethod: PaymentMethod {
        PaymentMethod(rawValue: rawValue) ?? .cash
    }
}
