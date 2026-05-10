import SwiftUI
import SwiftData

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var selectedColor: Color = Color(hex: "#007AFF")
    @State private var saveError = SaveErrorState()
    
    // Simple palette of colors to choose from
    private let colorOptions: [String] = ["#007AFF", "#FF9500", "#34C759", "#FF3B30", "#5856D6", "#FF2D55"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Friend Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    
                    // Color picker grid
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Button {
                                    selectedColorHex = hex
                                    selectedColor = Color(hex: hex)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedColorHex == hex ? Color(hex: hex) : Color(.quaternaryLabel),
                                                    lineWidth: selectedColorHex == hex ? 3 : 1
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
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .saveErrorAlert($saveError)
        }
    }

    private func addFriend() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newUser = User(name: trimmedName, profileColor: selectedColorHex)
        modelContext.insert(newUser)
        saveError.perform { try modelContext.save() }
        if !saveError.showAlert { dismiss() }
    }
}

#Preview {
    AddFriendView()
        .withPreviewContainer()
}
