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

    /// Reads directly from UserDefaults — guaranteed set by BillSplitterApp.init()
    private var currentUser: User? {
        guard let raw  = UserDefaults.standard.string(forKey: "currentUserID"),
              let uuid = UUID(uuidString: raw) else { return nil }
        return allUsers.first { $0.id == uuid }
    }

    private var members: [User]    { group.members ?? [] }
    private var groupExpenses: [Expense] { (group.expenses ?? []).sorted { $0.date > $1.date } }
    private var totalExpenses: Double    { groupExpenses.reduce(0) { $0 + $1.amount } }

    var body: some View {
        List {
            statsRow
            membersSection
            expensesSection
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
    }

    /// Silently inserts current user as first member if they aren't already in the group.
    private func ensureCurrentUserIsMember() {
        guard let me = currentUser else { return }
        guard !members.contains(where: { $0.id == me.id }) else { return }
        group.members = [me] + members
        try? modelContext.save()
    }

    // MARK: - Stats

    private var statsRow: some View {
        Section {
            HStack(spacing: 8) {
                statCard(title: "Members",  value: "\(members.count)",       icon: "person.2.fill",               color: .cyan)
                statCard(title: "Expenses", value: "\(groupExpenses.count)", icon: "list.bullet.rectangle",       color: .orange)
                statCard(title: "Total",    value: "\(CurrencyHelper.symbol)\(Int(totalExpenses))", icon: "indianrupeesign.circle.fill", color: .green)
            }
        }
        .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline).fontWeight(.bold).minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.1)))
    }

    // MARK: - Members

    private var membersSection: some View {
        Section("Members") {
            if members.isEmpty {
                Text("No members yet").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: member.profileColor).opacity(0.2)).frame(width: 38, height: 38)
                            Text(String(member.name.prefix(1))).font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(Color(hex: member.profileColor))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.name).font(.body)
                            if member.id == currentUser?.id {
                                Text("you").font(.caption2).foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { members[$0] }
                    guard !toDelete.contains(where: { $0.id == currentUser?.id }) else { return }
                    var updated = members
                    updated.remove(atOffsets: offsets)
                    group.members = updated
                    try? modelContext.save()
                }
            }

            Button { showAddMember = true } label: {
                Label("Add Member", systemImage: "person.badge.plus").foregroundStyle(.cyan)
            }
        }
    }

    // MARK: - Expenses

    private var expensesSection: some View {
        Section {
            if groupExpenses.isEmpty {
                Text("No expenses yet").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(groupExpenses) { expense in
                    NavigationLink {
                        ExpenseDetailView(expense: expense)
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                }
                .onDelete { offsets in
                    offsets.map { groupExpenses[$0] }.forEach { modelContext.delete($0) }
                    try? modelContext.save()
                }
            }
            Button { showAddExpense = true } label: {
                Label("Add Expense", systemImage: "plus.circle.fill").foregroundStyle(.cyan)
            }
        } header: {
            HStack {
                Text("Expenses")
                Spacer()
                if !groupExpenses.isEmpty {
                    Text("\(CurrencyHelper.symbol)\(totalExpenses, specifier: "%.2f") total").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - AddMemberSheet

struct AddMemberSheet: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext
    let group:         Group
    let allUsers:      [User]
    let currentUserID: UUID?

    private var nonMembers: [User] {
        let memberIDs = Set((group.members ?? []).map { $0.id })
        return allUsers.filter { !memberIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            memberListContent
                .navigationTitle("Add Member")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
        }
    }

    @ViewBuilder
    private var memberListContent: some View {
        if nonMembers.isEmpty {
            ContentUnavailableView(
                "Everyone's In",
                systemImage: "person.badge.checkmark.fill",
                description: Text("All friends are already members")
            )
        } else {
            List(nonMembers) { user in
                Button {
                    var members = group.members ?? []
                    members.append(user)
                    group.members = members
                    try? modelContext.save()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: user.profileColor).opacity(0.2)).frame(width: 42, height: 42)
                            Text(String(user.name.prefix(1))).font(.headline)
                                .foregroundStyle(Color(hex: user.profileColor))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.name).foregroundStyle(.primary).font(.body)
                            if user.id == currentUserID {
                                Text("you").font(.caption2).foregroundStyle(.cyan)
                            }
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.cyan)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: Group(name: "Flatmates", iconName: "house.fill"))
    }
    .withPreviewContainer()
}
