//
//  BalancesView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct BalancesView: View {
    @Query(sort: \User.name) private var allUsers:  [User]
    @Query private var expenses:                    [Expense]
    @Query private var settlements:                 [Settlement]

    @AppStorage("currentUserID") private var currentUserIDString: String = ""

    @State private var showSettleUp   = false
    @State private var showHistory    = false
    @State private var settleFrom:   User?   = nil
    @State private var settleTo:     User?   = nil
    @State private var settleAmount: Double? = nil

    private var currentUserID: UUID? { UUID(uuidString: currentUserIDString) }

    private var currentUser: User? {
        guard let uid = currentUserID else { return nil }
        return allUsers.first { $0.id == uid }
    }

    private var balances: [UUID: Double] {
        guard let uid = currentUserID else { return [:] }
        return BalanceCalculator.netBalances(
            expenses: expenses, settlements: settlements, currentUserID: uid
        )
    }

    private var totalOwed:   Double { BalanceCalculator.totalOwedToYou(balances) }
    private var totalYouOwe: Double { BalanceCalculator.totalYouOwe(balances) }
    private var netBalance:  Double { totalOwed - totalYouOwe }

    // Only show friends (exclude current user), sorted by abs balance
    private var friendsOnly: [User] {
        allUsers
            .filter { $0.id != currentUserID }
            .sorted { abs(balances[$0.id] ?? 0) > abs(balances[$1.id] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                summaryCard
                individualBalances
                actionsSection
            }
            .navigationTitle("Balances")
            .sheet(isPresented: $showSettleUp) {
                SettleUpView(from: settleFrom, to: settleTo, amount: settleAmount)
            }
            .sheet(isPresented: $showHistory) {
                PaymentHistoryView()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        Section {
            GroupBox {
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text("Net Balance").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(CurrencyHelper.symbol)\(abs(netBalance), specifier: "%.2f")")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(netBalanceColor)
                        Text(netBalanceLabel).font(.caption)
                            .foregroundColor(netBalance == 0 ? .green : .secondary)
                    }
                    Divider()
                    HStack(spacing: 0) {
                        summaryPill(title: "You owe",     value: totalYouOwe, color: totalYouOwe > 0.01 ? .red   : .secondary)
                        Divider().frame(width: 1, height: 40).padding(.horizontal, 16)
                        summaryPill(title: "Owed to you", value: totalOwed,   color: totalOwed   > 0.01 ? .green : .secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var netBalanceColor: Color {
        if netBalance > 0.01  { return .green }
        if netBalance < -0.01 { return .red }
        return .primary
    }

    private var netBalanceLabel: String {
        if netBalance > 0.01  { return "You are owed overall" }
        if netBalance < -0.01 { return "You owe overall" }
        return "All settled up ✓"
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
                    friendRow(friend: friend, balance: balances[friend.id] ?? 0)
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

                // Show Settle only when I owe them
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
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
