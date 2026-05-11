//
//  BalanceCache.swift
//  BillSplitter
//
//  An @Observable singleton that caches computed balances.
//  Views read from this instead of calling BalanceCalculator
//  as a computed property on every SwiftUI re-render.
//
//  Call `refresh()` whenever expenses or settlements change
//  (on appear, after save, after delete).
//

import SwiftData
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.billsplitter", category: "balances")

@Observable
final class BalanceCache {

    // MARK: - Published state

    private(set) var balances: [UUID: Double] = [:]
    private(set) var totalOwedToYou: Double = 0
    private(set) var totalYouOwe: Double = 0
    private(set) var isLoaded: Bool = false
    private(set) var lastRefreshed: Date? = nil
    var netBalance: Double { totalOwedToYou - totalYouOwe }

    // MARK: - Refresh

    /// Recalculate all balances. Call this:
    ///   - in .onAppear of top-level tabs (BalancesView, FriendsView)
    ///   - after saving / deleting an expense or settlement
    func refresh(
        expenses: [Expense],
        settlements: [Settlement],
        currentUserID: UUID
    ) {
        balances       = BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: currentUserID
        )
        totalOwedToYou = BalanceCalculator.totalOwedToYou(balances)
        totalYouOwe    = BalanceCalculator.totalYouOwe(balances)
        isLoaded       = true
        lastRefreshed  = Date()
        logger.info("Balances refreshed: \(self.balances.count) friends, net=\(self.netBalance, format: .fixed(precision: 2)), owed=\(self.totalOwedToYou, format: .fixed(precision: 2)), owe=\(self.totalYouOwe, format: .fixed(precision: 2))")
    }

    /// Balance for a single friend
    func balance(for friendID: UUID) -> Double {
        balances[friendID] ?? 0
    }

    /// Friends sorted by absolute balance (highest first), excluding current user
    func sortedFriends(from allUsers: [User], currentUserID: UUID?) -> [User] {
        allUsers
            .filter { $0.id != currentUserID }
            .sorted { abs(balances[$0.id] ?? 0) > abs(balances[$1.id] ?? 0) }
    }
}
