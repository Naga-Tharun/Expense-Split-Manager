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
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query private var allSettlements: [Settlement]

    @State private var showAddMember  = false
    @State private var showAddExpense = false
    @State private var showSettleUp   = false
    @State private var showEditGroup  = false
    @State private var saveError      = SaveErrorState()

    // Member removal with settle warning
    @State private var pendingRemoveMember: User?
    @State private var showSettleWarning   = false
    @State private var unsettledAmount: Double = 0

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
        .refreshable {
            try? await Task.sleep(for: .milliseconds(400))
            Haptics.light()
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditGroup = true } label: {
                        Label("Edit Group", systemImage: "pencil")
                    }
                    Divider()
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
        .sheet(isPresented: $showEditGroup)  { EditGroupView(group: group) }
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(group: group, allUsers: allUsers, currentUserID: currentUser?.id)
        }
        .sheet(isPresented: $showAddExpense) { AddExpenseView(preselectedGroup: group) }
        .sheet(isPresented: $showSettleUp)   { SettleUpView() }
        .alert("Unsettled Balance", isPresented: $showSettleWarning) {
            Button("Settle Up") {
                pendingRemoveMember = nil
                showSettleUp = true
            }
            Button("OK", role: .cancel) {
                pendingRemoveMember = nil
            }
        } message: {
            if let member = pendingRemoveMember {
                Text("\(member.name) has an unsettled balance of \(CurrencyHelper.formattedAbs(unsettledAmount)). Please settle up before removing them from the group.")
            }
        }
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
        let toRemove = offsets.map { members[$0] }
        // Don't allow removing yourself
        guard !toRemove.contains(where: { $0.id == currentUser?.id }) else { return }

        guard let member = toRemove.first else { return }
        attemptRemoveMember(member)
    }

    /// Check if member has unsettled balance before removing.
    private func attemptRemoveMember(_ member: User) {
        guard let currentUserID = currentUser?.id else {
            confirmRemoveMember(member)
            return
        }

        let balance = BalanceCalculator.balance(
            for: member.id,
            expenses: allExpenses,
            settlements: allSettlements,
            currentUserID: currentUserID
        )

        if abs(balance) > BalanceCalculator.epsilon {
            pendingRemoveMember = member
            unsettledAmount = balance
            showSettleWarning = true
        } else {
            confirmRemoveMember(member)
        }
    }

    private func confirmRemoveMember(_ member: User) {
        var updated = members
        updated.removeAll { $0.id == member.id }
        group.members = updated
        saveError.perform { try modelContext.save() }
        pendingRemoveMember = nil
        Haptics.warning()
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: Group(name: "Flatmates", iconName: "house.fill"))
    }
    .withPreviewContainer()
}
