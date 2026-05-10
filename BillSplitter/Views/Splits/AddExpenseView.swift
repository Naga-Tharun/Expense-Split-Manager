//
//  AddExpenseView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import os

struct AddExpenseView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name)  private var allUsers:  [User]
    @Query(sort: \Group.name) private var allGroups: [Group]

    @State private var expenseDescription       = ""
    @State private var amountText               = ""
    @State private var category: ExpenseCategory = .general
    @State private var date                     = Date()
    @State private var notes                    = ""
    @State private var splitType: SplitType     = .equal
    @State private var selectedGroupID: UUID?   = nil
    @State private var selectedParticipantIDs: Set<UUID> = []
    @State private var customAmounts:  [UUID: String]    = [:]
    @State private var percentages:    [UUID: String]    = [:]
    @State private var selectedPayerID: UUID?   = nil
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var receiptImageData: Data?  = nil
    @State private var isLoadingImage           = false
    @State private var saveError                = SaveErrorState()
    @State private var showSuccess              = false

    let preselectedGroup: Group?
    init(preselectedGroup: Group? = nil) { self.preselectedGroup = preselectedGroup }

    // MARK: - Computed (delegated to ExpenseFormLogic)

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }
    private var friends: [User] { CurrentUserManager.friends(from: allUsers) }
    private var amount: Double { Double(amountText) ?? 0 }

    private var selectedGroup: Group? {
        guard let id = selectedGroupID else { return nil }
        return allGroups.first { $0.id == id }
    }

    private var participantList: [User] {
        ExpenseFormLogic.participantList(
            selectedGroup: selectedGroup, friends: friends,
            selectedParticipantIDs: selectedParticipantIDs, currentUser: currentUser
        )
    }

    private var equalShare: Double {
        ExpenseFormLogic.equalShare(amount: amount, participantCount: participantList.count)
    }

    private var customTotal: Double    { ExpenseFormLogic.customTotal(customAmounts) }
    private var percentageTotal: Double { ExpenseFormLogic.percentageTotal(percentages) }

    private var isValid: Bool {
        ExpenseFormLogic.isValid(
            description: expenseDescription, amount: amount,
            participantCount: participantList.count, splitType: splitType,
            customTotal: customTotal, percentageTotal: percentageTotal
        )
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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExpense() }
                        .fontWeight(.semibold).disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                if let g = preselectedGroup { selectedGroupID = g.id }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Expense Added") { dismiss() }
        }
    }

    // MARK: - Save

    private static let logger = Logger(subsystem: "com.billsplitter", category: "expenses")

    private func saveExpense() {
        let expense = Expense(
            expenseDescription: expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            category: category,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            splitType: splitType
        )

        expense.receiptImageData = receiptImageData

        if let payerID = selectedPayerID,
           let payer = allUsers.first(where: { $0.id == payerID }) {
            expense.paidBy = payer
        } else {
            expense.paidBy = currentUser
        }

        if let group = selectedGroup {
            expense.group = group
            var existing = group.expenses ?? []
            existing.append(expense)
            group.expenses = existing
        }

        let participants = ExpenseFormLogic.buildParticipants(
            from: participantList, splitType: splitType,
            amount: amount, customAmounts: customAmounts, percentages: percentages
        )
        participants.forEach { modelContext.insert($0) }
        expense.participants = participants

        modelContext.insert(expense)
        saveError.perform { try modelContext.save() }
        if !saveError.showAlert {
            Self.logger.info("Expense created: '\(expenseDescription)' amount=\(amount, format: .fixed(precision: 2)), category=\(category.rawValue), split=\(splitType.rawValue), participants=\(participants.count)")
            showSuccess = true
        }
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
