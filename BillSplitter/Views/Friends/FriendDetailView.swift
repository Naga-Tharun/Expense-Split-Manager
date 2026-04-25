//
//  FriendDetailView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct FriendDetailView: View {
    let friend: User

    @Query private var allExpenses:  [Expense]
    @Query private var settlements:  [Settlement]
    @Query(sort: \User.name) private var allUsers: [User]

    @AppStorage("currentUserID") private var currentUserIDString: String = ""
    @State private var showSettleUp = false

    private var currentUserID: UUID? { UUID(uuidString: currentUserIDString) }

    private var currentUser: User? {
        guard let uid = currentUserID else { return nil }
        return allUsers.first { $0.id == uid }
    }

    private var sharedExpenses: [Expense] {
        allExpenses
            .filter { $0.participants?.contains { $0.friend?.id == friend.id } ?? false }
            .sorted { $0.date > $1.date }
    }

    private var balance: Double {
        guard let uid = currentUserID else { return 0 }
        return BalanceCalculator.netBalances(
            expenses: allExpenses, settlements: settlements, currentUserID: uid
        )[friend.id] ?? 0
    }

    private var friendSettlements: [Settlement] {
        settlements
            .filter { $0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            headerSection
            expensesSection
            if !friendSettlements.isEmpty { settlementsSection }
        }
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if balance < -0.01 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settle Up") { showSettleUp = true }
                        .fontWeight(.semibold).tint(.cyan)
                }
            }
        }
        .sheet(isPresented: $showSettleUp) {
            SettleUpView(from: currentUser, to: friend, amount: abs(balance))
        }
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
                        Text("₹\(abs(balance), specifier: "%.2f")")
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

    // MARK: - Expenses

    private var expensesSection: some View {
        Section("Shared Expenses") {
            if sharedExpenses.isEmpty {
                Text("No shared expenses yet").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(sharedExpenses) { expense in
                    NavigationLink {
                        ExpenseDetailView(expense: expense)
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                }
            }
        }
    }

    // MARK: - Settlements

    private var settlementsSection: some View {
        Section("Settlement History") {
            ForEach(friendSettlements) { s in
                HStack(spacing: 10) {
                    Image(systemName: "banknote.fill").font(.subheadline).foregroundColor(.green)
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
                    Text("₹\(s.amount, specifier: "%.2f")").fontWeight(.semibold).foregroundColor(.green)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FriendDetailView(friend: User(name: "Alex", profileColor: "#007AFF"))
    }
    .withPreviewContainer()
}
