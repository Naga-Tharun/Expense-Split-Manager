//
//  AddGroupView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData
import UIKit

struct AddGroupView: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name)  private var allUsers:  [User]
    @Query(sort: \Group.name) private var allGroups: [Group]

    @State private var name             = ""
    @State private var selectedColorHex = "#007AFF"
    @State private var selectedColor    = Color(hex: "#007AFF")
    @State private var description      = ""
    @State private var selectedIcon     = "person.3.fill"
    @State private var showIconPicker   = false
    @State private var saveError        = SaveErrorState()
    @State private var showSuccess      = false
    @State private var selectedMemberIDs: Set<UUID> = []
    @State private var nameTouched      = false

    private let colorOptions   = ["#007AFF", "#FF9500", "#34C759", "#FF3B30", "#5856D6", "#FF2D55"]
    private let availableIcons = [
        "person.3.fill", "house.fill", "car.fill", "airplane",
        "fork.knife", "cart.fill", "theatermasks.fill", "sportscourt.fill",
        "beach.umbrella.fill", "suitcase.fill", "briefcase.fill", "backpack.fill"
    ]

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }
    private var friends: [User] { CurrentUserManager.friends(from: allUsers) }

    private var nameError: String? {
        guard nameTouched else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Group name is required" }
        let existing = allGroups.map { $0.name.lowercased() }
        if existing.contains(trimmed.lowercased()) { return "A group with this name already exists" }
        return nil
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
                        Button("Edit Icon") { showIconPicker = true }
                            .font(.subheadline).fontWeight(.semibold)
                            .buttonStyle(.bordered).padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Group Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Group Name", text: $name)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .onChange(of: name) { _, _ in nameTouched = true }
                        if let error = nameError {
                            FormErrorMessage(message: error, isVisible: true)
                        }
                    }
                    TextField("Description (optional)", text: $description)
                        .autocorrectionDisabled()
                }

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

                // Members — you are always shown locked-in at the top
                Section("Members") {
                    if let me = currentUser {
                        HStack(spacing: 12) {
                            AvatarView(user: me, size: 32)
                            Text("\(me.name) (you)")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.cyan).font(.title3)
                        }
                    }

                    ForEach(friends) { friend in
                        let isSelected = selectedMemberIDs.contains(friend.id)
                        Button {
                            if isSelected { selectedMemberIDs.remove(friend.id) }
                            else          { selectedMemberIDs.insert(friend.id) }
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(user: friend, size: 32)
                                Text(friend.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.cyan : Color.secondary)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createGroup() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nameError != nil)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(availableIcons: availableIcons, selectedIcon: $selectedIcon) {
                    showIconPicker = false
                }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Group Created") { dismiss() }
        }
    }

    private func createGroup() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Reset validation before save so the @Query update
        // doesn't briefly trigger a "name already exists" error
        nameTouched = false

        let newGroup = Group(
            name: trimmed,
            groupDescription: description.isEmpty ? nil : description,
            iconName: selectedIcon,
            colorHex: selectedColorHex
        )

        // Always add current user first, then any selected friends
        var members: [User] = []
        if let me = currentUser { members.append(me) }
        members += friends.filter { selectedMemberIDs.contains($0.id) }
        newGroup.members = members

        modelContext.insert(newGroup)
        saveError.perform { try modelContext.save() }
        if !saveError.showAlert { showSuccess = true }
    }
}

#Preview {
    AddGroupView()
        .withPreviewContainer()
}
