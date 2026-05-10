//
//  ExpenseFormSections.swift
//  BillSplitter
//
//  Shared form sections extracted from AddExpenseView & EditExpenseView
//  to eliminate ~300 lines of duplicated code.
//

import SwiftUI
import SwiftData

// MARK: - Shared Category Data

enum ExpenseCategories {
    static let all: [(id: String, icon: String, label: String)] = [
        ("general",       "square.grid.2x2.fill", "General"),
        ("food",          "fork.knife",            "Food"),
        ("transport",     "car.fill",              "Transport"),
        ("accommodation", "house.fill",            "Stay"),
        ("entertainment", "theatermasks.fill",     "Fun"),
        ("shopping",      "cart.fill",             "Shopping"),
        ("utilities",     "bolt.fill",             "Utilities"),
        ("travel",        "airplane",              "Travel"),
    ]

    static func icon(for category: String) -> String {
        all.first { $0.id == category }?.icon ?? "square.grid.2x2.fill"
    }
}

// MARK: - Shared Form Sections

/// Reusable sections shared between Add and Edit expense views.
/// Requires the host view to supply its state via bindings.
struct ExpenseFormSections {

    // MARK: - Amount Section

    @ViewBuilder
    static func amountSection(amountText: Binding<String>) -> some View {
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
        category: Binding<String>
    ) -> some View {
        Section("Details") {
            TextField("What's this for?", text: description)
                .textInputAutocapitalization(.sentences)
            DatePicker("Date", selection: date, displayedComponents: .date)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExpenseCategories.all, id: \.id) { cat in
                        Button { category.wrappedValue = cat.id } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon).font(.title3)
                                Text(cat.label).font(.caption2)
                            }
                            .frame(width: 64, height: 56)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(category.wrappedValue == cat.id
                                      ? Color.cyan.opacity(0.18)
                                      : Color(.secondarySystemBackground)))
                            .foregroundColor(category.wrappedValue == cat.id ? .cyan : .secondary)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(category.wrappedValue == cat.id ? Color.cyan : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
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
        selectedParticipantIDs: Binding<Set<UUID>>
    ) -> some View {
        Section("Split With") {
            Picker("Group", selection: selectedGroupID) {
                Text("No Group").tag(UUID?.none)
                ForEach(allGroups) { g in
                    Label(g.name, systemImage: g.iconName).tag(Optional(g.id))
                }
            }

            if selectedGroupID.wrappedValue == nil {
                if let me = currentUser {
                    HStack(spacing: 12) {
                        avatarView(me)
                        Text("\(me.name) (you)").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cyan).font(.title3)
                    }
                }

                if friends.isEmpty {
                    Text("Add friends to split with them")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(friends) { friend in
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
                    }
                }
            } else {
                let members = selectedGroup?.members ?? []
                if members.isEmpty {
                    Text("This group has no members yet").foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            avatarView(member)
                            Text(member.id == currentUser?.id ? "\(member.name) (you)" : member.name)
                        }
                    }
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
        splitType: Binding<String>,
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
                Text("Equal").tag("equal")
                Text("Custom \(CurrencyHelper.symbol)").tag("custom")
                Text("By %").tag("percentage")
            }
            .pickerStyle(.segmented)

            switch splitType.wrappedValue {
            case "equal":
                ForEach(participantList) { p in
                    HStack {
                        avatarView(p)
                        Text(p.id == currentUser?.id ? "\(p.name) (you)" : p.name)
                        Spacer()
                        Text(amount > 0 ? "\(CurrencyHelper.symbol)\(equalShare, specifier: "%.2f")" : "—")
                            .foregroundStyle(.secondary)
                    }
                }

            case "custom":
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

            case "percentage":
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

            default:
                EmptyView()
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

    // MARK: - Avatar Helper

    @ViewBuilder
    static func avatarView(_ user: User, size: CGFloat = 30) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: user.profileColor).opacity(0.2))
                .frame(width: size, height: size)
            Text(String(user.name.prefix(1)))
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(Color(hex: user.profileColor))
        }
    }
}
