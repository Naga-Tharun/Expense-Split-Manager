//
//  BillSplitterShortcuts.swift
//  BillSplitter
//
//  Registers all App Intents with Siri via AppShortcutsProvider.
//  These appear in the Shortcuts app and can be triggered by voice.
//

import AppIntents

struct BillSplitterShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // MARK: - Open App

        AppShortcut(
            intent: OpenBillSplitterIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)",
                "Show \(.applicationName)"
            ],
            shortTitle: "Open App",
            systemImageName: "arrow.up.right.square"
        )

        // MARK: - Add Expense

        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Split a bill in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "New bill in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )

        // MARK: - Check Balance

        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "How much do I owe in \(.applicationName)",
                "Who owes me in \(.applicationName)",
                "Show balances in \(.applicationName)"
            ],
            shortTitle: "Check Balance",
            systemImageName: "indianrupeesign.circle.fill"
        )

        // MARK: - Settle Up

        AppShortcut(
            intent: SettleUpIntent(),
            phrases: [
                "Settle up in \(.applicationName)",
                "Record a payment in \(.applicationName)",
                "Clear my dues in \(.applicationName)"
            ],
            shortTitle: "Settle Up",
            systemImageName: "arrow.left.arrow.right.circle.fill"
        )
    }
}
