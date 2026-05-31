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
    @State private var saveError      = SaveErrorState()
    @State private var navigationPath = NavigationPath()

    // Search & filter state
    @State private var searchText      = ""
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var sortOrder: ExpenseSortOption = .dateDesc

    /// Deep link from Spotlight — when set, navigates to that expense's detail.
    @Binding var deepLinkExpenseID: UUID?

    init(deepLinkExpenseID: Binding<UUID?> = .constant(nil)) {
        _deepLinkExpenseID = deepLinkExpenseID
    }

    private var filteredExpenses: [Expense] {
        expenses.filtered(searchText: searchText, category: filterCategory, sortOrder: sortOrder)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Quick Actions
                Section {
                    HStack(spacing: 10) {
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

                // Expense list (search + filter + sort built in)
                FilteredExpensesList(
                    filtered: filteredExpenses,
                    total: expenses.count,
                    headerTitle: "Expenses",
                    emptyTitle: "No Expenses Yet",
                    emptyIcon: "cart.badge.plus",
                    emptyMessage: "Tap \"+\" to create your first split",
                    searchText: $searchText,
                    filterCategory: $filterCategory,
                    sortOrder: $sortOrder
                ) { offsets in
                    let toDelete = offsets.map { filteredExpenses[$0] }
                    saveError.perform {
                        try DataService.deleteExpenses(toDelete, context: modelContext)
                    }
                }
            }
            .refreshable {
                // SwiftData @Query auto-updates, but the gesture
                // gives tactile confirmation that data is current.
                try? await Task.sleep(for: .milliseconds(400))
                Haptics.light()
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ExportButton(expenses: expenses, scope: .all)
                }
            }
            .navigationDestination(for: Expense.self) { expense in
                ExpenseDetailView(expense: expense)
            }
            .onAppear {
                // Handle pending deep link on appear (in case onChange fired before view was ready)
                if let expenseID = deepLinkExpenseID,
                   let expense = expenses.first(where: { $0.id == expenseID }) {
                    navigationPath = NavigationPath()
                    navigationPath.append(expense)
                    deepLinkExpenseID = nil
                }
            }
            .onChange(of: deepLinkExpenseID) { _, newID in
                guard let expenseID = newID,
                      let expense = expenses.first(where: { $0.id == expenseID }) else { return }
                navigationPath = NavigationPath()
                navigationPath.append(expense)
                deepLinkExpenseID = nil
            }
            .sheet(isPresented: $showAddExpense) { AddExpenseView() }
            .sheet(isPresented: $showAddFriend)  { AddFriendView() }
            .sheet(isPresented: $showAddGroup)   { AddGroupView() }
            .sheet(isPresented: $showSettleUp)   { SettleUpView() }
            .saveErrorAlert($saveError)
        }
    }

    // MARK: - Quick Action Button

    @ViewBuilder
    private func quickAction(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
