//
//  FriendDetailView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct FriendDetailView: View {
    let friend: User

    @Environment(BalanceCache.self) private var cache
    @Query private var allExpenses:  [Expense]
    @Query private var settlements:  [Settlement]
    @Query(sort: \User.name) private var allUsers: [User]

    @State private var showSettleUp = false

    // Search & filter state
    @State private var searchText      = ""
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var sortOrder: ExpenseSortOption = .dateDesc

    private var currentUserID: UUID? { CurrentUserManager.currentUserID }
    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }

    private var sharedExpenses: [Expense] {
        allExpenses
            .filter { $0.participants?.contains { $0.friend?.id == friend.id } ?? false }
            .sorted { $0.date > $1.date }
    }

    private var filteredSharedExpenses: [Expense] {
        sharedExpenses.filtered(searchText: searchText, category: filterCategory, sortOrder: sortOrder)
    }

    private var balance: Double {
        cache.balance(for: friend.id)
    }

    private var friendSettlements: [Settlement] {
        settlements
            .filter { $0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            headerSection

            // Expenses (search + filter + sort built in)
            FilteredExpensesList(
                filtered: filteredSharedExpenses,
                total: sharedExpenses.count,
                headerTitle: "Shared Expenses",
                emptyTitle: "No Shared Expenses",
                emptyIcon: "cart",
                emptyMessage: "No expenses shared with \(friend.name) yet",
                searchText: $searchText,
                filterCategory: $filterCategory,
                sortOrder: $sortOrder
            )

            if !friendSettlements.isEmpty { settlementsSection }
        }
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshCache() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if balance < -0.01 {
                    Button("Settle Up") { showSettleUp = true }
                        .fontWeight(.semibold).tint(.cyan)
                }
            }
        }
        .sheet(isPresented: $showSettleUp) {
            SettleUpView(from: currentUser, to: friend, amount: abs(balance))
        }
        .onChange(of: showSettleUp) { _, showing in
            if !showing { refreshCache() }
        }
    }

    private func refreshCache() {
        guard let uid = currentUserID else { return }
        cache.refresh(expenses: allExpenses, settlements: settlements, currentUserID: uid)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(hex: friend.profileColor).opacity(0.2)).frame(width: 76, height: 76)
                    Text(String(friend.name.prefix(1)).uppercased())
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: friend.profileColor))
                }
                Text(friend.name).font(.title2).fontWeight(.bold)

                if abs(balance) < 0.01 {
                    Label("All settled up", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundColor(.green)
                } else {
                    VStack(spacing: 4) {
                        Text(balance > 0 ? "\(friend.name) owes you" : "You owe \(friend.name)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(CurrencyHelper.symbol)\(abs(balance), specifier: "%.2f")")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(balance > 0 ? .green : .red)
                    }
                    if balance < -0.01 {
                        Button {
                            showSettleUp = true
                        } label: {
                            Label("Settle Up", systemImage: "arrow.left.arrow.right.circle.fill")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent).tint(.cyan)
                    }
                }

                HStack(spacing: 24) {
                    miniStat("Expenses",    value: "\(sharedExpenses.count)")
                    miniStat("Settlements", value: "\(friendSettlements.count)")
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10).listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func miniStat(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).fontWeight(.bold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Settlements

    private var settlementsSection: some View {
        Section("Settlement History") {
            ForEach(friendSettlements) { s in
                HStack(spacing: 10) {
                    Image(systemName: s.paymentMethod.icon).font(.subheadline).foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(s.fromFriend?.id == currentUserID ? "You" : (s.fromFriend?.name ?? "?"))
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                            Text(s.toFriend?.id == currentUserID ? "You" : (s.toFriend?.name ?? "?"))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        Text(s.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(CurrencyHelper.symbol)\(s.amount, specifier: "%.2f")").fontWeight(.semibold).foregroundColor(.green)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

#Preview {
    let container = PreviewSampleData.container()
    let ctx       = container.mainContext
    let users     = (try? ctx.fetch(FetchDescriptor<User>())) ?? []
    let friend    = users.first { $0.name == "Alex" } ?? users.last!

    return NavigationStack {
        FriendDetailView(friend: friend)
    }
    .environment(BalanceCache())
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
