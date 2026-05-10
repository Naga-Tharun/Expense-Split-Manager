//
//  BalancesView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct BalancesView: View {
    @Environment(BalanceCache.self) private var cache
    @Query(sort: \User.name) private var allUsers:  [User]
    @Query private var expenses:                    [Expense]
    @Query private var settlements:                 [Settlement]

    @State private var showSettleUp   = false
    @State private var showHistory    = false
    @State private var settleFrom:   User?   = nil
    @State private var settleTo:     User?   = nil
    @State private var settleAmount: Double? = nil

    private var currentUserID: UUID? { CurrentUserManager.currentUserID }
    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }

    private var friendsOnly: [User] {
        cache.sortedFriends(from: allUsers, currentUserID: currentUserID)
    }

    var body: some View {
        NavigationStack {
            List {
                summaryCard
                individualBalances
                actionsSection
            }
            .navigationTitle("Balances")
            .onAppear { refreshCache() }
            .sheet(isPresented: $showSettleUp) {
                SettleUpView(from: settleFrom, to: settleTo, amount: settleAmount)
            }
            .onChange(of: showSettleUp) { _, showing in
                if !showing { refreshCache() }
            }
            .sheet(isPresented: $showHistory) {
                PaymentHistoryView()
            }
            .onChange(of: showHistory) { _, showing in
                if !showing { refreshCache() }
            }
        }
    }

    private func refreshCache() {
        guard let uid = currentUserID else { return }
        cache.refresh(expenses: expenses, settlements: settlements, currentUserID: uid)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        Section {
            GroupBox {
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text("Net Balance").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(CurrencyHelper.symbol)\(abs(cache.netBalance), specifier: "%.2f")")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(netBalanceColor)
                        Text(netBalanceLabel).font(.caption)
                            .foregroundColor(cache.netBalance == 0 ? .green : .secondary)
                    }
                    Divider()
                    HStack(spacing: 0) {
                        summaryPill(title: "You owe",     value: cache.totalYouOwe, color: cache.totalYouOwe > 0.01 ? .red   : .secondary)
                        Divider().frame(width: 1, height: 40).padding(.horizontal, 16)
                        summaryPill(title: "Owed to you", value: cache.totalOwedToYou, color: cache.totalOwedToYou > 0.01 ? .green : .secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var netBalanceColor: Color {
        if cache.netBalance > 0.01  { return .green }
        if cache.netBalance < -0.01 { return .red }
        return .primary
    }

    private var netBalanceLabel: String {
        if cache.netBalance > 0.01  { return "You are owed overall" }
        if cache.netBalance < -0.01 { return "You owe overall" }
        return "All settled up"
    }

    @ViewBuilder
    private func summaryPill(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(CurrencyHelper.symbol)\(value, specifier: "%.2f")").font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Individual Balances

    private var individualBalances: some View {
        Section("Individual Balances") {
            if friendsOnly.isEmpty {
                ContentUnavailableView(
                    "No Friends Yet",
                    systemImage: "person.2.fill",
                    description: Text("Add friends to track balances")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(friendsOnly) { friend in
                    friendRow(friend: friend, balance: cache.balance(for: friend.id))
                }
            }
        }
    }

    @ViewBuilder
    private func friendRow(friend: User, balance: Double) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: friend.profileColor).opacity(0.2)).frame(width: 46, height: 46)
                Text(String(friend.name.prefix(1))).font(.headline)
                    .foregroundColor(Color(hex: friend.profileColor))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name).font(.body).fontWeight(.medium)
                if abs(balance) < 0.01 {
                    Text("settled up").font(.caption).foregroundColor(.green)
                } else {
                    Text(balance > 0 ? "owes you" : "you owe")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(CurrencyHelper.symbol)\(abs(balance), specifier: "%.2f")")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(abs(balance) < 0.01 ? .secondary : balance > 0 ? .green : .red)

                if balance < -0.01 {
                    Button("Settle") {
                        settleFrom   = currentUser
                        settleTo     = friend
                        settleAmount = abs(balance)
                        showSettleUp = true
                    }
                    .font(.caption).fontWeight(.medium)
                    .buttonStyle(.bordered).controlSize(.mini).tint(.cyan)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Button {
                settleFrom = nil; settleTo = nil; settleAmount = nil
                showSettleUp = true
            } label: {
                Label("Record a Settlement", systemImage: "arrow.left.arrow.right.circle.fill")
            }
            Button { showHistory = true } label: {
                Label("Payment History (\(settlements.count))", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

#Preview {
    BalancesView()
        .environment(BalanceCache())
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
