//
//  EditExpenseView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditExpenseView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name)  private var allUsers:  [User]
    @Query(sort: \Group.name) private var allGroups: [Group]

    let expense: Expense

    // Basic fields — pre-filled from expense
    @State private var expenseDescription: String
    @State private var amountText:          String
    @State private var category:            ExpenseCategory
    @State private var date:                Date
    @State private var notes:               String

    // Split fields — pre-filled from expense
    @State private var splitType:              SplitType
    @State private var selectedGroupID:        UUID?
    @State private var selectedParticipantIDs: Set<UUID>
    @State private var selectedPayerID:        UUID?
    @State private var customAmounts:          [UUID: String]
    @State private var percentages:            [UUID: String]
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var receiptImageData: Data?
    @State private var isLoadingImage = false

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
        _receiptImageData   = State(initialValue: expense.receiptImageData)

        let participantIDs = Set(
            (expense.participants ?? []).compactMap { $0.friend?.id }
        )
        _selectedParticipantIDs = State(initialValue: participantIDs)

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

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }
    private var friends: [User] { CurrentUserManager.friends(from: allUsers) }

    private var amount: Double { Double(amountText) ?? 0 }

    private var selectedGroup: Group? {
        guard let id = selectedGroupID else { return nil }
        return allGroups.first { $0.id == id }
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
            && (splitType != .custom     || abs(customTotal - amount) < 0.01)
            && (splitType != .percentage || abs(percentageTotal - 100) < 0.01)
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
                ExpenseFormSections.receiptSection(
                    selectedPhoto: $selectedPhoto,
                    receiptImageData: $receiptImageData,
                    isLoadingImage: $isLoadingImage
                )
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

    // MARK: - Save

    private func saveChanges() {
        expense.expenseDescription = expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.amount             = amount
        expense.category           = category
        expense.date               = date
        expense.notes              = notes.isEmpty ? nil : notes
        expense.splitType          = splitType
        expense.receiptImageData   = receiptImageData

        // Always set paidBy explicitly
        if let payerID = selectedPayerID,
           let payer = allUsers.first(where: { $0.id == payerID }) {
            expense.paidBy = payer
        } else {
            expense.paidBy = currentUser
        }

        let oldGroup = expense.group
        let newGroup = selectedGroupID.flatMap { id in allGroups.first { $0.id == id } }

        if oldGroup?.id != newGroup?.id {
            if let old = oldGroup {
                old.expenses = (old.expenses ?? []).filter { $0.id != expense.id }
            }
            if let new = newGroup {
                var list = new.expenses ?? []
                list.append(expense)
                new.expenses = list
            }
            expense.group = newGroup
        }

        (expense.participants ?? []).forEach { modelContext.delete($0) }

        let newParticipants: [ExpenseParticipant] = participantList.map { user in
            let ep = ExpenseParticipant(friend: user)
            switch splitType {
            case .equal:
                ep.amountOwed = equalShare
            case .custom:
                ep.amountOwed = Double(customAmounts[user.id] ?? "0") ?? 0
            case .percentage:
                ep.amountOwed = amount * ((Double(percentages[user.id] ?? "0") ?? 0) / 100.0)
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
    let container = PreviewSampleData.container()
    let context   = container.mainContext
    let allUsers  = (try? context.fetch(FetchDescriptor<User>())) ?? []
    let me        = allUsers.first

    let friend  = User(name: "Alex", profileColor: "#007AFF")
    context.insert(friend)

    let expense = Expense(expenseDescription: "Team Lunch", amount: 1200, category: .food)
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
