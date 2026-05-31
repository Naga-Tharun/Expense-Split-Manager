//
//  EditFriendView.swift
//  BillSplitter
//
//  Edit a friend's name and profile color.
//

import SwiftUI
import SwiftData

struct EditFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name) private var allUsers: [User]

    let friend: User

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedColor: Color
    @State private var saveError = SaveErrorState()
    @State private var showSuccess = false
    @State private var nameTouched = false

    private let colorOptions: [String] = ["#007AFF", "#FF9500", "#34C759", "#FF3B30", "#5856D6", "#FF2D55"]

    init(friend: User) {
        self.friend = friend
        _name = State(initialValue: friend.name)
        _selectedColorHex = State(initialValue: friend.profileColor)
        _selectedColor = State(initialValue: Color(hex: friend.profileColor))
    }

    private var nameError: String? {
        guard nameTouched else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name is required" }
        let existing = allUsers.filter { $0.id != friend.id }.map { $0.name.lowercased() }
        if existing.contains(trimmed.lowercased()) { return "A friend with this name already exists" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        AvatarView(user: friend, size: 64)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Friend Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: name) { _, _ in nameTouched = true }
                        if let error = nameError {
                            FormErrorMessage(message: error, isVisible: true)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button {
                                    selectedColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            selectedColorHex == hex
                                                ? AnyView(Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white))
                                                : AnyView(EmptyView())
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedColorHex == hex ? .white.opacity(0.6) : Color(.quaternaryLabel),
                                                    lineWidth: selectedColorHex == hex ? 2.5 : 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.quaternaryLabel), lineWidth: 1))
                                .onChange(of: selectedColor) { _, newValue in
                                    selectedColorHex = newValue.toHexString()
                                }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .navigationTitle("Edit Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFriend() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nameError != nil)
                }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Saved") { dismiss() }
        }
    }

    private func saveFriend() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        nameTouched = false

        friend.name = trimmed
        friend.profileColor = selectedColorHex

        saveError.perform { try modelContext.save() }
        if !saveError.showAlert {
            SpotlightIndexer.index(friend)
            showSuccess = true
        }
    }
}

#Preview {
    EditFriendView(friend: User(name: "Alex", profileColor: "#007AFF"))
        .withPreviewContainer()
}
