//
//  EditExpenseView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct EditExpenseView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name)  private var allUsers:  [User]
    @Query(sort: \Group.name) private var allGroups: [Group]

    @AppStorage(CurrentUserManager.idKey) private var currentUserIDString: String = ""

    let expense: Expense

    // Basic fields — pre-filled from expense
    @State private var expenseDescription: String
    @State private var amountText:          String
    @State private var category:            String
    @State private var date:                Date
    @State private var notes:               String

    // Split fields — pre-filled from expense
    @State private var splitType:              String
    @State private var selectedGroupID:        UUID?
    @State private var selectedParticipantIDs: Set<UUID>
    @State private var selectedPayerID:        UUID?
    @State private var customAmounts:          [UUID: String]
    @State private var percentages:            [UUID: String]

    init(expense: Expense) {
        self.expense = expense

        _expenseDescription = State(initialValue: expense.expenseDescription)
        _amountText         = State(initialValue: String(format: "%.2f", expense.amount))
        _category           = State(initialValue: expense.category)
        _date               = State(initialValue: expense.date)
        _notes              = State(initialValue: expense.notes ?? "")
        _splitType          = State(initialValue: expense.splitType)
        _selectedGroupID    = State(initialValue: expense.group?.id)
        _selectedPayerID    = State(initialValue: expense.paidBy?.id)

        // Pre-fill participant IDs from existing participants
        let participantIDs = Set(
            (expense.participants ?? []).compactMap { $0.friend?.id }
        )
        _selectedParticipantIDs = State(initialValue: participantIDs)

        // Pre-fill custom amounts and percentages
        var amounts:  [UUID: String] = [:]
        var percents: [UUID: String] = [:]
        for p in expense.participants ?? [] {
            guard let uid = p.friend?.id else { continue }
            amounts[uid] = String(format: "%.2f", p.amountOwed)
            if expense.amount > 0 {
                percents[uid] = String(format: "%.1f", p.amountOwed / expense.amount * 100)
            }
        }
        _customAmounts = State(initialValue: amounts)
        _percentages   = State(initialValue: percents)
    }

    // MARK: - Computed

    private var currentUser: User? {
        guard let uuid = UUID(uuidString: currentUserIDString) else { return nil }
        return allUsers.first { $0.id == uuid }
    }

    private var amount: Double { Double(amountText) ?? 0 }

    private var selectedGroup: Group? {
        guard let id = selectedGroupID else { return nil }
        return allGroups.first { $0.id == id }
    }

    private var friends: [User] {
        allUsers.filter { $0.id != currentUser?.id }
    }

    private var participantList: [User] {
        if let g = selectedGroup { return g.members ?? [] }
        var list = friends.filter { selectedParticipantIDs.contains($0.id) }
        if let me = currentUser { list.insert(me, at: 0) }
        return list
    }

    private var equalShare: Double {
        let n = Double(participantList.count)
        guard n > 0 else { return 0 }
        return amount / n
    }

    private var customTotal: Double {
        customAmounts.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var percentageTotal: Double {
        percentages.values.compactMap { Double($0) }.reduce(0, +)
    }

    private var isValid: Bool {
        !expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && amount > 0
            && participantList.count >= 2
            && (splitType != "custom"     || abs(customTotal - amount) < 0.01)
            && (splitType != "percentage" || abs(percentageTotal - 100) < 0.01)
    }

    private let categories: [(id: String, icon: String, label: String)] = [
        ("general",       "square.grid.2x2.fill", "General"),
        ("food",          "fork.knife",            "Food"),
        ("transport",     "car.fill",              "Transport"),
        ("accommodation", "house.fill",            "Stay"),
        ("entertainment", "theatermasks.fill",     "Fun"),
        ("shopping",      "cart.fill",             "Shopping"),
        ("utilities",     "bolt.fill",             "Utilities"),
        ("travel",        "airplane",              "Travel"),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                detailsSection
                splitWithSection
                paidBySection
                if participantList.count >= 2 { splitTypeSection }
                notesSection
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Sections (identical to AddExpenseView)

    private var amountSection: some View {
        Section {
            VStack(spacing: 6) {
                Text("Amount").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("₹").font(.system(size: 30, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("What's this for?", text: $expenseDescription)
                .textInputAutocapitalization(.sentences)
            DatePicker("Date", selection: $date, displayedComponents: .date)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.id) { cat in
                        Button { category = cat.id } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon).font(.title3)
                                Text(cat.label).font(.caption2)
                            }
                            .frame(width: 64, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(category == cat.id ? Color.cyan.opacity(0.18) : Color(.secondarySystemBackground)))
                            .foregroundColor(category == cat.id ? .cyan : .secondary)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(category == cat.id ? Color.cyan : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var splitWithSection: some View {
        Section("Split With") {
            // Group picker — same as AddExpenseView, including "No Group"
            Picker("Group", selection: $selectedGroupID) {
                Text("No Group").tag(UUID?.none)
                ForEach(allGroups) { g in
                    Label(g.name, systemImage: g.iconName).tag(Optional(g.id))
                }
            }

            if selectedGroupID == nil {
                // Current user — always locked in
                if let me = currentUser {
                    HStack(spacing: 12) {
                        avatarView(me)
                        Text("\(me.name) (you)").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cyan).font(.title3)
                    }
                }

                if friends.isEmpty {
                    Text("Add friends to split with them")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(friends) { friend in
                        let isSelected = selectedParticipantIDs.contains(friend.id)
                        Button {
                            if isSelected { selectedParticipantIDs.remove(friend.id) }
                            else          { selectedParticipantIDs.insert(friend.id) }
                        } label: {
                            HStack(spacing: 12) {
                                avatarView(friend)
                                Text(friend.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .cyan : .secondary).font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                let members = selectedGroup?.members ?? []
                if members.isEmpty {
                    Text("This group has no members yet").foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            avatarView(member)
                            Text(member.id == currentUser?.id ? "\(member.name) (you)" : member.name)
                        }
                    }
                }
            }
        }
    }

    private var paidBySection: some View {
        Section("Paid By") {
            Picker("Who paid?", selection: $selectedPayerID) {
                Text(currentUser.map { "\($0.name) (you)" } ?? "You")
                    .tag(UUID?.none)
                ForEach(participantList.filter { $0.id != currentUser?.id }) { p in
                    Text(p.name).tag(Optional(p.id))
                }
            }
        }
    }

    @ViewBuilder
    private var splitTypeSection: some View {
        Section("Split Type") {
            Picker("How to split", selection: $splitType) {
                Text("Equal").tag("equal")
                Text("Custom ₹").tag("custom")
                Text("By %").tag("percentage")
            }
            .pickerStyle(.segmented)

            switch splitType {
            case "equal":      equalSplitRows
            case "custom":     customSplitRows
            case "percentage": percentageSplitRows
            default:           EmptyView()
            }
        }
    }

    @ViewBuilder
    private var equalSplitRows: some View {
        ForEach(participantList) { p in
            HStack {
                avatarView(p)
                Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                Spacer()
                Text(amount > 0 ? "₹\(equalShare, specifier: "%.2f")" : "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var customSplitRows: some View {
        ForEach(participantList) { p in
            HStack(spacing: 8) {
                avatarView(p)
                Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                Spacer()
                Text("₹").foregroundStyle(.secondary)
                TextField("0.00", text: Binding(
                    get: { customAmounts[p.id] ?? "" },
                    set: { customAmounts[p.id] = $0 }
                ))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
            }
        }
        HStack {
            Text("Assigned").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("₹\(customTotal, specifier: "%.2f") / ₹\(amount, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(abs(customTotal - amount) < 0.01 ? .green : .red)
        }
    }

    @ViewBuilder
    private var percentageSplitRows: some View {
        ForEach(participantList) { p in
            HStack(spacing: 8) {
                avatarView(p)
                Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                Spacer()
                TextField("0", text: Binding(
                    get: { percentages[p.id] ?? "" },
                    set: { percentages[p.id] = $0 }
                ))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                Text("%").foregroundStyle(.secondary)
            }
        }
        HStack {
            Text("Total").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(percentageTotal, specifier: "%.1f")% / 100%")
                .font(.caption)
                .foregroundColor(abs(percentageTotal - 100) < 0.01 ? .green : .red)
        }
    }

    private var notesSection: some View {
        Section("Notes (optional)") {
            TextField("Add a note…", text: $notes, axis: .vertical).lineLimit(3...6)
        }
    }

    @ViewBuilder
    private func avatarView(_ user: User) -> some View {
        ZStack {
            Circle().fill(Color(hex: user.profileColor).opacity(0.2)).frame(width: 30, height: 30)
            Text(String(user.name.prefix(1))).font(.footnote).fontWeight(.semibold)
                .foregroundColor(Color(hex: user.profileColor))
        }
    }

    // MARK: - Save
    // Mutates the existing Expense in-place — SwiftData propagates
    // changes to every view that observes this object automatically.

    private func saveChanges() {
        // Basic fields
        expense.expenseDescription = expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount             = amount
        expense.category           = category
        expense.date               = date
        expense.notes              = notes.isEmpty ? nil : notes
        expense.splitType          = splitType

        // Payer — nil means current user paid
        expense.paidBy = selectedPayerID.flatMap { id in allUsers.first { $0.id == id } }

        // Group — handle moves between groups and to/from no-group
        let oldGroup = expense.group
        let newGroup = selectedGroupID.flatMap { id in allGroups.first { $0.id == id } }

        if oldGroup?.id != newGroup?.id {
            // Remove from old group's expenses list
            if let old = oldGroup {
                old.expenses = (old.expenses ?? []).filter { $0.id != expense.id }
            }
            // Add to new group's expenses list
            if let new = newGroup {
                var list = new.expenses ?? []
                list.append(expense)
                new.expenses = list
            }
            expense.group = newGroup
        }

        // Participants — delete old, insert fresh
        (expense.participants ?? []).forEach { modelContext.delete($0) }

        let newParticipants: [ExpenseParticipant] = participantList.map { user in
            let ep = ExpenseParticipant(friend: user)
            switch splitType {
            case "equal":
                ep.amountOwed = equalShare
            case "custom":
                ep.amountOwed = Double(customAmounts[user.id] ?? "0") ?? 0
            case "percentage":
                ep.amountOwed = amount * ((Double(percentages[user.id] ?? "0") ?? 0) / 100.0)
            default:
                ep.amountOwed = equalShare
            }
            return ep
        }
        newParticipants.forEach { modelContext.insert($0) }
        expense.participants = newParticipants

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let container = previewContainer()
    let context   = container.mainContext
    let allUsers  = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let me        = allUsers.first

    let friend  = User(name: "Alex", profileColor: "#007AFF")
    context.insert(friend)

    let expense = Expense(expenseDescription: "Team Lunch", amount: 1200, category: "food")
    let p1      = ExpenseParticipant(friend: me,     amountOwed: 600)
    let p2      = ExpenseParticipant(friend: friend, amountOwed: 600)
    context.insert(p1); context.insert(p2)
    expense.participants = [p1, p2]
    context.insert(expense)
    try? context.save()

    return EditExpenseView(expense: expense)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
