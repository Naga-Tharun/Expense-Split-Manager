//
//  AddMemberSheet.swift
//  BillSplitter
//
//  Presents non-member friends so the user can tap to add them to a group.
//

import SwiftUI
import SwiftData

struct AddMemberSheet: View {
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var modelContext
    let group:         Group
    let allUsers:      [User]
    let currentUserID: UUID?
    @State private var saveError = SaveErrorState()

    private var nonMembers: [User] {
        let memberIDs = Set((group.members ?? []).map { $0.id })
        return allUsers.filter { !memberIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            memberListContent
                .navigationTitle("Add Member")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
                .saveErrorAlert($saveError)
        }
    }

    @ViewBuilder
    private var memberListContent: some View {
        if nonMembers.isEmpty {
            ContentUnavailableView(
                "Everyone's In",
                systemImage: "person.badge.checkmark.fill",
                description: Text("All friends are already members")
            )
        } else {
            List(nonMembers) { user in
                Button {
                    var members = group.members ?? []
                    members.append(user)
                    group.members = members
                    saveError.perform { try modelContext.save() }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(user: user, size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.name).foregroundStyle(.primary).font(.body)
                            if user.id == currentUserID {
                                Text("you").font(.caption2).foregroundStyle(.cyan)
                            }
                        }
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.cyan)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    AddMemberSheet(
        group: Group(name: "Flatmates", iconName: "house.fill"),
        allUsers: [],
        currentUserID: nil
    )
    .preferredColorScheme(.dark)
}
