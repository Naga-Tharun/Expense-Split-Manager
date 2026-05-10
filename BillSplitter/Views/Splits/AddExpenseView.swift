//
//  AddExpenseView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name)  private var allUsers:  [User]
    @Query(sort: \Group.name) private var allGroups: [Group]

    @AppStorage(CurrentUserManager.idKey) private var currentUserIDString: String = ""

    @State private var expenseDescription       = ""
    @State private var amountText               = ""
    @State private var category                 = "general"
    @State private var date                     = Date()
    @State private var notes                    = ""
    @State private var splitType: String        = "equal"
    @State private var selectedGroupID: UUID?   = nil
    @State private var selectedParticipantIDs: Set<UUID> = []
    @State private var customAmounts:  [UUID: String]    = [:]
    @State private var percentages:    [UUID: String]    = [:]
    @State private var selectedPayerID: UUID?   = nil

    let preselectedGroup: Group?
    init(preselectedGroup: Group? = nil) { self.preselectedGroup = preselectedGroup }

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                ExpenseFormSections.amountSection(amountText: $amountText)
                ExpenseFormSections.detailsSection(description: $expenseDescription, date: $date, category: $category)
                ExpenseFormSections.splitWithSection(
                    selectedGroupID: $selectedGroupID,
                    allGroups: allGroups,
                    selectedGroup: selectedGroup,
                    currentUser: currentUser,
                    friends: friends,
                    selectedParticipantIDs: $selectedParticipantIDs
                )
                ExpenseFormSections.paidBySection(
                    selectedPayerID: $selectedPayerID,
                    currentUser: currentUser,
                    participantList: participantList
                )
                if participantList.count >= 2 {
                    ExpenseFormSections.splitTypeSection(
                        splitType: $splitType,
                        participantList: participantList,
                        currentUser: currentUser,
                        amount: amount,
                        equalShare: equalShare,
                        customAmounts: $customAmounts,
                        customTotal: customTotal,
                        percentages: $percentages,
                        percentageTotal: percentageTotal
                    )
                }
                ExpenseFormSections.notesSection(notes: $notes)
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .fontWeight(.semibold).disabled(!isValid)
                }
            }
            .onAppear {
                if let g = preselectedGroup { selectedGroupID = g.id }
            }
        }
    }

    // MARK: - Save

    private func saveExpense() {
        let expense = Expense(
            expenseDescription: expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            category: category,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            splitType: splitType
        )

        if let payerID = selectedPayerID,
           let payer = allUsers.first(where: { $0.id == payerID }) {
            expense.paidBy = payer
        }

        if let group = selectedGroup {
            expense.group = group
            var existing = group.expenses ?? []
            existing.append(expense)
            group.expenses = existing
        }

        let participants = buildParticipants()
        participants.forEach { modelContext.insert($0) }
        expense.participants = participants

        modelContext.insert(expense)
        try? modelContext.save()
        dismiss()
    }

    private func buildParticipants() -> [ExpenseParticipant] {
        participantList.map { user in
            let ep = ExpenseParticipant(friend: user)
            switch splitType {
            case "equal":      ep.amountOwed = equalShare
            case "custom":     ep.amountOwed = Double(customAmounts[user.id] ?? "0") ?? 0
            case "percentage": ep.amountOwed = amount * ((Double(percentages[user.id] ?? "0") ?? 0) / 100.0)
            default:           ep.amountOwed = equalShare
            }
            return ep
        }
    }
}

#Preview {
    AddExpenseView()
        .withPreviewContainer()
}
