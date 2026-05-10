//
//  GroupDetailView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct GroupDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let group: Group

    @Query(sort: \User.name) private var allUsers: [User]

    @State private var showAddMember  = false
    @State private var showAddExpense = false
    @State private var showSettleUp   = false
    @State private var saveError      = SaveErrorState()

    // Search & filter state
    @State private var searchText      = ""
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var sortOrder: ExpenseSortOption = .dateDesc

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }

    private var members: [User]         { group.members ?? [] }
    private var groupExpenses: [Expense] { (group.expenses ?? []).sorted { $0.date > $1.date } }
    private var totalExpenses: Double    { groupExpenses.reduce(0) { $0 + $1.amount } }

    private var filteredExpenses: [Expense] {
        groupExpenses.filtered(searchText: searchText, category: filterCategory, sortOrder: sortOrder)
    }

    var body: some View {
        List {
            GroupStatsRow(
                memberCount: members.count,
                expenseCount: groupExpenses.count,
                totalSpend: totalExpenses
            )

            GroupMembersSection(
                members: members,
                currentUserID: currentUser?.id,
                onRemove: removeMember,
                onAddMember: { showAddMember = true }
            )

            FilteredExpensesList(
                filtered: filteredExpenses,
                total: groupExpenses.count,
                headerTitle: "Expenses",
                emptyTitle: "No Expenses Yet",
                emptyIcon: "cart.badge.plus",
                emptyMessage: "Add an expense to start tracking",
                searchText: $searchText,
                filterCategory: $filterCategory,
                sortOrder: $sortOrder
            ) { offsets in
                let toDelete = offsets.map { filteredExpenses[$0] }
                saveError.perform {
                    try DataService.deleteExpenses(toDelete, context: modelContext)
                }
            }

            Section {
                Button { showAddExpense = true } label: {
                    Label("Add Expense", systemImage: "plus.circle.fill").foregroundStyle(.cyan)
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showAddExpense = true } label: {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                    }
                    Button { showAddMember = true } label: {
                        Label("Add Member", systemImage: "person.badge.plus")
                    }
                    Button { showSettleUp = true } label: {
                        Label("Settle Up", systemImage: "arrow.left.arrow.right.circle.fill")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onAppear { ensureCurrentUserIsMember() }
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(group: group, allUsers: allUsers, currentUserID: currentUser?.id)
        }
        .sheet(isPresented: $showAddExpense) { AddExpenseView(preselectedGroup: group) }
        .sheet(isPresented: $showSettleUp)   { SettleUpView() }
        .saveErrorAlert($saveError)
    }

    // MARK: - Actions

    private func ensureCurrentUserIsMember() {
        guard let me = currentUser else { return }
        guard !members.contains(where: { $0.id == me.id }) else { return }
        group.members = [me] + members
        saveError.perform { try modelContext.save() }
    }

    private func removeMember(_ offsets: IndexSet) {
        let toDelete = offsets.map { members[$0] }
        guard !toDelete.contains(where: { $0.id == currentUser?.id }) else { return }
        var updated = members
        updated.remove(atOffsets: offsets)
        group.members = updated
        saveError.perform { try modelContext.save() }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: Group(name: "Flatmates", iconName: "house.fill"))
    }
    .withPreviewContainer()
}
