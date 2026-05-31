//
//  ExpenseFormSections.swift
//  BillSplitter
//
//  Shared form sections extracted from AddExpenseView & EditExpenseView
//  to eliminate duplicated code.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Shared Form Sections

/// Reusable sections shared between Add and Edit expense views.
/// Requires the host view to supply its state via bindings.
struct ExpenseFormSections {

    // MARK: - Amount Section

    @ViewBuilder
    static func amountSection(
        amountText: Binding<String>,
        editedFields: Binding<Set<String>>
    ) -> some View {
        Section {
            VStack(spacing: 6) {
                Text("Amount").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(CurrencyHelper.symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .onChange(of: amountText.wrappedValue) { _, _ in
                            editedFields.wrappedValue.insert("amount")
                        }
                }
                if let error = ExpenseFormLogic.amountError(amountText.wrappedValue),
                   editedFields.wrappedValue.contains("amount") {
                    FormErrorMessage(message: error, isVisible: true)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    static func detailsSection(
        description: Binding<String>,
        date: Binding<Date>,
        category: Binding<ExpenseCategory>,
        editedFields: Binding<Set<String>>
    ) -> some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("What's this for?", text: description)
                    .textInputAutocapitalization(.sentences)
                    .onChange(of: description.wrappedValue) { _, _ in
                        editedFields.wrappedValue.insert("description")
                    }
                if let error = ExpenseFormLogic.descriptionError(
                    description.wrappedValue,
                    fieldTouched: editedFields.wrappedValue.contains("description")
                ) {
                    FormErrorMessage(message: error, isVisible: true)
                }
            }
            DatePicker("Date", selection: date, displayedComponents: .date)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategory.allCases) { cat in
                        Button { category.wrappedValue = cat } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon).font(.title3)
                                Text(cat.label).font(.caption2)
                            }
                            .frame(width: 64, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(category.wrappedValue == cat
                                      ? Color.cyan.opacity(0.18)
                                      : Color(.secondarySystemBackground)))
                            .foregroundColor(category.wrappedValue == cat ? .cyan : .secondary)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(category.wrappedValue == cat ? Color.cyan : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(cat.label) category")
                        .accessibilityAddTraits(category.wrappedValue == cat ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Split With Section

    @ViewBuilder
    static func splitWithSection(
        selectedGroupID: Binding<UUID?>,
        allGroups: [Group],
        selectedGroup: Group?,
        currentUser: User?,
        friends: [User],
        selectedParticipantIDs: Binding<Set<UUID>>,
        excludedGroupMemberIDs: Binding<Set<UUID>>,
        participantSearchText: Binding<String>,
        participantCount: Int = 0,
        formStarted: Bool = false
    ) -> some View {
        Section("Split With") {
            Picker("Group", selection: selectedGroupID) {
                Text("No Group").tag(UUID?.none)
                ForEach(allGroups) { g in
                    Label(g.name, systemImage: g.iconName).tag(Optional(g.id))
                }
            }

            if selectedGroupID.wrappedValue == nil {
                // — Manual mode: current user + selectable friends —

                if let me = currentUser {
                    let meExcluded = excludedGroupMemberIDs.wrappedValue.contains(me.id)
                    let meIncluded = !meExcluded
                    Button {
                        if meExcluded { excludedGroupMemberIDs.wrappedValue.remove(me.id) }
                        else          { excludedGroupMemberIDs.wrappedValue.insert(me.id) }
                    } label: {
                        HStack(spacing: 12) {
                            avatarView(me)
                            Text("\(me.name) (you)")
                                .foregroundStyle(meIncluded ? .primary : .secondary)
                            Spacer()
                            Image(systemName: meIncluded ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(meIncluded ? .cyan : .secondary).font(.title3)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(me.name), \(meIncluded ? "included" : "excluded")")
                }

                if friends.isEmpty {
                    Text("Add friends to split with them")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    // Search bar for long friend lists
                    if friends.count > 5 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search friends…", text: participantSearchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if !participantSearchText.wrappedValue.isEmpty {
                                Button { participantSearchText.wrappedValue = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.subheadline)
                        .accessibilityLabel("Search friends")
                    }

                    let filteredFriends = participantSearchText.wrappedValue.isEmpty
                        ? friends
                        : friends.filter { $0.name.localizedCaseInsensitiveContains(participantSearchText.wrappedValue) }

                    ForEach(filteredFriends) { friend in
                        let isSelected = selectedParticipantIDs.wrappedValue.contains(friend.id)
                        Button {
                            if isSelected { selectedParticipantIDs.wrappedValue.remove(friend.id) }
                            else          { selectedParticipantIDs.wrappedValue.insert(friend.id) }
                        } label: {
                            HStack(spacing: 12) {
                                avatarView(friend)
                                Text(friend.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? .cyan : .secondary).font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(friend.name), \(isSelected ? "selected" : "not selected")")
                    }

                    if filteredFriends.isEmpty && !participantSearchText.wrappedValue.isEmpty {
                        Text("No friends matching \"\(participantSearchText.wrappedValue)\"")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                if let error = ExpenseFormLogic.participantError(
                    count: participantCount, formStarted: formStarted
                ) {
                    FormErrorMessage(message: error, isVisible: true)
                }
            } else {
                // — Group mode: toggleable member checkmarks —

                let members = selectedGroup?.members ?? []
                if members.isEmpty {
                    Text("This group has no members yet").foregroundStyle(.secondary)
                } else {
                    // Search bar for large groups
                    if members.count > 5 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Search members…", text: participantSearchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if !participantSearchText.wrappedValue.isEmpty {
                                Button { participantSearchText.wrappedValue = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.subheadline)
                        .accessibilityLabel("Search group members")
                    }

                    let filteredMembers = participantSearchText.wrappedValue.isEmpty
                        ? members
                        : members.filter { $0.name.localizedCaseInsensitiveContains(participantSearchText.wrappedValue) }

                    ForEach(filteredMembers) { member in
                        let isCurrentUser = member.id == currentUser?.id
                        let isExcluded = excludedGroupMemberIDs.wrappedValue.contains(member.id)
                        let isIncluded = !isExcluded

                        Button {
                            if isExcluded { excludedGroupMemberIDs.wrappedValue.remove(member.id) }
                            else          { excludedGroupMemberIDs.wrappedValue.insert(member.id) }
                        } label: {
                            HStack(spacing: 12) {
                                avatarView(member)
                                Text(isCurrentUser ? "\(member.name) (you)" : member.name)
                                    .foregroundStyle(isIncluded ? .primary : .secondary)
                                Spacer()
                                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isIncluded ? .cyan : .secondary).font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(member.name), \(isIncluded ? "included" : "excluded")")
                    }

                    if filteredMembers.isEmpty && !participantSearchText.wrappedValue.isEmpty {
                        Text("No members matching \"\(participantSearchText.wrappedValue)\"")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                if let error = ExpenseFormLogic.participantError(
                    count: participantCount, formStarted: formStarted
                ) {
                    FormErrorMessage(message: error, isVisible: true)
                }
            }
        }
    }

    // MARK: - Paid By Section

    @ViewBuilder
    static func paidBySection(
        selectedPayerID: Binding<UUID?>,
        currentUser: User?,
        participantList: [User]
    ) -> some View {
        Section("Paid By") {
            Picker("Who paid?", selection: selectedPayerID) {
                Text(currentUser.map { "\($0.name) (you)" } ?? "You")
                    .tag(UUID?.none)
                ForEach(participantList.filter { $0.id != currentUser?.id }) { p in
                    Text(p.name).tag(Optional(p.id))
                }
            }
        }
    }

    // MARK: - Split Type Section

    @ViewBuilder
    static func splitTypeSection(
        splitType: Binding<SplitType>,
        participantList: [User],
        currentUser: User?,
        amount: Double,
        equalShare: Double,
        customAmounts: Binding<[UUID: String]>,
        customTotal: Double,
        percentages: Binding<[UUID: String]>,
        percentageTotal: Double
    ) -> some View {
        Section("Split Type") {
            Picker("How to split", selection: splitType) {
                ForEach(SplitType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch splitType.wrappedValue {
            case .equal:
                ForEach(participantList) { p in
                    HStack {
                        avatarView(p)
                        Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                        Spacer()
                        Text(amount > 0 ? "\(CurrencyHelper.symbol)\(equalShare, specifier: "%.2f")" : "—")
                            .foregroundStyle(.secondary)
                    }
                }

            case .custom:
                ForEach(participantList) { p in
                    HStack(spacing: 8) {
                        avatarView(p)
                        Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                        Spacer()
                        Text(CurrencyHelper.symbol).foregroundStyle(.secondary)
                        TextField("0.00", text: Binding(
                            get: { customAmounts.wrappedValue[p.id] ?? "" },
                            set: { customAmounts.wrappedValue[p.id] = $0 }
                        ))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                HStack {
                    Text("Assigned").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(CurrencyHelper.symbol)\(customTotal, specifier: "%.2f") / \(CurrencyHelper.symbol)\(amount, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(abs(customTotal - amount) < 0.01 ? .green : .red)
                }
                if let error = ExpenseFormLogic.customSplitError(
                    customTotal: customTotal, expenseAmount: amount
                ) {
                    FormErrorMessage(message: error, isVisible: true)
                }

            case .percentage:
                ForEach(participantList) { p in
                    HStack(spacing: 8) {
                        avatarView(p)
                        Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                        Spacer()
                        TextField("0", text: Binding(
                            get: { percentages.wrappedValue[p.id] ?? "" },
                            set: { percentages.wrappedValue[p.id] = $0 }
                        ))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                        Text("%").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(percentageTotal, specifier: "%.1f")% / 100%")
                        .font(.caption)
                        .foregroundColor(abs(percentageTotal - 100) < 0.01 ? .green : .red)
                }
                if let error = ExpenseFormLogic.percentageSplitError(
                    percentageTotal: percentageTotal
                ) {
                    FormErrorMessage(message: error, isVisible: true)
                }
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    static func notesSection(notes: Binding<String>) -> some View {
        Section("Notes (optional)") {
            TextField("Add a note…", text: notes, axis: .vertical).lineLimit(3...6)
        }
    }

    // MARK: - Receipt Section (multiple images)
    //
    // NOTE: Camera and photo-picker presentations are handled by the
    // PARENT view (AddExpenseView / EditExpenseView) to avoid the
    // "already presenting" crash when this section lives inside a sheet.

    @ViewBuilder
    static func receiptSection(
        selectedPhotos: Binding<[PhotosPickerItem]>,
        receiptImages: Binding<[Data]>,
        isLoadingImage: Binding<Bool>,
        showCamera: Binding<Bool>
    ) -> some View {
        Section("Receipts (optional)") {
            // Existing images
            if !receiptImages.wrappedValue.isEmpty {
                ForEach(Array(receiptImages.wrappedValue.enumerated()), id: \.offset) { index, data in
                    if let uiImage = UIImage(data: data) {
                        HStack(spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Receipt \(index + 1)")
                                    .font(.subheadline).fontWeight(.medium)
                                let kb = data.count / 1024
                                Text("\(kb) KB")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                withAnimation {
                                    _ = receiptImages.wrappedValue.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if isLoadingImage.wrappedValue {
                HStack {
                    Spacer()
                    ProgressView("Loading image…")
                    Spacer()
                }
                .padding(.vertical, 10)
            }

            // Add more buttons
            VStack(spacing: 10) {
                if CameraAccess.isAvailable {
                    Button {
                        showCamera.wrappedValue = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered).tint(.cyan)
                }

                PhotosPicker(
                    selection: selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .tint(CameraAccess.isAvailable ? .secondary : .cyan)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Avatar Helper (delegates to shared AvatarView)

    @ViewBuilder
    static func avatarView(_ user: User, size: CGFloat = 30) -> some View {
        AvatarView(user: user, size: size)
    }
}
