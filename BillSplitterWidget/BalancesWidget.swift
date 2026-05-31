//
//  BalancesWidget.swift
//  BillSplitterWidget
//
//  Home screen widget showing top balances.
//  systemSmall  → net balance summary
//  systemMedium → top 3 balances (who owes you / you owe)
//

import WidgetKit
import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "widget")

// MARK: - Timeline Entry

struct BalancesEntry: TimelineEntry {
    let date: Date
    let netBalance: Double
    let totalOwedToYou: Double
    let totalYouOwe: Double
    let topBalances: [FriendBalance]
    let currencySymbol: String

    struct FriendBalance: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let amount: Double       // positive = owes you, negative = you owe
    }

    static let placeholder = BalancesEntry(
        date: .now,
        netBalance: 1250,
        totalOwedToYou: 2400,
        totalYouOwe: 1150,
        topBalances: [
            FriendBalance(id: UUID(), name: "Alice", colorHex: "#FF6B6B", amount: 1200),
            FriendBalance(id: UUID(), name: "Bob", colorHex: "#4ECDC4", amount: 800),
            FriendBalance(id: UUID(), name: "Charlie", colorHex: "#45B7D1", amount: -750),
        ],
        currencySymbol: "$"
    )

    static let empty = BalancesEntry(
        date: .now,
        netBalance: 0,
        totalOwedToYou: 0,
        totalYouOwe: 0,
        topBalances: [],
        currencySymbol: "$"
    )
}

// MARK: - Timeline Provider

struct BalancesProvider: TimelineProvider {

    func placeholder(in context: Context) -> BalancesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BalancesEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalancesEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh every 30 minutes — widgets update on a budget
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchEntry() -> BalancesEntry {
        let currencySymbol = widgetCurrencySymbol()
        let emptyEntry = BalancesEntry(
            date: .now, netBalance: 0, totalOwedToYou: 0,
            totalYouOwe: 0, topBalances: [], currencySymbol: currencySymbol
        )

        guard let container = try? SharedContainer.makeModelContainer(readOnly: true) else {
            logger.warning("Widget: failed to create ModelContainer")
            return emptyEntry
        }

        let context = ModelContext(container)

        guard let currentUserID = widgetCurrentUserID() else {
            logger.info("Widget: no current user ID found")
            return emptyEntry
        }

        let expenses    = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let settlements = (try? context.fetch(FetchDescriptor<Settlement>())) ?? []
        let allUsers    = (try? context.fetch(FetchDescriptor<User>())) ?? []

        let balances  = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: currentUserID
        )
        let owedToYou = BalanceCalculator.totalOwedToYou(balances)
        let youOwe    = BalanceCalculator.totalYouOwe(balances)

        // Sort by absolute balance descending, take top 4
        let sorted = balances
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(4)
            .compactMap { (friendID, amount) -> BalancesEntry.FriendBalance? in
                guard abs(amount) > BalanceCalculator.epsilon,
                      let user = allUsers.first(where: { $0.id == friendID }) else { return nil }
                return BalancesEntry.FriendBalance(
                    id: friendID,
                    name: user.name,
                    colorHex: user.profileColor,
                    amount: amount
                )
            }

        logger.info("Widget refreshed: \(expenses.count) expenses, \(sorted.count) balances")

        return BalancesEntry(
            date: .now,
            netBalance: owedToYou - youOwe,
            totalOwedToYou: owedToYou,
            totalYouOwe: youOwe,
            topBalances: Array(sorted),
            currencySymbol: currencySymbol
        )
    }

    // MARK: - Shared Defaults Helpers

    private func widgetCurrentUserID() -> UUID? {
        let raw = SharedContainer.defaults.string(forKey: CurrentUserManager.idKey)
            ?? UserDefaults.standard.string(forKey: CurrentUserManager.idKey)
        guard let raw else { return nil }
        return UUID(uuidString: raw)
    }

    private func widgetCurrencySymbol() -> String {
        let code = SharedContainer.defaults.string(forKey: "currency")
            ?? UserDefaults.standard.string(forKey: "currency")
        guard let code else { return "$" }
        return CurrencyHelper.symbol(for: code)
    }
}

// MARK: - Widget Definition

struct BalancesWidget: Widget {
    let kind = "com.billsplitter.balances"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalancesProvider()) { entry in
            BalancesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Balances")
        .description("See who owes you and who you owe at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
