//
//  ProfileView.swift
//  BillSplitter
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \User.name) private var allUsers:       [User]
    @Query private var expenses:                        [Expense]
    @Query private var groups:                          [Group]
    @Query private var settlements:                     [Settlement]
    @Query private var expenseParticipants:              [ExpenseParticipant]

    @AppStorage("currency")      private var currency: String            = "INR"

    @State private var isEditingName  = false
    @State private var draftName      = ""
    @State private var draftColorHex  = "#00BCD4"
    @State private var showClearAlert = false

    private var currentUser: User? { CurrentUserManager.currentUser(from: allUsers) }

    private var displayName:  String { currentUser?.name         ?? "You" }
    private var displayColor: String { currentUser?.profileColor ?? "#00BCD4" }
    private var friendCount:  Int    { CurrentUserManager.friends(from: allUsers).count }
    private var totalSplit:   Double { expenses.reduce(0) { $0 + $1.amount } }

    private let colorOptions = [
        "#007AFF", "#FF9500", "#34C759",
        "#FF3B30", "#5856D6", "#00BCD4", "#FF2D55"
    ]

    var body: some View {
        NavigationStack {
            Form {
                profileHeaderSection
                statsSection
                preferencesSection
                dangerSection
                aboutSection
            }
            .navigationTitle("Profile")
            .onAppear {
                draftColorHex = displayColor
                draftName     = displayName
            }
            .alert("Clear All Data", isPresented: $showClearAlert) {
                Button("Delete Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Deletes all expenses, groups, and settlements. Cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: draftColorHex).opacity(0.2))
                        .frame(width: 90, height: 90)
                    Text(String((isEditingName ? draftName : displayName).prefix(1)).uppercased())
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: draftColorHex))
                }

                if isEditingName {
                    editModeContent
                } else {
                    viewModeContent
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
        .listRowBackground(Color.clear)
    }

    private var editModeContent: some View {
        VStack(spacing: 12) {
            TextField("Your name", text: $draftName)
                .multilineTextAlignment(.center).font(.title3).fontWeight(.semibold)
                .textInputAutocapitalization(.words).onSubmit { saveProfile() }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal, 30)

            colorDotsView(binding: $draftColorHex, size: 28, applyImmediately: false)

            HStack(spacing: 20) {
                Button("Cancel") { cancelEdit() }.foregroundStyle(.secondary)
                Button("Save")   { saveProfile() }.fontWeight(.semibold).foregroundStyle(.cyan)
            }
            .font(.subheadline)
        }
    }

    private var viewModeContent: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(displayName).font(.title2).fontWeight(.bold)
                Text("Local Account").font(.subheadline).foregroundStyle(.secondary)
            }

            colorDotsView(binding: Binding(
                get: { displayColor },
                set: { applyColorChange($0) }
            ), size: 26, applyImmediately: true)

            Button("Edit Name") { startEdit() }
                .font(.subheadline).fontWeight(.medium).buttonStyle(.bordered).tint(.cyan)
        }
    }

    @ViewBuilder
    private func colorDotsView(binding: Binding<String>, size: CGFloat, applyImmediately: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(colorOptions, id: \.self) { hex in
                Button {
                    binding.wrappedValue = hex
                } label: {
                    ZStack {
                        Circle().fill(Color(hex: hex)).frame(width: size, height: size)
                        if binding.wrappedValue == hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.38)).fontWeight(.bold).foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(binding.wrappedValue == hex ? 1.15 : 1.0)
                .animation(.spring(duration: 0.2), value: binding.wrappedValue)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        Section("Your Activity") {
            statRow("Friends",     value: "\(friendCount)",      icon: "person.2.fill",         color: .cyan)
            statRow("Groups",      value: "\(groups.count)",     icon: "person.3.fill",         color: .orange)
            statRow("Expenses",    value: "\(expenses.count)",   icon: "list.bullet",           color: .blue)
            statRow("Settlements", value: "\(settlements.count)",icon: "checkmark.circle.fill", color: .green)
            statRow("Total Split", value: "\(CurrencyHelper.symbol)\(String(format: "%.2f", totalSplit))", icon: "banknote.fill", color: .purple)
        }
    }

    @ViewBuilder
    private func statRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Label { Text(label) } icon: { Image(systemName: icon).foregroundColor(color) }
            Spacer()
            Text(value).foregroundStyle(.secondary).fontWeight(.medium)
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker(selection: $currency) {
                Text("INR (₹)").tag("INR")
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
            } label: {
                Label("Currency", systemImage: "dollarsign.circle.fill")
            }
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { showClearAlert = true } label: {
                Label("Clear All Data", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack { Text("App"); Spacer(); Text("BillSplitter").foregroundStyle(.secondary) }
            HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }
        }
    }

    // MARK: - Actions

    private func startEdit() {
        draftName = displayName; draftColorHex = displayColor; isEditingName = true
    }

    private func cancelEdit() {
        draftColorHex = displayColor; isEditingName = false
    }

    private func saveProfile() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateCurrentUser(name: trimmed, color: draftColorHex)
        isEditingName = false
    }

    private func applyColorChange(_ hex: String) {
        draftColorHex = hex
        updateCurrentUser(name: displayName, color: hex)
    }

    /// Mutate the User record directly in SwiftData
    private func updateCurrentUser(name: String, color: String) {
        guard let user = currentUser else { return }
        user.name         = name
        user.profileColor = color
        UserDefaults.standard.set(name,  forKey: "userName")
        UserDefaults.standard.set(color, forKey: "userColor")
        try? modelContext.save()
    }

    private func clearAllData() {
        expenseParticipants.forEach { modelContext.delete($0) }
        expenses.forEach            { modelContext.delete($0) }
        groups.forEach              { modelContext.delete($0) }
        settlements.forEach         { modelContext.delete($0) }
        try? modelContext.save()
    }
}

#Preview {
    ProfileView()
        .modelContainer(PreviewSampleData.container())
        .preferredColorScheme(.dark)
}
