//
//  AddSplitView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

// MARK: - AddSplitView

struct AddSplitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var showAddExpense = false
    @State private var showAddFriend  = false
    @State private var showAddGroup   = false
    @State private var showSettleUp   = false

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Actions") {
                    actionRow("Add Expense", icon: "plus.circle.fill",               color: .blue)   { showAddExpense = true }
                    actionRow("Add Friend",  icon: "person.badge.plus",              color: .green)  { showAddFriend  = true }
                    actionRow("New Group",   icon: "person.3.fill",                  color: .orange) { showAddGroup   = true }
                    actionRow("Settle Up",   icon: "arrow.left.arrow.right.circle.fill", color: .purple) { showSettleUp = true }
                }

                Section {
                    if expenses.isEmpty {
                        ContentUnavailableView(
                            "No Expenses Yet",
                            systemImage: "cart.badge.plus",
                            description: Text("Tap \"Add Expense\" to create your first split")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(expenses.prefix(50)) { expense in
                            NavigationLink {
                                ExpenseDetailView(expense: expense)
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { expenses[$0] }.forEach { modelContext.delete($0) }
                        }
                    }
                } header: {
                    HStack {
                        Text("All Expenses")
                        Spacer()
                        if !expenses.isEmpty {
                            Text("\(expenses.count) total").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Split")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddExpense = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showAddFriend)  { AddFriendView() }
            .sheet(isPresented: $showAddGroup)   { AddGroupView() }
            .sheet(isPresented: $showSettleUp)   { SettleUpView() }
        }
    }

    @ViewBuilder
    private func actionRow(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon).foregroundStyle(color)
        }
    }
}

// MARK: - ExpenseRow

struct ExpenseRow: View {
    let expense: Expense

    private var categoryIcon: String {
        ExpenseCategories.icon(for: expense.category)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color.cyan.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: categoryIcon).font(.subheadline).foregroundStyle(.cyan)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.expenseDescription).font(.headline).lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.paidBy != nil ? "\(expense.paidBy!.name) paid" : "You paid")
                    if let count = expense.participants?.count, count > 0 {
                        Text("· \(count) people")
                    }
                    Text("· \(expense.date.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(CurrencyHelper.symbol)\(expense.amount, specifier: "%.2f")")
                .font(.subheadline).fontWeight(.semibold)
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    AddSplitView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
