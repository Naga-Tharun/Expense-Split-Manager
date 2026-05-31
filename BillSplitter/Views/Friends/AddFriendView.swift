import SwiftUI
import SwiftData
import UIKit

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name) private var allUsers: [User]

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var selectedColor: Color = Color(hex: "#007AFF")
    @State private var saveError = SaveErrorState()
    @State private var showSuccess = false
    @State private var nameTouched = false
    
    // Simple palette of colors to choose from
    private let colorOptions: [String] = ["#007AFF", "#FF9500", "#34C759", "#FF3B30", "#5856D6", "#FF2D55"]

    private var nameError: String? {
        guard nameTouched else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name is required" }
        let existing = allUsers.map { $0.name.lowercased() }
        if existing.contains(trimmed.lowercased()) { return "A friend with this name already exists" }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                    
                    // Color picker grid
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
                                .accessibilityLabel(Text(hex))
                            }
                            
                            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)
                                )
                                .accessibilityLabel(Text("Custom Color"))
                                .onChange(of: selectedColor) { oldValue, newValue in
                                    selectedColorHex = newValue.toHexString()
                                }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addFriend() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nameError != nil)
                }
            }
            .saveErrorAlert($saveError)
            .successOverlay(isPresented: $showSuccess, message: "Friend Added") { dismiss() }
        }
    }

    private func addFriend() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        // Reset validation before save so the @Query update
        // doesn't briefly trigger a "name already exists" error
        nameTouched = false

        saveError.perform {
            try DataService.addFriend(name: trimmedName, profileColor: selectedColorHex, context: modelContext)
        }
        if !saveError.showAlert { showSuccess = true }
    }
}

#Preview {
    AddFriendView()
        .withPreviewContainer()
}
