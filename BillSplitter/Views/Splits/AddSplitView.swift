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

    // Search & filter state
    @State private var searchText      = ""
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var sortOrder: ExpenseSortOption = .dateDesc
    @State private var showFilters     = false

    private var filteredExpenses: [Expense] {
        expenses.filtered(searchText: searchText, category: filterCategory, sortOrder: sortOrder)
    }

    var body: some View {
        NavigationStack {
            List {
                // Quick Actions
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        quickAction("Expense", icon: "plus.circle.fill", color: .blue)   { showAddExpense = true }
                        quickAction("Friend",  icon: "person.badge.plus", color: .green)  { showAddFriend  = true }
                        quickAction("Group",   icon: "person.3.fill", color: .orange)     { showAddGroup   = true }
                        quickAction("Settle",  icon: "arrow.left.arrow.right.circle.fill", color: .purple) { showSettleUp = true }
                    }
                    .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                // Spending insights
                if !expenses.isEmpty {
                    SpendingInsightsCard(expenses: expenses)
                }

                // Filter bar (collapsible)
                if !expenses.isEmpty {
                    ExpenseFilterBar(
                        filterCategory: $filterCategory,
                        sortOrder: $sortOrder,
                        isExpanded: $showFilters
                    )
                }

                // Expense list
                FilteredExpensesList(
                    filtered: filteredExpenses,
                    total: expenses.count,
                    headerTitle: "Expenses",
                    emptyTitle: "No Expenses Yet",
                    emptyIcon: "cart.badge.plus",
                    emptyMessage: "Tap \"+\" to create your first split"
                ) { offsets in
                    let toDelete = offsets.map { filteredExpenses[$0] }
                    toDelete.forEach { modelContext.delete($0) }
                }
            }
            .navigationTitle("Activity")
            .searchable(text: $searchText, prompt: "Search expenses…")
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

    // MARK: - Quick Action Button

    @ViewBuilder
    private func quickAction(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExpenseRow

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.icon)
                    .font(.subheadline)
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.expenseDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(expense.paidBy?.name ?? "You") · \(expense.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("\(CurrencyHelper.symbol)\(expense.amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AddSplitView()
        .environment(BalanceCache())
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
