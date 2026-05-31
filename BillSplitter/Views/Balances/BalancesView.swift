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

    @State private var showSettleUp    = false
    @State private var showHistory     = false
    @State private var settleFrom:   User?   = nil
    @State private var settleTo:     User?   = nil
    @State private var settleAmount: Double? = nil
    @State private var showCelebration = false
    @State private var lastNetBalance: Double = 0

    private var currentUserID: UUID? { CurrentUserManager.currentUserID }
    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }

    private var friendsOnly: [User] {
        cache.sortedFriends(from: allUsers, currentUserID: currentUserID)
    }

    var body: some View {
        NavigationStack {
            if !cache.isLoaded {
                ProgressView("Calculating balances…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { refreshCache() }
            } else {
                balancesList
            }
        }
    }

    private var balancesList: some View {
        List {
            summaryCard
            individualBalances
            actionsSection
        }
        .refreshable {
            refreshCache()
            try? await Task.sleep(for: .milliseconds(300))
            Haptics.light()
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
        .celebrationOverlay(isPresented: showCelebration)
    }

    private func refreshCache() {
        guard let uid = currentUserID else { return }
        let oldNet = lastNetBalance
        cache.refresh(expenses: expenses, settlements: settlements, currentUserID: uid)
        let newNet = cache.netBalance
        lastNetBalance = newNet

        // Celebrate when transitioning from unsettled → all settled
        if abs(oldNet) > BalanceCalculator.epsilon && abs(newNet) < BalanceCalculator.epsilon && !friendsOnly.isEmpty {
            showCelebration = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                showCelebration = false
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
                        Text("\(CurrencyHelper.symbol)\(abs(cache.netBalance), specifier: "%.2f")")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(netBalanceColor)
                        Text(netBalanceLabel).font(.caption)
                            .foregroundColor(cache.netBalance == 0 ? .green : .secondary)
                    }
                    Divider()
                    HStack(spacing: 0) {
                        summaryPill(title: "You owe",     value: cache.totalYouOwe, color: cache.totalYouOwe > BalanceCalculator.epsilon ? .red   : .secondary)
                        Divider().frame(width: 1, height: 40).padding(.horizontal, 16)
                        summaryPill(title: "Owed to you", value: cache.totalOwedToYou, color: cache.totalOwedToYou > BalanceCalculator.epsilon ? .green : .secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
        }
        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var netBalanceColor: Color {
        if cache.netBalance > BalanceCalculator.epsilon  { return .green }
        if cache.netBalance < -BalanceCalculator.epsilon { return .red }
        return .primary
    }

    private var netBalanceLabel: String {
        if cache.netBalance > BalanceCalculator.epsilon  { return "You are owed overall" }
        if cache.netBalance < -BalanceCalculator.epsilon { return "You owe overall" }
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
                    description: Text("Add friends to start tracking balances")
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
            AvatarView(user: friend, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name).font(.body).fontWeight(.medium)
                if abs(balance) < BalanceCalculator.epsilon {
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
                    .foregroundColor(abs(balance) < BalanceCalculator.epsilon ? .secondary : balance > 0 ? .green : .red)

                if balance < -BalanceCalculator.epsilon {
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
