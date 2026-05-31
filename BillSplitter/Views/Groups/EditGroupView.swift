//
//  EditGroupView.swift
//  BillSplitter
//
//  Edit group details (name, description, icon, color) and manage members.
//  Shows a warning when removing a member who has unsettled balances.
//

import SwiftUI
import SwiftData

struct EditGroupView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name) private var allUsers: [User]
    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Query private var allSettlements: [Settlement]
    @Query private var allParticipants: [ExpenseParticipant]

    let group: Group

    @State private var name: String
    @State private var groupDescription: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var selectedColor: Color

    @State private var showIconPicker  = false
    @State private var saveError       = SaveErrorState()
    @State private var showSuccess     = false
    @State private var nameTouched     = false

    // Member removal with settle warning
    @State private var pendingRemoveMember: User?
    @State private var showSettleWarning   = false
    @State private var unsettledAmount: Double = 0

    private let colorOptions = ["#007AFF", "#FF9500", "#34C759", "#FF3B30", "#5856D6", "#FF2D55"]
    private let availableIcons = [
        "person.3.fill", "house.fill", "car.fill", "airplane",
        "fork.knife", "cart.fill", "theatermasks.fill", "sportscourt.fill",
        "beach.umbrella.fill", "suitcase.fill", "briefcase.fill", "backpack.fill"
    ]

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }
    private var members: [User] { group.members ?? [] }

    // Only show friends not already in the group
    private var availableFriends: [User] {
        let memberIDs = Set(members.map(\.id))
        return CurrentUserManager.friends(from: allUsers)
            .filter { !memberIDs.contains($0.id) }
    }

    @Query(sort: \Group.name) private var allGroups: [Group]

    private var nameError: String? {
        guard nameTouched else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Group name is required" }
        let duplicates = allGroups.filter { $0.id != group.id && $0.name.lowercased() == trimmed.lowercased() }
        if !duplicates.isEmpty { return "A group with this name already exists" }
        return nil
    }

    init(group: Group) {
        self.group = group
        _name             = State(initialValue: group.name)
        _groupDescription = State(initialValue: group.groupDescription ?? "")
        _selectedIcon     = State(initialValue: group.iconName)
        _selectedColorHex = State(initialValue: group.colorHex)
        _selectedColor    = State(initialValue: Color(hex: group.colorHex))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Icon preview
                Section {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColorHex).opacity(0.2))
                                .frame(width: 80, height: 80)
                            Image(systemName: selectedIcon)
                                .font(.system(size: 36))
                                .foregroundStyle(Color(hex: selectedColorHex))
                        }
                        Button("Change Icon") { showIconPicker = true }
                            .font(.subheadline).fontWeight(.semibold)
                            .buttonStyle(.bordered).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // Group details
                Section("Group Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Group Name", text: $name)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .onChange(of: name) { _, _ in nameTouched = true }
                        if let error = nameError {
                            FormErrorMessage(message: error, isVisible: true)
                        }
                    }
                    TextField("Description (optional)", text: $groupDescription)
                        .autocorrectionDisabled()
                }

                // Color picker
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button {
                                    selectedColorHex = hex
                                    selectedColor = Color(hex: hex)
                                } label: {
                                    Circle().fill(Color(hex: hex)).frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(
                                            selectedColorHex == hex ? Color(hex: hex) : Color(.quaternaryLabel),
                                            lineWidth: selectedColorHex == hex ? 3 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden().frame(width: 32, height: 32).clipShape(Circle())
                                .overlay(Circle().stroke(Color(.quaternaryLabel), lineWidth: 1))
                                .onChange(of: selectedColor) { _, newValue in
                                    selectedColorHex = newValue.toHexString()
                                }
                        }
                        .padding(.vertical, 4).padding(.horizontal, 8)
                    }
                }

                // Members
                Section {
                    if members.isEmpty {
                        Text("No members yet")
                            .foregroundStyle(.secondary).font(.subheadline)
                    } else {
                        ForEach(members) { member in
                            HStack(spacing: 12) {
                                AvatarView(user: member, size: 38)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(member.name).font(.body)
                                    if member.id == currentUser?.id {
                                        Text("you").font(.caption2).foregroundStyle(.cyan)
                                    }
                                }
                                Spacer()
                                if member.id != currentUser?.id {
                                    Button(role: .destructive) {
                                        attemptRemoveMember(member)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Quick-add available friends
                    if !availableFriends.isEmpty {
                        Divider()
                        ForEach(availableFriends) { friend in
                            Button {
                                addMember(friend)
                            } label: {
                                HStack(spacing: 12) {
                                    AvatarView(user: friend, size: 38)
                                    Text(friend.name).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.cyan).font(.title3)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Members")
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nameError != nil)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(availableIcons: availableIcons, selectedIcon: $selectedIcon) {
                    showIconPicker = false
                }
            }
            .alert("Unsettled Balance", isPresented: $showSettleWarning) {
                Button("OK", role: .cancel) {
                    pendingRemoveMember = nil
                }
            } message: {
                if let member = pendingRemoveMember {
                    Text("\(member.name) has an unsettled balance of \(CurrencyHelper.formattedAbs(unsettledAmount)). Please settle up before removing them from the group.")
                }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Group Updated") { dismiss() }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        group.name = trimmed
        group.groupDescription = groupDescription.isEmpty ? nil : groupDescription
        group.iconName = selectedIcon
        group.colorHex = selectedColorHex

        saveError.perform { try modelContext.save() }
        if !saveError.showAlert {
            Haptics.success()
            showSuccess = true
        }
    }

    private func addMember(_ user: User) {
        var updated = members
        updated.append(user)
        group.members = updated
        saveError.perform { try modelContext.save() }
        Haptics.light()
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
            // Has unsettled balance — show warning
            pendingRemoveMember = member
            unsettledAmount = balance
            showSettleWarning = true
        } else {
            // All settled — remove directly
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
    EditGroupView(group: Group(name: "Flatmates", iconName: "house.fill"))
        .withPreviewContainer()
}
