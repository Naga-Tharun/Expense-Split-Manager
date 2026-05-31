//
//  EditExpenseView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var receiptImages: [Data]
    @State private var isLoadingImage = false
    @State private var showCamera    = false
    @State private var saveError      = SaveErrorState()
    @State private var showSuccess    = false
    @State private var editedFields: Set<String> = []
    @State private var excludedGroupMemberIDs: Set<UUID> = []
    @State private var participantSearchText   = ""

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
        _receiptImages      = State(initialValue: expense.receiptImages)

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
        // Pre-compute excluded group members (members in group but not in expense participants)
        if let group = expense.group {
            let allMemberIDs = Set((group.members ?? []).map(\.id))
            let excluded = allMemberIDs.subtracting(participantIDs)
            _excludedGroupMemberIDs = State(initialValue: excluded)
        }

        _customAmounts = State(initialValue: amounts)
        _percentages   = State(initialValue: percents)
    }

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
            selectedParticipantIDs: selectedParticipantIDs, currentUser: currentUser,
            excludedGroupMemberIDs: excludedGroupMemberIDs
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
                ExpenseFormSections.amountSection(amountText: $amountText, editedFields: $editedFields)
                ExpenseFormSections.detailsSection(description: $expenseDescription, date: $date, category: $category, editedFields: $editedFields)
                ExpenseFormSections.splitWithSection(
                    selectedGroupID: $selectedGroupID,
                    allGroups: allGroups,
                    selectedGroup: selectedGroup,
                    currentUser: currentUser,
                    friends: friends,
                    selectedParticipantIDs: $selectedParticipantIDs,
                    excludedGroupMemberIDs: $excludedGroupMemberIDs,
                    participantSearchText: $participantSearchText,
                    participantCount: participantList.count,
                    formStarted: !editedFields.isEmpty
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
                    selectedPhotos: $selectedPhotos,
                    receiptImages: $receiptImages,
                    isLoadingImage: $isLoadingImage,
                    showCamera: $showCamera
                )
            }
            .scrollDismissesKeyboard(.interactively)
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Saved") { dismiss() }
            .onAppear {
                if selectedPayerID == currentUser?.id {
                    selectedPayerID = nil
                }
            }
            .sheet(isPresented: $showCamera) {
                if CameraAccess.isAvailable {
                    CameraPicker(receiptImages: $receiptImages)
                        .ignoresSafeArea()
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                isLoadingImage = true
                Task { @MainActor in
                    for item in newItems {
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              !data.isEmpty,
                              let uiImage = UIImage(data: data),
                              uiImage.size.width > 0, uiImage.size.height > 0,
                              let jpeg = uiImage.jpegData(compressionQuality: 0.7)
                        else { continue }
                        receiptImages.append(jpeg)
                    }
                    isLoadingImage = false
                    selectedPhotos.removeAll()
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
        expense.receiptImages      = receiptImages

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

        let newParticipants = ExpenseFormLogic.buildParticipants(
            from: participantList, splitType: splitType,
            amount: amount, customAmounts: customAmounts, percentages: percentages
        )
        newParticipants.forEach { modelContext.insert($0) }
        expense.participants = newParticipants

        saveError.perform { try modelContext.save() }
        if !saveError.showAlert {
            DataService.reloadWidgets()
            SpotlightIndexer.index(expense)
            showSuccess = true
        }
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
